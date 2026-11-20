import 'dart:io';

import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final storage = StorageService();

  const sampleJson = '''
  [
    {
      "id": "K01-001",
      "topicCode": "K01",
      "level": "Nhớ",
      "front": "Câu hỏi K01",
      "back": "Đáp án K01",
      "front_en": "Question K01",
      "back_en": "Answer K01"
    },
    {
      "id": "K02-001",
      "topicCode": "K02",
      "level": "Hiểu",
      "front": "Câu hỏi K02",
      "back": "Đáp án K02"
    },
    {
      "id": "K01-002",
      "topicCode": "K01",
      "front": "Câu hỏi K01 thứ hai",
      "back": "Đáp án K01 thứ hai"
    }
  ]
  ''';

  group('Nạp dữ liệu từ JSON vào danh sách thẻ', () {
    test('đọc đủ thẻ và đúng các trường chính', () {
      final cards = storage.parseCardsFromJsonString(sampleJson);

      expect(cards, hasLength(3));
      expect(cards[0].id, 'K01-001');
      expect(cards[0].topicCode, 'K01');
      expect(cards[0].level, 'Nhớ');
      expect(cards[0].front, 'Câu hỏi K01');
      expect(cards[0].back, 'Đáp án K01');
      expect(cards[0].frontEn, 'Question K01');
      expect(cards[0].backEn, 'Answer K01');
      expect(cards[1].topicCode, 'K02');
      expect(cards[2].id, 'K01-002');
    });

    test('nạp 300 câu từ assets/default_cards.json', () {
      final jsonString = File('assets/default_cards.json').readAsStringSync();
      final cards = storage.parseCardsFromJsonString(jsonString);

      expect(cards, hasLength(300));
      expect(cards.every((card) => card.id.isNotEmpty), isTrue);
      expect(cards.every((card) => card.front.isNotEmpty), isTrue);
      expect(cards.every((card) => card.back.isNotEmpty), isTrue);
      expect(
        cards.map((card) => card.topicCode).toSet(),
        containsAll([
          for (var index = 1; index <= 20; index++)
            'K${index.toString().padLeft(2, '0')}',
        ]),
      );
    });
  });

  group('Lọc thẻ theo khối kiến thức K01–K20', () {
    late List<Flashcard> cards;

    setUp(() {
      cards = storage.parseCardsFromJsonString(sampleJson);
    });

    test('K01 chỉ còn thẻ của K01', () {
      final filtered = storage.filterCardsByTopic(cards, 'K01');

      expect(filtered, hasLength(2));
      expect(filtered.map((card) => card.id), ['K01-001', 'K01-002']);
      expect(filtered.every((card) => card.topicCode == 'K01'), isTrue);
    });

    test('không phân biệt hoa thường', () {
      final filtered = storage.filterCardsByTopic(cards, 'k02');

      expect(filtered, hasLength(1));
      expect(filtered.single.topicCode, 'K02');
    });

    test('khối không có thẻ thì trả về rỗng', () {
      expect(storage.filterCardsByTopic(cards, 'K20'), isEmpty);
    });

    test('ALL và chuỗi rỗng trả về toàn bộ danh sách', () {
      expect(storage.filterCardsByTopic(cards, 'ALL'), hasLength(3));
      expect(storage.filterCardsByTopic(cards, 'all'), hasLength(3));
      expect(storage.filterCardsByTopic(cards, ''), hasLength(3));
    });

    test('mỗi mã K01–K20 không lẫn thẻ của khối khác', () {
      final deck = storage.parseCardsFromJsonString(
        File('assets/default_cards.json').readAsStringSync(),
      );

      for (var index = 1; index <= 20; index++) {
        final code = 'K${index.toString().padLeft(2, '0')}';
        final filtered = storage.filterCardsByTopic(deck, code);

        expect(filtered, isNotEmpty, reason: code);
        expect(
          filtered.every((card) => card.topicCode.toUpperCase() == code),
          isTrue,
          reason: code,
        );
      }
    });
  });
}
