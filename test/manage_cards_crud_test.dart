import 'dart:async';
import 'dart:convert';

import 'package:flashcard_sm2/controllers/card_controller.dart';
import 'package:flashcard_sm2/core/app_theme.dart';
import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/screens/main_nav_screen.dart';
import 'package:flashcard_sm2/screens/manage_card_editor_screen.dart';
import 'package:flashcard_sm2/screens/manage_cards_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/manage_card_test_store.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.cards);
  final List<Flashcard> cards;
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      jsonEncode(cards.map((card) => card.toJson()).toList());
  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

Flashcard _card(String id, String front) => Flashcard(
  id: id,
  topicCode: 'K01',
  level: 'Nhớ',
  front: front,
  back: 'Đáp án $id',
  frontEn: 'Question $id',
  backEn: 'Answer $id',
);

Future<void> _show(
  WidgetTester tester,
  CardController controller, {
  Widget home = const ManageCardsScreen(),
}) => tester.pumpWidget(
  ChangeNotifierProvider.value(
    value: controller,
    child: MaterialApp(theme: AppTheme.lightTheme, home: home),
  ),
);

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    field,
    160,
    scrollable: find
        .descendant(of: find.byType(Form), matching: find.byType(Scrollable))
        .first,
  );
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> _openActions(WidgetTester tester, String id) async {
  final tile = find.byKey(PageStorageKey('manage_card_$id'));
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  if (find
      .descendant(of: tile, matching: find.text('Sửa thẻ'))
      .evaluate()
      .isEmpty) {
    await tester.tap(
      find.descendant(of: tile, matching: find.byIcon(Icons.expand_more)),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _deleteButton() => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.text('Xóa thẻ'),
);

void main() {
  late MemoryManageCardStore store;
  late CardController controller;
  setUp(() async {
    store = MemoryManageCardStore();
    controller = CardController(
      store: store,
      assetBundle: _Bundle([_card('seed', 'Câu hỏi gốc')]),
    );
    await controller.loadDefaultCards();
  });
  tearDown(() => controller.dispose());

  testWidgets('Thêm, sửa, hủy xóa và xác nhận xóa qua giao diện', (
    tester,
  ) async {
    await _show(tester, controller);
    await tester.enterText(find.byType(TextField), 'khongco987');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('manage_add_card')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu thẻ'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập câu hỏi.'), findsOneWidget);
    expect(store.writes, 0);
    await _enter(tester, 'manage_editor_front', 'Thẻ mới');
    await _enter(
      tester,
      'manage_editor_back',
      '```dart\nconst value = 42;\n```',
    );
    await _enter(tester, 'manage_editor_front_en', 'New card');
    await _enter(tester, 'manage_editor_back_en', 'English answer');
    await tester.tap(find.text('Lưu thẻ'));
    await tester.pumpAndSettle();
    expect(find.byType(ManageCardEditorScreen), findsNothing);
    expect(find.text('2 thẻ'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    final added = controller.cards.first;
    expect(added.id, startsWith('USER-'));
    expect(added.frontEn, 'New card');
    expect(added.repetitions, 0);
    expect(added.easeFactor, 2.5);
    await controller.updateCard(
      added.copyWith(
        repetitions: 3,
        interval: 15,
        nextReviewDate: DateTime(2030, 1, 1),
      ),
    );
    await tester.pumpAndSettle();
    await _openActions(tester, added.id);
    await _tapVisible(tester, find.text('Sửa thẻ'));
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('manage_editor_front')),
          )
          .controller!
          .text,
      'Thẻ mới',
    );
    await _enter(tester, 'manage_editor_front', 'Thẻ đã sửa');
    await _enter(tester, 'manage_editor_front_en', '');
    await tester.tap(find.text('Lưu thẻ'));
    await tester.pumpAndSettle();
    final edited = controller.cards.firstWhere((card) => card.id == added.id);
    expect(edited.front, 'Thẻ đã sửa');
    expect(edited.frontEn, '');
    expect(edited.repetitions, 3);
    expect(edited.interval, 15);
    await _openActions(tester, added.id);
    await _tapVisible(tester, find.text('Xóa thẻ'));
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(controller.cards, hasLength(2));
    await _tapVisible(tester, find.text('Xóa thẻ'));
    await tester.tap(_deleteButton());
    await tester.pumpAndSettle();
    expect(controller.cards.single.id, 'seed');
    expect(find.text('1 thẻ'), findsOneWidget);
  });

  testWidgets('Lưu lỗi giữ nội dung, thử lại được và không tạo thẻ trùng', (
    tester,
  ) async {
    await _show(tester, controller);
    await tester.tap(find.byKey(const ValueKey('manage_add_card')));
    await tester.pumpAndSettle();
    await _enter(tester, 'manage_editor_front', 'Chưa lưu được');
    await _enter(tester, 'manage_editor_back', 'Giữ lại đáp án');
    store.writeFailure = StateError('Unavailable');
    await tester.tap(find.text('Lưu thẻ'));
    await tester.pumpAndSettle();
    expect(
      find.text('Không thể lưu thay đổi. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(controller.cards, hasLength(1));
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('manage_editor_front')),
          )
          .controller!
          .text,
      'Chưa lưu được',
    );
    store.writeFailure = null;
    store.writeGate = Completer<void>();
    await tester.tap(find.text('Lưu thẻ'));
    await tester.pump();
    expect(find.text('Đang lưu...'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(ManageCardEditorScreen), findsOneWidget);
    store.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(controller.cards, hasLength(2));
    expect(store.writes, 2);
  });

  testWidgets('Quay lại khi đang nhập cho phép tiếp tục hoặc bỏ thay đổi', (
    tester,
  ) async {
    await _show(tester, controller);
    await tester.tap(find.byKey(const ValueKey('manage_add_card')));
    await tester.pumpAndSettle();
    await _enter(tester, 'manage_editor_front', 'Bản nháp');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thay đổi?'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Bản nháp'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ thay đổi'));
    await tester.pumpAndSettle();
    expect(find.byType(ManageCardEditorScreen), findsNothing);
    expect(store.writes, 0);
  });

  testWidgets('Xóa lỗi giữ hộp thoại; thử lại đến bộ thẻ rỗng có lối thêm', (
    tester,
  ) async {
    await _show(tester, controller);
    await _openActions(tester, 'seed');
    await _tapVisible(tester, find.text('Xóa thẻ'));
    store.writeFailure = StateError('Unavailable');
    await tester.tap(_deleteButton());
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(controller.cards, hasLength(1));
    expect(
      find.text('Không thể lưu thay đổi. Vui lòng thử lại.'),
      findsOneWidget,
    );
    store.writeFailure = null;
    await tester.tap(_deleteButton());
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thẻ nào'), findsOneWidget);
    expect(controller.cards, isEmpty);
    await tester.tap(find.text('Thêm thẻ mới'));
    await tester.pumpAndSettle();
    expect(find.byType(ManageCardEditorScreen), findsOneWidget);
  });

  testWidgets('Form nhập cuộn được với màn hình hẹp, chữ lớn và bàn phím', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetViewInsets);
    await _show(tester, controller);
    await tester.tap(find.byKey(const ValueKey('manage_add_card')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pump();
    await _enter(tester, 'manage_editor_front', 'Câu hỏi màn hình hẹp');
    await _enter(tester, 'manage_editor_back', 'Đáp án');
    await tester.tap(find.text('Lưu thẻ'));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(controller.cards, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Phiên Học thẻ nhận sửa/xóa/thêm mới thay cho dữ liệu đã chụp trước đó',
    (tester) async {
      await _show(tester, controller, home: const MainNavScreen());
      await controller.editCard(
        controller.cards.single.copyWith(front: 'Đã sửa ở Bộ thẻ'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Học thẻ'));
      await tester.pumpAndSettle();
      expect(find.text('Đã sửa ở Bộ thẻ'), findsOneWidget);
      await controller.deleteCard('seed');
      await tester.pumpAndSettle();
      expect(find.text('Chưa có thẻ nào trong phiên học!'), findsOneWidget);
      await controller.addCard(_card('fresh', 'Thẻ mới trong phiên'));
      await tester.pumpAndSettle();
      expect(find.text('Thẻ mới trong phiên'), findsOneWidget);
      expect(find.text('Đã sửa ở Bộ thẻ'), findsNothing);
      await tester.tap(find.text('Hiện đáp án'));
      await tester.pumpAndSettle();
      store.writeFailure = StateError('Disk full');
      await tester.tap(find.text('Tốt'));
      await tester.pumpAndSettle();
      expect(controller.cards.single.repetitions, 0);
      expect(
        find.text('Không thể lưu thay đổi. Vui lòng thử lại.'),
        findsOneWidget,
      );
      store.writeFailure = null;
      await tester.tap(find.text('Tốt'));
      await tester.pumpAndSettle();
      expect(controller.cards.single.repetitions, 1);
      expect(find.text('Tuyệt vời!'), findsOneWidget);
    },
  );
}
