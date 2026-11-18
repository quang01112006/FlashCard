import 'dart:async';

import 'package:flashcard_sm2/controllers/card_controller.dart';
import 'package:flashcard_sm2/core/app_theme.dart';
import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/screens/study_screen.dart';
import 'package:flashcard_sm2/screens/main_nav_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/manage_card_test_store.dart';

Flashcard _card(String id, {String topic = 'K01', DateTime? reviewDate}) =>
    Flashcard(
      id: id,
      topicCode: topic,
      level: 'Nhớ',
      front: 'Câu hỏi $id',
      back: 'Đáp án $id',
      nextReviewDate: reviewDate ?? DateTime(2020),
    );

Future<void> _show(
  WidgetTester tester,
  CardController controller, {
  String? topic,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: StudyScreen(topicCode: topic),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _rate(WidgetTester tester) async {
  // Chờ thông báo hoàn tác biến mất trước khi bấm nút ở cuối màn hình.
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Hiện đáp án'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tốt'));
  await tester.pumpAndSettle();
}

Finder get _undo => find.byWidgetPredicate(
  (widget) =>
      widget is IconButton && widget.tooltip == 'Hoàn tác câu vừa đánh giá',
);

void main() {
  late MemoryManageCardStore store;
  late CardController controller;

  Future<void> load(List<Flashcard> cards) async {
    store = MemoryManageCardStore()..savedCards = cards;
    controller = CardController(store: store);
    await controller.loadDefaultCards();
    addTearDown(controller.dispose);
  }

  testWidgets('Chủ đề được lọc trước khi ưu tiên thẻ đến hạn', (tester) async {
    await load([
      _card('other-due', topic: 'K02'),
      _card('selected-future', reviewDate: DateTime(2100)),
    ]);
    await _show(tester, controller, topic: 'K01');
    expect(find.text('Thẻ 1 / 1'), findsOneWidget);
    expect(find.text('Câu hỏi selected-future'), findsOneWidget);
    expect(find.text('Câu hỏi other-due'), findsNothing);
  });

  testWidgets(
    'Tab Học khởi tạo ngầm nhận thẻ nhập mới trước thẻ cũ ngay khi chuyển tab',
    (tester) async {
      await load([_card('a'), _card('b')]);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MainNavScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await controller.importCards([_card('x'), _card('y')]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Học thẻ'));
      await tester.pumpAndSettle();
      expect(find.text('Câu hỏi x'), findsOneWidget);
      expect(find.text('Thẻ 1 / 4'), findsOneWidget);
      await _rate(tester);
      expect(find.text('Câu hỏi y'), findsOneWidget);
      await _rate(tester);
      expect(find.text('Câu hỏi a'), findsOneWidget);
    },
  );

  testWidgets('Thẻ mới lên trước phần chưa học, giữ tiến độ thẻ đã đánh giá', (
    tester,
  ) async {
    await load([_card('a'), _card('b')]);
    await _show(tester, controller);
    await _rate(tester);
    await controller.addCard(_card('new'));
    await tester.pumpAndSettle();
    expect(find.text('Câu hỏi new'), findsOneWidget);
    expect(find.text('Thẻ 2 / 3'), findsOneWidget);
    expect(
      controller.cards.firstWhere((card) => card.id == 'a').repetitions,
      1,
    );
    controller.setLanguage(true);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data == 'Card 2 / 3' || w.data == 'Thẻ 2 / 3'),
      ),
      findsOneWidget,
    );
    await _rate(tester);
    expect(find.text('Câu hỏi b'), findsOneWidget);
  });

  testWidgets('Phiên đã hoàn thành nhận thẻ mới ngay', (tester) async {
    await load([_card('a')]);
    await _show(tester, controller);
    await _rate(tester);
    expect(find.text('Tuyệt vời!'), findsOneWidget);
    await controller.addCard(_card('new'));
    await tester.pumpAndSettle();
    expect(find.text('Câu hỏi new'), findsOneWidget);
    expect(find.text('Thẻ 2 / 2'), findsOneWidget);
  });

  testWidgets(
    'Tải lại đọc kho mới, bỏ thẻ đã xóa và giữ đúng chủ đề tùy chỉnh',
    (tester) async {
      await load([_card('a', topic: 'Nấu ăn')]);
      await _show(tester, controller, topic: 'Nấu ăn');
      store.savedCards = [
        _card('other', topic: 'Chơi game'),
        _card('new', topic: 'Nấu ăn'),
      ];
      await tester.tap(find.byKey(const ValueKey('study_refresh')));
      await tester.pumpAndSettle();
      expect(find.text('Câu hỏi new'), findsOneWidget);
      expect(find.text('Thẻ 1 / 1'), findsOneWidget);
      expect(find.text('Câu hỏi a'), findsNothing);
      expect(store.writes, 0);
    },
  );

  testWidgets('Tải lại lỗi giữ câu đang học và có thể thử lại', (tester) async {
    await load([_card('a'), _card('b')]);
    await _show(tester, controller);
    await _rate(tester);
    store.readFailure = StateError('Read failed');
    await tester.tap(find.byKey(const ValueKey('study_refresh')));
    await tester.pumpAndSettle();
    expect(find.text('Câu hỏi b'), findsOneWidget);
    expect(find.text('Thẻ 2 / 2'), findsOneWidget);
    expect(
      find.text('Không thể tải bộ thẻ. Vui lòng thử lại.'),
      findsOneWidget,
    );
    store.readFailure = null;
    await tester.tap(find.byKey(const ValueKey('study_refresh')));
    await tester.pumpAndSettle();
    expect(find.text('Câu hỏi b'), findsOneWidget);
    expect(find.text('Thẻ 1 / 1'), findsOneWidget);
    expect(controller.cards.first.repetitions, 1);
    expect(store.writes, 1);
  });

  testWidgets('Bộ rỗng có nút tải lại và nhận thẻ từ kho', (tester) async {
    await load([]);
    await _show(tester, controller);
    expect(find.text('Chưa có thẻ nào trong phiên học!'), findsOneWidget);
    store.savedCards = [_card('new')];
    await tester.tap(find.byKey(const ValueKey('study_refresh')));
    await tester.pumpAndSettle();
    expect(find.text('Câu hỏi new'), findsOneWidget);
  });

  testWidgets('Phiên theo chủ đề nhận thêm, sửa chủ đề và xóa thẻ', (
    tester,
  ) async {
    await load([_card('a'), _card('b')]);
    await _show(tester, controller, topic: 'K01');
    await controller.addCard(_card('other', topic: 'K02'));
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 1 / 2'), findsOneWidget);
    await controller.deleteCard('a');
    await tester.pumpAndSettle();
    expect(find.text('Câu hỏi b'), findsOneWidget);
    await controller.editCard(_card('b', topic: 'K02'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thẻ nào trong phiên học!'), findsOneWidget);
    await controller.addCard(_card('new'));
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 1 / 1'), findsOneWidget);
    expect(find.text('Câu hỏi new'), findsOneWidget);
  });

  testWidgets('Đổi chủ đề trên cùng màn hình bắt đầu đúng phiên mới', (
    tester,
  ) async {
    await load([_card('a'), _card('b', topic: 'K02')]);
    await _show(tester, controller, topic: 'K01');
    await _rate(tester);
    expect(find.text('Tuyệt vời!'), findsOneWidget);
    await _show(tester, controller, topic: 'K02');
    expect(find.text('Thẻ 1 / 1'), findsOneWidget);
    expect(find.text('Câu hỏi b'), findsOneWidget);
    expect(tester.widget<IconButton>(_undo).onPressed, isNull);
  });

  testWidgets('Hoàn tác lưu lại SM-2 cũ và giữ nội dung vừa sửa ở Bộ thẻ', (
    tester,
  ) async {
    final original = _card('a')
        .copyWith(repetitions: 3, interval: 15, easeFactor: 2.1);
    await load([original]);
    await _show(tester, controller);
    await _rate(tester);
    expect(find.text('Tuyệt vời!'), findsOneWidget);
    expect(controller.cards.single.repetitions, 4);
    await controller.editCard(original.copyWith(front: 'Nội dung vừa sửa'));
    await tester.pumpAndSettle();
    await tester.tap(_undo);
    await tester.pumpAndSettle();
    expect(find.text('Nội dung vừa sửa'), findsOneWidget);
    expect(find.text('Thẻ 1 / 1'), findsOneWidget);
    final restored = store.savedCards!.single;
    expect(restored.front, 'Nội dung vừa sửa');
    expect(restored.repetitions, original.repetitions);
    expect(restored.interval, original.interval);
    expect(restored.easeFactor, original.easeFactor);
    expect(restored.nextReviewDate, original.nextReviewDate);
    expect(tester.widget<IconButton>(_undo).onPressed, isNull);
    await controller.loadDefaultCards(forceReload: true);
    expect(controller.cards.single.toJson(), restored.toJson());
  });

  testWidgets('Đánh giá lỗi không ghi đè lượt hoàn tác thành công trước đó', (
    tester,
  ) async {
    await load([_card('a'), _card('b')]);
    await _show(tester, controller);
    await _rate(tester);
    store.writeFailure = StateError('Disk full');
    await _rate(tester);
    expect(find.text('Thẻ 2 / 2'), findsOneWidget);
    expect(controller.cards[1].repetitions, 0);
    store.writeFailure = null;
    await tester.tap(_undo);
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 1 / 2'), findsOneWidget);
    expect(find.text('Câu hỏi a'), findsOneWidget);
    expect(controller.cards.first.repetitions, 0);
  });

  testWidgets('Hoàn tác lỗi giữ vị trí; thử lại chờ lưu và chặn bấm lặp', (
    tester,
  ) async {
    await load([_card('a')]);
    await _show(tester, controller);
    await _rate(tester);
    store.writeFailure = StateError('Disk full');
    await tester.tap(_undo);
    await tester.pumpAndSettle();
    expect(find.text('Tuyệt vời!'), findsOneWidget);
    expect(controller.cards.single.repetitions, 1);
    expect(
      find.text('Không thể lưu thay đổi. Vui lòng thử lại.'),
      findsOneWidget,
    );
    store.writeFailure = null;
    final gate = Completer<void>();
    store.writeGate = gate;
    await tester.tap(_undo);
    await tester.pump();
    expect(find.text('Tuyệt vời!'), findsOneWidget);
    expect(tester.widget<IconButton>(_undo).onPressed, isNull);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Ôn tập lại từ đầu'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('study_refresh')))
          .onPressed,
      isNull,
    );
    expect(store.writes, 3);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 1 / 1'), findsOneWidget);
    expect(controller.cards.single.repetitions, 0);
    expect(store.savedCards!.single.repetitions, 0);
  });

  testWidgets('Hoàn tác tìm bằng ID sau khi xóa thẻ trước đó trong phiên', (
    tester,
  ) async {
    await load([_card('a'), _card('b'), _card('c')]);
    await _show(tester, controller);
    await _rate(tester);
    await _rate(tester);
    await controller.deleteCard('a');
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 2 / 2'), findsOneWidget);
    await tester.tap(_undo);
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 1 / 2'), findsOneWidget);
    expect(find.text('Câu hỏi b'), findsOneWidget);
    await _rate(tester);
    await controller.deleteCard('b');
    await tester.pumpAndSettle();
    expect(find.text('Câu hỏi c'), findsOneWidget);
    expect(tester.widget<IconButton>(_undo).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
