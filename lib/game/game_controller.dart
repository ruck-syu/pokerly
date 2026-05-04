import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart' as constants;
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/bot_ai_service.dart';
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
            players: _buildPlayers(botCount: constants.maxBots),
            smallBlind: constants.smallBlind,
            bigBlind: constants.bigBlind,
          ),
        ) {
    startGame(botCount: constants.maxBots);
  }

  final PokerEngine _engine;
  final BotAiService _botAi;
  Timer? _botTimer;

  static List<Player> _buildPlayers({required int botCount}) {
    final players = <Player>[
      const Player(
        id: 'human',
        name: 'You',
        chips: constants.startingChips,
        isBot: false,
        aiLevel: 0,
      ),
    ];

    for (var i = 0; i < botCount; i++) {
      players.add(
        Player(
          id: 'bot_$i',
          name: 'Bot ${i + 1}',
          chips: constants.startingChips,
          isBot: true,
          aiLevel: i.isEven ? 1 : 2,
        ),
      );
    }
    return players;
  }

  void startGame({required int botCount}) {
    final players = _buildPlayers(botCount: botCount);
    state = GameState.initial(
      players: players,
      smallBlind: constants.smallBlind,
      bigBlind: constants.bigBlind,
    );
    state = _engine.startNewHand(state);
    SoundService.playDeal();
    _maybeRunBotTurn();
  }

  void nextHand() {
    state = _engine.startNewHand(state);
    SoundService.playDeal();
    _maybeRunBotTurn();
  }

  void fold() => _applyAction(const PlayerAction(type: PlayerActionType.fold));
  void check() => _applyAction(const PlayerAction(type: PlayerActionType.check));
  void call() => _applyAction(const PlayerAction(type: PlayerActionType.call));
  void raiseTo(int value) => _applyAction(PlayerAction(type: PlayerActionType.raise, raiseTo: value));

  void _applyAction(PlayerAction action) {
    final previousPot = state.pot;
    final previousComplete = state.isHandComplete;
    state = _engine.applyAction(state, action);

    if (state.pot > previousPot) {
      SoundService.playBet();
    }
    if (!previousComplete && state.isHandComplete) {
      final humanWon = state.winnerIndexes.contains(state.humanPlayerIndex);
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
    if (state.isHandComplete) {
      return;
    }
    final current = state.currentPlayer;
    if (!current.isBot) {
      return;
    }

    _botTimer = Timer(constants.botActionDelay, () {
      if (state.isHandComplete || !state.currentPlayer.isBot) {
        return;
      }
      final idx = state.currentTurnIndex;
      final decision = _botAi.decideAction(state, idx);
      _applyAction(decision);
    });
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }
}
