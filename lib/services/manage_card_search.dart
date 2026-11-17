import '../models/flashcard.dart';

/// Tìm trên dữ liệu hiện có, không thay đổi danh sách trong CardController.
class ManageCardSearch {
  static final _vietnameseAccents = <RegExp, String>{
    RegExp('[àáạảãâầấậẩẫăằắặẳẵ]'): 'a',
    RegExp('[èéẹẻẽêềếệểễ]'): 'e',
    RegExp('[ìíịỉĩ]'): 'i',
    RegExp('[òóọỏõôồốộổỗơờớợởỡ]'): 'o',
    RegExp('[ùúụủũưừứựửữ]'): 'u',
    RegExp('[ỳýỵỷỹ]'): 'y',
    RegExp('đ'): 'd',
  };
  static final _combiningMarks = RegExp(r'[\u0300-\u036f]');
  static final _whitespace = RegExp(r'\s+');
  static final _codeBlocks = RegExp(
    r'```(?:[a-zA-Z0-9_-]*\r?\n)?([\s\S]*?)```',
  );
  static final _inlineCode = RegExp(r'`([^`]+)`');

  static List<Flashcard> search(Iterable<Flashcard> cards, String query) {
    final keyword = _normalize(query);
    if (keyword.isEmpty) return cards.toList();

    return cards.where((card) {
      return [
        card.id,
        card.topicCode,
        card.front,
        card.back,
        card.frontEn,
        card.backEn,
      ].any((text) => text != null && _normalize(text).contains(keyword));
    }).toList();
  }

  static String _normalize(String text) {
    // Tìm theo nội dung hiển thị, bỏ dấu định dạng và nhãn ngôn ngữ code.
    var result = text
        .replaceAllMapped(_codeBlocks, (match) => match.group(1)!)
        .replaceAllMapped(_inlineCode, (match) => match.group(1)!)
        .toLowerCase();
    for (final accent in _vietnameseAccents.entries) {
      result = result.replaceAll(accent.key, accent.value);
    }
    return result
        .replaceAll(_combiningMarks, '')
        .replaceAll(_whitespace, ' ')
        .trim();
  }
}
