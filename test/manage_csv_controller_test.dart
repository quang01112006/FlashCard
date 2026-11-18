import 'dart:async';
import 'dart:io';

import 'package:flashcard_sm2/controllers/card_controller.dart';
import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/services/csv_service.dart';
import 'package:flashcard_sm2/services/manage_card_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'support/manage_card_test_store.dart';

Flashcard _card(String id) => Flashcard(
  id: id,
  topicCode: 'K01',
  level: 'Nhớ',
  front: 'Câu hỏi $id',
  back: 'Đáp án',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryManageCardStore store;
  late CardController controller;
  setUp(() async {
    store = MemoryManageCardStore()..savedCards = [_card('seed')];
    controller = CardController(store: store);
    await controller.loadDefaultCards();
  });
  tearDown(() => controller.dispose());

  test(
    'Nhập cả lượt chỉ lưu một lần và không đổi nội dung/lịch ôn thẻ cũ',
    () async {
      final old = controller.cards.single;
      final batch = [_card('a'), _card('b')];
      await controller.importCards(batch);
      expect(store.writes, 1);
      expect(controller.cards.map((card) => card.id), ['a', 'b', 'seed']);
      expect(controller.cards.last.toJson(), old.toJson());
      final restored = CardController(store: store);
      addTearDown(restored.dispose);
      await restored.loadDefaultCards();
      expect(
        restored.cards.map((card) => card.toJson()),
        controller.cards.map((card) => card.toJson()),
      );
    },
  );

  test(
    'Thẻ lỗi, trùng ID trong file hoặc với bộ cũ không được nhập dở dang',
    () async {
      for (final batch in [
        [_card('a'), _card('b').copyWith(back: '')],
        [_card('a'), _card('a')],
        [_card('a'), _card('seed')],
        <Flashcard>[],
      ]) {
        await expectLater(
          controller.importCards(batch),
          throwsA(isA<CardOperationException>()),
        );
        expect(controller.cards.single.id, 'seed');
        expect(store.savedCards!.single.id, 'seed');
        expect(store.writes, 0);
      }
    },
  );

  test('Lưu lỗi giữ nguyên bộ cũ, thử lại nhập đủ cả lượt', () async {
    store.writeFailure = StateError('Disk full');
    final batch = [_card('a'), _card('b')];
    await expectLater(
      controller.importCards(batch),
      throwsA(isA<CardOperationException>()),
    );
    expect(controller.cards.single.id, 'seed');
    expect(store.savedCards!.single.id, 'seed');
    store.writeFailure = null;
    await controller.importCards(batch);
    expect(store.savedCards!.map((card) => card.id), ['a', 'b', 'seed']);
    expect(store.writes, 2);
  });

  test(
    'Chờ lưu xong mới cập nhật bộ thẻ và không nhận thao tác ghi chồng',
    () async {
      final gate = Completer<void>();
      store.writeGate = gate;
      final batch = [_card('a'), _card('b')];
      final pending = controller.importCards(batch);
      batch.clear();
      expect(controller.cards.single.id, 'seed');
      expect(controller.isSaving, isTrue);
      await expectLater(
        controller.importCards([_card('c')]),
        throwsA(isA<CardOperationException>()),
      );
      gate.complete();
      await pending;
      expect(controller.cards.map((card) => card.id), ['a', 'b', 'seed']);
    },
  );

  test(
    'Xuất rồi nhập lặp tạo ID mới, giữ tiến độ cũ và không ghi đè bộ hiện có',
    () async {
      await controller.updateCard(
        controller.cards.single.copyWith(repetitions: 4, interval: 30),
      );
      final parsed = CsvService.parseBytes(
        CsvService.exportBytes(controller.cards),
      );
      for (var attempt = 0; attempt < 2; attempt++) {
        await controller.importCards(
          parsed.cards
              .map(
                (draft) => draft.toCard(
                  id: controller.createCardId(),
                  defaultTopic: 'K01',
                  defaultLevel: 'Nhớ',
                ),
              )
              .toList(),
        );
      }
      expect(controller.cards, hasLength(3));
      expect(controller.cards.map((card) => card.id).toSet(), hasLength(3));
      expect(controller.cards.last.id, 'seed');
      expect(controller.cards.last.repetitions, 4);
      expect(
        controller.cards.take(2).every((card) => card.repetitions == 0),
        isTrue,
      );
    },
  );

  test('Nhập CSV rồi đóng/mở Hive giữ thẻ thật trên ổ đĩa', () async {
    final directory = await Directory.systemTemp.createTemp('manage-csv-hive-');
    try {
      Hive.init(directory.path);
      HiveManageCardStore diskStore() => HiveManageCardStore(
        openBox: () => Hive.openBox<dynamic>('manage_csv_disk_test'),
      );
      await diskStore().write([_card('seed')]);
      final first = CardController(store: diskStore());
      await first.loadDefaultCards();
      final parsed = CsvService.parseBytes(
        File('samples/csv/flashcards_bilingual.csv').readAsBytesSync(),
      );
      await first.importCards(
        parsed.cards
            .map(
              (draft) => draft.toCard(
                id: first.createCardId(),
                defaultTopic: 'K01',
                defaultLevel: 'Nhớ',
              ),
            )
            .toList(),
      );
      final expected = first.cards.map((card) => card.toJson()).toList();
      first.dispose();
      await Hive.close();
      final restored = CardController(store: diskStore());
      addTearDown(restored.dispose);
      await restored.loadDefaultCards();
      expect(restored.loadError, isNull);
      expect(restored.cards.map((card) => card.toJson()).toList(), expected);
    } finally {
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });
}
