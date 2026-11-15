import 'package:flutter/foundation.dart';
import '../models/flashcard.dart';

class CardController extends ChangeNotifier {
  final List<Flashcard> _cards = [];
  bool _isLoading = false;

  List<Flashcard> get cards => _cards;
  bool get isLoading => _isLoading;

  /// Danh sách thẻ cần ôn hôm nay
  List<Flashcard> get dueCards => _cards.where((c) => c.isDueToday).toList();

  /// Số lượng thẻ cần ôn hôm nay (để hiển thị ở Trang chủ)
  int get dueCount => dueCards.length;

  /// TODO [Member phụ trách Data / Storage]:
  /// Viết code đọc file assets/default_cards.json hoặc mở Hive box để nạp thẻ vào _cards
  Future<void> loadDefaultCards() async {
    _isLoading = true;
    notifyListeners();

    // Viết logic nạp dữ liệu ở đây...

    _isLoading = false;
    notifyListeners();
  }

  /// TODO [Member phụ trách Quản lý thẻ]:
  /// Viết code thêm thẻ mới vào _cards và lưu trữ
  void addCard(Flashcard card) {
    // Viết code thêm thẻ và gọi notifyListeners() ở đây...
  }

  /// TODO [Member phụ trách Quản lý thẻ]:
  /// Viết code xóa thẻ theo id
  void deleteCard(String id) {
    // Viết code xóa thẻ và gọi notifyListeners() ở đây...
  }

  /// TODO [Member phụ trách Màn hình Học]:
  /// Viết code cập nhật thông tin thẻ sau khi chấm điểm SM-2 (repetitions, interval, easeFactor...)
  void updateCard(Flashcard updatedCard) {
    // Viết code cập nhật thẻ và gọi notifyListeners() ở đây...
  }

  /// TODO [Member phụ trách CSV]:
  /// Viết code nhận danh sách thẻ đã parse từ file CSV và thêm vào _cards
  void importCards(List<Flashcard> newCards) {
    // Viết code import thẻ và gọi notifyListeners() ở đây...
  }
}
