import 'dart:convert';

import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/services/manage_card_search.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Map<String, dynamic>> records;
  final blocks = RegExp(r'```([a-z]+)\n([\s\S]*?)\n```');
  final inline = RegExp(r'`([^`\n]+)`');

  setUpAll(() async {
    final json = jsonDecode(
      await rootBundle.loadString('assets/default_cards.json'),
    ) as List;
    records = json.cast<Map<String, dynamic>>();
  });

  test('Dấu code đóng mở đầy đủ trong cả bốn trường nội dung', () {
    for (final record in records) {
      for (final field in ['front', 'back', 'front_en', 'back_en']) {
        final text = record[field] as String;
        final remaining = text.replaceAll(blocks, '').replaceAll(inline, '');
        expect(
          remaining,
          isNot(contains('`')),
          reason: '${record['id']} $field',
        );
        for (final match in blocks.allMatches(text)) {
          expect(
            match.group(2)!.trim(),
            isNotEmpty,
            reason: record['id'] as String,
          );
        }
      }
    }
  });

  test('78 khối code có cùng ngôn ngữ và nội dung ở hai bản Việt–Anh', () {
    final languageCounts = <String, int>{};
    for (final record in records) {
      final vi = blocks.allMatches(record['front'] as String).toList();
      final en = blocks.allMatches(record['front_en'] as String).toList();
      expect(en.length, vi.length, reason: record['id'] as String);
      for (var index = 0; index < vi.length; index++) {
        final language = vi[index].group(1)!;
        expect(en[index].group(1), language, reason: record['id'] as String);
        expect(
          en[index].group(2),
          vi[index].group(2),
          reason: record['id'] as String,
        );
        languageCounts.update(
          language,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    expect(languageCounts, {
      'dart': 65,
      'text': 3,
      'yaml': 6,
      'json': 1,
      'shell': 1,
      'kotlin': 2,
    });
  });

  test('Giữ nguyên nội dung, nội suy chuỗi và thụt lề ví dụ K01-005', () {
    final card = records.singleWhere((record) => record['id'] == 'K01-005');
    const originalCode = r'''class Animal {
  String speak() => 'generic';
}
class Cat extends Animal {
  @override
  String speak() => 'meow ${super.speak()}';
}
void main() {
  Animal a = Cat();
  print(a.speak());
}''';
    expect(blocks.firstMatch(card['front'] as String)!.group(2), originalCode);
    expect(
      blocks.firstMatch(card['front_en'] as String)!.group(2),
      originalCode,
    );
    expect(card['back'], startsWith('Đáp án A: `meow generic`\n\nGiải thích:'));
  });

  test('Tìm kiếm dữ liệu thật vẫn khớp qua các đoạn được định dạng', () {
    final cards = records.map(Flashcard.fromJson).toList();
    expect(
      ManageCardSearch.search(
        cards,
        'khai bao void greet',
      ).map((card) => card.id),
      contains('K01-002'),
    );
    expect(
      ManageCardSearch.search(cards, 'dap an c: const').map((card) => card.id),
      contains('K01-001'),
    );
    expect(
      ManageCardSearch.search(
        cards,
        'flutter run --profile',
      ).map((card) => card.id),
      contains('K17-008'),
    );
  });
}
