/// Định nghĩa 4 mức đánh giá chất lượng ghi nhớ (Ánh xạ từ thang 0-5 của SM-2)
enum ReviewRating {
  again(1, 'Học lại'), // Chả nhớ gì (Fail)
  hard(3, 'Khó'), // Nhớ nhưng rất khó khăn (Pass)
  good(4, 'Tốt'), // Nhớ bình thường sau chút đắn đo (Pass)
  easy(5, 'Dễ'); // Nhắm mắt cũng làm được (Pass)

  final int quality;
  final String label;
  const ReviewRating(this.quality, this.label);
}

/// Kết quả đầu ra sau khi tính toán thuật toán SM-2
class SM2Result {
  final int repetitions; // Số lần ôn tập thành công liên tiếp
  final int interval; // Khoảng thời gian đến lần ôn tiếp theo (tính theo ngày)
  final double easeFactor; // Hệ số độ dễ (Easiness Factor, tối thiểu 1.3)
  final DateTime nextReviewDate; // Ngày cụ thể cần ôn tập tiếp theo

  const SM2Result({
    required this.repetitions,
    required this.interval,
    required this.easeFactor,
    required this.nextReviewDate,
  });

  @override
  String toString() {
    return 'SM2Result(repetitions: $repetitions, interval: ${interval}d, EF: $easeFactor, next: $nextReviewDate)';
  }
}

/// Triển khai thuật toán SM-2
class SM2Algorithm {
  /// Tính toán trạng thái ôn tập mới dựa trên lịch sử và mức độ nhớ của user
  static SM2Result calculate({
    required int currentRepetitions,
    required int currentInterval,
    required double currentEaseFactor,
    required int quality, // Giá trị từ 0 đến 5
    DateTime? fromDate, // Cho phép truyền ngày tùy chọn để phục vụ Unit Test
  }) {
    final baseDate = fromDate ?? DateTime.now();

    // 1. Tính hệ số độ dễ mới (EF') theo công thức gốc:
    // EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    double newEaseFactor =
        currentEaseFactor +
        (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));

    // Thuật toán SM-2 quy định hệ số độ dễ không bao giờ được nhỏ hơn 1.3
    if (newEaseFactor < 1.3) {
      newEaseFactor = 1.3;
    }

    int newRepetitions;
    int newInterval;

    // 2. Phân nhánh theo kết quả ghi nhớ:
    if (quality < 3) {
      // THẤT BẠI (Quên): Reset chuỗi ôn tập về 0, bắt buộc ôn lại sau 1 ngày
      newRepetitions = 0;
      newInterval = 1;
    } else {
      // THÀNH CÔNG: Tăng dần khoảng cách ôn tập theo từng giai đoạn
      if (currentRepetitions == 0) {
        newInterval = 1; // Lần 1: 1 ngày sau
      } else if (currentRepetitions == 1) {
        newInterval = 6; // Lần 2: 6 ngày sau
      } else {
        // Lần 3 trở đi: Khoảng cách = Khoảng cách trước * Hệ số độ dễ mới
        newInterval = (currentInterval * newEaseFactor).round();
      }
      newRepetitions = currentRepetitions + 1;
    }

    // Làm tròn 2 chữ số thập phân cho EF để tránh sai số dấu phẩy động
    newEaseFactor = double.parse(newEaseFactor.toStringAsFixed(2));

    // Tính ngày ôn tập tiếp theo
    final nextReviewDate = baseDate.add(Duration(days: newInterval));

    return SM2Result(
      repetitions: newRepetitions,
      interval: newInterval,
      easeFactor: newEaseFactor,
      nextReviewDate: nextReviewDate,
    );
  }

  /// Hàm tiện ích: Gọi trực tiếp bằng ReviewRating enum
  static SM2Result calculateWithRating({
    required int currentRepetitions,
    required int currentInterval,
    required double currentEaseFactor,
    required ReviewRating rating,
    DateTime? fromDate,
  }) {
    return calculate(
      currentRepetitions: currentRepetitions,
      currentInterval: currentInterval,
      currentEaseFactor: currentEaseFactor,
      quality: rating.quality,
      fromDate: fromDate,
    );
  }
}
