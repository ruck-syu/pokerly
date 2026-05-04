import 'package:flutter_test/flutter_test.dart';
import 'package:pokerly/game/hand_evaluator.dart';
import 'package:pokerly/models/card.dart';
import 'package:pokerly/models/hand_rank.dart';

Card c(CardRank rank, CardSuit suit) => Card(rank: rank, suit: suit);

void main() {
  test('detects straight flush', () {
    final value = HandEvaluator.evaluateHandValue([
      c(CardRank.ten, CardSuit.hearts),
      c(CardRank.jack, CardSuit.hearts),
      c(CardRank.queen, CardSuit.hearts),
      c(CardRank.king, CardSuit.hearts),
      c(CardRank.ace, CardSuit.hearts),
      c(CardRank.two, CardSuit.clubs),
      c(CardRank.three, CardSuit.diamonds),
    ]);

    expect(value.rank, HandRank.straightFlush);
  });

  test('compares full house over flush', () {
    final fullHouse = HandEvaluator.evaluateHandValue([
      c(CardRank.king, CardSuit.spades),
      c(CardRank.king, CardSuit.hearts),
      c(CardRank.king, CardSuit.clubs),
      c(CardRank.ten, CardSuit.diamonds),
      c(CardRank.ten, CardSuit.hearts),
      c(CardRank.two, CardSuit.clubs),
      c(CardRank.three, CardSuit.clubs),
    ]);

    final flush = HandEvaluator.evaluateHandValue([
      c(CardRank.ace, CardSuit.hearts),
      c(CardRank.jack, CardSuit.hearts),
      c(CardRank.nine, CardSuit.hearts),
      c(CardRank.five, CardSuit.hearts),
      c(CardRank.three, CardSuit.hearts),
      c(CardRank.king, CardSuit.clubs),
      c(CardRank.king, CardSuit.diamonds),
    ]);

    expect(fullHouse.compareTo(flush), greaterThan(0));
  });
}
