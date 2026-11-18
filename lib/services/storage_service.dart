import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/flashcard.dart';

class StorageService {
  static const String _boxName = 'flashcards_box';
  static bool _isInitialized = false;

  /// Khởi tạo Hive và mở Box lưu trữ (an toàn khi gọi nhiều lần)
  Future<Box> _getBox() async {
    if (!_isInitialized) {
      await Hive.initFlutter();
      _isInitialized = true;
    }
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  /// Nạp 300 câu hỏi từ assets/default_cards.json vào Hive khi mở app lần đầu.
  /// Nếu Hive đã có dữ liệu thì đọc từ Hive ra để giữ nguyên tiến độ ôn tập SM-2.
  Future<List<Flashcard>> initAndLoadCards({
    String assetPath = 'assets/default_cards.json',
  }) async {
    final box = await _getBox();

    // Lần đầu mở app (Box rỗng) -> Đọc từ JSON và lưu vào Hive
    if (box.isEmpty) {
      final defaultCards = await loadCardsFromJsonAsset(assetPath);
      await saveAllCards(defaultCards);
      return defaultCards;
    }

    // Các lần mở sau -> Lấy danh sách thẻ đã lưu trong Hive
    return getAllCards();
  }

  /// Đọc và chuyển đổi dữ liệu từ file JSON asset thành danh sách Flashcard
  Future<List<Flashcard>> loadCardsFromJsonAsset(String assetPath) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      return parseCardsFromJsonString(jsonString);
    } catch (e) {
      debugPrint('Lỗi đọc file JSON ($assetPath): $e');
      return [];
    }
  }

  /// Hàm tách riêng logic parse chuỗi JSON (giúp viết Unit Test dễ dàng)
  List<Flashcard> parseCardsFromJsonString(String jsonString) {
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
    return jsonList.map((item) {
      return Flashcard.fromJson(Map<String, dynamic>.from(item as Map));
    }).toList();
  }

  /// Lấy toàn bộ thẻ đang có trong Hive
  Future<List<Flashcard>> getAllCards() async {
    final box = await _getBox();
    return box.values.map((item) {
      return Flashcard.fromJson(Map<String, dynamic>.from(item as Map));
    }).toList();
  }

  /// Lưu danh sách nhiều thẻ vào Hive (dùng id thẻ làm key)
  Future<void> saveAllCards(List<Flashcard> cards) async {
    final box = await _getBox();
    final Map<String, Map<String, dynamic>> entries = {
      for (final card in cards) card.id: card.toJson(),
    };
    await box.putAll(entries);
  }

  /// Lưu hoặc cập nhật 1 thẻ vào Hive
  Future<void> saveCard(Flashcard card) async {
    final box = await _getBox();
    await box.put(card.id, card.toJson());
  }

  /// Xóa 1 thẻ khỏi Hive theo id
  Future<void> deleteCard(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Xóa sạch dữ liệu trong Hive (hỗ trợ chức năng Reset)
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Lọc danh sách thẻ theo mã khối kiến thức (K01–K20)
  List<Flashcard> filterCardsByTopic(
    List<Flashcard> allCards,
    String topicCode,
  ) {
    if (topicCode.isEmpty || topicCode.toUpperCase() == 'ALL') {
      return List<Flashcard>.from(allCards);
    }
    return allCards
        .where((card) => card.topicCode.toUpperCase() == topicCode.toUpperCase())
        .toList();
  }
}