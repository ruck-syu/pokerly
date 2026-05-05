import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart' as constants;
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/bot_ai_service.dart';
import '../services/lan/lan_serialization.dart';
import '../services/lan/lan_types.dart';
import '../services/sound_service.dart';
import 'poker_engine.dart';

final botAiProvider = Provider<BotAiService>((ref) => BotAiService());

final gameControllerProvider = StateNotifierProvider<GameController, GameState>((ref) {
  return GameController(ref.read(botAiProvider));
});

class GameController extends StateNotifier<GameState> {
  GameController(this._botAi)
      : _engine = PokerEngine(),
        super(
          GameState.initial(
            players: _buildPlayers(
              botCount: constants.maxBots,
              startingChips: constants.startingChips,
            ),
            smallBlind: constants.smallBlind,
            bigBlind: constants.bigBlind,
          ),
        ) {
    _localPlayerId = 'human';
    startGame(botCount: constants.maxBots);
  }

  final PokerEngine _engine;
  final BotAiService _botAi;
  Timer? _botTimer;
  HostSession? _hostSession;
  ClientSession? _clientSession;
  StreamSubscription<HostEvent>? _hostSub;
  StreamSubscription<Map<String, dynamic>>? _clientSub;
  String _lanRole = LanRole.none;
  String? _localPlayerId;
  bool _awaitingHostAck = false;

  bool get isLan => _lanRole != LanRole.none;
  bool get isLanHost => _lanRole == LanRole.host;
  bool get isLanClient => _lanRole == LanRole.client;
  String? get localPlayerId => _localPlayerId;
  bool get awaitingHostAck => _awaitingHostAck;

  int get localPlayerIndex {
    final id = _localPlayerId;
    if (id == null) return state.humanPlayerIndex;
    final idx = state.players.indexWhere((p) => p.id == id);
    if (idx == -1) return state.humanPlayerIndex;
    return idx;
  }

  bool canLocalPlayerAct() {
    if (state.isHandComplete) {
      return false;
    }
    return state.currentTurnIndex == localPlayerIndex;
  }

  static List<Player> _buildPlayers({
    required int botCount,
    required int startingChips,
  }) {
    final players = <Player>[
      Player(
        id: 'human',
        name: 'You',
        chips: startingChips,
        isBot: false,
        aiLevel: 0,
      ),
    ];

    for (var i = 0; i < botCount; i++) {
      final personalityLevels = [1, 2, 3, 4];
      players.add(
        Player(
          id: 'bot_$i',
          name: 'Bot ${i + 1}',
          chips: startingChips,
          isBot: true,
          aiLevel: personalityLevels[i % personalityLevels.length],
        ),
      );
    }
    return players;
  }

  Future<void> startLanHostSession({
    required HostSession session,
    required List<LanPlayerInfo> lobbyPlayers,
    required int startingChips,
    required int smallBlind,
    required int bigBlind,
  }) async {
    await _clearLanSession();
    _lanRole = LanRole.host;
    _hostSession = session;
    _localPlayerId = session.hostPlayerId;
    _hostSub = session.events.listen(_onHostEvent);

    final players = lobbyPlayers
        .map(
          (p) => Player(
            id: p.id,
            name: p.name,
            chips: startingChips,
            isBot: false,
            aiLevel: 0,
          ),
        )
        .toList(growable: false);

    state = GameState.initial(
      players: players,
      smallBlind: smallBlind,
      bigBlind: bigBlind,
    );
    state = _engine.startNewHand(state);
    await session.broadcast({
      'type': 'GAME_START',
      'state': gameStateToJson(state),
    });
  }

  Future<void> startLanClientSession({
    required ClientSession session,
    required GameState initialState,
  }) async {
    await _clearLanSession();
    _lanRole = LanRole.client;
    _clientSession = session;
    _localPlayerId = session.playerId;
    state = initialState;
    _clientSub = session.messages.listen(_onClientMessage);
  }

  void startGame({
    required int botCount,
    int? startingChips,
    int? smallBlind,
    int? bigBlind,
    bool tournamentMode = false,
    int handsPerLevel = 5,
  }) {
    final configuredStartingChips = startingChips ?? constants.startingChips;
    final configuredSmallBlind = smallBlind ?? constants.smallBlind;
    final configuredBigBlind = bigBlind ?? constants.bigBlind;
    _lanRole = LanRole.none;
    _localPlayerId = 'human';
    _awaitingHostAck = false;
    final players = _buildPlayers(
      botCount: botCount,
      startingChips: configuredStartingChips,
    );
    _botAi.resetMemory();
    state = GameState.initial(
      players: players,
      smallBlind: configuredSmallBlind,
      bigBlind: configuredBigBlind,
      isTournamentMode: tournamentMode,
      handsPerLevel: handsPerLevel,
    );
    state = _engine.startNewHand(state);
    SoundService.playDeal();
    _maybeRunBotTurn();
  }

  void nextHand() {
    state = _engine.startNewHand(state);
    SoundService.playDeal();
    _maybeRunBotTurn();
    if (isLanHost) {
      unawaited(_broadcastStateUpdate());
    }
  }

  void toggleSitOut() {
    if (isLanClient) return; // TODO: Implement for LAN clients if needed
    final players = state.players.toList(growable: false);
    final p = players[localPlayerIndex];
    players[localPlayerIndex] = p.copyWith(isSittingOut: !p.isSittingOut);
    state = state.copyWith(players: players);
    if (isLanHost) {
      unawaited(_broadcastStateUpdate());
    }
  }

  void rebuy(int amount) {
    if (isLanClient) return; // TODO: Implement for LAN clients if needed
    final players = state.players.toList(growable: false);
    final p = players[localPlayerIndex];
    players[localPlayerIndex] = p.copyWith(chips: p.chips + amount);
    state = state.copyWith(players: players);
    if (isLanHost) {
      unawaited(_broadcastStateUpdate());
    }
  }

  void fold() => _applyAction(const PlayerAction(type: PlayerActionType.fold));
  void check() => _applyAction(const PlayerAction(type: PlayerActionType.check));
  void call() => _applyAction(const PlayerAction(type: PlayerActionType.call));
  void raiseTo(int value) => _applyAction(PlayerAction(type: PlayerActionType.raise, raiseTo: value));

  void _applyAction(PlayerAction action) {
    if (isLanClient) {
      if (!canLocalPlayerAct() || _awaitingHostAck) {
        return;
      }
      _awaitingHostAck = true;
      final actionType = switch (action.type) {
        PlayerActionType.fold => 'FOLD',
        PlayerActionType.check => 'CHECK',
        PlayerActionType.call => 'CALL',
        PlayerActionType.raise => 'RAISE',
      };
      unawaited(
        _clientSession?.send({
          'type': 'PLAYER_ACTION',
          'playerId': _localPlayerId,
          'action': actionType,
          'amount': action.raiseTo,
        }) ??
            Future<void>.value(),
      );
      return;
    }

    _applyLocalAction(action);
    if (isLanHost) {
      unawaited(_broadcastStateUpdate());
    }
  }

  void _applyLocalAction(PlayerAction action) {
    final actorIndex = state.currentTurnIndex;
    final actorId = state.players[actorIndex].id;
    final previousActorAction = state.players[actorIndex].lastAction;
    final previousPot = state.pot;
    final previousComplete = state.isHandComplete;
    state = _engine.applyAction(state, action);
    final newActorAction = state.players[actorIndex].lastAction;
    if (newActorAction.isNotEmpty && newActorAction != previousActorAction) {
      _botAi.observeAction(actorId, newActorAction);
    }

    if (state.pot > previousPot) {
      SoundService.playBet();
    }
    if (!previousComplete && state.isHandComplete) {
      final humanWon = state.winnerIndexes.contains(localPlayerIndex);
      if (humanWon) {
        SoundService.playWin();
      } else {
        SoundService.playLose();
      }
    }

    _maybeRunBotTurn();
  }

  void _maybeRunBotTurn() {
    _botTimer?.cancel();
    if (state.isHandComplete || isLan) {
      return;
    }
    final current = state.currentPlayer;
    if (!current.isBot) {
      return;
    }

    final delay = _botAi.thinkDelayFor(state, state.currentTurnIndex);
    _botTimer = Timer(delay, () {
      if (state.isHandComplete || !state.currentPlayer.isBot) {
        return;
      }
      final idx = state.currentTurnIndex;
      final decision = _botAi.decideAction(state, idx);
      _applyLocalAction(decision);
    });
  }

  Future<void> _broadcastStateUpdate() async {
    final hostSession = _hostSession;
    if (hostSession == null) return;
    await hostSession.broadcast({
      'type': 'STATE_UPDATE',
      'state': gameStateToJson(state),
    });
  }

  void _onHostEvent(HostEvent event) {
    switch (event.type) {
      case HostEventType.playerJoined:
        break;
      case HostEventType.playerAction:
        final action = event.action;
        final actorId = event.playerId;
        if (action == null || actorId == null) return;
        if (state.currentPlayer.id != actorId) {
          return;
        }
        final mapped = switch (action) {
          'FOLD' => const PlayerAction(type: PlayerActionType.fold),
          'CHECK' => const PlayerAction(type: PlayerActionType.check),
          'CALL' => const PlayerAction(type: PlayerActionType.call),
          'RAISE' => PlayerAction(type: PlayerActionType.raise, raiseTo: event.amount),
          _ => null,
        };
        if (mapped == null) return;
        _applyLocalAction(mapped);
        unawaited(_broadcastStateUpdate());
      case HostEventType.playerDisconnected:
        final disconnectedId = event.playerId;
        if (disconnectedId == null) return;
        if (state.currentPlayer.id == disconnectedId) {
          _applyLocalAction(const PlayerAction(type: PlayerActionType.fold));
        } else {
          final players = state.players.toList(growable: false);
          final idx = players.indexWhere((p) => p.id == disconnectedId);
          if (idx >= 0) {
            players[idx] = players[idx].copyWith(
              hasFolded: true,
              lastAction: 'Disconnected',
            );
            state = state.copyWith(players: players);
          }
        }
        unawaited(
          _hostSession?.broadcast({'type': 'PLAYER_DISCONNECTED', 'playerId': disconnectedId}) ?? Future<void>.value(),
        );
        unawaited(_broadcastStateUpdate());
    }
  }

  void _onClientMessage(Map<String, dynamic> message) {
    final type = message['type'] as String? ?? '';
    if (type == 'STATE_UPDATE' || type == 'GAME_START') {
      final raw = message['state'];
      if (raw is Map) {
        state = gameStateFromJson(Map<String, dynamic>.from(raw));
        _awaitingHostAck = false;
      }
      return;
    }
    if (type == 'DISCONNECTED') {
      state = state.copyWith(handMessage: 'Disconnected from host.');
      _awaitingHostAck = false;
    }
  }

  Future<void> _clearLanSession() async {
    await _hostSub?.cancel();
    await _clientSub?.cancel();
    _hostSub = null;
    _clientSub = null;
    _hostSession = null;
    _clientSession = null;
    _awaitingHostAck = false;
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    unawaited(_hostSub?.cancel());
    unawaited(_clientSub?.cancel());
    super.dispose();
  }
}
