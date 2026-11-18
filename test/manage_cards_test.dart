import 'dart:async';
import 'dart:convert';

import 'package:flashcard_sm2/controllers/card_controller.dart';
import 'package:flashcard_sm2/core/app_theme.dart';
import 'package:flashcard_sm2/screens/manage_cards_screen.dart';
import 'package:flashcard_sm2/screens/study_screen.dart';
import 'package:flashcard_sm2/widgets/code_text_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/manage_card_test_store.dart';

// Kiểm tra các màn cũ độc lập; tab sản phẩm nay mở danh sách bộ thẻ.
class _LegacyTabs extends StatefulWidget {
  const _LegacyTabs();
  @override
  State<_LegacyTabs> createState() => _LegacyTabsState();
}

class _LegacyTabsState extends State<_LegacyTabs> {
  int index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: index,
      children: const [
        SizedBox(),
        StudyScreen(),
        ManageCardsScreen(),
        SizedBox(),
      ],
    ),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: index,
      onTap: (value) => setState(() => index = value),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
        BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Học thẻ'),
        BottomNavigationBarItem(icon: Icon(Icons.style), label: 'Bộ thẻ'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Cài đặt'),
      ],
    ),
  );
}

CardController _controller({AssetBundle? assetBundle}) =>
    CardController(assetBundle: assetBundle, store: MemoryManageCardStore());

class _TestBundle extends CachingAssetBundle {
  _TestBundle(this.read);

  final Future<String> Function() read;

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    expectSync(key, 'assets/default_cards.json');
    return read();
  }

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

Map<String, dynamic> _record({String id = 'K01-001', String? front}) => {
  'id': id,
  'topicCode': 'K01',
  'level': 'Nhớ',
  'front': front ?? 'Từ khóa const dùng để làm gì?',
  'back': 'Tạo hằng số thời gian biên dịch.\nGiải thích chi tiết.',
  'front_en': 'What does const do?',
  'back_en': 'Creates a compile-time constant.',
};

Future<void> _showScreen(
  WidgetTester tester,
  CardController controller, {
  Widget home = const ManageCardsScreen(),
}) {
  return tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(theme: AppTheme.lightTheme, home: home),
    ),
  );
}

Future<void> _selectFilter(
  WidgetTester tester,
  String field,
  String option,
) async {
  await tester.tap(find.byKey(ValueKey(field)));
  await tester.pumpAndSettle();
  final menu = find.byType(Scrollable).last;
  final choice = find.descendant(of: menu, matching: find.text(option));
  await tester.scrollUntilVisible(choice, 160, scrollable: menu);
  await tester.tap(choice);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Nạp đủ 300 thẻ thật, 20 khối và giữ nội dung song ngữ', () async {
    final controller = _controller();
    addTearDown(controller.dispose);

    await controller.loadDefaultCards();

    expect(controller.loadError, isNull);
    expect(controller.isLoading, isFalse);
    expect(controller.cards, hasLength(300));
    expect(controller.cards.map((card) => card.id).toSet(), hasLength(300));
    expect(
      controller.cards.map((card) => card.topicCode).toSet(),
      hasLength(20),
    );
    expect(controller.cards.first.frontEn, isNotEmpty);
    expect(controller.cards.first.backEn, isNotEmpty);
  });

  test('Không nạp trùng khi có hai yêu cầu đồng thời hoặc nạp lại', () async {
    final pending = Completer<String>();
    var calls = 0;
    final controller = _controller(
      assetBundle: _TestBundle(() {
        calls++;
        return pending.future;
      }),
    );
    addTearDown(controller.dispose);

    final loading = controller.loadDefaultCards();
    expect(controller.isLoading, isTrue);
    await controller.loadDefaultCards();
    expect(calls, 1);
    pending.complete(jsonEncode([_record()]));
    await loading;
    await controller.loadDefaultCards();

    expect(controller.cards, hasLength(1));
    expect(controller.isLoading, isFalse);
  });

  test(
    'Nạp mặc định không ghi đè thẻ đã học; tải lại chỉ khi yêu cầu',
    () async {
      var reads = 0;
      final controller = _controller(
        assetBundle: _TestBundle(() async {
          reads++;
          return jsonEncode([_record()]);
        }),
      );
      addTearDown(controller.dispose);
      await controller.loadDefaultCards();
      final reviewed = controller.cards.single.copyWith(
        repetitions: 3,
        interval: 15,
        easeFactor: 2.1,
        nextReviewDate: DateTime(2099, 1, 1),
      );
      await controller.updateCard(reviewed);
      await controller.loadDefaultCards();

      expect(reads, 1);
      expect(controller.cards.single.nextReviewDate, reviewed.nextReviewDate);
      expect(controller.cards.single.repetitions, 3);
      expect(controller.dueCount, 0);

      await controller.loadDefaultCards(forceReload: true);
      expect(reads, 1);
      expect(controller.cards.single.repetitions, 3);
    },
  );

  test(
    'Dùng model chung để nạp song ngữ camelCase và lịch ôn đã lưu',
    () async {
      final reviewDate = DateTime.utc(2030, 1, 15);
      final controller = _controller(
        assetBundle: _TestBundle(
          () async => jsonEncode([
            {
              ..._record(),
              'topicCode': 'K20',
              'front_en': null,
              'back_en': null,
              'frontEn': 'Question in English',
              'backEn': 'Answer in English',
              'repetitions': 4,
              'interval': 30,
              'easeFactor': 2.3,
              'nextReviewDate': reviewDate.toIso8601String(),
            },
            _record(id: 'K01-002'),
          ]),
        ),
      );
      addTearDown(controller.dispose);
      await controller.loadDefaultCards();

      final restored = controller.cards.first;
      expect(controller.loadError, isNull);
      expect(restored.frontEn, 'Question in English');
      expect(restored.backEn, 'Answer in English');
      expect(restored.repetitions, 4);
      expect(restored.interval, 30);
      expect(restored.easeFactor, 2.3);
      expect(restored.nextReviewDate, reviewDate);
      expect(controller.allTopics, ['K01', 'K20']);

      controller.setLanguage(true);
      controller.setDarkMode(true);
      expect(controller.isEnglish, isTrue);
      expect(controller.isDarkMode, isTrue);
    },
  );

  for (final invalid in <String, dynamic>{
    'JSON sai cú pháp': 'invalid json',
    'JSON không phải danh sách': '{}',
    'bản ghi sai kiểu': jsonEncode([123]),
    'mặt trước rỗng': jsonEncode([_record(front: '  ')]),
    'ID trùng': jsonEncode([_record(), _record()]),
  }.entries) {
    test('${invalid.key}: báo lỗi và giữ nguyên dữ liệu đang có', () async {
      var content = jsonEncode([_record()]);
      final controller = _controller(
        assetBundle: _TestBundle(() async => content),
      );
      addTearDown(controller.dispose);
      await controller.loadDefaultCards();
      final original = controller.cards.single;

      content = invalid.value as String;
      await controller.loadDefaultCards(forceReload: true);

      expect(controller.loadError, isNotNull);
      expect(controller.isLoading, isFalse);
      expect(controller.cards.single, same(original));
    });
  }

  testWidgets('Hiển thị đang tải rồi chuyển sang danh sách', (tester) async {
    final pending = Completer<String>();
    final controller = _controller(
      assetBundle: _TestBundle(() => pending.future),
    );
    addTearDown(controller.dispose);
    final loading = controller.loadDefaultCards();
    await _showScreen(tester, controller);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(jsonEncode([_record()]));
    await loading;
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('1 thẻ'), findsOneWidget);
    expect(find.text('K01 • Nhớ'), findsOneWidget);
  });

  testWidgets('Chạm thẻ mở và đóng đáp án', (tester) async {
    final controller = _controller(
      assetBundle: _TestBundle(() async => jsonEncode([_record()])),
    );
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    await _showScreen(tester, controller);

    expect(find.text(_record()['back'] as String), findsNothing);
    await tester.tap(find.text(_record()['front'] as String));
    await tester.pumpAndSettle();
    expect(find.text(_record()['back'] as String), findsOneWidget);

    await tester.tap(find.text(_record()['front'] as String));
    await tester.pumpAndSettle();
    expect(find.text(_record()['back'] as String), findsNothing);
  });

  testWidgets('Dùng widget chung để hiển thị code ở câu hỏi và đáp án', (
    tester,
  ) async {
    const front =
        'Từ khóa `const` trong đoạn mã:\n\n```dart\nconst value = 42;\n```';
    const back = 'Kết quả là `42`.\n\n```dart\n  print(value);\n```';
    final controller = _controller(
      assetBundle: _TestBundle(
        () async => jsonEncode([
          {..._record(front: front), 'back': back},
        ]),
      ),
    );
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    await _showScreen(tester, controller);

    expect(find.byType(CodeTextView), findsOneWidget);
    expect(find.text('const'), findsOneWidget);
    expect(find.text('const value = 42;'), findsOneWidget);
    expect(find.textContaining('```'), findsNothing);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(find.byType(CodeTextView), findsNWidgets(2));
    expect(find.text('42'), findsOneWidget);
    expect(find.text('  print(value);'), findsOneWidget);
    expect(find.textContaining('```'), findsNothing);
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Code cuộn ngang không xung đột với trạng thái mở thẻ', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final longCode = "  print('${List.filled(60, 'Dart').join(' ')}');";
    final controller = _controller(
      assetBundle: _TestBundle(
        () async => jsonEncode([
          {
            ..._record(front: 'Ví dụ Dart\n\n```dart\n$longCode\n```'),
            'back': 'Giải thích\n\n```dart\n$longCode\n```',
          },
        ]),
      ),
    );
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    await _showScreen(tester, controller);

    final frontView = find.byKey(
      const PageStorageKey('manage_front_K01-001_vi'),
    );
    final frontScroll = find.descendant(
      of: frontView,
      matching: find.byType(Scrollable),
    );
    await tester.drag(frontScroll, const Offset(-120, 0));
    await tester.pumpAndSettle();
    final frontPosition = tester.state<ScrollableState>(frontScroll).position;
    expect(frontPosition.pixels, greaterThan(0));

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    final backView = find.byKey(
      const PageStorageKey('manage_answer_K01-001_vi'),
    );
    final backScroll = find.descendant(
      of: backView,
      matching: find.byType(Scrollable),
    );
    expect(tester.state<ScrollableState>(backScroll).position.pixels, 0);
    await tester.ensureVisible(backView);
    await tester.pumpAndSettle();
    await tester.drag(backScroll, const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(backScroll).position.pixels,
      greaterThan(0),
    );

    // Dựng lại danh sách để kiểm tra khôi phục cả trạng thái mở và vị trí code.
    await tester.enterText(find.byType(TextField), 'khongtontai987654');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'K01-001');
    await tester.pumpAndSettle();
    expect(find.byType(CodeTextView), findsNWidgets(2));
    expect(
      tester.state<ScrollableState>(frontScroll).position.pixels,
      greaterThan(0),
    );
    expect(
      tester.state<ScrollableState>(backScroll).position.pixels,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dữ liệu thật có code nội dòng và khối code trên màn hình hẹp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.runAsync(controller.loadDefaultCards);
    await _showScreen(tester, controller);

    await tester.enterText(find.byType(TextField), 'K01-002');
    await tester.pumpAndSettle();
    expect(
      find.text('void greet(String name, [String? title])'),
      findsOneWidget,
    );
    expect(find.text('1 / 300 thẻ'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), 'K01-005');
    await tester.pumpAndSettle();
    final frontView = find.byKey(
      const PageStorageKey('manage_front_K01-005_vi'),
    );
    final codeScroll = find.descendant(
      of: frontView,
      matching: find.byType(Scrollable),
    );
    expect(codeScroll, findsOneWidget);
    expect(
      tester.state<ScrollableState>(codeScroll).position.maxScrollExtent,
      greaterThan(0),
    );
    expect(find.textContaining('```'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Lỗi đọc file có nút thử lại và phục hồi được', (tester) async {
    var shouldFail = true;
    final controller = _controller(
      assetBundle: _TestBundle(() async {
        if (shouldFail) throw StateError('Asset unavailable');
        return jsonEncode([_record()]);
      }),
    );
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    await _showScreen(tester, controller);

    expect(find.text('Chưa tải được bộ thẻ'), findsOneWidget);
    shouldFail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('1 thẻ'), findsOneWidget);
    expect(find.text('Chưa tải được bộ thẻ'), findsNothing);
    expect(controller.loadError, isNull);
  });

  testWidgets('Danh sách rỗng có lối ra bằng form thêm thẻ', (tester) async {
    var content = '[]';
    final controller = _controller(
      assetBundle: _TestBundle(() async => content),
    );
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    await _showScreen(tester, controller);

    expect(find.text('Chưa có thẻ nào'), findsOneWidget);
    await tester.tap(find.text('Thêm thẻ mới'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('manage_editor_front')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thẻ nào'), findsOneWidget);
    expect(controller.cards, isEmpty);
  });

  testWidgets('Câu hỏi dài và chữ lớn cuộn được ở màn hình hẹp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = _controller(
      assetBundle: _TestBundle(
        () async => jsonEncode([
          _record(
            front: List.filled(30, 'Câu hỏi có mã Dart rất dài.').join('\n'),
          ),
          _record(id: 'K01-002', front: 'Câu hỏi cuối danh sách'),
        ]),
      ),
    );
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    await _showScreen(tester, controller);
    await tester.scrollUntilVisible(
      find.text('Câu hỏi cuối danh sách'),
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(find.text('Câu hỏi cuối danh sách'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gõ để tìm, đổi từ khóa và xóa để khôi phục danh sách', (
    tester,
  ) async {
    final controller = _controller(
      assetBundle: _TestBundle(
        () async => jsonEncode([
          _record(),
          {
            ..._record(id: 'K01-002', front: 'Cách dựng giao diện?'),
            'back': 'Sử dụng Widget.',
          },
        ]),
      ),
    );
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    await _showScreen(tester, controller);

    await tester.enterText(find.byType(TextField), 'k01-002');
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 thẻ'), findsOneWidget);
    expect(find.text('Cách dựng giao diện?'), findsOneWidget);
    expect(find.text(_record()['front'] as String), findsNothing);

    await tester.enterText(find.byType(TextField), 'BIEN DICH');
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 thẻ'), findsOneWidget);
    expect(find.text(_record()['front'] as String), findsOneWidget);
    expect(find.text('Cách dựng giao diện?'), findsNothing);

    await tester.tap(find.byTooltip('Xóa từ khóa'));
    await tester.pumpAndSettle();
    expect(find.text('2 thẻ'), findsOneWidget);
    expect(find.text('Cách dựng giao diện?'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(controller.cards, hasLength(2));
  });

  testWidgets('Không tìm thấy có nút xóa để quay về toàn bộ thẻ', (
    tester,
  ) async {
    final controller = _controller(
      assetBundle: _TestBundle(() async => jsonEncode([_record()])),
    );
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    await _showScreen(tester, controller);

    await tester.enterText(find.byType(TextField), 'khongtontai987654');
    await tester.pumpAndSettle();
    expect(find.text('0 / 1 thẻ'), findsOneWidget);
    expect(find.text('Không tìm thấy thẻ'), findsOneWidget);
    expect(find.text('Chưa có thẻ nào'), findsNothing);

    await tester.tap(find.text('Xóa tìm kiếm'));
    await tester.pumpAndSettle();
    expect(find.text('1 thẻ'), findsOneWidget);
    expect(find.text(_record()['front'] as String), findsOneWidget);
    expect(find.text('Không tìm thấy thẻ'), findsNothing);
  });

  testWidgets('Tìm khi đang ở cuối danh sách vẫn thấy kết quả và đúng đáp án', (
    tester,
  ) async {
    final controller = _controller(
      assetBundle: _TestBundle(
        () async => jsonEncode(
          List.generate(60, (index) {
            final id = 'K01-${(index + 1).toString().padLeft(3, '0')}';
            return {
              ..._record(id: id, front: 'Câu hỏi số ${index + 1}'),
              'back': 'Đáp án riêng số ${index + 1}',
            };
          }),
        ),
      ),
    );
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    await _showScreen(tester, controller);
    await tester.scrollUntilVisible(
      find.text('Câu hỏi số 60'),
      500,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    await tester.enterText(find.byType(TextField), 'K01-001');
    await tester.pumpAndSettle();
    expect(find.text('1 / 60 thẻ'), findsOneWidget);
    await tester.tap(find.text('Câu hỏi số 1'));
    await tester.pumpAndSettle();
    expect(find.text('Đáp án riêng số 1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'K01-060');
    await tester.pumpAndSettle();
    expect(find.text('Đáp án riêng số 1'), findsNothing);
    await tester.tap(find.text('Câu hỏi số 60'));
    await tester.pumpAndSettle();
    expect(find.text('Đáp án riêng số 60'), findsOneWidget);
    expect(controller.cards, hasLength(60));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Áp dụng đồng thời hai bộ lọc và tìm kiếm trên dữ liệu thật', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.runAsync(controller.loadDefaultCards);
    await _showScreen(tester, controller);

    await tester.tap(find.text('Bộ lọc'));
    await tester.pumpAndSettle();
    await _selectFilter(tester, 'manage_filter_topic', 'K01');
    await _selectFilter(tester, 'manage_filter_level', 'Nhớ');
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();

    final expectedCount = controller.cards
        .where((card) => card.topicCode == 'K01' && card.level == 'Nhớ')
        .length;
    expect(find.text('$expectedCount / 300 thẻ'), findsOneWidget);
    expect(find.text('Bộ lọc (2)'), findsOneWidget);
    expect(find.text('K01 • Nhớ'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'K01-001');
    await tester.pumpAndSettle();
    expect(find.text('1 / 300 thẻ'), findsOneWidget);
    await tester.tap(find.byTooltip('Xóa từ khóa'));
    await tester.pumpAndSettle();
    expect(find.text('$expectedCount / 300 thẻ'), findsOneWidget);
    expect(find.text('Bộ lọc (2)'), findsOneWidget);
    expect(controller.cards, hasLength(300));
  });

  testWidgets('Bộ lọc chỉ thay đổi khi áp dụng; đặt lại giữ từ khóa', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.runAsync(controller.loadDefaultCards);
    await _showScreen(tester, controller);

    await tester.enterText(find.byType(TextField), 'K01');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bộ lọc'));
    await tester.pumpAndSettle();
    await _selectFilter(tester, 'manage_filter_topic', 'K20');
    // Đóng bảng mà chưa áp dụng không được đổi bộ lọc của danh sách.
    Navigator.of(tester.element(find.text('Lọc bộ thẻ'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('20 / 300 thẻ'), findsOneWidget);
    expect(find.text('Bộ lọc'), findsOneWidget);

    await tester.tap(find.text('Bộ lọc'));
    await tester.pumpAndSettle();
    await _selectFilter(tester, 'manage_filter_topic', 'K01');
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bộ lọc (1)'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const ValueKey('manage_filter_topic')),
          )
          .value,
      'K01',
    );
    await tester.tap(find.text('Đặt lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(find.text('Bộ lọc'), findsOneWidget);
    expect(find.text('20 / 300 thẻ'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'K01',
    );
  });

  testWidgets('Không có kết quả kết hợp có thể xóa mọi điều kiện', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.runAsync(controller.loadDefaultCards);
    await _showScreen(tester, controller);
    await tester.enterText(find.byType(TextField), 'K01-001');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bộ lọc'));
    await tester.pumpAndSettle();
    await _selectFilter(tester, 'manage_filter_topic', 'K20');
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();

    expect(find.text('0 / 300 thẻ'), findsOneWidget);
    expect(find.text('Không tìm thấy thẻ'), findsOneWidget);
    await tester.tap(find.text('Xóa tìm kiếm và bộ lọc'));
    await tester.pumpAndSettle();
    expect(find.text('300 thẻ'), findsOneWidget);
    expect(find.text('Bộ lọc'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('Giữ bộ lọc khi chuyển tab rồi quay lại', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.runAsync(controller.loadDefaultCards);
    await _showScreen(tester, controller, home: const _LegacyTabs());
    await tester.tap(find.text('Bộ thẻ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bộ lọc'));
    await tester.pumpAndSettle();
    await _selectFilter(tester, 'manage_filter_topic', 'K20');
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bộ thẻ').last);
    await tester.pumpAndSettle();

    expect(find.text('8 / 300 thẻ'), findsOneWidget);
    expect(find.text('Bộ lọc (1)'), findsOneWidget);
  });

  testWidgets('Đổi Việt–Anh cập nhật cả hai mặt của thẻ đang mở', (
    tester,
  ) async {
    final controller = _controller(
      assetBundle: _TestBundle(() async => jsonEncode([_record()])),
    );
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    final original = controller.cards.single;
    await _showScreen(tester, controller);
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    expect(find.text(original.back), findsOneWidget);

    controller.setLanguage(true);
    await tester.pumpAndSettle();
    expect(find.text(original.frontEn!), findsOneWidget);
    expect(find.text(original.backEn!), findsOneWidget);
    expect(find.text(original.front), findsNothing);
    expect(find.text(original.back), findsNothing);

    controller.setLanguage(false);
    await tester.pumpAndSettle();
    expect(find.text(original.front), findsOneWidget);
    expect(find.text(original.back), findsOneWidget);
    expect(controller.cards.single, same(original));
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    {
      'name': 'Thiếu câu hỏi Anh vẫn dùng được đáp án Anh',
      'front_en': null,
      'back_en': 'Translated answer',
      'expected_front': _record()['front'],
      'expected_back': 'Translated answer',
    },
    {
      'name': 'Đáp án Anh chỉ có khoảng trắng thì dùng đáp án Việt',
      'front_en': 'Translated question',
      'back_en': '  \n\t',
      'expected_front': 'Translated question',
      'expected_back': _record()['back'],
    },
    {
      'name': 'Hai bản dịch rỗng đều trở về nội dung Việt',
      'front_en': '',
      'back_en': '',
      'expected_front': _record()['front'],
      'expected_back': _record()['back'],
    },
  ]) {
    testWidgets(scenario['name'] as String, (tester) async {
      final controller = _controller(
        assetBundle: _TestBundle(
          () async => jsonEncode([
            {
              ..._record(),
              'front_en': scenario['front_en'],
              'back_en': scenario['back_en'],
            },
          ]),
        ),
      );
      addTearDown(controller.dispose);
      await controller.loadDefaultCards();
      controller.setLanguage(true);
      await _showScreen(tester, controller);
      expect(find.text(scenario['expected_front'] as String), findsOneWidget);
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();
      expect(find.text(scenario['expected_back'] as String), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Đổi ngôn ngữ giữ bộ lọc, từ khóa Việt và thẻ đang mở', (
    tester,
  ) async {
    final controller = _controller(
      assetBundle: _TestBundle(
        () async => jsonEncode([
          _record(),
          {
            ..._record(id: 'K02-001', front: 'Câu hỏi khác'),
            'topicCode': 'K02',
            'level': 'Hiểu',
          },
        ]),
      ),
    );
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    await _showScreen(tester, controller);
    await tester.enterText(find.byType(TextField), 'tu khoa');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bộ lọc'));
    await tester.pumpAndSettle();
    await _selectFilter(tester, 'manage_filter_topic', 'K01');
    await _selectFilter(tester, 'manage_filter_level', 'Nhớ');
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    controller.setLanguage(true);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data == '1 / 2 cards' || w.data == '1 / 2 thẻ'),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data == 'Bộ lọc (2)' || w.data == 'Filter (2)'),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data == 'K01 • Nhớ' || w.data == 'K01 • Remember'),
      ),
      findsWidgets,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'tu khoa',
    );
    expect(find.text('What does const do?'), findsOneWidget);
    expect(find.text('Creates a compile-time constant.'), findsOneWidget);
    expect(controller.cards, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Đổi ngôn ngữ thẻ thật có code vẫn giữ định dạng và trạng thái mở',
    (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.runAsync(controller.loadDefaultCards);
      await _showScreen(tester, controller);
      await tester.enterText(find.byType(TextField), 'K01-005');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      controller.setLanguage(true);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('What does the following code print?'),
        findsOneWidget,
      );
      expect(find.textContaining('Explanation:'), findsOneWidget);
      final englishView = find.byKey(
        const PageStorageKey('manage_front_K01-005_en'),
      );
      expect(
        find.descendant(of: englishView, matching: find.byType(Scrollable)),
        findsOneWidget,
      );
      expect(find.text('meow generic'), findsOneWidget);
      expect(find.textContaining('```'), findsNothing);

      controller.setLanguage(false);
      await tester.pumpAndSettle();
      expect(find.textContaining('Đoạn mã sau in ra gì?'), findsOneWidget);
      expect(find.textContaining('Giải thích:'), findsOneWidget);
      expect(
        find.byKey(const PageStorageKey('manage_front_K01-005_vi')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Học và chấm điểm ở màn hình mới giữ dữ liệu và bộ lọc Bộ thẻ', (
    tester,
  ) async {
    final controller = _controller(
      assetBundle: _TestBundle(
        () async => jsonEncode([
          _record(),
          {
            ..._record(id: 'K02-001', front: 'Câu hỏi tiếp theo'),
            'topicCode': 'K02',
          },
        ]),
      ),
    );
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    controller.setLanguage(true);
    await _showScreen(tester, controller, home: const _LegacyTabs());
    await tester.tap(find.text('Bộ thẻ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'K01-001');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data == 'Bộ lọc' || w.data == 'Filter'),
      ),
    );
    await tester.pumpAndSettle();
    await _selectFilter(tester, 'manage_filter_topic', 'K01');
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data == 'Áp dụng' || w.data == 'Apply'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Học thẻ'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data == 'Hiện đáp án' || w.data == 'Show Answer' || w.data == 'Show answer'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data == 'Tốt' || w.data == 'Good'),
      ),
    );
    await tester.pumpAndSettle();

    final reviewed = controller.cards.firstWhere(
      (card) => card.id == 'K01-001',
    );
    expect(reviewed.repetitions, 1);
    expect(reviewed.interval, 1);
    expect(controller.cards, hasLength(2));
    await tester.tap(find.text('Bộ thẻ'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data == '1 / 2 thẻ' || w.data == '1 / 2 cards'),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data == 'Bộ lọc (1)' || w.data == 'Filter (1)'),
      ),
      findsOneWidget,
    );
    expect(find.text('What does const do?'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'K01-001',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Lọc và xóa lọc trên màn hình hẹp với cỡ chữ lớn', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = _controller(
      assetBundle: _TestBundle(() async => jsonEncode([_record()])),
    );
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    await _showScreen(tester, controller);
    await tester.tap(find.text('Bộ lọc'));
    await tester.pumpAndSettle();
    await _selectFilter(tester, 'manage_filter_level', 'Vận dụng');
    await tester.ensureVisible(find.text('Áp dụng'));
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 1 thẻ'), findsOneWidget);
    await tester.ensureVisible(find.text('Xóa bộ lọc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa bộ lọc'));
    await tester.pumpAndSettle();
    expect(find.text('1 thẻ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
