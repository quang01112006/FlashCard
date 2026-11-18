import 'dart:async';

import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/services/manage_card_store.dart';

class MemoryManageCardStore implements ManageCardStore {
  List<Flashcard>? savedCards;
  Object? readFailure;
  Object? writeFailure;
  Completer<void>? writeGate;
  int writes = 0;

  List<Flashcard> _clone(List<Flashcard> cards) =>
      decodeManageCards(cards.map((card) => card.toJson()).toList());

  @override
  Future<List<Flashcard>?> read() async {
    if (readFailure != null) throw readFailure!;
    return savedCards == null ? null : _clone(savedCards!);
  }

  @override
  Future<void> write(List<Flashcard> cards) async {
    writes++;
    if (writeGate != null) await writeGate!.future;
    if (writeFailure != null) throw writeFailure!;
    savedCards = _clone(cards);
  }
}
