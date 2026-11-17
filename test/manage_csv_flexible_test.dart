import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flashcard_sm2/services/csv_service.dart';
import 'package:flashcard_sm2/controllers/card_controller.dart';
import 'package:flashcard_sm2/services/manage_card_search.dart';
import 'package:flashcard_sm2/services/manage_card_filter.dart';

import 'support/manage_card_test_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Tên cột Việt/Anh, viết hoa, dấu và gạch dưới được ghép đúng', () {
    for (final title in [
      'Trước,Sau,Chủ đề,Mức độ',
      'CÂU_HỎI,TRẢ LỜI,Nhóm,Level',
      'Question,Answer,Category,Level',
      'Ca\u0302u ho\u0309i,Đa\u0301p a\u0301n,Topic,Level',
    ]) {
      final table = CsvService.inspectBytes(
        Uint8List.fromList(utf8.encode('$title\nQ,A,Nấu ăn,Hiểu')),
      );
      expect(table.suggestedHeader, isTrue);
      final result = CsvService.parse(
        table.source,
        hasHeader: true,
        mapping: table.suggest(true),
      );
      expect(result.cards.single.topicCode, 'Nấu ăn');
      expect(result.cards.single.back, 'A');
    }
  });
  test('Tên lạ, cột dư, đổi thứ tự và ghép thủ công', () {
    const source = 'Response,Prompt,Group,Ignore\nA,Q,K99,Something';
    final result = CsvService.parse(
      source,
      hasHeader: true,
      mapping: {'front': 1, 'back': 0, 'topicCode': 2},
    );
    expect(result.cards.single.front, 'Q');
    expect(result.cards.single.topicCode, 'K99');
  });
  test('Cột mơ hồ không tự chọn; thiếu/trùng cột bắt buộc phải được xử lý', () {
    final table = CsvService.inspectBytes(
      Uint8List.fromList(utf8.encode('Trước,Question,Sau\nQ,Q2,A')),
    );
    expect(table.suggest(true).containsKey('front'), isFalse);
    for (final mapping in [
      {'front': 0},
      {'front': 0, 'back': 0},
      {'front': 3, 'back': 2},
    ]) {
      expect(
        () => CsvService.parse(table.source, hasHeader: true, mapping: mapping),
        throwsA(isA<CsvFileException>()),
      );
    }
    expect(
      CsvService.parse(
        table.source,
        hasHeader: true,
        mapping: {'front': 1, 'back': 2},
      ).cards.single.front,
      'Q2',
    );
  });
  test('Tắt tiêu đề giữ dòng đầu thật và không thay đổi nội dung code', () {
    final result = CsvService.parse(
      'Câu hỏi,Đáp án\nQ,"```dart\n print(""A"");\n```"',
      hasHeader: false,
      mapping: {'front': 0, 'back': 1},
    );
    expect(result.cards, hasLength(2));
    expect(result.cards.first.front, 'Câu hỏi');
    expect(result.cards.last.back, '```dart\n print("A");\n```');
  });
  test(
    'Chủ đề tự tạo lưu/khôi phục, tìm kiếm, lọc, sửa và xuất/nhập',
    () async {
      final store = MemoryManageCardStore()..savedCards = [];
      final controller = CardController(store: store);
      final restored = CardController(store: store);
      addTearDown(controller.dispose);
      addTearDown(restored.dispose);
      await controller.loadDefaultCards();
      final draft = CsvService.parse(
        'front,back,topicCode\nQ,A,Nấu ăn\nQ2,A2,K99',
      );
      await controller.importCards(
        draft.cards
            .map(
              (d) => d.toCard(
                id: controller.createCardId(),
                defaultTopic: 'Khác',
                defaultLevel: 'Nhớ',
              ),
            )
            .toList(),
      );
      await controller.editCard(
        controller.cards.first.copyWith(topicCode: 'Chơi game'),
      );
      await restored.loadDefaultCards();
      expect(restored.allTopics, ['Chơi game', 'K99']);
      expect(
        ManageCardSearch.search(restored.cards, 'choi game'),
        hasLength(1),
      );
      expect(
        const ManageCardFilter(topicCode: 'K99').apply(restored.cards),
        hasLength(1),
      );
      final roundtrip = CsvService.parseBytes(
        CsvService.exportBytes(restored.cards),
      );
      expect(roundtrip.cards.map((d) => d.topicCode), ['Chơi game', 'K99']);
    },
  );
}
