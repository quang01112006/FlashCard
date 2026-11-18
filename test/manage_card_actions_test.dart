import 'package:flashcard_sm2/widgets/manage_card_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'Ba thao tác đều nhau, chữ lớn và ${dark ? 'nền tối' : 'nền sáng'}',
      (tester) async {
        var edits = 0;
        var moves = 0;
        var deletes = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 260,
                  child: ManageCardActions(
                    showMove: true,
                    onEdit: () => edits++,
                    onMove: () => moves++,
                    onDelete: () => deletes++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final buttons = find.byType(TextButton);
        expect(buttons, findsNWidgets(3));
        final first = tester.getRect(buttons.at(0));
        for (var i = 1; i < 3; i++) {
          final other = tester.getRect(buttons.at(i));
          expect(other.width, closeTo(first.width, .1));
          expect(other.height, first.height);
          expect(other.top, first.top);
        }
        await tester.tap(find.text('Sửa thẻ'));
        await tester.tap(find.text('Chuyển bộ'));
        await tester.tap(find.text('Xóa thẻ'));
        expect([edits, moves, deletes], [1, 1, 1]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Đang bận vẫn giữ ba ô; bộ không có nơi chuyển chỉ hiện hai ô', (
    tester,
  ) async {
    Future<void> show(bool move) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManageCardActions(
            showMove: move,
            onEdit: null,
            onMove: null,
            onDelete: null,
          ),
        ),
      ),
    );
    await show(true);
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsNWidgets(3));
    for (final button in tester.widgetList<TextButton>(
      find.byType(TextButton),
    )) {
      expect(button.onPressed, isNull);
    }
    await show(false);
    await tester.pumpAndSettle();
    expect(find.text('Chuyển bộ'), findsNothing);
    expect(find.byType(TextButton), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
