import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Widget dùng chung để hiển thị nội dung câu hỏi/đáp án
/// Tự động nhận diện văn bản thường, code inline (`code`) và khối code (```code```)
/// Tự động thích ứng Dark Mode / Light Mode
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

    final defaultTextColor =
        isDark ? const Color(0xFFF1F5F9) : AppColors.textPrimary;
    final defaultTextStyle =
        baseStyle ??
        theme.textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.5,
          color: defaultTextColor,
        ) ??
        TextStyle(fontSize: 16, height: 1.5, color: defaultTextColor);

    // Nếu văn bản có chứa khối code ``` thì tự động căn trái để bố cục code thẳng hàng
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
  /// - Khối code ``` -> Hiển thị hộp code cuộn ngang macOS Window Dots
  /// - Văn bản thường & inline code ` -> Hiển thị qua Text.rich
  List<Widget> _buildContentWidgets({
    required BuildContext context,
    required String input,
    required TextStyle defaultStyle,
    required TextAlign textAlign,
    required bool isDark,
  }) {
    final List<Widget> widgets = [];
    if (input.trim().isEmpty) return widgets;

    final blockRegex = RegExp(r'```(?:([a-zA-Z0-9_-]*)\r?\n)?([\s\S]*?)```');
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

      final lang = match.group(1)?.trim() ?? '';
      final codeContent = match.group(2) ?? '';
      widgets.add(_buildCodeBlock(
        code: codeContent,
        language: lang.isNotEmpty ? lang : 'dart',
        isDark: isDark,
      ));

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

  /// Hiển thị đoạn văn bản có chứa inline code `...` cùng dòng mượt mà
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
        _addStyledTextSpans(
          text: text.substring(lastIndex, match.start),
          defaultStyle: defaultStyle,
          isDark: isDark,
          spans: inlineSpans,
        );
      }

      final inlineCode = match.group(1) ?? '';

      if (inlineCode.length > 28) {
        // Nếu chuỗi code inline dài (> 28 ký tự), render bằng TextSpan monospace có màu nền
        // để tự động ngắt dòng mềm mại (word wrap), không bao giờ đẩy rớt dấu câu sang dòng mới
        inlineSpans.add(
          TextSpan(
            text: ' $inlineCode ',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: (defaultStyle.fontSize ?? 16) * 0.9,
              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
              backgroundColor:
                  isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else {
        // Từ khóa ngắn (< 28 ký tự): Giữ nguyên WidgetSpan bo góc đẹp chuẩn Notion/Discord
        inlineSpans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3.0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
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
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      _addStyledTextSpans(
        text: text.substring(lastIndex),
        defaultStyle: defaultStyle,
        isDark: isDark,
        spans: inlineSpans,
      );
    }

    final isExplanation =
        text.trim().startsWith('Giải thích:') ||
        text.trim().startsWith('Explanation:');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isExplanation)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 6.0),
            child: Divider(
              height: 1,
              thickness: 0.8,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text.rich(TextSpan(children: inlineSpans), textAlign: textAlign),
        ),
      ],
    );
  }

  /// Tự động làm đậm và đổi màu nổi bật cho các tiêu đề "Giải thích:" và "Explanation:"
  void _addStyledTextSpans({
    required String text,
    required TextStyle defaultStyle,
    required bool isDark,
    required List<InlineSpan> spans,
  }) {
    final labelRegex = RegExp(r'(Giải thích:|Explanation:)');
    int lastIdx = 0;

    for (final m in labelRegex.allMatches(text)) {
      if (m.start > lastIdx) {
        spans.add(TextSpan(
          text: text.substring(lastIdx, m.start),
          style: defaultStyle,
        ));
      }

      final label = m.group(0)!;
      final labelColor =
          isDark ? const Color(0xFF94A3B8) : AppColors.textPrimary;

      spans.add(TextSpan(
        text: label,
        style: defaultStyle.copyWith(
          fontWeight: FontWeight.bold,
          color: labelColor,
        ),
      ));

      lastIdx = m.end;
    }

    if (lastIdx < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIdx),
        style: defaultStyle,
      ));
    }
  }

  /// Hiển thị khối code nhiều dòng (hỗ trợ cuộn ngang)
  /// Có thanh header 3 chấm macOS (Red, Yellow, Green) chuẩn phong cách IDE
  /// Giữ nguyên khoảng trắng thụt đầu dòng (indentation) của từng dòng
  Widget _buildCodeBlock({
    required String code,
    String language = 'dart',
    required bool isDark,
  }) {
    final bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFCBD5E1);
    final headerBgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final headerBorderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
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
        borderRadius: BorderRadius.circular(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thanh header phong cách macOS IDE Window Dots
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
              decoration: BoxDecoration(
                color: headerBgColor,
                border: Border(
                  bottom: BorderSide(color: headerBorderColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  _buildMacDot(const Color(0xFFFF5F56)),
                  const SizedBox(width: 6),
                  _buildMacDot(const Color(0xFFFFBD2E)),
                  const SizedBox(width: 6),
                  _buildMacDot(const Color(0xFF27C93F)),
                  const Spacer(),
                  Text(
                    language,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Khối code cuộn ngang
            SingleChildScrollView(
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
          ],
        ),
      ),
    );
  }

  Widget _buildMacDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
