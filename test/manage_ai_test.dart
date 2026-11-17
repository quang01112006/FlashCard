import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flashcard_sm2/controllers/card_controller.dart';
import 'package:flashcard_sm2/models/card_deck.dart';
import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/screens/manage_cards_screen.dart';
import 'package:flashcard_sm2/screens/manage_ai_screen.dart';
import 'package:flashcard_sm2/services/ai_card_service.dart';

import 'support/manage_deck_test_store.dart';

void main() {
  testWidgets(
    'English AI flow supports dark theme, large text and live language changes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryDeckTestStore()..savedCards = [];
      final controller = CardController(store: store);
      addTearDown(controller.dispose);
      await controller.loadDefaultCards();
      controller.setLanguage(true);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const ManageCardsScreen(
              deckId: CardDeck.flutterId,
              aiService: DemoAiCardService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manage_csv_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create cards with AI'));
      await tester.pumpAndSettle();
      expect(find.text('Create cards with AI'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('manage_ai_topic')),
        'Cooking',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('manage_ai_bilingual')),
      );
      await tester.tap(find.byKey(const ValueKey('manage_ai_bilingual')));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('manage_ai_generate')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('manage_ai_generate')));
      await tester.pumpAndSettle();
      expect(find.text('5/5 cards selected'), findsOneWidget);
      controller.setLanguage(false);
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 5/5 thẻ'), findsOneWidget);
      controller.setLanguage(true);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const PageStorageKey('manage_ai_draft_0')),
      );
      await tester.tap(find.byKey(const PageStorageKey('manage_ai_draft_0')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('manage_ai_edit_0')),
      );
      await tester.tap(find.byKey(const ValueKey('manage_ai_edit_0')));
      await tester.pumpAndSettle();
      expect(find.text('Edit card'), findsOneWidget);
      expect(find.text('Question'), findsOneWidget);
      final front = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('manage_editor_front')),
          matching: find.byType(TextField),
        ),
      );
      expect(front.style?.color, ThemeData.dark().textTheme.bodyLarge?.color);
      await tester.enterText(
        find.byKey(const ValueKey('manage_editor_front_en')),
        'Edited English question',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.text('Save card'));
      await tester.pumpAndSettle();
      expect(store.writes, 0);
      await tester.ensureVisible(
        find.byKey(const ValueKey('manage_ai_select_0')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manage_ai_select_0')));
      await tester.pumpAndSettle();
      expect(find.text('Save 4 selected cards'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('manage_ai_select_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manage_ai_save')));
      await tester.pumpAndSettle();
      expect(store.savedCards, hasLength(5));
      expect(
        store.savedCards!.every((c) => c.frontEn != null && c.backEn != null),
        isTrue,
      );
      expect(
        store.savedCards!.any((c) => c.frontEn == 'Edited English question'),
        isTrue,
      );
      expect(
        store.savedCards!.every(
          (c) => c.level == 'Nhớ' && c.deckId == CardDeck.flutterId,
        ),
        isTrue,
      );
      expect(find.text('Saved 5 cards.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'AI form fits a narrow screen with large text and translates validation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryDeckTestStore()..savedCards = [];
      final controller = CardController(store: store);
      addTearDown(controller.dispose);
      await controller.loadDefaultCards();
      controller.setLanguage(true);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: const ManageAiScreen(
              deckId: CardDeck.flutterId,
              service: DemoAiCardService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('manage_ai_generate')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('manage_ai_generate')));
      await tester.pumpAndSettle();
      expect(
        find.text('Please enter a topic or study material.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('manage_ai_topic')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('manage_ai_topic')),
        'Dart code and long questions',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('manage_ai_generate')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manage_ai_generate')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const PageStorageKey('manage_ai_draft_0')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const PageStorageKey('manage_ai_draft_0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('manage_ai_save')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'Reports model configuration errors without leaking provider content',
    () async {
      final service = WorkerAiCardService(
        endpoint: 'https://worker.example',
        client: MockClient(
          (_) async => http.Response(
            '{"error":"provider_model_unavailable","providerStatus":404}',
            502,
          ),
        ),
      );
      await expectLater(
        service.generate(
          const AiCardRequest(
            topic: 'Cooking',
            count: 1,
            level: 'Nhớ',
            bilingual: false,
          ),
        ),
        throwsA(
          isA<AiCardException>().having(
            (e) => e.message,
            'message',
            contains('Model Gemini'),
          ),
        ),
      );
    },
  );
  test(
    'Worker parses Vietnamese cards and reports rate limits and bad data',
    () async {
      const request = AiCardRequest(
        topic: 'Nấu ăn',
        count: 1,
        level: 'Hiểu',
        bilingual: true,
      );
      final ok = WorkerAiCardService(
        endpoint: 'https://worker.example',
        client: MockClient((message) async {
          expect(message.url.path, '/generate');
          return http.Response(
            '{"cards":[{"front":"Câu hỏi","back":"Đáp án","frontEn":"Question","backEn":"Answer"}]}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      expect((await ok.generate(request)).single.front, 'Câu hỏi');
      final limited = WorkerAiCardService(
        endpoint: 'https://worker.example',
        client: MockClient((_) async => http.Response('', 429)),
      );
      await expectLater(
        limited.generate(request),
        throwsA(
          isA<AiCardException>().having(
            (e) => e.message,
            'message',
            contains('giới hạn'),
          ),
        ),
      );
      final malformed = WorkerAiCardService(
        endpoint: 'https://worker.example',
        client: MockClient((_) async => http.Response('{"cards":[]}', 200)),
      );
      await expectLater(
        malformed.generate(request),
        throwsA(isA<AiCardException>()),
      );
      await expectLater(
        const WorkerAiCardService().generate(request),
        throwsA(isA<AiCardException>()),
      );
    },
  );
  test(
    'Demo produces labeled placeholders and validates the request',
    () async {
      const service = DemoAiCardService();
      final cards = await service.generate(
        const AiCardRequest(
          topic: 'Nấu ăn',
          count: 2,
          level: 'Hiểu',
          bilingual: true,
        ),
      );
      expect(cards, hasLength(2));
      expect(cards.first.front, contains('[Demo]'));
      expect(cards.first.back, contains('chưa phải đáp án do AI tạo'));
      expect(cards.first.frontEn, contains('[Demo]'));
      expect(cards.first.level, 'Hiểu');
      expect(
        () => service.generate(
          const AiCardRequest(
            topic: ' ',
            count: 2,
            level: 'Nhớ',
            bilingual: false,
          ),
        ),
        throwsFormatException,
      );
    },
  );

  testWidgets('Chọn, sửa và lưu thẻ demo vào đúng bộ; thử lại khi lưu lỗi', (
    tester,
  ) async {
    final store = MemoryDeckTestStore()
      ..decks = [
        const CardDeck(id: CardDeck.flutterId, name: 'Học Flutter'),
        const CardDeck(id: 'cooking', name: 'Nấu ăn'),
      ]
      ..savedCards = [
        Flashcard(id: 'old', front: 'Cũ', back: 'Đáp án cũ', level: 'Nhớ'),
      ];
    final controller = CardController(store: store);
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(
          home: ManageCardsScreen(
            deckId: 'cooking',
            aiService: DemoAiCardService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('manage_csv_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo thẻ AI'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('manage_ai_topic')),
      'Nấu ăn',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('manage_ai_generate')),
    );
    await tester.tap(find.byKey(const ValueKey('manage_ai_generate')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('kiểm tra và chỉnh sửa nội dung AI'),
      findsOneWidget,
    );
    expect(find.text('Bộ nhận: Nấu ăn'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('manage_ai_select_1')));
    await tester.tap(find.byKey(const PageStorageKey('manage_ai_draft_0')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('manage_ai_edit_0')));
    await tester.tap(find.byKey(const ValueKey('manage_ai_edit_0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('manage_editor_front')),
      'Câu hỏi đã sửa',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.text('Lưu thẻ'));
    await tester.tap(find.text('Lưu thẻ'));
    await tester.pumpAndSettle();
    expect(store.writes, 0);
    store.writeFailure = StateError('disk full');
    await tester.tap(find.byKey(const ValueKey('manage_ai_save')));
    await tester.pumpAndSettle();
    expect(controller.cardsInDeck('cooking'), isEmpty);
    expect(find.text('Câu hỏi đã sửa'), findsWidgets);
    store.writeFailure = null;
    await tester.tap(find.byKey(const ValueKey('manage_ai_save')));
    await tester.pumpAndSettle();
    expect(controller.cardsInDeck('cooking'), hasLength(4));
    expect(
      controller.cardsInDeck('cooking').any((c) => c.front == 'Câu hỏi đã sửa'),
      isTrue,
    );
    expect(controller.cardsInDeck(CardDeck.flutterId), hasLength(1));
    expect(store.savedCards, hasLength(5));
    expect(find.text('Đã lưu 4 thẻ.'), findsOneWidget);
  });
}
