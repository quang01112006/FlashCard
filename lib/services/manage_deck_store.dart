import '../models/card_deck.dart';
import '../models/flashcard.dart';

class DeckCollection {
  DeckCollection({
    required Iterable<CardDeck> decks,
    required Iterable<Flashcard> cards,
  }) : decks = List.unmodifiable(decks),
       cards = List.unmodifiable(cards);
  final List<CardDeck> decks;
  final List<Flashcard> cards;
  void validate() {
    for (final deck in decks) {
      CardDeck.fromJson(deck.toJson());
    }
    final ids = decks.map((deck) => deck.id).toSet();
    if (ids.length != decks.length ||
        cards.any((card) => !ids.contains(card.deckId))) {
      throw const FormatException('Duplicate decks or orphan cards');
    }
  }
}

abstract interface class ManageDeckStore {
  Future<DeckCollection?> readCollection();
  Future<void> writeCollection(DeckCollection collection);
}
