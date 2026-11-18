import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import '../models/flashcard.dart';
import 'manage_card_filter.dart';

class CsvCardDraft {
  const CsvCardDraft({
    required this.line,
    required this.front,
    required this.back,
    this.topicCode,
    this.level,
    this.frontEn,
    this.backEn,
  });

  final int line;
  final String front;
  final String back;
  final String? topicCode;
  final String? level;
  final String? frontEn;
  final String? backEn;

  Flashcard toCard({
    required String id,
    required String defaultTopic,
    required String defaultLevel,
  }) => Flashcard(
    id: id,
    topicCode: topicCode ?? defaultTopic,
    level: level ?? defaultLevel,
    front: front,
    back: back,
    frontEn: frontEn,
    backEn: backEn,
  );
}

class CsvRowError {
  const CsvRowError(this.line, this.message);
  final int line;
  final String message;
}

class CsvImportResult {
  CsvImportResult({
    required List<CsvCardDraft> cards,
    required List<CsvRowError> errors,
    required this.blankRows,
  }) : cards = List.unmodifiable(cards),
       errors = List.unmodifiable(errors);

  final List<CsvCardDraft> cards;
  final List<CsvRowError> errors;
  final int blankRows;
  bool get needsTopic => cards.any((card) => card.topicCode == null);
  bool get needsLevel => cards.any((card) => card.level == null);
}

class CsvFileException implements Exception {
  const CsvFileException(this.message);
  final String message;
}

/// Định dạng trao đổi nội dung thẻ; không sao lưu ID hay lịch ôn SM-2.
class CsvService {
  static CsvTable inspectBytes(Uint8List bytes) {
    if (bytes.length > maxFileBytes) {
      throw const CsvFileException('File vượt quá 5 MB.');
    }
    String source;
    try {
      source = utf8.decode(bytes);
    } on FormatException {
      throw const CsvFileException(
        'Không đọc được tiếng Việt trong file. Hãy lưu file ở dạng CSV UTF-8.',
      );
    }
    if (source.startsWith('\ufeff')) source = source.substring(1);
    final hint = RegExp(r'^sep=([,;])\r?\n').firstMatch(source);
    final delimiter = hint?.group(1) ?? _detectDelimiter(source);
    final data = hint == null ? source : source.substring(hint.end);
    final codec = Csv(
      fieldDelimiter: delimiter,
      autoDetect: false,
      skipEmptyLines: false,
    );
    final sample = <List<String>>[];
    for (final record in _records(data, delimiter, hint == null ? 1 : 2)) {
      if (record.error != null || record.text.trim().isEmpty) continue;
      final rows = codec.decode(record.text);
      if (rows.isEmpty) continue;
      sample.add(rows.single.map((value) => value.toString()).toList());
      if (sample.length == 4) break;
    }
    return CsvTable(source, sample);
  }

  static const maxFileBytes = 5 * 1024 * 1024;
  static const columns = [
    'front',
    'back',
    'topicCode',
    'level',
    'front_en',
    'back_en',
  ];

  static CsvImportResult parseBytes(Uint8List bytes) {
    if (bytes.length > maxFileBytes) {
      throw const CsvFileException(
        'File vượt quá 5 MB. Vui lòng chia thành file nhỏ hơn.',
      );
    }
    try {
      return parse(utf8.decode(bytes));
    } on FormatException {
      throw const CsvFileException(
        'Không đọc được tiếng Việt trong file. Hãy lưu file ở dạng CSV UTF-8.',
      );
    }
  }

  static CsvImportResult parse(
    String source, {
    bool? hasHeader,
    Map<String, int>? mapping,
  }) {
    if (source.startsWith('\ufeff')) source = source.substring(1);
    var firstLine = 1;
    String? explicitDelimiter;
    final separatorHint = RegExp(r'^sep=([,;])\r?\n').firstMatch(source);
    if (separatorHint != null) {
      explicitDelimiter = separatorHint.group(1);
      source = source.substring(separatorHint.end);
      firstLine++;
    }
    final delimiter = explicitDelimiter ?? _detectDelimiter(source);
    final codec = Csv(
      fieldDelimiter: delimiter,
      autoDetect: false,
      skipEmptyLines: false,
    );
    final cards = <CsvCardDraft>[];
    final errors = <CsvRowError>[];
    var blankRows = 0;
    Map<String, int>? header;
    int? expectedColumns;
    var isFirstRecord = true;

    for (final record in _records(source, delimiter, firstLine)) {
      if (record.text.trim().isEmpty) {
        blankRows++;
        continue;
      }
      if (record.error != null) {
        errors.add(CsvRowError(record.line, record.error!));
        continue;
      }
      final rows = codec.decode(record.text);
      final fields = (rows.isEmpty ? [''] : rows.single)
          .map((value) => value.toString())
          .toList();
      if (fields.every((value) => value.trim().isEmpty)) {
        blankRows++;
        continue;
      }
      if (isFirstRecord) {
        isFirstRecord = false;
        if (hasHeader != null) {
          header = Map.of(mapping ?? {'front': 0, 'back': 1});
          if (!header.containsKey('front') ||
              !header.containsKey('back') ||
              header.values.toSet().length != header.length ||
              header.values.any(
                (index) => index < 0 || index >= fields.length,
              )) {
            throw const CsvFileException(
              'Hãy chọn các cột riêng biệt cho câu hỏi và đáp án.',
            );
          }
          expectedColumns = fields.length;
          if (hasHeader) continue;
        } else {
          final names = fields.map(_columnName).toList();
          // Một cột tên mặt thẻ đủ để nhận ra header bị thiếu cột bắt buộc.
          if (names.contains('front') || names.contains('back')) {
            header = {};
            for (var index = 0; index < names.length; index++) {
              final name = names[index];
              if (name == null) continue;
              if (header.containsKey(name)) {
                throw CsvFileException(
                  'Cột "$name" bị lặp trong dòng tiêu đề.',
                );
              }
              header[name] = index;
            }
            if (!header.containsKey('front') || !header.containsKey('back')) {
              throw const CsvFileException(
                'Dòng tiêu đề cần đủ hai cột front,back hoặc Mặt trước,Mặt sau.',
              );
            }
            expectedColumns = fields.length;
            continue;
          }
          expectedColumns = 2;
        }
      }
      if (fields.length != expectedColumns) {
        errors.add(
          CsvRowError(
            record.line,
            'Có ${fields.length} cột; cần $expectedColumns cột. Nội dung chứa dấu phân cách phải đặt trong dấu ngoặc kép.',
          ),
        );
        continue;
      }
      String value(String name) {
        final index = header == null
            ? (name == 'front'
                  ? 0
                  : name == 'back'
                  ? 1
                  : null)
            : header[name];
        return index == null ? '' : fields[index];
      }

      final front = value('front');
      final back = value('back');
      final topic = value('topicCode').trim();
      final level = value('level').trim();
      String? error;
      if (front.trim().isEmpty || back.trim().isEmpty) {
        error = 'Thiếu câu hỏi hoặc đáp án.';
      } else if (level.isNotEmpty && !ManageCardFilter.levels.contains(level)) {
        error = 'Mức độ phải là Nhớ, Hiểu hoặc Vận dụng.';
      }
      if (error != null) {
        errors.add(CsvRowError(record.line, error));
        continue;
      }
      String? optional(String name) {
        final text = value(name);
        return text.trim().isEmpty ? null : text;
      }

      cards.add(
        CsvCardDraft(
          line: record.line,
          front: front,
          back: back,
          topicCode: topic.isEmpty ? null : topic,
          level: level.isEmpty ? null : level,
          frontEn: optional('front_en'),
          backEn: optional('back_en'),
        ),
      );
    }
    return CsvImportResult(cards: cards, errors: errors, blankRows: blankRows);
  }

  static Uint8List exportBytes(Iterable<Flashcard> cards) => Uint8List.fromList(
    utf8.encode(
      Csv(addBom: true, autoDetect: false).encode([
        columns,
        for (final card in cards)
          [
            card.front,
            card.back,
            card.topicCode,
            card.level,
            card.frontEn ?? '',
            card.backEn ?? '',
          ],
      ]),
    ),
  );

  static String? _columnName(String text) => switch (_normalizeHeader(text)) {
    'front' || 'mattruoc' || 'truoc' || 'cauhoi' || 'question' => 'front',
    'back' || 'matsau' || 'sau' || 'dapan' || 'traloi' || 'answer' => 'back',
    'topiccode' || 'chude' || 'nhom' || 'topic' || 'category' => 'topicCode',
    'level' || 'mucdo' => 'level',
    'fronten' || 'questionen' || 'cauhoitienganh' => 'front_en',
    'backen' || 'answeren' || 'dapantienganh' => 'back_en',
    _ => null,
  };

  static String _normalizeHeader(String text) {
    var result = text.toLowerCase();
    const accents = {
      'àáạảãâầấậẩẫăằắặẳẵ': 'a',
      'èéẹẻẽêềếệểễ': 'e',
      'ìíịỉĩ': 'i',
      'òóọỏõôồốộổỗơờớợởỡ': 'o',
      'ùúụủũưừứựửữ': 'u',
      'ỳýỵỷỹ': 'y',
      'đ': 'd',
    };
    for (final entry in accents.entries) {
      result = result.replaceAll(RegExp('[${entry.key}]'), entry.value);
    }
    return result.replaceAll(RegExp(r'[\s_\-\u0300-\u036f]'), '');
  }

  static String _detectDelimiter(String source) {
    // Chỉ nhìn bản ghi đầu tiên, bỏ dấu phân cách nằm trong chuỗi được quote.
    var quoted = false;
    var commas = 0;
    var semicolons = 0;
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if (char == '"') {
        if (quoted && index + 1 < source.length && source[index + 1] == '"') {
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted) {
        if (char == ',') commas++;
        if (char == ';') semicolons++;
        if ((char == '\n' || char == '\r') && (commas + semicolons > 0)) break;
      }
    }
    return semicolons > commas ? ';' : ',';
  }

  /// Kiểm tra dấu quote và giữ số dòng vật lý trước khi dùng thư viện CSV.
  /// Nếu thiếu quote đóng, phần còn lại được báo lỗi thay vì tự đoán ranh giới thẻ.
  static Iterable<_CsvRecord> _records(
    String source,
    String delimiter,
    int line,
  ) sync* {
    var start = 0;
    var startLine = line;
    var state = 0; // 0: đầu ô, 1: ô thường, 2: trong quote, 3: sau quote.
    String? error;
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if (state == 2) {
        if (char == '"') {
          if (index + 1 < source.length && source[index + 1] == '"') {
            index++;
          } else {
            state = 3;
          }
        }
      } else if (char == '\n' || char == '\r') {
        yield _CsvRecord(source.substring(start, index), startLine, error);
        if (char == '\r' &&
            index + 1 < source.length &&
            source[index + 1] == '\n') {
          index++;
        }
        start = index + 1;
        startLine = ++line;
        state = 0;
        error = null;
        continue;
      } else if (char == delimiter) {
        state = 0;
      } else if (char == '"' && state == 0) {
        state = 2;
      } else {
        if (state == 3 || char == '"') {
          error = 'Dấu ngoặc kép không đúng định dạng CSV.';
        }
        state = 1;
      }
      if (char == '\n' ||
          (char == '\r' &&
              (index + 1 == source.length || source[index + 1] != '\n'))) {
        line++;
      }
    }
    if (start < source.length) {
      yield _CsvRecord(
        source.substring(start),
        startLine,
        state == 2
            ? 'Thiếu dấu ngoặc kép đóng; không thể tách an toàn các dòng còn lại.'
            : error,
      );
    }
  }
}

class _CsvRecord {
  const _CsvRecord(this.text, this.line, this.error);
  final String text;
  final int line;
  final String? error;
}

class CsvTable {
  CsvTable(this.source, this.sample);
  final String source;
  final List<List<String>> sample;
  int get columnCount => sample.isEmpty ? 0 : sample.first.length;
  bool get suggestedHeader =>
      sample.isNotEmpty &&
      sample.first.any((value) => CsvService._columnName(value) != null);
  Map<String, int> suggest(bool hasHeader) {
    if (!hasHeader) return columnCount < 2 ? {} : {'front': 0, 'back': 1};
    final found = <String, List<int>>{};
    for (var index = 0; index < columnCount; index++) {
      final name = CsvService._columnName(sample.first[index]);
      if (name != null) (found[name] ??= []).add(index);
    }
    return {
      for (final entry in found.entries)
        if (entry.value.length == 1) entry.key: entry.value.single,
    };
  }
}
