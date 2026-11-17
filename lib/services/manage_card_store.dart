import 'package:hive_flutter/hive_flutter.dart';

import '../models/flashcard.dart';

/// Có thể thay bằng lớp lưu trữ chung của nhóm qua constructor CardController.
abstract interface class ManageCardStore {
  /// null: chưa lưu lần nào; []: người dùng đã xóa hết thẻ.
  Future<List<Flashcard>?> read();
  Future<void> write(List<Flashcard> cards);
}

class HiveManageCardStore implements ManageCardStore {
  HiveManageCardStore({Future<Box<dynamic>> Function()? openBox})
    : _openBox = openBox ?? _openDefaultBox;

  static const boxName = 'manage_cards_v1';
  static const _deckKey = 'deck';
  final Future<Box<dynamic>> Function() _openBox;
  Future<Box<dynamic>>? _box;

  static Future<Box<dynamic>> _openDefaultBox() async {
    await Hive.initFlutter();
    return Hive.openBox<dynamic>(boxName);
  }

  Future<Box<dynamic>> _getBox() async {
    final opening = _box ??= _openBox();
    try {
      return await opening;
    } catch (_) {
      _box = null;
      rethrow;
    }
  }

  @override
  Future<List<Flashcard>?> read() async {
    final box = await _getBox();
    final value = box.get(_deckKey);
    if (value == null) return null;
    if (value is! Map || value['version'] != 1) {
      throw const FormatException('Unsupported saved deck.');
    }
    return decodeManageCards(value['cards']);
  }

  @override
  Future<void> write(List<Flashcard> cards) async {
    final records = cards.map((card) => card.toJson()).toList();
    decodeManageCards(records);
    final box = await _getBox();
    // Một bản ghi duy nhất để không lưu dở dang giữa nhiều thẻ.
    await box.put(_deckKey, {'version': 1, 'cards': records});
  }
}

List<Flashcard> decodeManageCards(Object? value) {
  if (value is! List) {
    throw const FormatException('Expected a list of flashcards.');
  }
  final ids = <String>{};
  return value.map((record) {
    if (record is! Map) {
      throw const FormatException('Invalid flashcard record.');
    }
    final entry = Map<String, dynamic>.from(record);
    for (final field in ['id', 'front', 'back']) {
      final text = entry[field];
      if (text is! String || text.trim().isEmpty) {
        throw FormatException('Invalid flashcard field: $field.');
      }
    }
    if (!ids.add(entry['id'] as String)) {
      throw const FormatException('Duplicate flashcard ID.');
    }
    return Flashcard.fromJson(entry);
  }).toList();
}

class CardOperationException implements Exception {
  const CardOperationException(this.message);
  final String message;

  @override
  String toString() => message;
}
