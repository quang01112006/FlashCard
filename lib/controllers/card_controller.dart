import 'dart:convert';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/flashcard.dart';
import '../models/card_deck.dart';
import '../services/manage_deck_store.dart';
import '../services/manage_card_filter.dart';
import '../services/manage_card_store.dart';

class CardController extends ChangeNotifier {
  CardController({AssetBundle? assetBundle, ManageCardStore? store})
    : _assetBundle = assetBundle ?? rootBundle,
      _store = store ?? HiveManageCardStore();

  final AssetBundle _assetBundle;
  final ManageCardStore _store;
  final List<Flashcard> _cards = [];
  List<CardDeck> _decks = [];
  List<CardDeck> get decks => List.unmodifiable(_decks);
  List<Flashcard> cardsInDeck(String id) =>
      _cards.where((card) => card.deckId == id).toList();
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
      final deckStore = _store is ManageDeckStore
          ? _store as ManageDeckStore
          : null;
      final collection = deckStore == null
          ? null
          : await deckStore.readCollection();
      final savedCards = collection?.cards ?? await _store.read();
      final loadedCards =
          savedCards ??
          decodeManageCards(
            jsonDecode(
              await _assetBundle.loadString('assets/default_cards.json'),
            ),
          );

      var migratedCards = loadedCards;
      var loadedDecks =
          collection?.decks ??
          [const CardDeck(id: CardDeck.flutterId, name: 'Học Flutter')];
      if (collection == null && deckStore != null) {
        // Phân loại bằng ID gốc, giữ nguyên nội dung sửa và lịch ôn của người dùng.
        final originals = decodeManageCards(
          jsonDecode(
            await _assetBundle.loadString('assets/default_cards.json'),
          ),
        );
        final originalIds = originals.map((card) => card.id).toSet();
        migratedCards = loadedCards
            .map(
              (card) => card.copyWith(
                deckId: originalIds.contains(card.id)
                    ? CardDeck.flutterId
                    : CardDeck.legacyId,
              ),
            )
            .toList();
        if (migratedCards.any((card) => card.deckId == CardDeck.legacyId)) {
          loadedDecks = [
            ...loadedDecks,
            const CardDeck(
              id: CardDeck.legacyId,
              name: 'Thẻ đã thêm',
              description: 'Thẻ từ dữ liệu cũ; chưa phân loại vào các bộ mới.',
            ),
          ];
        }
        await deckStore.writeCollection(
          DeckCollection(decks: loadedDecks, cards: migratedCards),
        );
      }
      _decks = List.of(loadedDecks);
      // Chỉ thay danh sách sau khi toàn bộ dữ liệu đã được đọc hợp lệ.
      _cards
        ..clear()
        ..addAll(migratedCards);
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
  Future<Flashcard> editCard(Flashcard edited, {String? expectedDeckId}) async {
    late Flashcard result;
    await _persist((next) {
      _validateManualCard(edited);
      final index = _indexOf(next, edited.id);
      _checkSource(next[index], expectedDeckId);
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

  Future<void> deleteCard(String id, {String? expectedDeckId}) =>
      _persist((next) {
        final index = _indexOf(next, id);
        _checkSource(next[index], expectedDeckId);
        next.removeAt(index);
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
    if (deckById(card.deckId) == null) {
      throw const CardOperationException('Bộ thẻ không còn tồn tại.');
    }
    if (card.id.trim().isEmpty ||
        card.front.trim().isEmpty ||
        card.back.trim().isEmpty) {
      throw const CardOperationException(
        'Vui lòng nhập đầy đủ câu hỏi và đáp án.',
      );
    }
    if (!ManageCardFilter.levels.contains(card.level)) {
      throw const CardOperationException('Vui lòng chọn mức độ hợp lệ.');
    }
  }

  Future<void> _persist(
    void Function(List<Flashcard>) change, {
    List<CardDeck>? decks,
  }) async {
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
      if (_store is ManageDeckStore) {
        await (_store as ManageDeckStore).writeCollection(
          DeckCollection(decks: decks ?? _decks, cards: next),
        );
      } else {
        if (decks != null) {
          throw const CardOperationException(
            'Kho dữ liệu chưa hỗ trợ nhiều bộ thẻ.',
          );
        }
        await _store.write(next);
      }
      _cards
        ..clear()
        ..addAll(next);
      if (decks != null) _decks = List.of(decks);
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

  Future<CardDeck> createDeck(String name, {String description = ''}) async {
    final title = name.trim();
    if (title.isEmpty) {
      throw const CardOperationException('Vui lòng nhập tên bộ thẻ.');
    }
    if (_decks.any((deck) => deck.name.toLowerCase() == title.toLowerCase())) {
      throw const CardOperationException('Tên bộ thẻ đã tồn tại.');
    }
    if (_disposed ||
        !_hasLoaded ||
        _isLoading ||
        _loadError != null ||
        _isSaving) {
      throw const CardOperationException(
        'Bộ thẻ đang bận hoặc chưa tải xong. Vui lòng thử lại.',
      );
    }
    if (_store is! ManageDeckStore) {
      throw const CardOperationException(
        'Kho dữ liệu chưa hỗ trợ nhiều bộ thẻ.',
      );
    }
    final deck = CardDeck(
      id: 'DECK-${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}',
      name: title,
      description: description.trim(),
    );
    _isSaving = true;
    _notify();
    try {
      final next = [..._decks, deck];
      await (_store as ManageDeckStore).writeCollection(
        DeckCollection(decks: next, cards: _cards),
      );
      _decks = next;
      return deck;
    } catch (_) {
      throw const CardOperationException(
        'Không thể lưu bộ thẻ mới. Vui lòng thử lại.',
      );
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  CardDeck? deckById(String id) {
    for (final deck in _decks) {
      if (deck.id == id) return deck;
    }
    return null;
  }

  List<String> topicsInDeck(String id) =>
      cardsInDeck(id)
          .map((card) => card.topicCode)
          .where((topic) => topic.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  void _checkSource(Flashcard card, String? deckId) {
    if (deckId != null && card.deckId != deckId) {
      throw const CardOperationException(
        'Thẻ đã được chuyển sang bộ khác. Vui lòng quay lại danh sách.',
      );
    }
  }

  Future<void> moveCard(
    String id,
    String targetDeckId, {
    String? expectedDeckId,
  }) => _persist((next) {
    if (deckById(targetDeckId) == null) {
      throw const CardOperationException('Bộ nhận không còn tồn tại.');
    }
    final index = _indexOf(next, id);
    _checkSource(next[index], expectedDeckId);
    next[index] = next[index].copyWith(deckId: targetDeckId);
  });

  Future<void> renameDeck(String id, String name, {String description = ''}) {
    if (deckById(id) == null) {
      return Future.error(
        const CardOperationException('Bộ thẻ không còn tồn tại.'),
      );
    }
    final title = name.trim();
    if (title.isEmpty) {
      return Future.error(
        const CardOperationException('Vui lòng nhập tên bộ thẻ.'),
      );
    }
    if (_decks.any(
      (deck) => deck.id != id && deck.name.toLowerCase() == title.toLowerCase(),
    )) {
      return Future.error(
        const CardOperationException('Tên bộ thẻ đã tồn tại.'),
      );
    }
    return _persist(
      (_) {},
      decks: [
        for (final deck in _decks)
          if (deck.id == id)
            CardDeck(id: id, name: title, description: description.trim())
          else
            deck,
      ],
    );
  }

  Future<void> deleteDeck(String id) {
    if (deckById(id) == null) {
      return Future.error(
        const CardOperationException('Bộ thẻ không còn tồn tại.'),
      );
    }
    return _persist(
      (next) => next.removeWhere((card) => card.deckId == id),
      decks: _decks.where((deck) => deck.id != id).toList(),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Thêm cả lượt nhập trong một lần lưu; lỗi ở bất kỳ thẻ nào thì giữ bộ cũ.
  Future<void> importCards(List<Flashcard> newCards) {
    final batch = List<Flashcard>.of(newCards);
    if (batch.isEmpty) {
      return Future.error(
        const CardOperationException('Không có thẻ hợp lệ để nhập.'),
      );
    }
    return _persist((next) {
      final ids = next.map((card) => card.id).toSet();
      for (final card in batch) {
        _validateManualCard(card);
        if (!ids.add(card.id)) {
          throw const CardOperationException(
            'Mã thẻ bị trùng. Vui lòng thử lại.',
          );
        }
      }
      next.insertAll(0, batch);
    });
  }
}
