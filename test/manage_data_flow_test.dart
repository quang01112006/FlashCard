import 'dart:convert';
import 'dart:io';

import 'package:flashcard_sm2/controllers/card_controller.dart';
import 'package:flashcard_sm2/models/card_deck.dart';
import 'package:flashcard_sm2/models/flashcard.dart';
import 'package:flashcard_sm2/services/ai_card_service.dart';
import 'package:flashcard_sm2/services/csv_service.dart';
import 'package:flashcard_sm2/services/manage_card_store.dart';
import 'package:flashcard_sm2/services/manage_deck_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _NoAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      throw StateError('Must restore persisted data, not seed assets');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'CSV và AI qua nhiều bộ, đóng/mở Hive giữ bản dịch và lịch ôn',
    () async {
      final directory = await Directory.systemTemp.createTemp('manage-flow-');
      try {
        Hive.init(directory.path);
        HiveManageCardStore store() => HiveManageCardStore(
          openBox: () => Hive.openBox<dynamic>('manage_flow_test'),
        );
        final original = Flashcard(
          id: 'original',
          front: 'Câu hỏi Flutter gốc',
          back: 'Đáp án gốc',
          level: 'Nhớ',
          repetitions: 4,
          interval: 30,
          nextReviewDate: DateTime(2035),
        );
        await store().writeCollection(
          DeckCollection(
            decks: [
              const CardDeck(id: CardDeck.flutterId, name: 'Học Flutter'),
            ],
            cards: [original],
          ),
        );
        final controller = CardController(
          store: store(),
          assetBundle: _NoAssets(),
        );
        addTearDown(controller.dispose);
        await controller.loadDefaultCards();
        expect(controller.loadError, isNull);
        final cooking = await controller.createDeck('Nấu ăn');
        final games = await controller.createDeck('Giải trí');
        final csv = CsvService.parse(
          'front,back,topicCode,level,front_en,back_en\n'
          'Nấu cơm?,Dùng nồi cơm.,Món chính,Nhớ,Cook rice?,Use a rice cooker.\n'
          'Luộc trứng?,Dùng nước sôi.,Món phụ,Hiểu,Boil eggs?,Use boiling water.\n',
        );
        expect(csv.errors, isEmpty);
        await controller.importCards([
          for (final draft in csv.cards)
            draft
                .toCard(
                  id: controller.createCardId(),
                  defaultTopic: '',
                  defaultLevel: 'Nhớ',
                )
                .copyWith(deckId: cooking.id),
        ]);
        final csvIds = controller
            .cardsInDeck(cooking.id)
            .map((c) => c.id)
            .toList();
        final client = MockClient((request) async {
          expect(jsonDecode(request.body)['bilingual'], true);
          return http.Response(
            jsonEncode({
              'cards': [
                {
                  'front': 'Bảo quản thức ăn?',
                  'back': 'Giữ lạnh phù hợp.',
                  'frontEn': 'Store food?',
                  'backEn': 'Keep refrigerated.',
                },
                {
                  'front': 'Vệ sinh bếp?',
                  'back': 'Làm sạch dụng cụ.',
                  'frontEn': 'Clean the kitchen?',
                  'backEn': 'Clean utensils.',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });
        addTearDown(client.close);
        final drafts =
            await WorkerAiCardService(
              endpoint: 'https://test.example',
              client: client,
            ).generate(
              const AiCardRequest(
                topic: 'Nấu ăn',
                count: 2,
                level: 'Vận dụng',
                bilingual: true,
              ),
            );
        final aiCards = [
          for (final draft in drafts)
            draft.toCard(id: controller.createCardId(), deckId: cooking.id),
        ];
        await controller.importCards(aiCards);
        await controller.editCard(
          aiCards.first.copyWith(backEn: 'Edited translation.'),
          expectedDeckId: cooking.id,
        );
        await controller.updateCard(
          controller.cards.first.copyWith(
            repetitions: 2,
            interval: 6,
            nextReviewDate: DateTime(2035),
          ),
        );
        await controller.moveCard(
          aiCards.last.id,
          games.id,
          expectedDeckId: cooking.id,
        );
        await controller.renameDeck(
          cooking.id,
          'Bếp gia đình',
          description: 'CSV và AI',
        );
        await controller.deleteCard(csvIds.last, expectedDeckId: cooking.id);
        expect(
          controller.cardsInDeck(CardDeck.flutterId).single.toJson(),
          original.toJson(),
        );

        final exported = CsvService.parseBytes(
          CsvService.exportBytes(controller.cardsInDeck(cooking.id)),
        );
        expect(exported.errors, isEmpty);
        expect(exported.cards, hasLength(2));
        final copyDeck = await controller.createDeck('Bản nhập lại');
        await controller.importCards([
          for (final draft in exported.cards)
            draft
                .toCard(
                  id: controller.createCardId(),
                  defaultTopic: '',
                  defaultLevel: 'Nhớ',
                )
                .copyWith(deckId: copyDeck.id),
        ]);
        expect(
          controller
              .cardsInDeck(copyDeck.id)
              .every((c) => c.repetitions == 0 && c.interval == 0),
          isTrue,
        );
        expect(
          controller
              .cardsInDeck(copyDeck.id)
              .any((c) => c.backEn == 'Edited translation.'),
          isTrue,
        );
        await controller.deleteDeck(games.id);
        final expectedCards = controller.cards.map((c) => c.toJson()).toList();
        final expectedDecks = controller.decks.map((d) => d.toJson()).toList();
        await Hive.close();

        final restored = CardController(
          store: store(),
          assetBundle: _NoAssets(),
        );
        addTearDown(restored.dispose);
        await restored.loadDefaultCards();
        expect(restored.loadError, isNull);
        expect(restored.cards.map((c) => c.toJson()).toList(), expectedCards);
        expect(restored.decks.map((d) => d.toJson()).toList(), expectedDecks);
        expect(
          restored.cardsInDeck(CardDeck.flutterId).single.toJson(),
          original.toJson(),
        );
        expect(
          restored.cards.any(
            (c) => c.id == aiCards.last.id || c.id == csvIds.last,
          ),
          isFalse,
        );
        final savedAi = restored.cards.singleWhere(
          (c) => c.id == aiCards.first.id,
        );
        expect(savedAi.backEn, 'Edited translation.');
        expect(savedAi.repetitions, 2);
        expect(savedAi.interval, 6);
        expect(savedAi.nextReviewDate, DateTime(2035));
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
