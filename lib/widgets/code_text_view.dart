import 'package:flutter/material.dart';

/// Widget dùng chung để hiển thị nội dung câu hỏi/đáp án
/// Tự động nhận diện văn bản thường, code nội dòng `code` và khối code ```code```
class CodeTextView extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;
  final TextAlign textAlign;

  const CodeTextView({
    super.key,
    required this.text,
    this.baseStyle,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultTextStyle =
        baseStyle ??
        theme.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5) ??
        const TextStyle(fontSize: 16, height: 1.5);

    // Nếu văn bản có chứa khối code ``` thì tự động căn trái để bố cục thẳng hàng, dễ đọc
    final hasCodeBlock = text.contains('```');
    final effectiveTextAlign = hasCodeBlock ? TextAlign.left : textAlign;

    final widgets = _buildContentWidgets(
      context: context,
      input: text,
      defaultStyle: defaultTextStyle,
      textAlign: effectiveTextAlign,
      isDark: isDark,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  /// Tách văn bản thành danh sách Widget:
  /// - Khối code ``` -> Hiển thị hộp code cuộn ngang
  /// - Văn bản thường & inline code ` -> Hiển thị qua Text.rich nằm trên cùng dòng
  List<Widget> _buildContentWidgets({
    required BuildContext context,
    required String input,
    required TextStyle defaultStyle,
    required TextAlign textAlign,
    required bool isDark,
  }) {
    final List<Widget> widgets = [];
    if (input.trim().isEmpty) return widgets;

    // Quét tìm các khối code ``` ... ```
    final blockRegex = RegExp(r'```(?:[a-zA-Z0-9_-]*\r?\n)?([\s\S]*?)```');
    int lastIndex = 0;

    for (final match in blockRegex.allMatches(input)) {
      if (match.start > lastIndex) {
        final textPart = input.substring(lastIndex, match.start);
        if (textPart.trim().isNotEmpty) {
          widgets.add(
            _buildRichTextParagraph(
              text: textPart,
              defaultStyle: defaultStyle,
              textAlign: textAlign,
              isDark: isDark,
            ),
          );
        }
      }

      final codeContent = match.group(1) ?? '';
      widgets.add(_buildCodeBlock(code: codeContent, isDark: isDark));

      lastIndex = match.end;
    }

    if (lastIndex < input.length) {
      final textPart = input.substring(lastIndex);
      if (textPart.trim().isNotEmpty) {
        widgets.add(
          _buildRichTextParagraph(
            text: textPart,
            defaultStyle: defaultStyle,
            textAlign: textAlign,
            isDark: isDark,
          ),
        );
      }
    }

    return widgets;
  }

  /// Hiển thị đoạn văn bản có chứa inline code `...` cùng dòng mượt mà như Notion/Discord
  Widget _buildRichTextParagraph({
    required String text,
    required TextStyle defaultStyle,
    required TextAlign textAlign,
    required bool isDark,
  }) {
    final inlineSpans = <InlineSpan>[];
    final inlineRegex = RegExp(r'`([^`]+)`');
    int lastIndex = 0;

    for (final match in inlineRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        inlineSpans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: defaultStyle,
          ),
        );
      }

      final inlineCode = match.group(1) ?? '';
      inlineSpans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3.0),
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF475569)
                    : const Color(0xFFCBD5E1),
                width: 0.5,
              ),
            ),
            child: Text(
              inlineCode,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: (defaultStyle.fontSize ?? 16) * 0.9,
                color: isDark
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      inlineSpans.add(
        TextSpan(text: text.substring(lastIndex), style: defaultStyle),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text.rich(TextSpan(children: inlineSpans), textAlign: textAlign),
    );
  }

  /// Hiển thị khối code nhiều dòng (hỗ trợ cuộn ngang)
  /// Giữ nguyên khoảng trắng thụt đầu dòng (indentation) của từng dòng
  Widget _buildCodeBlock({required String code, required bool isDark}) {
    final bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFCBD5E1);
    final textColor = isDark
        ? const Color(0xFF38BDF8)
        : const Color(0xFF0F172A);

    // Chỉ cắt bỏ dòng trống thừa ở đầu/cuối block, giữ nguyên khoảng trắng thụt lề bên trong
    final cleanedCode = code.replaceAll(RegExp(r'^\r?\n+|\r?\n+$'), '');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(14.0),
          physics: const BouncingScrollPhysics(),
          child: Text(
            cleanedCode,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              height: 1.45,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
