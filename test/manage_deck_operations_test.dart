import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flashcard_sm2/controllers/card_controller.dart';
import 'package:flashcard_sm2/models/card_deck.dart';
import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/services/manage_card_store.dart';
import 'package:flashcard_sm2/services/manage_deck_store.dart';

import 'support/manage_deck_test_store.dart';

Flashcard _card(String id, {String deck = 'flutter-default'}) => Flashcard(
  id: id,
  deckId: deck,
  front: 'Question $id',
  back: 'Answer',
  frontEn: 'EN question',
  backEn: 'EN answer',
  topicCode: '',
  level: 'Nhớ',
  repetitions: 3,
  interval: 15,
  nextReviewDate: DateTime(2030),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryDeckTestStore store;
  late CardController controller;
  setUp(() async {
    store = MemoryDeckTestStore()
      ..decks = [
        const CardDeck(id: 'flutter-default', name: 'Học Flutter'),
        const CardDeck(id: 'cooking', name: 'Nấu ăn'),
      ]
      ..savedCards = [_card('flutter'), _card('recipe', deck: 'cooking')];
    controller = CardController(store: store);
    await controller.loadDefaultCards();
  });
  tearDown(() => controller.dispose());
  test('Thêm/sửa trong bộ đích và đổi tên giữ ID, nội dung, lịch ôn', () async {
    await controller.addCard(_card('new', deck: 'cooking'));
    await controller.editCard(
      controller.cards.first.copyWith(front: 'Edited'),
      expectedDeckId: 'cooking',
    );
    final before = controller.cards.map((c) => c.toJson()).toList();
    await controller.renameDeck(
      'cooking',
      '  Bếp gia đình  ',
      description: 'Món Việt',
    );
    expect(controller.deckById('cooking')!.name, 'Bếp gia đình');
    expect(controller.cards.map((c) => c.toJson()).toList(), before);
    expect(controller.cardsInDeck('cooking'), hasLength(2));
    expect(controller.cardsInDeck('flutter-default').single.id, 'flutter');
    await controller.loadDefaultCards(forceReload: true);
    expect(controller.deckById('cooking')!.description, 'Món Việt');
  });
  test('Chuyển giữ toàn bộ nội dung/lịch ôn; bản sửa/xóa cũ không tác động bộ khác', () async {
    final before = controller.cards.last;
    await controller.moveCard(
      before.id,
      'flutter-default',
      expectedDeckId: 'cooking',
    );
    final after = controller.cards.last;
    expect(after.toJson(), before.copyWith(deckId: 'flutter-default').toJson());
    expect(controller.cardsInDeck('cooking'), isEmpty);
    await expectLater(
      controller.deleteCard(before.id, expectedDeckId: 'cooking'),
      throwsA(isA<CardOperationException>()),
    );
    await expectLater(
      controller.editCard(
        before.copyWith(front: 'Stale'),
        expectedDeckId: 'cooking',
      ),
      throwsA(isA<CardOperationException>()),
    );
    await controller.updateCard(before.copyWith(repetitions: 4));
    expect(controller.cards.last.deckId, 'flutter-default');
    expect(controller.cards.last.repetitions, 4);
  });
  test(
    'Xóa bộ chỉ xóa câu hỏi thuộc bộ đó; xóa hết không tự nạp dữ liệu gốc',
    () async {
      await controller.deleteDeck('cooking');
      expect(controller.cards.single.id, 'flutter');
      await controller.deleteDeck('flutter-default');
      await controller.loadDefaultCards(forceReload: true);
      expect(controller.decks, isEmpty);
      expect(controller.cards, isEmpty);
      await expectLater(
        controller.addCard(_card('orphan')),
        throwsA(isA<CardOperationException>()),
      );
      final newDeck = await controller.createDeck('Tiếng Anh');
      await controller.addCard(_card('english', deck: newDeck.id));
      expect(controller.cards.single.deckId, newDeck.id);
    },
  );
  test('Tên rỗng/trùng, bộ nhận mất và ID sai được từ chối', () async {
    for (final name in ['  ', 'học flutter']) {
      await expectLater(
        controller.renameDeck('cooking', name),
        throwsA(isA<CardOperationException>()),
      );
    }
    await expectLater(
      controller.renameDeck('missing', 'Name'),
      throwsA(isA<CardOperationException>()),
    );
    await expectLater(
      controller.deleteDeck('missing'),
      throwsA(isA<CardOperationException>()),
    );
    await expectLater(
      controller.moveCard('recipe', 'missing'),
      throwsA(isA<CardOperationException>()),
    );
    expect(store.writes, 0);
  });
  test('Lỗi ghi khi đổi tên/xóa/chuyển giữ cả bộ và câu hỏi cũ', () async {
    final before = controller.cards.map((c) => c.toJson()).toList();
    store.writeFailure = StateError('Disk full');
    for (final action in <Future<void> Function()>[
      () => controller.renameDeck('cooking', 'New'),
      () => controller.deleteDeck('cooking'),
      () => controller.moveCard('recipe', 'flutter-default'),
    ]) {
      await expectLater(action(), throwsA(isA<CardOperationException>()));
      expect(controller.cards.map((c) => c.toJson()).toList(), before);
      expect(controller.decks.last.name, 'Nấu ăn');
      expect(store.decks.last.name, 'Nấu ăn');
    }
    store.writeFailure = null;
    await controller.deleteDeck('cooking');
    expect(controller.cards.single.id, 'flutter');
  });
  test(
    'Không cập nhật sớm hoặc nhận thao tác ghi chồng khi chuyển thẻ',
    () async {
      final gate = Completer<void>();
      store.writeGate = gate;
      final saving = controller.moveCard('recipe', 'flutter-default');
      expect(controller.cards.last.deckId, 'cooking');
      await expectLater(
        controller.deleteDeck('cooking'),
        throwsA(isA<CardOperationException>()),
      );
      gate.complete();
      await saving;
      expect(controller.cards.last.deckId, 'flutter-default');
    },
  );
  test('Đóng/mở Hive giữ chuyển thẻ, tên bộ và xóa bộ cuối cùng', () async {
    final directory = await Directory.systemTemp.createTemp('phase2-decks-');
    try {
      Hive.init(directory.path);
      HiveManageCardStore disk() =>
          HiveManageCardStore(openBox: () => Hive.openBox<dynamic>('phase2'));
      await disk().writeCollection(
        DeckCollection(decks: store.decks, cards: store.savedCards!),
      );
      final first = CardController(store: disk());
      await first.loadDefaultCards();
      await first.moveCard('recipe', 'flutter-default');
      await first.renameDeck('flutter-default', 'Flutter và ghi chú');
      await first.deleteDeck('cooking');
      first.dispose();
      await Hive.close();
      final restored = CardController(store: disk());
      await restored.loadDefaultCards();
      expect(restored.decks.single.name, 'Flutter và ghi chú');
      expect(restored.cards, hasLength(2));
      expect(restored.cards.last.repetitions, 3);
      await restored.deleteDeck('flutter-default');
      restored.dispose();
      await Hive.close();
      final empty = CardController(store: disk());
      await empty.loadDefaultCards();
      expect(empty.decks, isEmpty);
      expect(empty.cards, isEmpty);
      empty.dispose();
    } finally {
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });
}
