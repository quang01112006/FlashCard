import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/services/csv_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Đọc hai cột Mặt trước,Mặt sau và file không có tiêu đề', () {
    for (final header in ['', 'Mặt trước,Mặt sau\n', ' front , BACK \n']) {
      final result = CsvService.parse(
        '${header}Câu hỏi,Đáp án',
        hasHeader: header.isEmpty ? false : null,
      );
      expect(result.errors, isEmpty);
      expect(result.cards.single.front, 'Câu hỏi');
      expect(result.cards.single.back, 'Đáp án');
      expect(result.needsTopic, isTrue);
      expect(result.needsLevel, isTrue);
    }
  });

  test('Giữ tiếng Việt, số có zero đầu và boolean ở dạng chữ', () {
    final result = CsvService.parseBytes(
      Uint8List.fromList(
        utf8.encode(
          '\ufefffront,back\r\n001,true\r\nĐúng rồi,Tiếng Việt đầy đủ',
        ),
      ),
    );
    expect(result.cards.first.front, '001');
    expect(result.cards.first.back, 'true');
    expect(result.cards.last.back, 'Tiếng Việt đầy đủ');
  });

  test('Giữ dấu phẩy, quote, xuống dòng và thụt đầu dòng trong code', () {
    final result = CsvService.parse(
      'front,back\r\n"Câu hỏi, có dấu phẩy",'
      '"```dart\r\n  print(""xin chào"");\r\n```"\r\n'
      'Tiếp theo,Đáp án',
    );
    expect(result.errors, isEmpty);
    expect(result.cards.first.front, 'Câu hỏi, có dấu phẩy');
    expect(result.cards.first.back, '```dart\r\n  print("xin chào");\r\n```');
    expect(result.cards.last.line, 5);
  });

  test('Bỏ dòng rỗng nhưng giữ số dòng vật lý cho lỗi', () {
    final result = CsvService.parse('\nfront,back\n\n,,\nQ,A\nThiếu\n,\n');
    expect(result.cards.single.line, 5);
    expect(result.blankRows, 4);
    expect(result.errors.single.line, 6);
  });

  test('Dòng rỗng hoặc chỉ quote rỗng không làm crash', () {
    for (final source in ['', '\ufeff', '\n\r\n', '""', ',\n"",""']) {
      final result = CsvService.parse(source);
      expect(result.cards, isEmpty);
      expect(result.errors, isEmpty);
    }
  });

  test('Báo thiếu mặt thẻ và sai số cột, vẫn giữ dòng hợp lệ', () {
    final result = CsvService.parse('front,back\n,A\nQ,\nQ,A,Extra\nOnly\nQ,A');
    expect(result.cards, hasLength(1));
    expect(result.errors.map((error) => error.line), [2, 3, 4, 5]);
    expect(result.errors.first.message, contains('Thiếu'));
  });

  test(
    'Quote sai giữa ô hoặc ký tự sau quote được báo lỗi và phục hồi dòng sau',
    () {
      final result = CsvService.parse(
        'front,back\nQ"oops,A\n"Q"oops,A\nGood,Answer',
      );
      expect(result.errors.map((error) => error.line), [2, 3]);
      expect(result.cards.single.front, 'Good');
    },
  );

  test('Thiếu quote đóng không bị tự đoán thành thẻ hợp lệ', () {
    final result = CsvService.parse(
      'front,back\nGood,A\n"Unclosed\nNext,Answer',
    );
    expect(result.cards.single.front, 'Good');
    expect(result.errors.single.line, 3);
    expect(result.errors.single.message, contains('Thiếu dấu ngoặc kép đóng'));
  });

  test('Nhận dấu chấm phẩy và chỉ dẫn sep= của Excel', () {
    for (final prefix in ['', 'sep=;\r\n']) {
      final result = CsvService.parse('${prefix}front;back\r\n"Q; A";Đáp án');
      expect(result.cards.single.front, 'Q; A');
      expect(result.errors, isEmpty);
    }
    expect(CsvService.parse('front,back\n"Q; Q; Q",A').cards.single.back, 'A');
  });

  test('Các cột có thể đổi thứ tự; cột dư không dùng để ghi đè ID/lịch ôn', () {
    final result = CsvService.parse(
      'back,front,topic_code,level,frontEn,back_en,id,repetitions\n'
      'A,Q,K20,Vận dụng,English question,English answer,old-id,99',
    );
    final card = result.cards.single.toCard(
      id: 'new-id',
      defaultTopic: 'K01',
      defaultLevel: 'Nhớ',
    );
    expect(card.id, 'new-id');
    expect(card.front, 'Q');
    expect(card.back, 'A');
    expect(card.topicCode, 'K20');
    expect(card.level, 'Vận dụng');
    expect(card.frontEn, 'English question');
    expect(card.backEn, 'English answer');
    expect(card.repetitions, 0);
    expect(card.interval, 0);
    expect(card.easeFactor, 2.5);
    expect(result.needsTopic, isFalse);
    expect(result.needsLevel, isFalse);
  });

  test('Chỉ bổ sung mặc định cho ô thiếu; metadata sai bị loại', () {
    final result = CsvService.parse(
      'front,back,topicCode,level\nQ,A,,\nQ2,A2,K02,Hiểu\n'
      'Q3,A3,K21,Nhớ\nQ4,A4,K01,Sai',
    );
    expect(result.cards, hasLength(3));
    expect(result.cards.last.topicCode, "K21");
    expect(result.errors.map((error) => error.line), [5]);
    final missing = result.cards.first.toCard(
      id: 'x',
      defaultTopic: 'K03',
      defaultLevel: 'Vận dụng',
    );
    expect(missing.topicCode, 'K03');
    expect(missing.level, 'Vận dụng');
    final specified = result.cards[1].toCard(
      id: 'y',
      defaultTopic: 'K03',
      defaultLevel: 'Nhớ',
    );
    expect(specified.topicCode, 'K02');
    expect(specified.level, 'Hiểu');
  });

  test('Tiêu đề thiếu cột bắt buộc hoặc trùng cột báo lỗi rõ ràng', () {
    for (final header in [
      'front,other',
      'other,back',
      'front,back,front',
      'front,back,Mặt trước',
    ]) {
      expect(
        () => CsvService.parse('$header\nQ,A'),
        throwsA(isA<CsvFileException>()),
      );
    }
  });

  test('Từ chối UTF-8 hỏng và file vượt giới hạn', () {
    expect(
      () => CsvService.parseBytes(Uint8List.fromList([255, 254, 0])),
      throwsA(
        isA<CsvFileException>().having(
          (error) => error.message,
          'message',
          contains('UTF-8'),
        ),
      ),
    );
    expect(
      () => CsvService.parseBytes(Uint8List(CsvService.maxFileBytes + 1)),
      throwsA(
        isA<CsvFileException>().having(
          (error) => error.message,
          'message',
          contains('5 MB'),
        ),
      ),
    );
  });

  test('Xuất rồi nhập giữ nguyên tất cả nội dung, không mang lịch ôn/ID', () {
    final original = Flashcard(
      id: 'old-id',
      topicCode: 'K10',
      level: 'Hiểu',
      front: '  Câu hỏi, "quote"\n```dart\n  print("hello");\n```  ',
      back: 'A\r\n  Giải thích: Việt Nam',
      frontEn: 'English, "question"\nLine 2',
      backEn: ' English answer ',
      repetitions: 9,
      interval: 100,
    );
    final bytes = CsvService.exportBytes([original]);
    expect(bytes.take(3), [239, 187, 191]);
    final text = utf8.decode(bytes);
    expect(text, isNot(contains('old-id')));
    expect(text, isNot(contains('repetitions')));
    final result = CsvService.parseBytes(bytes);
    expect(result.errors, isEmpty);
    final imported = result.cards.single.toCard(
      id: 'new',
      defaultTopic: 'K01',
      defaultLevel: 'Nhớ',
    );
    for (final key in [
      'front',
      'back',
      'topicCode',
      'level',
      'front_en',
      'back_en',
    ]) {
      expect(imported.toJson()[key], original.toJson()[key], reason: key);
    }
    expect(imported.repetitions, 0);
  });

  test('Xuất đủ 300 câu mẫu rồi nhập lại không mất nội dung và metadata', () {
    final originals =
        (jsonDecode(File('assets/default_cards.json').readAsStringSync())
                as List)
            .map((json) => Flashcard.fromJson(Map<String, dynamic>.from(json)))
            .toList();
    final result = CsvService.parseBytes(CsvService.exportBytes(originals));
    expect(result.errors, isEmpty);
    expect(result.cards, hasLength(300));
    for (var index = 0; index < originals.length; index++) {
      final draft = result.cards[index];
      final original = originals[index];
      expect(draft.front, original.front, reason: original.id);
      expect(draft.back, original.back, reason: original.id);
      expect(draft.frontEn, original.frontEn, reason: original.id);
      expect(draft.backEn, original.backEn, reason: original.id);
      expect(draft.topicCode, original.topicCode, reason: original.id);
      expect(draft.level, original.level, reason: original.id);
    }
  });

  test('Bộ rỗng xuất tiêu đề hợp lệ; không tự sinh thẻ', () {
    final result = CsvService.parseBytes(CsvService.exportBytes([]));
    expect(result.cards, isEmpty);
    expect(result.errors, isEmpty);
  });

  test('Các file mẫu có số thẻ hợp lệ và lỗi như hướng dẫn', () {
    for (final sample in {
      'basic': (2, 0),
      'bilingual': (2, 0),
      'with_errors': (1, 3),
    }.entries) {
      final bytes = File('samples/csv/flashcards_${sample.key}.csv')
          .readAsBytesSync();
      expect(bytes.take(3), [
        239,
        187,
        191,
      ], reason: '${sample.key}: Excel cần BOM để nhận UTF-8 khi mở trực tiếp');
      final result = CsvService.parseBytes(bytes);
      expect(result.cards.length, sample.value.$1, reason: sample.key);
      expect(result.errors.length, sample.value.$2, reason: sample.key);
    }
  });
}
