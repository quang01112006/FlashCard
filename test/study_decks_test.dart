import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flashcard_sm2/controllers/card_controller.dart';
import 'package:flashcard_sm2/core/app_theme.dart';
import 'package:flashcard_sm2/models/card_deck.dart';
import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/screens/main_nav_screen.dart';
import 'package:flashcard_sm2/screens/study_decks_screen.dart';
import 'package:flashcard_sm2/screens/study_screen.dart';

import 'support/manage_deck_test_store.dart';

Flashcard _card(String id, String deck) => Flashcard(
  id: id,
  deckId: deck,
  front: 'Question $id',
  back: 'Answer $id',
  topicCode: 'K01',
  level: 'Nhớ',
  nextReviewDate: DateTime(2020),
);
Finder get _picker => find.byWidgetPredicate(
  (w) =>
      w is DropdownButtonFormField<String> &&
      w.key.toString().contains('study_deck_picker'),
);
Finder get _undo => find.byWidgetPredicate(
  (w) => w is IconButton && w.tooltip == 'Hoàn tác câu vừa đánh giá',
);
Future<void> _choose(WidgetTester tester, String name) async {
  await tester.tap(_picker);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> _rate(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Hiện đáp án'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tốt'));
  await tester.pumpAndSettle();
}

void main() {
  late MemoryDeckTestStore store;
  late CardController controller;
  setUp(() async {
    store = MemoryDeckTestStore()
      ..decks = [
        const CardDeck(id: 'flutter-default', name: 'Học Flutter'),
        const CardDeck(id: 'cooking', name: 'Nấu ăn'),
        const CardDeck(id: 'empty', name: 'Bộ rỗng'),
      ]
      ..savedCards = [
        _card('f1', 'flutter-default'),
        _card('f2', 'flutter-default'),
        _card('c1', 'cooking'),
        _card('c2', 'cooking'),
      ];
    controller = CardController(store: store);
    await controller.loadDefaultCards();
  });
  tearDown(() => controller.dispose());
  Future<void> show(
    WidgetTester tester, {
    Widget home = const StudyDecksScreen(),
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(theme: AppTheme.lightTheme, home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Chọn bộ chỉ hiện và chấm điểm câu hỏi của bộ đó', (
    tester,
  ) async {
    await show(tester);
    expect(find.text('Question f1'), findsOneWidget);
    expect(find.text('Question c1'), findsNothing);
    await _choose(tester, 'Nấu ăn');
    expect(find.text('Question c1'), findsOneWidget);
    expect(find.text('Thẻ 1 / 2'), findsOneWidget);
    await _rate(tester);
    expect(controller.cards.firstWhere((c) => c.id == 'c1').repetitions, 1);
    expect(controller.cards.first.repetitions, 0);
    expect(find.text('Question c2'), findsOneWidget);
  });
  testWidgets('Đổi bộ giữ phiên riêng và hoàn tác không ảnh hưởng bộ khác', (
    tester,
  ) async {
    await show(tester);
    await _rate(tester);
    await _choose(tester, 'Nấu ăn');
    await _rate(tester);
    await _choose(tester, 'Học Flutter');
    expect(find.text('Question f2'), findsOneWidget);
    await _choose(tester, 'Nấu ăn');
    expect(find.text('Question c2'), findsOneWidget);
    await tester.tap(_undo);
    await tester.pumpAndSettle();
    expect(find.text('Question c1'), findsOneWidget);
    expect(controller.cards.first.repetitions, 1);
    expect(controller.cards.firstWhere((c) => c.id == 'c1').repetitions, 0);
  });
  testWidgets('Tự nhận thêm/sửa/xóa/chuyển đúng bộ, không trộn câu hỏi', (
    tester,
  ) async {
    await show(tester);
    await _choose(tester, 'Nấu ăn');
    await controller.importCards([_card('newFlutter', 'flutter-default')]);
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 1 / 2'), findsOneWidget);
    await controller.addCard(_card('newCooking', 'cooking'));
    await tester.pumpAndSettle();
    expect(find.text('Question newCooking'), findsOneWidget);
    await controller.editCard(
      controller.cards.first.copyWith(front: 'Edited cooking'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edited cooking'), findsOneWidget);
    await controller.moveCard('newCooking', 'flutter-default');
    await tester.pumpAndSettle();
    expect(find.text('Question c1'), findsOneWidget);
    await controller.deleteCard('c1');
    await tester.pumpAndSettle();
    expect(find.text('Question c2'), findsOneWidget);
    expect(find.text('Thẻ 1 / 1'), findsOneWidget);
  });
  testWidgets(
    'Đổi tên giữ phiên; xóa bộ đang học yêu cầu chọn lại và giữ phiên bộ khác',
    (tester) async {
      await show(tester);
      await _rate(tester);
      await _choose(tester, 'Nấu ăn');
      await _rate(tester);
      await controller.renameDeck('cooking', 'Bếp nhà');
      await tester.pumpAndSettle();
      expect(find.text('Question c2'), findsOneWidget);
      expect(find.text('Bếp nhà'), findsWidgets);
      await controller.deleteDeck('cooking');
      await tester.pumpAndSettle();
      expect(
        find.text('Bộ đang học đã bị xóa. Hãy chọn bộ khác.'),
        findsOneWidget,
      );
      expect(find.text('Question f1'), findsNothing);
      await _choose(tester, 'Học Flutter');
      expect(find.text('Question f2'), findsOneWidget);
    },
  );
  testWidgets('Bộ rỗng và xóa hết bộ không lấy câu hỏi từ bộ khác', (
    tester,
  ) async {
    await show(tester);
    await _choose(tester, 'Bộ rỗng');
    expect(find.text('Chưa có thẻ nào trong phiên học!'), findsOneWidget);
    await controller.deleteDeck('cooking');
    await controller.deleteDeck('flutter-default');
    await controller.deleteDeck('empty');
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa có bộ thẻ để học. Hãy tạo bộ mới ở tab Bộ thẻ.'),
      findsOneWidget,
    );
    final fresh = await controller.createDeck('Bộ mới');
    await tester.pumpAndSettle();
    await _choose(tester, 'Bộ mới');
    await controller.addCard(_card('fresh', fresh.id));
    await tester.pumpAndSettle();
    expect(find.text('Question fresh'), findsOneWidget);
  });
  testWidgets('Học bộ này từ danh sách chuyển đúng tab và chọn lại đúng bộ', (
    tester,
  ) async {
    await show(tester, home: const MainNavScreen());
    await tester.tap(find.text('Bộ thẻ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('manage_study_deck_cooking')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      1,
    );
    expect(find.text('Question c1'), findsOneWidget);
    await _rate(tester);
    await _choose(tester, 'Học Flutter');
    await tester.tap(find.text('Bộ thẻ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('manage_study_deck_cooking')));
    await tester.pumpAndSettle();
    expect(find.text('Question c2'), findsOneWidget);
  });
  testWidgets('Học từ chi tiết bộ quay về tab Học, không mở phiên chung', (
    tester,
  ) async {
    await show(tester, home: const MainNavScreen());
    await tester.tap(find.text('Bộ thẻ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('manage_deck_cooking')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('manage_study_this_deck')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      1,
    );
    expect(find.text('Question c1'), findsOneWidget);
    expect(find.text('Question f1'), findsNothing);
  });
  testWidgets('Lọc nhóm và ưu tiên đến hạn nằm bên trong bộ đã chọn', (
    tester,
  ) async {
    await controller.updateCard(
      controller.cards
          .firstWhere((c) => c.id == 'c1')
          .copyWith(nextReviewDate: DateTime(2100)),
    );
    await controller.deleteCard('c2');
    await show(
      tester,
      home: const StudyScreen(deckId: 'cooking', topicCode: 'K01'),
    );
    expect(find.text('Question c1'), findsOneWidget);
    expect(find.text('Question f1'), findsNothing);
  });
  testWidgets('Tải lại chỉ dựng lại phiên của bộ hiện tại', (tester) async {
    await show(tester);
    await _rate(tester);
    await _choose(tester, 'Nấu ăn');
    store.savedCards = [...store.savedCards!, _card('c3', 'cooking')];
    await tester.tap(find.byKey(const ValueKey('study_refresh')));
    await tester.pumpAndSettle();
    expect(find.text('Thẻ 1 / 3'), findsOneWidget);
    await _choose(tester, 'Học Flutter');
    expect(find.text('Question f2'), findsOneWidget);
    expect(find.text('Thẻ 2 / 2'), findsOneWidget);
  });
  testWidgets(
    'Đang ghi không cho đổi bộ; lưu lỗi giữ câu đang học để thử lại',
    (tester) async {
      await show(tester);
      await _choose(tester, 'Nấu ăn');
      await tester.tap(find.text('Hiện đáp án'));
      await tester.pumpAndSettle();
      final gate = Completer<void>();
      store.writeGate = gate;
      store.writeFailure = StateError('Disk full');
      await tester.tap(find.text('Tốt'));
      await tester.pump();
      expect(
        tester.widget<DropdownButtonFormField<String>>(_picker).onChanged,
        isNull,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Thẻ 1 / 2'), findsOneWidget);
      expect(
        find.text('Không thể lưu thay đổi. Vui lòng thử lại.'),
        findsOneWidget,
      );
      store.writeFailure = null;
      store.writeGate = null;
      await tester.tap(find.text('Tốt'));
      await tester.pumpAndSettle();
      expect(find.text('Question c2'), findsOneWidget);
    },
  );
  testWidgets('Chọn bộ và lật thẻ trên màn hình hẹp chữ lớn', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await show(tester, home: const MainNavScreen());
    await tester.tap(find.text('Học thẻ'));
    await tester.pumpAndSettle();
    await _choose(tester, 'Nấu ăn');
    await _rate(tester);
    await _rate(tester);
    expect(find.text('Tuyệt vời!'), findsOneWidget);
    await _choose(tester, 'Bộ rỗng');
    expect(find.text('Chưa có thẻ nào trong phiên học!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
