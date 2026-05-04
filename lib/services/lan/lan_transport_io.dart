import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'lan_types.dart';

LanTransport createLanTransport() => _SocketLanTransport();

class _SocketLanTransport implements LanTransport {
  @override
  bool get supported => true;

  @override
  Future<HostSession> hostGame({required String hostName, int port = 4040}) async {
    final server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    final hostId = 'host_${DateTime.now().millisecondsSinceEpoch}';
    final hostIp = await localIpv4();
    return _SocketHostSession(
      server: server,
      hostPlayer: LanPlayerInfo(id: hostId, name: hostName, isHost: true),
      hostIp: hostIp,
    );
  }

  @override
  Future<ClientSession> joinGame({
    required String hostIp,
    required String playerName,
    int port = 4040,
  }) async {
    final socket = await Socket.connect(hostIp, port, timeout: const Duration(seconds: 6));
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    final lines = const LineSplitter().bind(utf8.decoder.bind(socket));
    final completer = Completer<_SocketClientSession>();

    lines.listen((line) {
      final message = jsonDecode(line) as Map<String, dynamic>;
      controller.add(message);
      if (message['type'] == 'JOIN_REJECTED' && !completer.isCompleted) {
        completer.completeError(SocketException((message['reason'] as String?) ?? 'Join rejected'));
        return;
      }
      if (message['type'] == 'JOIN_ACCEPTED' && !completer.isCompleted) {
        final playerId = message['playerId'] as String;
        final players = (message['players'] as List<dynamic>)
            .map((e) => LanPlayerInfo.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false);
        completer.complete(
          _SocketClientSession(
            socket: socket,
            playerId: playerId,
            players: players,
            messagesController: controller,
          ),
        );
      }
    }, onError: (e, st) {
      if (!completer.isCompleted) {
        completer.completeError(e, st);
      }
      controller.add({'type': 'ERROR', 'message': e.toString()});
    }, onDone: () {
      controller.add({'type': 'DISCONNECTED'});
    });

    socket.write('${jsonEncode({'type': 'JOIN_REQUEST', 'name': playerName})}\n');
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw SocketException('Timeout waiting for host response.'),
    );
  }

  @override
  Future<String?> localIpv4() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    for (final networkInterface in interfaces) {
      for (final addr in networkInterface.addresses) {
        if (!addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return null;
  }
}

class _SocketHostSession implements HostSession {
  _SocketHostSession({
    required ServerSocket server,
    required LanPlayerInfo hostPlayer,
    required this.hostIp,
  })  : _server = server,
        _players = [hostPlayer] {
    _serverSub = _server.listen(_onConnection);
  }

  final ServerSocket _server;
  final StreamController<HostEvent> _events = StreamController<HostEvent>.broadcast();
  final List<LanPlayerInfo> _players;
  final Map<String, Socket> _sockets = {};
  final Random _random = Random();
  StreamSubscription<Socket>? _serverSub;

  @override
  final String? hostIp;

  @override
  String get hostPlayerId => _players.first.id;

  @override
  int get port => _server.port;

  @override
  List<LanPlayerInfo> get players => List.unmodifiable(_players);

  @override
  Stream<HostEvent> get events => _events.stream;

  void _onConnection(Socket socket) {
    const LineSplitter()
        .bind(utf8.decoder.bind(socket))
        .listen((line) => _onMessage(socket, line), onDone: () => _onDisconnected(socket), onError: (_) => _onDisconnected(socket));
  }

  void _onMessage(Socket socket, String line) {
    final message = jsonDecode(line) as Map<String, dynamic>;
    final type = message['type'] as String? ?? '';
    if (type == 'JOIN_REQUEST') {
      final name = (message['name'] as String? ?? '').trim();
      if (name.isEmpty) {
        socket.write('${jsonEncode({'type': 'JOIN_REJECTED', 'reason': 'Invalid name'})}\n');
        return;
      }
      if (_players.length >= 10) {
        socket.write('${jsonEncode({'type': 'JOIN_REJECTED', 'reason': 'Lobby is full'})}\n');
        return;
      }
      final playerId = 'p_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(9999)}';
      _sockets[playerId] = socket;
      _players.add(LanPlayerInfo(id: playerId, name: name, isHost: false));
      socket.write(
        '${jsonEncode({'type': 'JOIN_ACCEPTED', 'playerId': playerId, 'players': _players.map((p) => p.toJson()).toList()})}\n',
      );
      unawaited(_broadcastLobbyUpdate());
      _events.add(HostEvent(type: HostEventType.playerJoined, playerId: playerId, players: players));
      return;
    }

    if (type == 'PLAYER_ACTION') {
      final playerId = message['playerId'] as String?;
      if (playerId == null || !_sockets.containsKey(playerId)) {
        return;
      }
      _events.add(
        HostEvent(
          type: HostEventType.playerAction,
          playerId: playerId,
          action: message['action'] as String?,
          amount: (message['amount'] as num?)?.toInt(),
          players: players,
        ),
      );
    }
  }

  void _onDisconnected(Socket socket) {
    String? disconnectedId;
    for (final entry in _sockets.entries) {
      if (entry.value == socket) {
        disconnectedId = entry.key;
        break;
      }
    }
    if (disconnectedId == null) {
      return;
    }
    _sockets.remove(disconnectedId);
    _players.removeWhere((p) => p.id == disconnectedId);
    unawaited(_broadcastLobbyUpdate());
    _events.add(HostEvent(type: HostEventType.playerDisconnected, playerId: disconnectedId, players: players));
  }

  Future<void> _broadcastLobbyUpdate() async {
    await broadcast({
      'type': 'LOBBY_UPDATE',
      'players': _players.map((p) => p.toJson()).toList(growable: false),
    });
  }

  @override
  Future<void> broadcast(Map<String, dynamic> message) async {
    final line = '${jsonEncode(message)}\n';
    for (final socket in _sockets.values) {
      socket.write(line);
    }
  }

  @override
  Future<void> sendTo(String playerId, Map<String, dynamic> message) async {
    final socket = _sockets[playerId];
    if (socket == null) return;
    socket.write('${jsonEncode(message)}\n');
  }

  @override
  Future<void> close() async {
    await _serverSub?.cancel();
    for (final socket in _sockets.values) {
      await socket.close();
    }
    _sockets.clear();
    await _server.close();
    await _events.close();
  }
}

class _SocketClientSession implements ClientSession {
  _SocketClientSession({
    required Socket socket,
    required this.playerId,
    required List<LanPlayerInfo> players,
    required StreamController<Map<String, dynamic>> messagesController,
  })  : _socket = socket,
        _players = players,
        _messagesController = messagesController;

  final Socket _socket;
  final List<LanPlayerInfo> _players;
  final StreamController<Map<String, dynamic>> _messagesController;

  @override
  final String playerId;

  @override
  List<LanPlayerInfo> get players => List.unmodifiable(_players);

  @override
  Stream<Map<String, dynamic>> get messages => _messagesController.stream;

  @override
  Future<void> send(Map<String, dynamic> message) async {
    _socket.write('${jsonEncode(message)}\n');
  }

  @override
  Future<void> close() async {
    await _socket.close();
    await _messagesController.close();
  }
}
