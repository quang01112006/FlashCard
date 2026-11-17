import 'dart:convert';
import 'dart:io';

import 'package:flashcard_sm2/controllers/card_controller.dart';
import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/services/manage_card_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.content);
  final String content;
  @override
  Future<String> loadString(String key, {bool cache = true}) async => content;
  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flashcard-crud-test-');
    Hive.init(directory.path);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  HiveManageCardStore openStore() => HiveManageCardStore(
    openBox: () => Hive.openBox<dynamic>(HiveManageCardStore.boxName),
  );
  Flashcard card(String id) => Flashcard(
    id: id,
    topicCode: 'K01',
    level: 'Nhớ',
    front: 'Câu hỏi $id',
    back: 'Đáp án',
  );

  test(
    'Đóng và mở lại Hive giữ CRUD, bản dịch rỗng, tiến độ và bộ thẻ rỗng',
    () async {
      final seed = card('seed');
      final first = CardController(
        store: openStore(),
        assetBundle: _Bundle(jsonEncode([seed.toJson()])),
      );
      await first.loadDefaultCards();
      final added = card(first.createCardId()).copyWith(frontEn: 'Question');
      await first.addCard(added);
      await first.updateCard(
        added.copyWith(
          repetitions: 2,
          interval: 6,
          nextReviewDate: DateTime(2030, 1, 1),
        ),
      );
      await first.editCard(added.copyWith(front: 'Đã sửa', frontEn: ''));
      await first.deleteCard('seed');
      first.dispose();
      await Hive.close();

      final second = CardController(
        store: openStore(),
        assetBundle: _Bundle('invalid - must read Hive'),
      );
      await second.loadDefaultCards();
      expect(second.loadError, isNull);
      expect(second.cards.single.id, added.id);
      expect(second.cards.single.front, 'Đã sửa');
      expect(second.cards.single.frontEn, '');
      expect(second.cards.single.repetitions, 2);
      expect(second.cards.single.interval, 6);
      expect(second.cards.single.nextReviewDate, DateTime(2030, 1, 1));
      await second.deleteCard(added.id);
      second.dispose();
      await Hive.close();

      final third = CardController(
        store: openStore(),
        assetBundle: _Bundle(jsonEncode([seed.toJson()])),
      );
      addTearDown(third.dispose);
      await third.loadDefaultCards();
      expect(third.loadError, isNull);
      expect(third.cards, isEmpty);
    },
  );

  test(
    'Bản ghi hỏng không bị ghi đè khi nạp và có thể phục hồi sau khi sửa',
    () async {
      final box = await Hive.openBox<dynamic>(HiveManageCardStore.boxName);
      await box.put('deck', {'version': 99, 'cards': []});
      final controller = CardController(
        store: openStore(),
        assetBundle: _Bundle('[]'),
      );
      addTearDown(controller.dispose);
      await controller.loadDefaultCards();
      expect(controller.loadError, isNotNull);
      await expectLater(
        controller.addCard(card('new')),
        throwsA(isA<CardOperationException>()),
      );
      expect((box.get('deck') as Map)['version'], 99);
      await box.put('deck', {
        'version': 1,
        'cards': [card('restored').toJson()],
      });
      await controller.loadDefaultCards(forceReload: true);
      expect(controller.cards.single.id, 'restored');
    },
  );

  test('Mở kho lỗi được thử lại và dữ liệu trùng ID bị từ chối', () async {
    var attempts = 0;
    final store = HiveManageCardStore(
      openBox: () async {
        if (++attempts == 1) throw const FileSystemException('Unavailable');
        return Hive.openBox<dynamic>(HiveManageCardStore.boxName);
      },
    );
    await expectLater(store.read(), throwsA(isA<FileSystemException>()));
    expect(await store.read(), isNull);
    await expectLater(
      store.write([card('same'), card('same')]),
      throwsFormatException,
    );
    expect(await store.read(), isNull);
  });

  test('Kho mặc định nối Hive Flutter với thư mục dữ liệu ứng dụng', () async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return directory.path;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final store = HiveManageCardStore();
    await store.write([card('default-path')]);
    expect((await store.read())!.single.id, 'default-path');
    expect(
      await File('${directory.path}/${HiveManageCardStore.boxName}.hive')
          .exists(),
      isTrue,
    );
  });
}
