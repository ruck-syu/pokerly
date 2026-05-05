import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../game/game_controller.dart';
import '../../services/lan/lan_join_code.dart';
import '../../services/lan/lan_serialization.dart';
import '../../services/lan/lan_transport.dart';
import '../../services/lan/lan_types.dart';
import 'game_screen.dart';

class LanHostLobbyScreen extends StatefulWidget {
  const LanHostLobbyScreen({super.key});

  @override
  State<LanHostLobbyScreen> createState() => _LanHostLobbyScreenState();
}

class _LanHostLobbyScreenState extends State<LanHostLobbyScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Host');
  final LanTransport _transport = createLanTransport();
  int _startingChips = 2000;
  int _smallBlind = 25;
  int _bigBlind = 50;
  HostSession? _session;
  StreamSubscription<HostEvent>? _sub;
  List<LanPlayerInfo> _players = const [];
  bool _starting = false;
  bool _launchedGame = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    unawaited(_sub?.cancel());
    if (!_launchedGame) {
      unawaited(_session?.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_transport.supported) {
      return const _UnsupportedLanScaffold();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Host LAN Game')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _session == null
            ? SingleChildScrollView(
                padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom + 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Your name'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _startingChips,
                      decoration: const InputDecoration(labelText: 'Starting chips'),
                      items: const [
                        DropdownMenuItem(value: 1000, child: Text('1000')),
                        DropdownMenuItem(value: 1500, child: Text('1500')),
                        DropdownMenuItem(value: 2000, child: Text('2000')),
                        DropdownMenuItem(value: 3000, child: Text('3000')),
                        DropdownMenuItem(value: 5000, child: Text('5000')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _startingChips = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _smallBlind,
                      decoration: const InputDecoration(labelText: 'Small blind'),
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10')),
                        DropdownMenuItem(value: 25, child: Text('25')),
                        DropdownMenuItem(value: 50, child: Text('50')),
                        DropdownMenuItem(value: 100, child: Text('100')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _smallBlind = value;
                            if (_bigBlind <= _smallBlind) {
                              _bigBlind = _smallBlind * 2;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _bigBlind,
                      decoration: const InputDecoration(labelText: 'Big blind'),
                      items: const [
                        DropdownMenuItem(value: 20, child: Text('20')),
                        DropdownMenuItem(value: 50, child: Text('50')),
                        DropdownMenuItem(value: 100, child: Text('100')),
                        DropdownMenuItem(value: 200, child: Text('200')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _bigBlind = value > _smallBlind ? value : (_smallBlind * 2));
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _starting ? null : _createLobby,
                      child: Text(_starting ? 'Creating...' : 'Create Lobby'),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_session!.hostIp != null)
                    _JoinCodeTile(
                      code: LanJoinCodeService.encode(
                            hostIp: _session!.hostIp!,
                            port: _session!.port,
                          ) ??
                          'UNAVAILABLE',
                    ),
                  const SizedBox(height: 8),
                  Text('Chips $_startingChips • Blinds $_smallBlind/$_bigBlind'),
                  const SizedBox(height: 8),
                  Text('Players (${_players.length}/10)'),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _players.length,
                      itemBuilder: (context, index) {
                        final p = _players[index];
                        return ListTile(
                          title: Text(p.name),
                          trailing: p.isHost ? const Text('HOST') : const Text('CLIENT'),
                        );
                      },
                    ),
                  ),
                  FilledButton(
                    onPressed: _players.length >= 2 && _players.length <= 10 ? _startGame : null,
                    child: const Text('Start Game'),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    ),
                ],
              ),
        ),
    );
  }

  Future<void> _createLobby() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final session = await _transport.hostGame(hostName: _nameController.text.trim().isEmpty ? 'Host' : _nameController.text.trim());
      _sub = session.events.listen((event) {
        setState(() {
          _players = event.players;
        });
      });
      setState(() {
        _session = session;
        _players = session.players;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  Future<void> _startGame() async {
    final session = _session;
    if (session == null) return;
    final container = ProviderScope.containerOf(context, listen: false);
    await container.read(gameControllerProvider.notifier).startLanHostSession(
          session: session,
          lobbyPlayers: _players,
          startingChips: _startingChips,
          smallBlind: _smallBlind,
          bigBlind: _bigBlind,
        );
    _launchedGame = true;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GameScreen()));
  }
}

class LanJoinScreen extends StatefulWidget {
  const LanJoinScreen({super.key});

  @override
  State<LanJoinScreen> createState() => _LanJoinScreenState();
}

class _LanJoinScreenState extends State<LanJoinScreen> {
  final LanTransport _transport = createLanTransport();
  final TextEditingController _nameController = TextEditingController(text: 'Player');
  final TextEditingController _codeController = TextEditingController();
  bool _joining = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_transport.supported) {
      return const _UnsupportedLanScaffold();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Join LAN Game')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Your name')),
            const SizedBox(height: 10),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Join code'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _joining ? null : _join,
              child: Text(_joining ? 'Joining...' : 'Join Lobby'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final name = _nameController.text.trim().isEmpty ? 'Player' : _nameController.text.trim();
      final decoded = LanJoinCodeService.decode(_codeController.text.trim());
      final hostIp = decoded?.hostIp;
      final port = decoded?.port ?? 4040;
      if (hostIp == null || hostIp.isEmpty) {
        throw const FormatException('Invalid join code');
      }

      final session = await _transport.joinGame(
        hostIp: hostIp,
        port: port,
        playerName: name,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LanClientLobbyScreen(session: session)),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      }
    }
  }
}

class _JoinCodeTile extends StatelessWidget {
  const _JoinCodeTile({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.withValues(alpha: 0.25),
            Colors.amber.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.password, size: 20, color: Colors.amberAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'JOIN CODE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Join code copied')));
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }
}

class LanClientLobbyScreen extends StatefulWidget {
  const LanClientLobbyScreen({required this.session, super.key});

  final ClientSession session;

  @override
  State<LanClientLobbyScreen> createState() => _LanClientLobbyScreenState();
}

class _LanClientLobbyScreenState extends State<LanClientLobbyScreen> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  List<LanPlayerInfo> _players = const [];
  bool _launchedGame = false;

  @override
  void initState() {
    super.initState();
    _players = widget.session.players;
    _sub = widget.session.messages.listen(_onMessage);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    if (!_launchedGame) {
      unawaited(widget.session.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LAN Lobby')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Waiting for host to start the game...'),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _players.length,
                itemBuilder: (context, index) {
                  final p = _players[index];
                  return ListTile(
                    title: Text(p.name),
                    trailing: p.isHost ? const Text('HOST') : const Text('CONNECTED'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onMessage(Map<String, dynamic> message) {
    final type = message['type'] as String? ?? '';
    if (type == 'LOBBY_UPDATE') {
      final players = (message['players'] as List<dynamic>)
          .map((e) => LanPlayerInfo.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
      if (mounted) {
        setState(() => _players = players);
      }
      return;
    }

    if (type == 'GAME_START') {
      final rawState = message['state'];
      if (rawState is! Map) return;
      final state = gameStateFromJson(Map<String, dynamic>.from(rawState));
      final container = ProviderScope.containerOf(context, listen: false);
      unawaited(
        container.read(gameControllerProvider.notifier).startLanClientSession(
              session: widget.session,
              initialState: state,
            ),
      );
      _launchedGame = true;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GameScreen()));
    }
  }
}

class _UnsupportedLanScaffold extends StatelessWidget {
  const _UnsupportedLanScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LAN Multiplayer')),
      body: const Center(
        child: Text('LAN sockets are not supported on this platform.'),
      ),
    );
  }
}
