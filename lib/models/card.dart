enum CardSuit { clubs, diamonds, hearts, spades }

enum CardRank {
  two(2, '2'),
  three(3, '3'),
  four(4, '4'),
  five(5, '5'),
  six(6, '6'),
  seven(7, '7'),
  eight(8, '8'),
  nine(9, '9'),
  ten(10, '10'),
  jack(11, 'J'),
  queen(12, 'Q'),
  king(13, 'K'),
  ace(14, 'A');

  const CardRank(this.value, this.symbol);
  final int value;
  final String symbol;
}

class Card {
  const Card({required this.rank, required this.suit});

  final CardRank rank;
  final CardSuit suit;

  String get suitSymbol => switch (suit) {
        CardSuit.clubs => '♣',
        CardSuit.diamonds => '♦',
        CardSuit.hearts => '♥',
        CardSuit.spades => '♠',
      };

  bool get isRed => suit == CardSuit.hearts || suit == CardSuit.diamonds;

  String get label => '${rank.symbol}$suitSymbol';
}
