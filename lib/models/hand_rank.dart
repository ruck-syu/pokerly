enum HandRank {
  highCard(0, 'High Card'),
  pair(1, 'Pair'),
  twoPair(2, 'Two Pair'),
  threeOfAKind(3, 'Three of a Kind'),
  straight(4, 'Straight'),
  flush(5, 'Flush'),
  fullHouse(6, 'Full House'),
  fourOfAKind(7, 'Four of a Kind'),
  straightFlush(8, 'Straight Flush');

  const HandRank(this.strength, this.label);
  final int strength;
  final String label;
}

class HandValue implements Comparable<HandValue> {
  const HandValue({
    required this.rank,
    required this.kickers,
  });

  final HandRank rank;
  final List<int> kickers;

  @override
  int compareTo(HandValue other) {
    if (rank.strength != other.rank.strength) {
      return rank.strength.compareTo(other.rank.strength);
    }

    final maxLen = kickers.length > other.kickers.length ? kickers.length : other.kickers.length;
    for (var i = 0; i < maxLen; i++) {
      final lhs = i < kickers.length ? kickers[i] : 0;
      final rhs = i < other.kickers.length ? other.kickers[i] : 0;
      if (lhs != rhs) {
        return lhs.compareTo(rhs);
      }
    }

    return 0;
  }

  String describe() => rank.label;
}
