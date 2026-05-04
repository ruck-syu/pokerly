import 'dart:math';

import 'card.dart';

class DrawResult {
  const DrawResult({required this.deck, required this.cards});
  final Deck deck;
  final List<Card> cards;
}

class Deck {
  const Deck(this.cards);

  final List<Card> cards;

  factory Deck.standard52({Random? random}) {
    final buffer = <Card>[];
    for (final suit in CardSuit.values) {
      for (final rank in CardRank.values) {
        buffer.add(Card(rank: rank, suit: suit));
      }
    }
    buffer.shuffle(random);
    return Deck(List.unmodifiable(buffer));
  }

  DrawResult draw([int count = 1]) {
    if (count > cards.length) {
      throw StateError('Cannot draw $count cards from a deck of ${cards.length}');
    }
    final drawn = cards.take(count).toList(growable: false);
    final remaining = cards.skip(count).toList(growable: false);
    return DrawResult(deck: Deck(List.unmodifiable(remaining)), cards: drawn);
  }
}
