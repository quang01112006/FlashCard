import 'package:dropdown_search/dropdown_search.dart';
import 'package:flashcard_sm2/widgets/manage_motion.dart';
import 'package:flashcard_sm2/widgets/manage_select_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final sheet in [false, true]) {
    testWidgets(
      'Giảm chuyển động vẫn mở/chọn/đóng được ${sheet ? 'bảng chọn' : 'menu'}',
      (tester) async {
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: ManageSelectField<String>(
                  searchableSheet: sheet,
                  initialValue: 'Nhớ',
                  decoration: const InputDecoration(labelText: 'Mức độ'),
                  items: [
                    for (final item in ['Nhớ', 'Hiểu', 'Vận dụng'])
                      DropdownMenuItem(value: item, child: Text(item)),
                  ],
                  onChanged: (value) => selected = value,
                ),
              ),
            ),
          ),
        );
        final props = tester
            .widget<DropdownSearch<String>>(find.byType(DropdownSearch<String>))
            .popupProps;
        final style = sheet
            ? props.modalBottomSheetProps.sheetAnimationStyle
            : props.menuProps.popUpAnimationStyle;
        expect(style?.duration, Duration.zero);
        expect(style?.reverseDuration, Duration.zero);
        await tester.tap(find.byType(ManageSelectField<String>));
        await tester.pumpAndSettle();
        final choice = find.text('Vận dụng').last;
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        await tester.tapAt(tester.getCenter(choice));
        await tester.pumpAndSettle();
        expect(selected, 'Vận dụng');
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Nhãn đang xử lý cuộn chữ lớn không tràn và không chạy animation liên tục',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2),
              accessibleNavigation: true,
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 160,
                child: ElevatedButton(
                  onPressed: null,
                  child: ManageActionLabel(
                    busy: true,
                    label: 'Đang lưu thay đổi...',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đang lưu thay đổi...'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
