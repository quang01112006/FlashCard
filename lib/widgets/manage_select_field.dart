import 'dart:math' as math;

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

import 'manage_motion.dart';

/// Ô chọn thống nhất cho quản lý thẻ và chọn bộ học.
class ManageSelectField<T> extends StatelessWidget {
  const ManageSelectField({
    super.key,
    required this.items,
    required this.onChanged,
    required this.decoration,
    this.initialValue,
    this.validator,
    this.searchableSheet = false,
    this.isEnglish = false,
    this.subtitle,
  });

  // Giữ nhãn tách khỏi ID: tên bộ có thể trùng nội dung hoặc được đổi tên.
  final List<DropdownMenuItem<T>> items;
  final T? initialValue;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final FormFieldValidator<T>? validator;
  final bool searchableSheet;
  final bool isEnglish;
  final String? Function(T)? subtitle;

  String _label(T value) {
    for (final item in items) {
      if (item.value == value && item.child is Text) {
        final text = item.child as Text;
        return text.data ?? text.textSpan?.toPlainText() ?? '';
      }
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) => searchableSheet
      ? _build(context, MediaQuery.sizeOf(context).width)
      : LayoutBuilder(builder: (context, box) => _build(context, box.maxWidth));

  Widget _build(BuildContext context, double width) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    Widget row(BuildContext context, T item, bool disabled, bool selected) =>
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label(item),
                      maxLines: searchableSheet ? null : 2,
                      overflow: searchableSheet ? null : TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: selected
                            ? colors.onPrimaryContainer
                            : colors.onSurface,
                      ),
                    ),
                    if (subtitle?.call(item) case final String description) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 24,
                child: selected
                    ? Icon(Icons.check_rounded, color: colors.primary)
                    : null,
              ),
            ],
          ),
        );
    Widget empty(BuildContext context, String search) => Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        isEnglish ? 'No matching results.' : 'Không tìm thấy kết quả phù hợp.',
      ),
    );
    final popup = searchableSheet
        ? PopupProps<T>.modalBottomSheet(
            showSearchBox: true,
            showSelectedItems: true,
            searchDelay: Duration.zero,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .7,
            ),
            modalBottomSheetProps: ModalBottomSheetProps(
              sheetAnimationStyle: ManageMotion.style(context),
              backgroundColor: colors.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              clipBehavior: Clip.antiAlias,
              showDragHandle: true,
            ),
            title: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      decoration.labelText ?? '',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: isEnglish ? 'Close' : 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: isEnglish ? 'Search…' : 'Tìm kiếm…',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            itemBuilder: row,
            emptyBuilder: empty,
          )
        : PopupProps<T>.menu(
            fit: FlexFit.loose,
            showSelectedItems: true,
            constraints: BoxConstraints(
              maxWidth: width,
              maxHeight: math.min(320, MediaQuery.sizeOf(context).height * .45),
            ),
            menuProps: MenuProps(
              popUpAnimationStyle: ManageMotion.style(context),
              align: MenuAlign.bottomStart,
              margin: const EdgeInsets.only(top: 6),
              shape: shape,
              backgroundColor: colors.surface,
              elevation: 4,
              clipBehavior: Clip.antiAlias,
            ),
            itemBuilder: row,
            emptyBuilder: empty,
          );
    return DropdownSearch<T>(
      selectedItem: initialValue,
      enabled: onChanged != null,
      items: (_, _) => items.map((item) => item.value).whereType<T>().toList(),
      itemAsString: _label,
      compareFn: (a, b) => a == b,
      validator: validator,
      onChanged: onChanged,
      popupProps: popup,
      onBeforePopupOpening: (_) async {
        FocusScope.of(context).unfocus();
        return true;
      },
      decoratorProps: DropDownDecoratorProps(
        decoration: decoration.copyWith(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
      suffixProps: const DropdownSuffixProps(
        dropdownButtonProps: DropdownButtonProps(
          iconClosed: Icon(Icons.keyboard_arrow_down_rounded),
          iconOpened: Icon(Icons.keyboard_arrow_up_rounded),
        ),
      ),
      dropdownBuilder: (context, item) => Text(
        item == null ? '' : _label(item),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge,
      ),
    );
  }
}
