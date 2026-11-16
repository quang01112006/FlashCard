import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/flashcard.dart';

class CardController extends ChangeNotifier {
  CardController({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;
  final List<Flashcard> _cards = [];
  bool _isLoading = false;
  String? _loadError;

  // Trạng thái đa ngôn ngữ dùng chung toàn app (Mặc định: Tiếng Việt)
  bool _isEnglish = false;

  // Trạng thái giao diện Tối / Sáng dùng chung toàn app
  bool _isDarkMode = false;

  List<Flashcard> get cards => _cards;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  bool get isEnglish => _isEnglish;
  bool get isDarkMode => _isDarkMode;

  /// Danh sách thẻ cần ôn hôm nay (SM-2 isDueToday)
  List<Flashcard> get dueCards => _cards.where((c) => c.isDueToday).toList();

  /// Số lượng thẻ cần ôn hôm nay (để hiển thị ở Trang chủ)
  int get dueCount => dueCards.length;

  /// Danh sách các mã khối kiến thức duy nhất (K01, K02...) có trong hệ thống
  List<String> get allTopics {
    final topics = _cards
        .map((c) => c.topicCode)
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    topics.sort();
    return topics;
  }

  /// Nạp dữ liệu 300 câu hỏi môn học từ assets/default_cards.json
  /// Không nạp đè thẻ đang có trừ khi yêu cầu tải lại rõ ràng.
  /// Member Data / Storage sẽ bổ sung đọc dữ liệu đã lưu trước bước này.
  Future<void> loadDefaultCards({bool forceReload = false}) async {
    if (_isLoading || (_cards.isNotEmpty && !forceReload)) return;

    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      final json = jsonDecode(
        await _assetBundle.loadString('assets/default_cards.json'),
      );
      if (json is! List) {
        throw const FormatException('Expected a list of flashcards.');
      }

      final ids = <String>{};
      final loadedCards = json.map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException('Invalid flashcard record.');
        }
        for (final field in ['id', 'front', 'back']) {
          final value = entry[field];
          if (value is! String || value.trim().isEmpty) {
            throw FormatException('Invalid flashcard field: $field.');
          }
        }
        final id = entry['id'] as String;
        if (!ids.add(id)) {
          throw const FormatException('Duplicate flashcard ID.');
        }
        return Flashcard.fromJson(entry);
      }).toList();

      // Chỉ thay danh sách sau khi toàn bộ dữ liệu đã được đọc hợp lệ.
      _cards
        ..clear()
        ..addAll(loadedCards);
    } catch (e) {
      _loadError = 'Không thể tải bộ thẻ. Vui lòng thử lại.';
      debugPrint('Lỗi nạp default_cards.json: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// TODO [Người 2 phụ trách Trang chủ & Lọc thẻ]:
  /// Viết logic lọc danh sách thẻ theo mã khối kiến thức (K01–K20)
  List<Flashcard> getCardsByTopic(String topicCode) {
    // TODO: Người 2 điền code lọc danh sách thẻ ở đây
    return [];
  }

  /// TODO [Người 4 phụ trách Cài đặt]:
  /// Viết logic khôi phục toàn bộ dữ liệu thẻ về trạng thái 300 câu hỏi gốc ban đầu
  Future<void> resetAllCards() async {
    // TODO: Người 4 điền code reset ở đây
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

  /// TODO [Người 3 phụ trách Quản lý thẻ]:
  /// Viết logic thêm thẻ mới vào hệ thống
  void addCard(Flashcard card) {
    // TODO: Người 3 điền code thêm thẻ ở đây
  }

  /// TODO [Người 3 phụ trách Quản lý thẻ]:
  /// Viết logic xóa thẻ theo id khỏi hệ thống
  void deleteCard(String id) {
    // TODO: Người 3 điền code xóa thẻ ở đây
  }

  /// Cập nhật thẻ sau khi chấm điểm SM-2 (Leader gọi ở Tab Học thẻ)
  void updateCard(Flashcard updatedCard) {
    final index = _cards.indexWhere((c) => c.id == updatedCard.id);
    if (index != -1) {
      _cards[index] = updatedCard;
      notifyListeners();
    }
  }

  /// TODO [Người 3 phụ trách Quản lý thẻ]:
  /// Viết logic nạp danh sách thẻ từ file CSV hoặc AI
  void importCards(List<Flashcard> newCards) {
    // TODO: Người 3 điền code import thẻ ở đây
  }
}
