import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flashcard_sm2/controllers/card_controller.dart';
import 'package:flashcard_sm2/core/app_theme.dart';
import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/screens/manage_cards_screen.dart';
import 'package:flashcard_sm2/screens/manage_csv_import_screen.dart';
import 'package:flashcard_sm2/services/csv_service.dart';
import 'package:flashcard_sm2/services/manage_csv_files.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/manage_card_test_store.dart';

class _Files implements ManageCsvFiles {
  ManageCsvFile? file;
  Object? pickError;
  Object? saveError;
  Uint8List? exported;
  Uri? saved = Uri.parse('content://test/flashcards.csv');
  int saveCalls = 0;
  @override
  Future<ManageCsvFile?> pick() async {
    if (pickError != null) throw pickError!;
    return file;
  }

  @override
  Future<Uri?> save(Uint8List bytes, {required String suggestedName}) async {
    saveCalls++;
    if (saveError != null) throw saveError!;
    exported = bytes;
    return saved;
  }
}

ManageCsvFile _file(String text) => ManageCsvFile(
  name: 'test.csv',
  bytes: Uint8List.fromList(utf8.encode(text)),
);

Flashcard _card(String id) => Flashcard(
  id: id,
  topicCode: 'K01',
  level: 'Nhớ',
  front: 'Câu hỏi $id',
  back: 'Đáp án $id',
);

Future<void> _show(
  WidgetTester tester,
  CardController controller,
  _Files files,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: ManageCardsScreen(csvFiles: files),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _settleCsv(WidgetTester tester) async {
  // compute chạy isolate thật; cho vòng sự kiện thực hoàn tất trước khi settle animation.
  await tester.runAsync(() async {
    for (var attempt = 0; attempt < 150; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(ManageCsvImportScreen).evaluate().isNotEmpty ||
          (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
              find.text('Đang đọc...').evaluate().isEmpty)) {
        return;
      }
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _choose(
  WidgetTester tester,
  String label, {
  bool preview = true,
}) async {
  await tester.tap(find.byKey(const ValueKey('manage_csv_menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pump(const Duration(milliseconds: 350));
  await _settleCsv(tester);
  if (preview &&
      label == 'Nhập CSV' &&
      find
          .byKey(const ValueKey('manage_csv_mapping_next'))
          .evaluate()
          .isNotEmpty) {
    await tester.tap(find.byKey(const ValueKey('manage_csv_mapping_next')));
    await tester.pump();
    await _settleCsv(tester);
  }
}

Finder get _confirm => find.byKey(const ValueKey('manage_csv_confirm_import'));

void main() {
  late MemoryManageCardStore store;
  late CardController controller;
  late _Files files;
  setUp(() async {
    store = MemoryManageCardStore()..savedCards = [_card('seed')];
    controller = CardController(store: store);
    await controller.loadDefaultCards();
    files = _Files();
  });
  tearDown(() => controller.dispose());

  testWidgets(
    'Sửa riêng từng thẻ trước khi nhập giữ mặc định cho thẻ còn lại',
    (tester) async {
      files.file = _file('Trước,Sau\nQ,A\nQ2,A2');
      await _show(tester, controller, files);
      await _choose(tester, 'Nhập CSV');
      final tile = find.byKey(const PageStorageKey('manage_csv_preview_0'));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: tile, matching: find.byIcon(Icons.expand_more)),
      );
      await tester.pumpAndSettle();
      final edit = find.byKey(const ValueKey('manage_csv_edit_0'));
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('manage_editor_front')),
        'Câu hỏi đã sửa',
      );
      final topic = find.descendant(
        of: find.byKey(const ValueKey('manage_editor_topic')),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(topic);
      await tester.pumpAndSettle();
      await tester.enterText(topic, 'Nấu ăn');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu thẻ'));
      await tester.pumpAndSettle();
      expect(store.writes, 0);
      expect(controller.cards.single.id, 'seed');
      await tester.tap(_confirm);
      await tester.pumpAndSettle();
      expect(controller.cards[0].front, 'Câu hỏi đã sửa');
      expect(controller.cards[0].topicCode, 'Nấu ăn');
      expect(controller.cards[1].topicCode, 'K01');
      expect(store.writes, 1);
    },
  );

  testWidgets('Tên cột lạ được ghép thủ công, báo thiếu và trùng cột', (
    tester,
  ) async {
    files.file = _file('Response,Prompt,Group\nA,Q,K99');
    await _show(tester, controller, files);
    await _choose(tester, 'Nhập CSV', preview: false);
    await tester.tap(find.byKey(const ValueKey('manage_csv_has_header')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('manage_csv_mapping_next')));
    await tester.pumpAndSettle();
    expect(
      find.text('Chọn đủ câu hỏi, đáp án; mỗi cột chỉ dùng cho một trường.'),
      findsOneWidget,
    );
    Future<void> select(String label, String option) async {
      final field = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<int> &&
            w.decoration.labelText == label,
      );
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    await select('Câu hỏi *', 'Cột 2: Prompt');
    await select('Đáp án *', 'Cột 1: Response');
    await select('Chủ đề', 'Cột 3: Group');
    await tester.tap(find.byKey(const ValueKey('manage_csv_mapping_next')));
    await tester.pump();
    await _settleCsv(tester);
    expect(find.text('1 thẻ hợp lệ'), findsOneWidget);
    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    expect(controller.cards.first.front, 'Q');
    expect(controller.cards.first.back, 'A');
    expect(controller.cards.first.topicCode, 'K99');
  });

  testWidgets('Chọn file, xem trước lỗi, đổi metadata rồi xác nhận nhập', (
    tester,
  ) async {
    files.file = _file('Mặt trước,Mặt sau\nCâu hỏi CSV,Đáp án CSV\nThiếu\n\n');
    await _show(tester, controller, files);
    await tester.enterText(find.byType(TextField), 'khongco987');
    await tester.pumpAndSettle();
    await _choose(tester, 'Nhập CSV');
    expect(find.text('Xem trước CSV'), findsOneWidget);
    expect(find.text('1 thẻ hợp lệ'), findsOneWidget);
    expect(find.text('1 dòng lỗi'), findsOneWidget);
    expect(find.text('1 dòng trống'), findsOneWidget);
    expect(find.text('Dòng 3'), findsOneWidget);
    expect(store.writes, 0);
    final topic = find.byKey(const ValueKey('manage_csv_topic'));
    await tester.ensureVisible(topic);
    await tester.enterText(
      find.descendant(of: topic, matching: find.byType(TextFormField)),
      'K02',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final level = find.byKey(const ValueKey('manage_csv_level'));
    await tester.ensureVisible(level);
    await tester.tap(level);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hiểu').last);
    await tester.pumpAndSettle();
    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    expect(find.byType(ManageCsvImportScreen), findsNothing);
    expect(find.text('2 thẻ'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(controller.cards.first.front, 'Câu hỏi CSV');
    expect(controller.cards.first.topicCode, 'K02');
    expect(controller.cards.first.level, 'Hiểu');
    expect(controller.cards.first.id, startsWith('USER-'));
    expect(controller.cards.first.repetitions, 0);
    expect(store.writes, 1);
  });

  testWidgets(
    'Mở/đóng xem trước thẻ có code Việt–Anh không lẫn trạng thái cuộn',
    (tester) async {
      files.file = _file(
        'front,back,front_en,back_en\n'
        '"Q\n```dart\n  print(""hello"");\n```",'
        '"A\n```dart\n  print(1);\n```",'
        '"EN Q\n```dart\n  print(2);\n```",'
        '"EN A\n```dart\n  print(3);\n```"',
      );
      await _show(tester, controller, files);
      await _choose(tester, 'Nhập CSV');
      final tile = find.byKey(const PageStorageKey('manage_csv_preview_0'));
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: tile, matching: find.byIcon(Icons.expand_more)),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const PageStorageKey('manage_csv_front_en_0')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.descendant(of: tile, matching: find.byIcon(Icons.expand_more)),
        );
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('Hủy chọn file và quay lại từ xem trước không thay đổi bộ thẻ', (
    tester,
  ) async {
    await _show(tester, controller, files);
    await _choose(tester, 'Nhập CSV');
    expect(find.byType(ManageCsvImportScreen), findsNothing);
    files.file = _file('front,back\nQ,A');
    await _choose(tester, 'Nhập CSV');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(controller.cards.single.id, 'seed');
    expect(store.writes, 0);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('manage_add_card')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('File rỗng hoặc toàn lỗi không được xác nhận nhập', (
    tester,
  ) async {
    await _show(tester, controller, files);
    for (final source in ['', 'front,back\nQ,']) {
      files.file = _file(source);
      await _choose(tester, 'Nhập CSV');
      expect(find.text('0 thẻ hợp lệ'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(_confirm).onPressed, isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    expect(store.writes, 0);
  });

  testWidgets('Lỗi chọn/đọc file có thông báo và cho chọn lại', (tester) async {
    await _show(tester, controller, files);
    files.pickError = StateError('Permission denied');
    await _choose(tester, 'Nhập CSV');
    expect(
      find.text('Không thể đọc file CSV. Vui lòng chọn lại file.'),
      findsOneWidget,
    );
    files.pickError = null;
    files.file = ManageCsvFile(
      name: 'bad.csv',
      bytes: Uint8List.fromList([255, 254]),
    );
    await _choose(tester, 'Nhập CSV');
    expect(
      find.text(
        'Không đọc được tiếng Việt trong file. Hãy lưu file ở dạng CSV UTF-8.',
      ),
      findsOneWidget,
    );
    files.file = _file('front,back\nQ,A');
    await _choose(tester, 'Nhập CSV');
    expect(find.text('Xem trước CSV'), findsOneWidget);
    expect(store.writes, 0);
  });

  testWidgets(
    'Nhập lỗi giữ xem trước; thử lại chờ lưu, chặn bấm lặp và quay lại',
    (tester) async {
      files.file = _file('front,back\nQ,A\nQ2,A2');
      await _show(tester, controller, files);
      await _choose(tester, 'Nhập CSV');
      store.writeFailure = StateError('Disk full');
      await tester.tap(_confirm);
      await tester.pumpAndSettle();
      expect(
        find.text('Không thể lưu thay đổi. Vui lòng thử lại.'),
        findsOneWidget,
      );
      expect(controller.cards.single.id, 'seed');
      expect(find.text('2 thẻ hợp lệ'), findsOneWidget);
      store.writeFailure = null;
      final gate = Completer<void>();
      store.writeGate = gate;
      await tester.tap(_confirm);
      await tester.pump();
      expect(find.text('Đang nhập...'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(_confirm).onPressed, isNull);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(ManageCsvImportScreen), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(controller.cards, hasLength(3));
      expect(store.writes, 2);
    },
  );

  testWidgets('Xuất toàn bộ thẻ khi đang tìm kiếm; nhập lại file vừa xuất', (
    tester,
  ) async {
    await controller.addCard(
      _card('second')
          .copyWith(frontEn: 'English question', backEn: 'English answer'),
    );
    final originals = controller.cards.toList();
    await _show(tester, controller, files);
    await tester.enterText(find.byType(TextField), 'khongco987');
    await tester.pumpAndSettle();
    await _choose(tester, 'Xuất CSV');
    expect(find.textContaining('Xuất toàn bộ 2 thẻ'), findsOneWidget);
    await tester.tap(find.text('Chọn nơi lưu'));
    await tester.pump();
    await _settleCsv(tester);
    expect(find.text('Đã xuất 2 thẻ ra file CSV.'), findsOneWidget);
    expect(CsvService.parseBytes(files.exported!).cards, hasLength(2));
    files.file = ManageCsvFile(name: 'exported.csv', bytes: files.exported!);
    await _choose(tester, 'Nhập CSV');
    expect(find.byKey(const ValueKey('manage_csv_topic')), findsNothing);
    expect(find.byKey(const ValueKey('manage_csv_level')), findsNothing);
    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    expect(controller.cards, hasLength(4));
    for (var index = 0; index < 2; index++) {
      expect(controller.cards[index].front, originals[index].front);
      expect(controller.cards[index].backEn, originals[index].backEn);
      expect(controller.cards[index].id, isNot(originals[index].id));
    }
  });

  testWidgets('Hủy xuất và lỗi lưu không báo thành công, thử lại được', (
    tester,
  ) async {
    await _show(tester, controller, files);
    await _choose(tester, 'Xuất CSV');
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(files.saveCalls, 0);
    files.saved = null;
    await _choose(tester, 'Xuất CSV');
    await tester.tap(find.text('Chọn nơi lưu'));
    await tester.pump();
    await _settleCsv(tester);
    expect(find.textContaining('Đã xuất'), findsNothing);
    files.saveError = StateError('Permission denied');
    await _choose(tester, 'Xuất CSV');
    await tester.tap(find.text('Chọn nơi lưu'));
    await tester.pump();
    await _settleCsv(tester);
    expect(
      find.text('Không thể lưu file CSV. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(store.writes, 0);
  });

  testWidgets('Bộ rỗng vẫn nhập được CSV và không cho xuất', (tester) async {
    await controller.deleteCard('seed');
    await _show(tester, controller, files);
    await tester.tap(find.byKey(const ValueKey('manage_csv_menu')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PopupMenuItem<dynamic>>(
            find.ancestor(
              of: find.text('Xuất CSV'),
              matching: find.byWidgetPredicate(
                (widget) => widget is PopupMenuItem,
              ),
            ),
          )
          .enabled,
      isFalse,
    );
    files.file = _file('Q,A');
    await tester.tap(find.text('Nhập CSV'));
    await tester.pump(const Duration(milliseconds: 350));
    await _settleCsv(tester);
    if (find
        .byKey(const ValueKey('manage_csv_mapping_next'))
        .evaluate()
        .isNotEmpty) {
      await tester.tap(find.byKey(const ValueKey('manage_csv_mapping_next')));
      await tester.pump();
      await _settleCsv(tester);
    }
    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    expect(controller.cards.single.front, 'Q');
  });

  testWidgets('Xem trước CSV cuộn được trên màn hình hẹp với chữ lớn', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    files.file = _file('front,back\nQ,A\nInvalid\n');
    await _show(tester, controller, files);
    await _choose(tester, 'Nhập CSV');
    await tester.scrollUntilVisible(
      find.text('Dòng 3'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Dòng 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    expect(controller.cards, hasLength(2));
  });
}
