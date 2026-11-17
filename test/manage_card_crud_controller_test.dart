import 'dart:async';
import 'dart:convert';

import 'package:flashcard_sm2/controllers/card_controller.dart';
import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/services/manage_card_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/manage_card_test_store.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.read);
  final Future<String> Function() read;
  @override
  Future<String> loadString(String key, {bool cache = true}) => read();
  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

Flashcard _card(String id, {String front = 'Câu hỏi'}) => Flashcard(
  id: id,
  topicCode: 'K01',
  level: 'Nhớ',
  front: front,
  back: 'Đáp án',
  frontEn: 'Question',
  backEn: 'Answer',
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
    'Thêm, sửa và xóa được khôi phục từ cùng kho khi tạo controller mới',
    () async {
      final added = _card(controller.createCardId());
      await controller.addCard(added);
      expect(controller.cards.first.id, added.id);
      await controller.editCard(
        added.copyWith(front: 'Nội dung đã sửa', frontEn: ''),
      );
      await controller.deleteCard('seed');

      final restored = CardController(store: store);
      addTearDown(restored.dispose);
      await restored.loadDefaultCards();
      expect(restored.cards.single.front, 'Nội dung đã sửa');
      expect(restored.cards.single.frontEn, '');
      expect(restored.cards.single.id, added.id);
      expect(store.writes, 3);
    },
  );

  test(
    'Sửa bằng bản nháp cũ giữ tiến độ mới nhất; chấm điểm giữ nội dung mới',
    () async {
      final draft = controller.cards.single;
      final date = DateTime(2030, 5, 1);
      await controller.updateCard(
        draft.copyWith(
          repetitions: 4,
          interval: 30,
          easeFactor: 2.3,
          nextReviewDate: date,
        ),
      );
      await controller.editCard(
        draft.copyWith(front: 'Mới', frontEn: '', backEn: ''),
      );
      expect(controller.cards.single.repetitions, 4);
      expect(controller.cards.single.interval, 30);
      expect(controller.cards.single.nextReviewDate, date);
      expect(controller.cards.single.frontEn, '');
      await controller.updateCard(draft.copyWith(repetitions: 5, interval: 60));
      expect(controller.cards.single.front, 'Mới');
      expect(controller.cards.single.repetitions, 5);
    },
  );

  test('Xóa hết thẻ và tải lại không tự nạp lại thẻ gốc', () async {
    await controller.deleteCard('seed');
    final restored = CardController(
      store: store,
      assetBundle: _Bundle(
        () async => throw StateError('Must not read defaults'),
      ),
    );
    addTearDown(restored.dispose);
    await restored.loadDefaultCards();
    expect(restored.loadError, isNull);
    expect(restored.cards, isEmpty);
    await restored.loadDefaultCards(forceReload: true);
    expect(restored.cards, isEmpty);
  });

  for (final action in ['add', 'edit', 'delete', 'review']) {
    test('Lỗi ghi khi $action không đổi dữ liệu và có thể thử lại', () async {
      final before = controller.cards.map((card) => card.toJson()).toList();
      Future<void> perform() async {
        switch (action) {
          case 'add':
            await controller.addCard(_card('new'));
          case 'edit':
            await controller.editCard(_card('seed', front: 'Đã sửa'));
          case 'delete':
            await controller.deleteCard('seed');
          case 'review':
            await controller.updateCard(
              controller.cards.single.copyWith(repetitions: 1, interval: 1),
            );
        }
      }

      store.writeFailure = StateError('Disk full');
      await expectLater(perform(), throwsA(isA<CardOperationException>()));
      expect(controller.cards.map((card) => card.toJson()).toList(), before);
      expect(store.savedCards!.map((card) => card.toJson()).toList(), before);
      expect(controller.isSaving, isFalse);
      store.writeFailure = null;
      await perform();
      expect(store.writes, 2);
    });
  }

  test(
    'Chặn ID trùng, trường rỗng, phân loại sai và ID không còn tồn tại',
    () async {
      for (final invalid in [
        _card('seed'),
        _card('new', front: '  '),
        _card('new').copyWith(topicCode: 'K99'),
        _card('new').copyWith(level: ''),
      ]) {
        await expectLater(
          controller.addCard(invalid),
          throwsA(isA<CardOperationException>()),
        );
      }
      await expectLater(
        controller.editCard(_card('missing')),
        throwsA(isA<CardOperationException>()),
      );
      await expectLater(
        controller.deleteCard('missing'),
        throwsA(isA<CardOperationException>()),
      );
      expect(store.writes, 0);
      expect(controller.cards, hasLength(1));
      expect(() => controller.cards.clear(), throwsUnsupportedError);
      expect({
        for (var i = 0; i < 100; i++) controller.createCardId(),
      }, hasLength(100));
    },
  );

  test('Chặn ghi chồng trong khi thao tác trước chưa hoàn tất', () async {
    store.writeGate = Completer<void>();
    final first = controller.addCard(_card('first'));
    expect(controller.isSaving, isTrue);
    expect(controller.cards, hasLength(1));
    await expectLater(
      controller.addCard(_card('second')),
      throwsA(isA<CardOperationException>()),
    );
    store.writeGate!.complete();
    await first;
    expect(controller.cards.map((card) => card.id), ['first', 'seed']);
    expect(store.writes, 1);
  });

  test(
    'Lỗi đọc storage không được thay bằng JSON hoặc ghi đè dữ liệu',
    () async {
      final broken = MemoryManageCardStore()
        ..readFailure = StateError('Corrupt');
      final other = CardController(
        store: broken,
        assetBundle: _Bundle(
          () async => jsonEncode([_card('fallback').toJson()]),
        ),
      );
      addTearDown(other.dispose);
      await other.loadDefaultCards();
      expect(other.loadError, isNotNull);
      await expectLater(
        other.addCard(_card('new')),
        throwsA(isA<CardOperationException>()),
      );
      expect(broken.writes, 0);
      broken.readFailure = null;
      await other.loadDefaultCards(forceReload: true);
      expect(other.cards.single.id, 'fallback');
    },
  );

  test('Hoàn tất tải hoặc ghi sau dispose không gọi listener đã hủy', () async {
    store.writeGate = Completer<void>();
    final operation = controller.addCard(_card('later'));
    controller.dispose();
    store.writeGate!.complete();
    await operation;
    expect(store.savedCards!.first.id, 'later');
    // tearDown sẽ dispose instance mới để không gọi dispose hai lần.
    controller = CardController(store: MemoryManageCardStore());
  });
}
