class Flashcard {
  final String id;
  final String topicCode; // Mã các khối kiến thức Flutter (K01–K20)
  final String level; // Mức độ nhận thức: Nhớ, Hiểu, Vận dụng
  final String front;
  final String back;
  final String? frontEn;
  final String? backEn;

  // Các trường phục vụ thuật toán SM-2
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

  /// Chuyển đổi sang Map/JSON (Dùng chung cho lưu Hive, xuất file CSV/JSON)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topicCode': topicCode,
      'level': level,
      'front': front,
      'back': back,
      'front_en': frontEn,
      'back_en': backEn,
      'repetitions': repetitions,
      'interval': interval,
      'easeFactor': easeFactor,
      'nextReviewDate': nextReviewDate.toIso8601String(),
    };
  }

  /// Khởi tạo từ Map/JSON (Hỗ trợ an toàn cả định dạng camelCase và snake_case)
  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id']?.toString() ?? '',
      topicCode: json['topicCode']?.toString() ?? '',
      level: json['level']?.toString() ?? '',
      front: json['front']?.toString() ?? '',
      back: json['back']?.toString() ?? '',
      frontEn: (json['front_en'] ?? json['frontEn'])?.toString(),
      backEn: (json['back_en'] ?? json['backEn'])?.toString(),
      repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
      interval: (json['interval'] as num?)?.toInt() ?? 0,
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      nextReviewDate: json['nextReviewDate'] != null
          ? DateTime.tryParse(json['nextReviewDate'].toString()) ??
                DateTime.now()
          : DateTime.now(),
    );
  }
}
