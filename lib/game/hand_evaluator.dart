import '../models/card.dart';
import '../models/hand_rank.dart';

class HandEvaluator {
  static HandRank evaluateHand(List<Card> cards) {
    return evaluateHandValue(cards).rank;
  }

  static HandValue evaluateHandValue(List<Card> cards) {
    if (cards.length < 5) {
      throw ArgumentError('At least 5 cards are required to evaluate a poker hand.');
    }
    if (cards.length == 5) {
      return _evaluateFive(cards);
    }

    HandValue? best;
    for (final combo in _fiveCardCombinations(cards)) {
      final value = _evaluateFive(combo);
      if (best == null || value.compareTo(best) > 0) {
        best = value;
      }
    }
    return best!;
  }

  static List<List<Card>> _fiveCardCombinations(List<Card> cards) {
    final combos = <List<Card>>[];
    for (var i = 0; i < cards.length - 4; i++) {
      for (var j = i + 1; j < cards.length - 3; j++) {
        for (var k = j + 1; k < cards.length - 2; k++) {
          for (var l = k + 1; l < cards.length - 1; l++) {
            for (var m = l + 1; m < cards.length; m++) {
              combos.add([cards[i], cards[j], cards[k], cards[l], cards[m]]);
            }
          }
        }
      }
    }
    return combos;
  }

  static HandValue _evaluateFive(List<Card> cards) {
    final ranks = cards.map((c) => c.rank.value).toList()..sort((a, b) => b.compareTo(a));
    final rankCounts = <int, int>{};
    for (final rank in ranks) {
      rankCounts.update(rank, (value) => value + 1, ifAbsent: () => 1);
    }

    final isFlush = cards.every((c) => c.suit == cards.first.suit);
    final straightHigh = _straightHigh(ranks);

    final grouped = rankCounts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) {
          return byCount;
        }
        return b.key.compareTo(a.key);
      });

    if (isFlush && straightHigh != null) {
      return HandValue(rank: HandRank.straightFlush, kickers: [straightHigh]);
    }

    if (grouped.first.value == 4) {
      final quad = grouped.first.key;
      final kicker = grouped.firstWhere((g) => g.value == 1).key;
      return HandValue(rank: HandRank.fourOfAKind, kickers: [quad, kicker]);
    }

    if (grouped.first.value == 3 && grouped.length > 1 && grouped[1].value >= 2) {
      return HandValue(rank: HandRank.fullHouse, kickers: [grouped[0].key, grouped[1].key]);
    }

    if (isFlush) {
      return HandValue(rank: HandRank.flush, kickers: ranks);
    }

    if (straightHigh != null) {
      return HandValue(rank: HandRank.straight, kickers: [straightHigh]);
    }

    if (grouped.first.value == 3) {
      final trips = grouped.first.key;
      final kickers = grouped.where((g) => g.value == 1).map((g) => g.key).toList()..sort((a, b) => b.compareTo(a));
      return HandValue(rank: HandRank.threeOfAKind, kickers: [trips, ...kickers]);
    }

    if (grouped.first.value == 2 && grouped[1].value == 2) {
      final highPair = grouped[0].key > grouped[1].key ? grouped[0].key : grouped[1].key;
      final lowPair = grouped[0].key > grouped[1].key ? grouped[1].key : grouped[0].key;
      final kicker = grouped.firstWhere((g) => g.value == 1).key;
      return HandValue(rank: HandRank.twoPair, kickers: [highPair, lowPair, kicker]);
    }

    if (grouped.first.value == 2) {
      final pair = grouped.first.key;
      final kickers = grouped.where((g) => g.value == 1).map((g) => g.key).toList()..sort((a, b) => b.compareTo(a));
      return HandValue(rank: HandRank.pair, kickers: [pair, ...kickers]);
    }

    return HandValue(rank: HandRank.highCard, kickers: ranks);
  }

  static int? _straightHigh(List<int> ranks) {
    final unique = ranks.toSet().toList()..sort((a, b) => b.compareTo(a));
    if (unique.contains(14)) {
      unique.add(1);
    }
    var streak = 1;
    for (var i = 0; i < unique.length - 1; i++) {
      if (unique[i] - 1 == unique[i + 1]) {
        streak++;
        if (streak >= 5) {
          return unique[i - 3];
        }
      } else {
        streak = 1;
      }
    }
    return null;
  }
}
