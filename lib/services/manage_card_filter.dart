import '../models/flashcard.dart';

/// Tiêu chí lọc riêng cho tab Bộ thẻ, không sửa dữ liệu dùng chung.
class ManageCardFilter {
  const ManageCardFilter({this.topicCode, this.level});

  final String? topicCode;
  final String? level;

  static final topicCodes = List<String>.unmodifiable(
    List.generate(20, (index) => 'K${(index + 1).toString().padLeft(2, '0')}'),
  );
  static const levels = ['Nhớ', 'Hiểu', 'Vận dụng'];

  int get activeCount => (topicCode == null ? 0 : 1) + (level == null ? 0 : 1);
  bool get isActive => activeCount > 0;

  List<Flashcard> apply(Iterable<Flashcard> cards) {
    return cards.where((card) {
      return (topicCode == null || card.topicCode == topicCode) &&
          (level == null || card.level == level);
    }).toList();
  }
}
