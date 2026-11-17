import 'dart:convert';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/flashcard.dart';
import '../services/manage_card_filter.dart';
import '../services/manage_card_store.dart';

class CardController extends ChangeNotifier {
  CardController({AssetBundle? assetBundle, ManageCardStore? store})
    : _assetBundle = assetBundle ?? rootBundle,
      _store = store ?? HiveManageCardStore();

  final AssetBundle _assetBundle;
  final ManageCardStore _store;
  final List<Flashcard> _cards = [];
  bool _isLoading = false;
  String? _loadError;
  bool _hasLoaded = false;
  bool _isSaving = false;
  bool _disposed = false;
  int _idSequence = 0;

  // Trạng thái đa ngôn ngữ dùng chung toàn app (Mặc định: Tiếng Việt)
  bool _isEnglish = false;

  // Trạng thái giao diện Tối / Sáng dùng chung toàn app
  bool _isDarkMode = false;

  List<Flashcard> get cards => UnmodifiableListView(_cards);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
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

  /// Ưu tiên bộ thẻ đã lưu; JSON chỉ dùng khi chưa có dữ liệu trên máy.
  /// forceReload tải lại storage, không khôi phục/xóa thay đổi của người dùng.
  Future<void> loadDefaultCards({bool forceReload = false}) async {
    if (_disposed || _isLoading || _isSaving || (_hasLoaded && !forceReload)) {
      return;
    }

    _isLoading = true;
    _loadError = null;
    _notify();

    try {
      final savedCards = await _store.read();
      final loadedCards =
          savedCards ??
          decodeManageCards(
            jsonDecode(
              await _assetBundle.loadString('assets/default_cards.json'),
            ),
          );

      // Chỉ thay danh sách sau khi toàn bộ dữ liệu đã được đọc hợp lệ.
      _cards
        ..clear()
        ..addAll(loadedCards);
      _hasLoaded = true;
    } catch (e) {
      _loadError = 'Không thể tải bộ thẻ. Vui lòng thử lại.';
      debugPrint('Lỗi nạp bộ thẻ: $e');
    } finally {
      _isLoading = false;
      _notify();
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

  String createCardId() {
    String id;
    do {
      id = 'USER-${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}';
    } while (_cards.any((card) => card.id == id));
    return id;
  }

  Future<Flashcard> addCard(Flashcard card) async {
    await _persist((next) {
      _validateManualCard(card);
      if (next.any((existing) => existing.id == card.id)) {
        throw const CardOperationException(
          'Mã thẻ bị trùng. Vui lòng thử lại.',
        );
      }
      next.insert(0, card);
    });
    return card;
  }

  /// Chỉ sửa nội dung; giữ lịch ôn mới nhất, kể cả khi form mở từ trước.
  Future<Flashcard> editCard(Flashcard edited) async {
    late Flashcard result;
    await _persist((next) {
      _validateManualCard(edited);
      final index = _indexOf(next, edited.id);
      result = next[index].copyWith(
        topicCode: edited.topicCode,
        level: edited.level,
        front: edited.front,
        back: edited.back,
        frontEn: edited.frontEn ?? '',
        backEn: edited.backEn ?? '',
      );
      next[index] = result;
    });
    return result;
  }

  Future<void> deleteCard(String id) => _persist((next) {
    next.removeAt(_indexOf(next, id));
  });

  /// Lưu kết quả SM-2, giữ nội dung mới nhất của thẻ.
  Future<void> updateCard(Flashcard updatedCard) => _persist((next) {
    final index = _indexOf(next, updatedCard.id);
    next[index] = next[index].copyWith(
      repetitions: updatedCard.repetitions,
      interval: updatedCard.interval,
      easeFactor: updatedCard.easeFactor,
      nextReviewDate: updatedCard.nextReviewDate,
    );
  });

  int _indexOf(List<Flashcard> cards, String id) {
    final index = cards.indexWhere((card) => card.id == id);
    if (index < 0) {
      throw const CardOperationException(
        'Thẻ không còn tồn tại. Vui lòng tải lại danh sách.',
      );
    }
    return index;
  }

  void _validateManualCard(Flashcard card) {
    if (card.id.trim().isEmpty ||
        card.front.trim().isEmpty ||
        card.back.trim().isEmpty) {
      throw const CardOperationException(
        'Vui lòng nhập đầy đủ câu hỏi và đáp án.',
      );
    }
    if (!ManageCardFilter.topicCodes.contains(card.topicCode) ||
        !ManageCardFilter.levels.contains(card.level)) {
      throw const CardOperationException(
        'Vui lòng chọn khối kiến thức và mức độ hợp lệ.',
      );
    }
  }

  Future<void> _persist(void Function(List<Flashcard>) change) async {
    if (_disposed || !_hasLoaded || _isLoading || _loadError != null) {
      throw const CardOperationException(
        'Bộ thẻ chưa tải xong. Vui lòng thử lại.',
      );
    }
    if (_isSaving) {
      throw const CardOperationException(
        'Đang lưu thay đổi khác. Vui lòng đợi.',
      );
    }
    _isSaving = true;
    _notify();
    try {
      final next = List<Flashcard>.of(_cards);
      change(next);
      await _store.write(next);
      _cards
        ..clear()
        ..addAll(next);
    } on CardOperationException {
      rethrow;
    } catch (error) {
      debugPrint('Lỗi lưu bộ thẻ: $error');
      throw const CardOperationException(
        'Không thể lưu thay đổi. Vui lòng thử lại.',
      );
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// TODO [Người 3 phụ trách Quản lý thẻ]:
  /// Viết logic nạp danh sách thẻ từ file CSV hoặc AI
  void importCards(List<Flashcard> newCards) {
    // TODO: Người 3 điền code import thẻ ở đây
  }
}
