import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flashcard_sm2/controllers/card_controller.dart';
import 'package:flashcard_sm2/core/app_theme.dart';
import 'package:flashcard_sm2/models/card_deck.dart';
import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/screens/manage_decks_screen.dart';
import 'package:flashcard_sm2/screens/manage_cards_screen.dart';

import 'support/manage_deck_test_store.dart';

void main() {
  late MemoryDeckTestStore store;
  late CardController controller;
  setUp(() async {
    store = MemoryDeckTestStore()
      ..decks = [
        const CardDeck(id: 'flutter-default', name: 'Học Flutter'),
        const CardDeck(id: 'cooking', name: 'Nấu ăn'),
      ]
      ..savedCards = [
        Flashcard(
          id: 'flutter',
          front: 'Flutter question',
          back: 'Flutter answer',
          topicCode: 'K01',
          level: 'Nhớ',
        ),
        Flashcard(
          id: 'recipe',
          deckId: 'cooking',
          front: 'Cooking question',
          back: 'Cooking answer',
          topicCode: 'Món Việt',
          level: 'Hiểu',
          repetitions: 4,
        ),
      ];
    controller = CardController(store: store);
    await controller.loadDefaultCards();
  });
  tearDown(() => controller.dispose());
  Future<void> show(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(theme: AppTheme.lightTheme, home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> actions(WidgetTester tester, String label) async {
    final tile = find.byKey(const ValueKey('manage_deck_cooking'));
    await tester.tap(
      find.descendant(of: tile, matching: find.byTooltip('Quản lý bộ thẻ')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> expand(WidgetTester tester) async {
    final tile = find.byKey(const PageStorageKey('manage_card_recipe'));
    await tester.tap(
      find.descendant(of: tile, matching: find.byIcon(Icons.expand_more)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Thêm câu hỏi trong bộ đang mở, không yêu cầu nhóm hoặc trộn dữ liệu',
    (tester) async {
      await show(tester, const ManageCardsScreen(deckId: 'cooking'));
      expect(find.text('Flutter question'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('manage_add_card')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('manage_editor_front')),
        'New recipe',
      );
      await tester.enterText(
        find.byKey(const ValueKey('manage_editor_back')),
        'New answer',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu thẻ'));
      await tester.pumpAndSettle();
      expect(controller.cardsInDeck('cooking'), hasLength(2));
      expect(controller.cards.first.topicCode, '');
      expect(controller.cardsInDeck('flutter-default'), hasLength(1));
      await tester.enterText(find.byType(TextField), 'Flutter');
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy thẻ'), findsOneWidget);
    },
  );
  testWidgets('Chuyển thẻ qua giao diện giữ tiến độ và cập nhật số câu', (
    tester,
  ) async {
    await show(tester, const ManageCardsScreen(deckId: 'cooking'));
    await expand(tester);
    await tester.ensureVisible(find.text('Chuyển bộ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyển bộ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('manage_move_destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Học Flutter').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('manage_deck_action_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thẻ nào'), findsOneWidget);
    expect(controller.cardsInDeck('flutter-default'), hasLength(2));
    expect(controller.cards.last.repetitions, 4);
  });
  testWidgets('Đổi tên có lỗi giữ nội dung nhập và thử lại được', (
    tester,
  ) async {
    await show(tester, const ManageDecksScreen());
    await actions(tester, 'Đổi tên / mô tả');
    await tester.enterText(
      find.byKey(const ValueKey('manage_deck_name')),
      'Bếp nhà',
    );
    store.writeFailure = StateError('Disk full');
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(
      find.text('Không thể lưu thay đổi. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(controller.deckById('cooking')!.name, 'Nấu ăn');
    store.writeFailure = null;
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(find.text('Bếp nhà'), findsOneWidget);
    expect(controller.cards.last.repetitions, 4);
  });
  testWidgets('Xóa bộ có xác nhận số câu; hủy, lỗi và chờ lưu đều an toàn', (
    tester,
  ) async {
    await show(tester, const ManageDecksScreen());
    await actions(tester, 'Xóa bộ thẻ');
    expect(find.textContaining('toàn bộ 1 câu hỏi'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(controller.decks, hasLength(2));
    await actions(tester, 'Xóa bộ thẻ');
    store.writeFailure = StateError('Disk full');
    await tester.tap(find.byKey(const ValueKey('manage_deck_action_confirm')));
    await tester.pumpAndSettle();
    expect(
      find.text('Không thể lưu thay đổi. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(controller.cards, hasLength(2));
    store.writeFailure = null;
    final gate = Completer<void>();
    store.writeGate = gate;
    await tester.tap(find.byKey(const ValueKey('manage_deck_action_confirm')));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('manage_deck_action_confirm')),
          )
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(controller.decks, hasLength(1));
    expect(controller.cards.single.id, 'flutter');
  });
  testWidgets('Xóa câu hỏi trong bộ không tác động bộ khác', (tester) async {
    await show(tester, const ManageCardsScreen(deckId: 'cooking'));
    await expand(tester);
    await tester.ensureVisible(find.text('Xóa thẻ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa thẻ'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Xóa thẻ'),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.cards.single.id, 'flutter');
    expect(find.text('Chưa có thẻ nào'), findsOneWidget);
  });
}
