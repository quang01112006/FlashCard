import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import '../core/app_theme.dart';
import '../models/flashcard.dart';
import '../services/manage_card_filter.dart';
import '../services/manage_card_search.dart';
import '../widgets/manage_card_filters_sheet.dart';

class ManageCardsScreen extends StatefulWidget {
  const ManageCardsScreen({super.key});

  @override
  State<ManageCardsScreen> createState() => _ManageCardsScreenState();
}

class _ManageCardsScreenState extends State<ManageCardsScreen> {
  final _searchController = TextEditingController();
  final _listController = ScrollController();
  String _query = '';
  ManageCardFilter _filter = const ManageCardFilter();

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    if (_listController.hasClients) _listController.jumpTo(0);
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  Future<void> _openFilters() async {
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<ManageCardFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ManageCardFiltersSheet(initialFilter: _filter),
    );
    if (!mounted || selected == null) return;
    setState(() => _filter = selected);
    if (_listController.hasClients) _listController.jumpTo(0);
  }

  void _resetSearchAndFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _filter = const ManageCardFilter();
    });
    if (_listController.hasClients) _listController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CardController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Bộ thẻ')),
      body: SafeArea(child: _buildBody(controller)),
    );
  }

  Widget _buildBody(CardController controller) {
    if (controller.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(semanticsLabel: 'Đang tải bộ thẻ'),
            SizedBox(height: 16),
            Text('Đang tải bộ thẻ...', style: AppTextStyles.body),
          ],
        ),
      );
    }

    if (controller.loadError != null) {
      return _ManageCardsMessage(
        icon: Icons.error_outline,
        title: 'Chưa tải được bộ thẻ',
        message: controller.loadError!,
        actionLabel: 'Thử lại',
        onAction: controller.loadDefaultCards,
      );
    }

    final cards = controller.cards;
    if (cards.isEmpty) {
      return _ManageCardsMessage(
        icon: Icons.style_outlined,
        title: 'Chưa có thẻ nào',
        message: 'Bạn có thể tải lại để kiểm tra dữ liệu bộ thẻ.',
        actionLabel: 'Tải lại',
        onAction: controller.loadDefaultCards,
      );
    }

    final results = ManageCardSearch.search(_filter.apply(cards), _query);
    final isSearching = _query.trim().isNotEmpty;
    final hasCriteria = isSearching || _filter.isActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            textInputAction: TextInputAction.search,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              labelText: 'Tìm kiếm thẻ',
              hintText: 'Câu hỏi, đáp án hoặc mã thẻ',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa từ khóa',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    hasCriteria
                        ? '${results.length} / ${cards.length} thẻ'
                        : '${cards.length} thẻ',
                    style: AppTextStyles.subHeading,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _openFilters,
                    icon: const Icon(Icons.filter_list),
                    label: Text(
                      _filter.isActive
                          ? 'Bộ lọc (${_filter.activeCount})'
                          : 'Bộ lọc',
                    ),
                  ),
                ],
              ),
              if (_filter.isActive) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    _filter.topicCode,
                    _filter.level,
                  ].whereType<String>().join(' • '),
                  style: AppTextStyles.caption,
                ),
              ],
              const SizedBox(height: 4),
              const Text(
                'Chạm vào thẻ để xem đáp án và giải thích.',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? _ManageCardsMessage(
                  icon: Icons.search_off,
                  title: 'Không tìm thấy thẻ',
                  message: 'Thử đổi điều kiện hoặc xóa điều kiện để xem toàn bộ thẻ.',
                  actionLabel: _filter.isActive
                      ? (isSearching ? 'Xóa tìm kiếm và bộ lọc' : 'Xóa bộ lọc')
                      : 'Xóa tìm kiếm',
                  onAction: _resetSearchAndFilters,
                )
              : ListView.builder(
                  key: const PageStorageKey('manage_cards_list'),
                  controller: _listController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: results.length,
                  itemBuilder: (context, index) => _ManageCardItem(
                    key: ValueKey(results[index].id),
                    card: results[index],
                  ),
                ),
        ),
      ],
    );
  }
}

class _ManageCardItem extends StatelessWidget {
  const _ManageCardItem({super.key, required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey('manage_card_${card.id}'),
        tilePadding: const EdgeInsets.all(16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(card.front, style: AppTextStyles.body),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            [
              card.id,
              card.topicCode,
              card.level,
            ].where((value) => value.isNotEmpty).join(' • '),
            style: AppTextStyles.caption,
          ),
        ),
        children: [
          const Divider(color: AppColors.border),
          const Text('Đáp án & giải thích', style: AppTextStyles.subHeading),
          const SizedBox(height: 8),
          SelectableText(
            card.back,
            key: PageStorageKey('manage_answer_${card.id}'),
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}

class _ManageCardsMessage extends StatelessWidget {
  const _ManageCardsMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.subHeading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
