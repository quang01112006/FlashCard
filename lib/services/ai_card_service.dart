import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/flashcard.dart';
import 'manage_card_filter.dart';

class AiCardRequest {
  const AiCardRequest({
    required this.topic,
    required this.count,
    required this.level,
    required this.bilingual,
  });
  final String topic;
  final int count;
  final String level;
  final bool bilingual;
}

/// Kết quả nháp chưa thuộc bộ thẻ và chưa có ID lưu trữ.
class AiCardDraft {
  const AiCardDraft({
    required this.front,
    required this.back,
    required this.level,
    this.topicCode = '',
    this.frontEn,
    this.backEn,
  });
  final String front;
  final String back;
  final String level;
  final String topicCode;
  final String? frontEn;
  final String? backEn;

  factory AiCardDraft.fromCard(Flashcard card) => AiCardDraft(
    front: card.front,
    back: card.back,
    level: card.level,
    topicCode: card.topicCode,
    frontEn: card.frontEn,
    backEn: card.backEn,
  );
  Flashcard toCard({required String id, required String deckId}) => Flashcard(
    id: id,
    deckId: deckId,
    front: front,
    back: back,
    level: level,
    topicCode: topicCode,
    frontEn: frontEn,
    backEn: backEn,
  );
  bool get isValid =>
      front.trim().isNotEmpty &&
      back.trim().isNotEmpty &&
      ManageCardFilter.levels.contains(level);
}

abstract interface class AiCardService {
  Future<List<AiCardDraft>> generate(AiCardRequest request);
}

class AiCardException implements Exception {
  const AiCardException(this.message);
  final String message;
}

class WorkerAiCardService implements AiCardService {
  const WorkerAiCardService({
    this.endpoint = const String.fromEnvironment('AI_WORKER_URL'),
    this.client,
  });
  final String endpoint;
  final http.Client? client;

  @override
  Future<List<AiCardDraft>> generate(AiCardRequest request) async {
    final base = Uri.tryParse(endpoint);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        base.userInfo.isNotEmpty) {
      throw const AiCardException('Chưa cấu hình địa chỉ dịch vụ AI.');
    }
    try {
      final response = await (client?.post ?? http.post)(
        base.resolve('/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topic': request.topic.trim(),
          'count': request.count,
          'level': request.level,
          'bilingual': request.bilingual,
        }),
      ).timeout(const Duration(seconds: 55));
      if (response.statusCode == 429) {
        throw const AiCardException(
          'Đã đạt giới hạn yêu cầu. Vui lòng chờ rồi thử lại.',
        );
      }
      if (response.statusCode != 200) {
        String? code;
        try {
          final body = jsonDecode(utf8.decode(response.bodyBytes));
          if (body is Map && body['error'] is String) code = body['error'];
        } catch (_) {
          /* Phản hồi có thể là HTML từ cổng mạng. */
        }
        const messages = {
          'provider_unavailable': 'Gemini đang tạm thời quá tải hoặc không khả dụng. Hãy chờ một lúc rồi thử lại.',
          'provider_location_unsupported': 'Khu vực máy chủ AI hiện chưa được Gemini hỗ trợ. Cần kiểm tra vị trí dịch vụ.',
          'not_configured':
              'Dịch vụ AI chưa được cấu hình đầy đủ trên Cloudflare.',
          'provider_key_invalid': 'Khóa Gemini trên dịch vụ AI không hợp lệ.',
          'provider_access_denied':
              'Gemini từ chối truy cập. Cần kiểm tra quyền của khóa API.',
          'provider_model_unavailable':
              'Model Gemini đang cấu hình không khả dụng.',
          'provider_request_invalid': 'Gemini không chấp nhận yêu cầu. Cần kiểm tra cấu hình dịch vụ AI.',
          'invalid_response':
              'Gemini chưa trả về đủ thẻ hợp lệ. Hãy thử lại với ít thẻ hơn.',
        };
        throw AiCardException(
          messages[code] ??
              'Không thể tạo thẻ AI (HTTP ${response.statusCode}). Vui lòng thử lại sau.',
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map || decoded['cards'] is! List) {
        throw const FormatException();
      }
      final cards = decoded['cards'] as List;
      if (cards.length != request.count) throw const FormatException();
      return cards.map((item) {
        if (item is! Map ||
            item['front'] is! String ||
            item['back'] is! String ||
            (request.bilingual &&
                (item['frontEn'] is! String || item['backEn'] is! String))) {
          throw const FormatException();
        }
        final draft = AiCardDraft(
          front: item['front'],
          back: item['back'],
          level: request.level,
          frontEn: request.bilingual ? item['frontEn'] : null,
          backEn: request.bilingual ? item['backEn'] : null,
        );
        if (!draft.isValid ||
            (request.bilingual &&
                (draft.frontEn!.trim().isEmpty ||
                    draft.backEn!.trim().isEmpty))) {
          throw const FormatException();
        }
        return draft;
      }).toList();
    } on AiCardException {
      rethrow;
    } on TimeoutException {
      throw const AiCardException('Kết nối AI quá lâu. Vui lòng thử lại.');
    } on FormatException {
      throw const AiCardException(
        'Dữ liệu AI trả về không hợp lệ. Vui lòng thử lại.',
      );
    } catch (_) {
      throw const AiCardException(
        'Không thể kết nối dịch vụ AI. Kiểm tra mạng rồi thử lại.',
      );
    }
  }
}

/// Dữ liệu minh họa; không gửi yêu cầu đến AI hay tạo kiến thức thực.
class DemoAiCardService implements AiCardService {
  const DemoAiCardService();
  @override
  Future<List<AiCardDraft>> generate(AiCardRequest request) async {
    final topic = request.topic.trim();
    if (topic.isEmpty ||
        request.count < 1 ||
        request.count > 10 ||
        !ManageCardFilter.levels.contains(request.level)) {
      throw const FormatException('Yêu cầu tạo thẻ không hợp lệ.');
    }
    return List.generate(
      request.count,
      (index) => AiCardDraft(
        front: '[Demo] Câu hỏi mẫu ${index + 1} về $topic',
        back: '[Demo] Đây là nội dung minh họa, chưa phải đáp án do AI tạo. Hãy chỉnh sửa trước khi dùng để học.',
        level: request.level,
        frontEn: request.bilingual
            ? '[Demo] Sample question ${index + 1} about $topic'
            : null,
        backEn: request.bilingual
            ? '[Demo] Placeholder answer. Edit before studying.'
            : null,
      ),
    );
  }
}
