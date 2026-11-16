import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/flashcard.dart';

class CardController extends ChangeNotifier {
  final List<Flashcard> _cards = [];
  bool _isLoading = false;

  // Trạng thái đa ngôn ngữ dùng chung toàn app (Mặc định: Tiếng Việt)
  bool _isEnglish = false;

  // Trạng thái giao diện Tối / Sáng dùng chung toàn app
  bool _isDarkMode = false;

  List<Flashcard> get cards => _cards;
  bool get isLoading => _isLoading;
  bool get isEnglish => _isEnglish;
  bool get isDarkMode => _isDarkMode;

  /// Danh sách thẻ cần ôn hôm nay (SM-2 isDueToday)
  List<Flashcard> get dueCards => _cards.where((c) => c.isDueToday).toList();

  /// Số lượng thẻ cần ôn hôm nay (để hiển thị ở Trang chủ)
  int get dueCount => dueCards.length;

  /// Danh sách các mã khối kiến thức duy nhất (K01, K02...) có trong hệ thống
  List<String> get allTopics {
    final topics = _cards.map((c) => c.topicCode).where((t) => t.isNotEmpty).toSet().toList();
    topics.sort();
    return topics;
  }

  /// Nạp dữ liệu 300 câu hỏi môn học từ assets/default_cards.json
  Future<void> loadDefaultCards() async {
    if (_cards.isNotEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final jsonString =
          await rootBundle.loadString('assets/default_cards.json');
      final List<dynamic> jsonList = json.decode(jsonString);

      final loadedCards = jsonList.map((item) {
        return Flashcard.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();

      _cards.clear();
      _cards.addAll(loadedCards);
    } catch (e) {
      debugPrint('Lỗi nạp default_cards.json: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// TODO [Người 2 phụ trách Trang chủ & Lọc thẻ]:
  /// Lọc danh sách thẻ theo mã khối kiến thức (K01–K20)
  List<Flashcard> getCardsByTopic(String topicCode) {
    if (topicCode.isEmpty) return _cards;
    return _cards.where((c) => c.topicCode == topicCode).toList();
  }

  /// TODO [Người 4 phụ trách Cài đặt]:
  /// Khôi phục toàn bộ dữ liệu thẻ về trạng thái 300 câu hỏi gốc ban đầu
  Future<void> resetAllCards() async {
    _cards.clear();
    await loadDefaultCards();
    notifyListeners();
  }

  /// Cập nhật ngôn ngữ (Người 4 gọi ở Tab Cài đặt)
  void setLanguage(bool isEnglish) {
    if (_isEnglish != isEnglish) {
      _isEnglish = isEnglish;
      notifyListeners(); // Thông báo để toàn bộ app tự đổi ngôn ngữ
    }
  }

  /// Cập nhật Dark Mode (Người 4 gọi ở Tab Cài đặt)
  void setDarkMode(bool isDarkMode) {
    if (_isDarkMode != isDarkMode) {
      _isDarkMode = isDarkMode;
      notifyListeners(); // Thông báo để toàn bộ app đổi theme
    }
  }

  /// Thêm thẻ mới (Người 3 gọi ở Tab Quản lý thẻ)
  void addCard(Flashcard card) {
    _cards.insert(0, card);
    notifyListeners();
  }

  /// Xóa thẻ theo id (Người 3 gọi ở Tab Quản lý thẻ)
  void deleteCard(String id) {
    _cards.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  /// Cập nhật thẻ sau khi chấm điểm SM-2 (Leader gọi ở Tab Học thẻ)
  void updateCard(Flashcard updatedCard) {
    final index = _cards.indexWhere((c) => c.id == updatedCard.id);
    if (index != -1) {
      _cards[index] = updatedCard;
      notifyListeners();
    }
  }

  /// Nhập danh sách thẻ từ CSV (Người 3 gọi khi Import CSV)
  void importCards(List<Flashcard> newCards) {
    _cards.addAll(newCards);
    notifyListeners();
  }
}
