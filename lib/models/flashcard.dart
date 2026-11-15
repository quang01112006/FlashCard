class Flashcard {
  final String id;
  final String topicCode; // mã các khối kiến thức flutter
  final String level; // Nhớ, Hiểu, Vận dụng
  final String front;
  final String back;
  final String? frontEn; // Song ngữ Anh
  final String? backEn; // Song ngữ Anh

  // Các trường phục vụ thuật toán SM-2 (mặc định cho thẻ mới)
  final int repetitions;
  final int interval;
  final double easeFactor;
  final DateTime nextReviewDate;

  Flashcard({
    required this.id,
    this.topicCode = '',
    this.level = '',
    required this.front,
    required this.back,
    this.frontEn,
    this.backEn,
    this.repetitions = 0,
    this.interval = 0,
    this.easeFactor = 2.5,
    DateTime? nextReviewDate,
  }) : nextReviewDate = nextReviewDate ?? DateTime.now();
}
