import 'package:flashcard_sm2/models/card_deck.dart';
import 'package:flashcard_sm2/services/manage_deck_store.dart';

import 'manage_card_test_store.dart';

class MemoryDeckTestStore extends MemoryManageCardStore
    implements ManageDeckStore {
  List<CardDeck> decks = [
    const CardDeck(id: CardDeck.flutterId, name: 'Học Flutter'),
  ];
  @override
  Future<DeckCollection?> readCollection() async {
    final cards = await read();
    return cards == null ? null : DeckCollection(decks: decks, cards: cards);
  }

  @override
  Future<void> writeCollection(DeckCollection collection) async {
    collection.validate();
    await write(collection.cards);
    decks = List.of(collection.decks);
  }
}
