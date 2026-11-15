import 'package:flutter_test/flutter_test.dart';
import 'package:flashcard_sm2/main.dart';

void main() {
  testWidgets('Kiểm tra hiển thị thanh điều hướng 4 Tab cơ bản', (WidgetTester tester) async {
    await tester.pumpWidget(const FlashcardApp());

    // Kiểm tra có đủ 4 tab
    expect(find.text('Trang chủ'), findsWidgets);
    expect(find.text('Học thẻ'), findsOneWidget);
    expect(find.text('Bộ thẻ'), findsOneWidget);
    expect(find.text('Cài đặt'), findsOneWidget);
  });
}
