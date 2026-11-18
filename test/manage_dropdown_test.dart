import 'package:flashcard_sm2/widgets/manage_select_field.dart';
import 'package:flashcard_sm2/controllers/card_controller.dart';
import 'package:flashcard_sm2/models/card_deck.dart';
import 'package:flashcard_sm2/screens/manage_card_editor_screen.dart';
import 'package:flashcard_sm2/screens/study_decks_screen.dart';
import 'package:flashcard_sm2/services/manage_card_filter.dart';
import 'package:flashcard_sm2/widgets/manage_card_filters_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/manage_deck_test_store.dart';

void main() {
  late CardController controller;
  setUp(() async {
    final store = MemoryDeckTestStore()
      ..decks = [
        const CardDeck(
          id: CardDeck.flutterId,
          name:
              'Bộ câu hỏi Flutter với tên rất dài để kiểm tra chiều rộng menu',
        ),
        for (var i = 0; i < 12; i++)
          CardDeck(id: 'deck-$i', name: 'Bộ kiến thức mở rộng số $i'),
      ]
      ..savedCards = [];
    controller = CardController(store: store);
    await controller.loadDefaultCards();
  });
  tearDown(() => controller.dispose());

  Future<void> show(
    WidgetTester tester,
    Widget child, {
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> checkMenu(WidgetTester tester, Finder field) async {
    final box = tester.getRect(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    final menu = tester.getRect(find.byType(ListView).last);
    final sheet = tester
        .widget<ManageSelectField<String>>(field)
        .searchableSheet;
    expect(menu.left, greaterThanOrEqualTo(sheet ? 0 : box.left - 1));
    expect(menu.right, lessThanOrEqualTo(sheet ? 320 : box.right + 1));
    expect(menu.height, lessThanOrEqualTo(sheet ? 449 : 289));
    expect(menu.top, greaterThanOrEqualTo(0));
    expect(menu.bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);
  }

  testWidgets('Mức độ trong form không tràn chiều rộng ô và vẫn chọn được', (
    tester,
  ) async {
    await show(
      tester,
      const ManageCardEditorScreen(deckId: CardDeck.flutterId),
    );
    final field = find.byKey(const ValueKey('manage_editor_level'));
    await tester.scrollUntilVisible(
      field,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await checkMenu(tester, field);
    await tester.ensureVisible(find.text('Vận dụng').last);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('Vận dụng').last));
    await tester.pumpAndSettle();
    expect(find.text('Vận dụng'), findsOneWidget);
  });

  testWidgets('Bộ đang học tên dài, menu có cuộn và đóng khi chạm ngoài', (
    tester,
  ) async {
    await show(tester, const StudyDecksScreen(), dark: true);
    final field = find.byWidgetPredicate((w) => w is ManageSelectField<String>);
    await checkMenu(tester, field);
    final list = find.byType(ListView).last;
    final scrollable = find
        .descendant(of: list, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      find.text('Bộ kiến thức mở rộng số 11'),
      200,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(find.text('Bộ kiến thức mở rộng số 11').last),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: field,
        matching: find.text('Bộ kiến thức mở rộng số 11'),
      ),
      findsOneWidget,
    );
    await checkMenu(tester, field);
    await tester.tapAt(const Offset(4, 20));
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bộ lọc dùng cùng chiều rộng và hỗ trợ chủ đề dài', (
    tester,
  ) async {
    await show(
      tester,
      const Scaffold(
        body: ManageCardFiltersSheet(
          initialFilter: ManageCardFilter(),
          includeFlutterTopics: false,
          topics: ['Một chủ đề dài để thử menu nhiều dòng trên màn hình hẹp'],
        ),
      ),
    );
    await checkMenu(tester, find.byKey(const ValueKey('manage_filter_topic')));
    final choice = find
        .text('Một chủ đề dài để thử menu nhiều dòng trên màn hình hẹp')
        .last;
    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(choice));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tìm bộ, kết quả rỗng và chọn khi mở bàn phím', (tester) async {
    await show(tester, const StudyDecksScreen(), dark: true);
    final field = find.byType(ManageSelectField<String>);
    await tester.tap(field);
    await tester.pumpAndSettle();
    final search = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(search, 'không có bộ này');
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy kết quả phù hợp.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(search, 'số 11');
    await tester.pumpAndSettle();
    final choice = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('Bộ kiến thức mở rộng số 11'),
    );
    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(choice));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      find.descendant(
        of: field,
        matching: find.text('Bộ kiến thức mở rộng số 11'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
