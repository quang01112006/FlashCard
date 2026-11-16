import 'dart:async';
import 'dart:convert';

import 'package:flashcard_sm2/controllers/card_controller.dart';
import 'package:flashcard_sm2/core/app_theme.dart';
import 'package:flashcard_sm2/screens/manage_cards_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _TestBundle extends CachingAssetBundle {
  _TestBundle(this.read);

  final Future<String> Function() read;

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    expect(key, 'assets/default_cards.json');
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

Future<void> _showScreen(WidgetTester tester, CardController controller) {
  return tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ManageCardsScreen(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Nạp đủ 300 thẻ thật, 20 khối và giữ nội dung song ngữ', () async {
    final controller = CardController();
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
    final controller = CardController(
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

  for (final invalid in <String, dynamic>{
    'JSON sai cú pháp': 'invalid json',
    'JSON không phải danh sách': '{}',
    'bản ghi sai kiểu': jsonEncode([123]),
    'mặt trước rỗng': jsonEncode([_record(front: '  ')]),
    'ID trùng': jsonEncode([_record(), _record()]),
  }.entries) {
    test('${invalid.key}: báo lỗi và giữ nguyên dữ liệu đang có', () async {
      var content = jsonEncode([_record()]);
      final controller = CardController(
        assetBundle: _TestBundle(() async => content),
      );
      addTearDown(controller.dispose);
      await controller.loadDefaultCards();
      final original = controller.cards.single;

      content = invalid.value as String;
      await controller.loadDefaultCards();

      expect(controller.loadError, isNotNull);
      expect(controller.isLoading, isFalse);
      expect(controller.cards.single, same(original));
    });
  }

  testWidgets('Hiển thị đang tải rồi chuyển sang danh sách', (tester) async {
    final pending = Completer<String>();
    final controller = CardController(
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
    expect(find.text('K01-001 • K01 • Nhớ'), findsOneWidget);
  });

  testWidgets('Chạm thẻ mở và đóng đáp án', (tester) async {
    final controller = CardController(
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

  testWidgets('Lỗi đọc file có nút thử lại và phục hồi được', (tester) async {
    var shouldFail = true;
    final controller = CardController(
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

  testWidgets('Danh sách rỗng có lối ra bằng nút tải lại', (tester) async {
    var content = '[]';
    final controller = CardController(
      assetBundle: _TestBundle(() async => content),
    );
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    await _showScreen(tester, controller);

    expect(find.text('Chưa có thẻ nào'), findsOneWidget);
    content = jsonEncode([_record()]);
    await tester.tap(find.text('Tải lại'));
    await tester.pumpAndSettle();

    expect(find.text('1 thẻ'), findsOneWidget);
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
    final controller = CardController(
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
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Câu hỏi cuối danh sách'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
