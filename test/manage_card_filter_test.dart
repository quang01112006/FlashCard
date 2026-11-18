import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/services/manage_card_filter.dart';
import 'package:flashcard_sm2/services/manage_card_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final first = Flashcard(
    id: 'K01-001',
    topicCode: 'K01',
    level: 'Nhớ',
    front: 'Từ khóa const?',
    back: 'Hằng số.',
  );
  final second = Flashcard(
    id: 'K01-002',
    topicCode: 'K01',
    level: 'Hiểu',
    front: 'So sánh const và final?',
    back: 'Khác thời điểm khởi tạo.',
  );
  final third = Flashcard(
    id: 'K02-001',
    topicCode: 'K02',
    level: 'Nhớ',
    front: 'Công cụ Flutter?',
    back: 'Flutter CLI.',
  );
  final custom = Flashcard(id: 'custom', front: 'Tự tạo', back: 'Nội dung');
  final cards = List<Flashcard>.unmodifiable([first, second, third, custom]);

  test('Lọc riêng theo khối hoặc mức độ, giữ thứ tự thẻ', () {
    expect(const ManageCardFilter(topicCode: 'K01').apply(cards), [
      first,
      second,
    ]);
    expect(const ManageCardFilter(level: 'Nhớ').apply(cards), [first, third]);
    expect(const ManageCardFilter(topicCode: 'K20').apply(cards), isEmpty);
  });

  test('Khối, mức độ và từ khóa phải đồng thời khớp', () {
    const filter = ManageCardFilter(topicCode: 'K01', level: 'Hiểu');
    expect(filter.apply(cards), [second]);
    expect(ManageCardSearch.search(filter.apply(cards), 'FINAL'), [second]);
    expect(ManageCardSearch.search(filter.apply(cards), 'CLI'), isEmpty);
    expect(filter.activeCount, 2);
  });

  test('Bỏ lọc trả cả thẻ thiếu phân loại và không thay đổi nguồn', () {
    const filter = ManageCardFilter();
    final results = filter.apply(cards);
    expect(filter.isActive, isFalse);
    expect(results, [first, second, third, custom]);
    results.clear();
    expect(cards, hasLength(4));
    expect(const ManageCardFilter(level: 'Nhớ').activeCount, 1);
    expect(filter.apply([]), isEmpty);
  });

  test('Lọc khớp chính xác mã khối, không dựa vào tiền tố ID', () {
    final card = first.copyWith(id: 'K01-custom', topicCode: 'K010');
    expect(const ManageCardFilter(topicCode: 'K01').apply([card]), isEmpty);
    expect(ManageCardFilter.topicCodes, hasLength(20));
    expect(ManageCardFilter.topicCodes.first, 'K01');
    expect(ManageCardFilter.topicCodes.last, 'K20');
  });
}
