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

  List<Flashcard> get cards => _cards;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  /// Danh sách thẻ cần ôn hôm nay
  List<Flashcard> get dueCards => _cards.where((c) => c.isDueToday).toList();

  /// Số lượng thẻ cần ôn hôm nay (để hiển thị ở Trang chủ)
  int get dueCount => dueCards.length;

  /// Nạp dữ liệu đóng gói để các tab có thể hiển thị thẻ khi chưa nối Hive.
  /// Member Data / Storage sẽ bổ sung đọc dữ liệu đã lưu trước bước này.
  Future<void> loadDefaultCards() async {
    if (_isLoading) return;

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
        return Flashcard(
          id: id,
          topicCode: entry['topicCode'] as String? ?? '',
          level: entry['level'] as String? ?? '',
          front: entry['front'] as String,
          back: entry['back'] as String,
          frontEn: entry['front_en'] as String?,
          backEn: entry['back_en'] as String?,
        );
      }).toList();

      // Chỉ thay danh sách sau khi toàn bộ dữ liệu đã được đọc hợp lệ.
      _cards
        ..clear()
        ..addAll(loadedCards);
    } catch (_) {
      _loadError = 'Không thể tải bộ thẻ. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
