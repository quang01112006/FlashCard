import 'package:flutter_test/flutter_test.dart';
import 'package:flashcard_sm2/logic/sm2_algorithm.dart';

void main() {
  group('Kiểm thử Thuật toán SuperMemo SM-2 (Unit Tests)', () {
    final fixedDate = DateTime(2026, 11, 15);

    test('Case 1: Lần đầu học thẻ, đánh giá Tốt (Good - q=4) -> interval=1, repetitions=1', () {
      final result = SM2Algorithm.calculateWithRating(
        currentRepetitions: 0,
        currentInterval: 0,
        currentEaseFactor: 2.5,
        rating: ReviewRating.good,
        fromDate: fixedDate,
      );

      expect(result.repetitions, 1);
      expect(result.interval, 1);
      expect(result.easeFactor, 2.5); // q=4 giữ nguyên EF 2.5
      expect(result.nextReviewDate, fixedDate.add(const Duration(days: 1)));
    });

    test('Case 2: Ôn tập lần 2 thành công (Good - q=4) -> interval nhảy lên 6 ngày', () {
      final result = SM2Algorithm.calculateWithRating(
        currentRepetitions: 1,
        currentInterval: 1,
        currentEaseFactor: 2.5,
        rating: ReviewRating.good,
        fromDate: fixedDate,
      );

      expect(result.repetitions, 2);
      expect(result.interval, 6);
      expect(result.nextReviewDate, fixedDate.add(const Duration(days: 6)));
    });

    test('Case 3: Ôn tập lần 3 thành công (Good - q=4) -> interval = (6 * EF).round()', () {
      final result = SM2Algorithm.calculateWithRating(
        currentRepetitions: 2,
        currentInterval: 6,
        currentEaseFactor: 2.5,
        rating: ReviewRating.good,
        fromDate: fixedDate,
      );

      expect(result.repetitions, 3);
      expect(result.interval, 15); // 6 * 2.5 = 15 ngày
      expect(result.nextReviewDate, fixedDate.add(const Duration(days: 15)));
    });

    test('Case 4: Đánh giá Quên (Again - q=1) -> repetitions reset về 0, interval về 1', () {
      final result = SM2Algorithm.calculateWithRating(
        currentRepetitions: 5,
        currentInterval: 30,
        currentEaseFactor: 2.5,
        rating: ReviewRating.again,
        fromDate: fixedDate,
      );

      expect(result.repetitions, 0); // Bị reset chuỗi
      expect(result.interval, 1);    // Ngày mai ôn lại ngay
      expect(result.nextReviewDate, fixedDate.add(const Duration(days: 1)));
    });

    test('Case 5: Đánh giá Dễ (Easy - q=5) -> Hệ số EF tăng lên', () {
      final result = SM2Algorithm.calculateWithRating(
        currentRepetitions: 2,
        currentInterval: 6,
        currentEaseFactor: 2.5,
        rating: ReviewRating.easy,
        fromDate: fixedDate,
      );

      // Công thức: 2.5 + (0.1 - 0) = 2.6
      expect(result.easeFactor, 2.6);
      expect(result.easeFactor, greaterThan(2.5));
    });

    test('Case 6: Đánh giá Khó (Hard - q=3) -> Hệ số EF giảm xuống', () {
      final result = SM2Algorithm.calculateWithRating(
        currentRepetitions: 2,
        currentInterval: 6,
        currentEaseFactor: 2.5,
        rating: ReviewRating.hard,
        fromDate: fixedDate,
      );

      // Công thức: 2.5 + (0.1 - 2 * (0.08 + 0.04)) = 2.36
      expect(result.easeFactor, 2.36);
      expect(result.easeFactor, lessThan(2.5));
    });

    test('Case 7: Hệ số EF không bao giờ giảm xuống dưới 1.3 dù đánh giá khó liên tục', () {
      final result = SM2Algorithm.calculate(
        currentRepetitions: 1,
        currentInterval: 1,
        currentEaseFactor: 1.35,
        quality: 0, // hoàn toàn quên
        fromDate: fixedDate,
      );

      expect(result.easeFactor, 1.3); // Chặn sàn tối thiểu 1.3
    });

    test('Case 8: Chuỗi ôn tập tăng trưởng lũy tiến khi liên tục đánh giá Dễ (Easy)', () {
      final r1 = SM2Algorithm.calculateWithRating(
        currentRepetitions: 2,
        currentInterval: 6,
        currentEaseFactor: 2.5,
        rating: ReviewRating.easy,
      );
      final r2 = SM2Algorithm.calculateWithRating(
        currentRepetitions: r1.repetitions,
        currentInterval: r1.interval,
        currentEaseFactor: r1.easeFactor,
        rating: ReviewRating.easy,
      );

      expect(r2.interval, greaterThan(r1.interval));
      expect(r2.repetitions, 4);
    });

    test('Case 9: Đánh giá quality=2 (vẫn tính là thất bại) -> repetitions reset về 0', () {
      final result = SM2Algorithm.calculate(
        currentRepetitions: 3,
        currentInterval: 15,
        currentEaseFactor: 2.2,
        quality: 2,
        fromDate: fixedDate,
      );

      expect(result.repetitions, 0);
      expect(result.interval, 1);
    });

    test('Case 10: Ngày ôn tập tiếp theo nextReviewDate phản ánh đúng số ngày interval', () {
      final base = DateTime(2027, 5, 1);
      final result = SM2Algorithm.calculateWithRating(
        currentRepetitions: 0,
        currentInterval: 0,
        currentEaseFactor: 2.5,
        rating: ReviewRating.good,
        fromDate: base,
      );

      expect(result.nextReviewDate, DateTime(2027, 5, 2));
    });
  });
}
