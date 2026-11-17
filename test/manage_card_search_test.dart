import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/services/manage_card_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final first = Flashcard(
    id: 'K01-001',
    front: 'Từ khóa const dùng để làm gì?',
    back: 'Định nghĩa hằng số thời gian biên dịch.',
    frontEn: 'What does const do?',
    backEn: 'Creates a compile-time constant.',
  );
  final second = Flashcard(
    id: 'K02-001',
    front: 'Cách chạy ứng dụng Flutter?',
    back: 'Sử dụng lệnh flutter run.',
  );
  final cards = [first, second];

  test('Tìm theo mã, hai mặt thẻ và nội dung tiếng Anh', () {
    for (final query in [
      'K01-001',
      'const dùng',
      'biên dịch',
      'What does',
      'compile-time',
    ]) {
      expect(ManageCardSearch.search(cards, query), [first], reason: query);
    }
    expect(ManageCardSearch.search(cards, 'flutter run'), [second]);
  });

  test('Tìm tiếng Việt có dấu, không dấu, chữ hoa và dấu tổ hợp', () {
    for (final query in [
      'ĐỊNH NGHĨA',
      'dinh nghia',
      'đi\u0323nh nghi\u0303a',
    ]) {
      expect(ManageCardSearch.search(cards, query), [first], reason: query);
    }
    expect(ManageCardSearch.search(cards, 'UNG DUNG'), [second]);
  });

  test('Chuẩn hóa khoảng trắng trong từ khóa và nội dung', () {
    expect(ManageCardSearch.search(cards, '  const   dùng  '), [first]);
    final multiline = Flashcard(
      id: 'code',
      front: 'Dòng đầu\n\n  dòng sau',
      back: 'Đáp án',
    );
    expect(ManageCardSearch.search([multiline], 'đầu dòng sau'), [multiline]);
  });

  test('Từ khóa rỗng trả đủ thẻ, giữ thứ tự và không sửa nguồn', () {
    final source = List<Flashcard>.unmodifiable(cards);
    for (final query in ['', '   ', '\n\t']) {
      final results = ManageCardSearch.search(source, query);
      expect(results, [first, second]);
      results.clear();
      expect(source, [first, second]);
    }
    expect(ManageCardSearch.search(source, 'const'), [first]);
    expect(source, [first, second]);
  });

  test('Không có kết quả và danh sách nguồn rỗng không gây lỗi', () {
    expect(ManageCardSearch.search(cards, 'không tồn tại 987654'), isEmpty);
    expect(ManageCardSearch.search([], 'const'), isEmpty);
  });

  test('Tìm xuyên qua dấu định dạng và không nhầm nhãn ngôn ngữ code', () {
    final formatted = Flashcard(
      id: 'formatted',
      front: 'Trong khai báo `void greet(String name)`, tham số `name` là gì?',
      back: 'Ví dụ:\n\n```dart\nvoid greet(String name) {}\n```',
    );
    expect(ManageCardSearch.search([formatted], 'khai bao void greet'), [
      formatted,
    ]);
    expect(ManageCardSearch.search([formatted], 'tham so name la gi'), [
      formatted,
    ]);
    expect(ManageCardSearch.search([formatted], 'void greet(String name)'), [
      formatted,
    ]);
    expect(ManageCardSearch.search([formatted], '`void greet(String name)`'), [
      formatted,
    ]);
    expect(ManageCardSearch.search([formatted], 'dart'), isEmpty);
  });
}
