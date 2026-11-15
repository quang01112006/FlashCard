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

  /// Kiểm tra thẻ có đến hạn cần ôn tập hôm nay hay không
  bool get isDueToday {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return nextReviewDate.isBefore(todayEnd);
  }

  Flashcard copyWith({
    String? id,
    String? topicCode,
    String? level,
    String? front,
    String? back,
    String? frontEn,
    String? backEn,
    int? repetitions,
    int? interval,
    double? easeFactor,
    DateTime? nextReviewDate,
  }) {
    return Flashcard(
      id: id ?? this.id,
      topicCode: topicCode ?? this.topicCode,
      level: level ?? this.level,
      front: front ?? this.front,
      back: back ?? this.back,
      frontEn: frontEn ?? this.frontEn,
      backEn: backEn ?? this.backEn,
      repetitions: repetitions ?? this.repetitions,
      interval: interval ?? this.interval,
      easeFactor: easeFactor ?? this.easeFactor,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
    );
  }
}
