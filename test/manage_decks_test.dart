import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:flashcard_sm2/controllers/card_controller.dart';
import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/models/card_deck.dart';
import 'package:flashcard_sm2/services/manage_card_store.dart';
import 'package:flashcard_sm2/services/manage_deck_store.dart';
import 'package:flashcard_sm2/screens/main_nav_screen.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.source);
  final String source;
  @override
  Future<String> loadString(String key, {bool cache = true}) async => source;
  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

class _FailingStore extends HiveManageCardStore {
  _FailingStore({super.openBox});
  bool fail = true;
  @override
  Future<void> writeCollection(DeckCollection collection) async {
    if (fail) throw StateError('Disk unavailable');
    await super.writeCollection(collection);
  }
}

class _MemoryStore implements ManageCardStore, ManageDeckStore {
  DeckCollection? collection;

  @override
  Future<List<Flashcard>?> read() async {
    return collection?.cards;
  }

  @override
  Future<void> write(List<Flashcard> cards) async {
    collection = DeckCollection(
      decks: collection?.decks ??
          [const CardDeck(id: CardDeck.flutterId, name: 'Học Flutter')],
      cards: cards,
    );
  }

  @override
  Future<DeckCollection?> readCollection() async {
    return collection;
  }

  @override
  Future<void> writeCollection(DeckCollection value) async {
    collection = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('manage-decks-');
    Hive.init(dir.path);
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  HiveManageCardStore store() =>
      HiveManageCardStore(openBox: () => Hive.openBox<dynamic>('deck-tests'));
  Flashcard card(String id) => Flashcard(
    id: id,
    front: 'Question $id',
    back: 'Answer',
    topicCode: 'K01',
    level: 'Nhớ',
  );

  test(
    'Nâng dữ liệu v1 giữ nội dung và SM2, tách thẻ thêm, có bản sao v1',
    () async {
      final edited = card('original').copyWith(
        front: 'Đã sửa',
        repetitions: 5,
        interval: 30,
        nextReviewDate: DateTime(2030),
      );
      final added = card('USER-added').copyWith(topicCode: 'Nấu ăn');
      await store().write([edited, added]);
      final controller = CardController(
        store: store(),
        assetBundle: _Bundle(jsonEncode([card('original').toJson()])),
      );
      await controller.loadDefaultCards();
      expect(controller.loadError, isNull);
      expect(controller.cardsInDeck(CardDeck.flutterId).single.front, 'Đã sửa');
      expect(controller.cardsInDeck(CardDeck.flutterId).single.repetitions, 5);
      expect(controller.cardsInDeck(CardDeck.legacyId).single.id, 'USER-added');
      final box = await Hive.openBox<dynamic>('deck-tests');
      expect((box.get('deck_v1_backup') as Map)['version'], 1);
      final id = (await controller.createDeck(
        'Nấu ăn',
        description: 'Các món ăn',
      )).id;
      controller.dispose();
      await Hive.close();
      final restored = CardController(
        store: store(),
        assetBundle: _Bundle('invalid'),
      );
      addTearDown(restored.dispose);
      await restored.loadDefaultCards();
      expect(restored.loadError, isNull);
      expect(restored.decks.last.id, id);
      expect(restored.decks.last.description, 'Các món ăn');
      expect(restored.cardsInDeck(id), isEmpty);
      expect(restored.cards.first.interval, 30);
      expect(restored.cards.first.nextReviewDate, DateTime(2030));
      expect(restored.cards, hasLength(2));
    },
  );

  test(
    'Khởi tạo đủ 300 câu Flutter; bộ mới rỗng và kiểm tra tên trùng',
    () async {
      final controller = CardController(store: store());
      addTearDown(controller.dispose);
      await controller.loadDefaultCards();
      expect(controller.cardsInDeck(CardDeck.flutterId), hasLength(300));
      final deck = await controller.createDeck('  Khoa học  ');
      expect(deck.name, 'Khoa học');
      expect(controller.cardsInDeck(deck.id), isEmpty);
      await expectLater(
        controller.createDeck('khoa học'),
        throwsA(isA<CardOperationException>()),
      );
      await expectLater(
        controller.createDeck('   '),
        throwsA(isA<CardOperationException>()),
      );
      await controller.loadDefaultCards(forceReload: true);
      expect(controller.decks, hasLength(2));
      expect(controller.cards, hasLength(300));
    },
  );

  test('Dữ liệu rỗng cố ý không tự nạp lại 300 câu', () async {
    await store().write([]);
    final controller = CardController(
      store: store(),
      assetBundle: _Bundle('[]'),
    );
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    await controller.createDeck('Tiếng Anh');
    await controller.loadDefaultCards(forceReload: true);
    expect(controller.cards, isEmpty);
    expect(controller.decks, hasLength(2));
  });

  test('Nâng dữ liệu hoặc tạo bộ lỗi không mất bản cũ; thử lại được', () async {
    await store().write([card('x')]);
    final failing = _FailingStore(
      openBox: () => Hive.openBox<dynamic>('deck-tests'),
    );
    final controller = CardController(
      store: failing,
      assetBundle: _Bundle(jsonEncode([card('x').toJson()])),
    );
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    expect(controller.loadError, isNotNull);
    final box = await Hive.openBox<dynamic>('deck-tests');
    expect((box.get('deck') as Map)['version'], 1);
    failing.fail = false;
    await controller.loadDefaultCards(forceReload: true);
    expect(controller.loadError, isNull);
    failing.fail = true;
    await expectLater(
      controller.createDeck('Nấu ăn'),
      throwsA(isA<CardOperationException>()),
    );
    expect(controller.decks, hasLength(1));
    expect(((box.get('deck') as Map)['decks'] as List), hasLength(1));
    failing.fail = false;
    await controller.createDeck('Nấu ăn');
    expect(controller.decks, hasLength(2));
    expect(controller.cards.single.id, 'x');
  });

  test('Bộ tham chiếu hỏng không được tự ghi đè', () async {
    final box = await Hive.openBox<dynamic>('deck-tests');
    await box.put('deck', {
      'version': 2,
      'decks': [],
      'cards': [card('x').toJson()],
    });
    final controller = CardController(
      store: store(),
      assetBundle: _Bundle('[]'),
    );
    addTearDown(controller.dispose);
    await controller.loadDefaultCards();
    expect(controller.loadError, isNotNull);
    await expectLater(
      controller.createDeck('New'),
      throwsA(isA<CardOperationException>()),
    );
    expect((box.get('deck') as Map)['cards'], hasLength(1));
  });

  testWidgets('Danh sách bộ, tạo bộ rỗng, mở và quay lại không trộn câu hỏi', (
      tester,
      ) async {
    final memoryStore = _MemoryStore();

    await memoryStore.writeCollection(
      DeckCollection(
        decks: [
          const CardDeck(
            id: CardDeck.flutterId,
            name: 'Học Flutter',
          ),
        ],
        cards: [card('x')],
      ),
    );

    final controller = CardController(store: memoryStore);
    await controller.loadDefaultCards();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: MainNavScreen()),
      ),
    );

    await tester.tap(find.text('Bộ thẻ'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('manage_create_deck')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('manage_deck_name')),
      'Nấu ăn',
    );

    await tester.tap(find.text('Tạo bộ mới'));
    await tester.pumpAndSettle();

    expect(controller.isSaving, isFalse);
    expect(find.byKey(const ValueKey('manage_deck_name')), findsNothing);

    await tester.tap(find.text('Nấu ăn'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có thẻ nào'), findsOneWidget);
    expect(find.text('Question x'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Học Flutter'));
    await tester.pumpAndSettle();

    expect(find.text('Question x'), findsOneWidget);
  });
}
