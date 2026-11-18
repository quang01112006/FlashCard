import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import '../core/app_theme.dart';
import '../l10n/app_strings.dart';
import '../models/flashcard.dart';
import '../widgets/code_text_view.dart';
import 'study_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToStudy;

  const HomeScreen({
    super.key,
    this.onNavigateToStudy,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedTopic = 'ALL';
  int _previewLimit = 5;

  static const int _dailyNewCardsLimit = 20;

  void _startStudy({String? topicCode, int? limit}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudyScreen(topicCode: topicCode, cardLimit: limit),
      ),
    );
  }

  void _showCardPreview(BuildContext context, Flashcard card, bool isDark, AppStrings strings, bool isEnglish) {
    final questionText =
        isEnglish && card.frontEn != null && card.frontEn!.trim().isNotEmpty
            ? card.frontEn!
            : card.front;
    final answerText =
        isEnglish && card.backEn != null && card.backEn!.trim().isNotEmpty
            ? card.backEn!
            : card.back;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final bottomPadding = MediaQuery.of(ctx).padding.bottom;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: bottomInset > 0 ? bottomInset + 16 : bottomPadding + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF312E81) : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          card.topicCode.isNotEmpty ? card.topicCode : 'Chung',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFA5B4FC) : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          card.level,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade300 : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _buildCardStatusBadge(card, strings),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.questionLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CodeTextView(
                    text: questionText,
                    baseStyle: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.answerLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : AppColors.border,
                      ),
                    ),
                    child: CodeTextView(
                      text: answerText,
                      baseStyle: AppTextStyles.body.copyWith(
                        color: isDark ? Colors.grey.shade200 : AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.school, size: 18),
                    label: Text(strings.studyTopicAction(card.topicCode)),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _startStudy(topicCode: card.topicCode);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardStatusBadge(Flashcard card, AppStrings strings) {
    if (card.repetitions == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fiber_new_rounded, size: 15, color: Colors.blue),
            const SizedBox(width: 4),
            Text(
              strings.newCardBadge,
              style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    } else if (card.isDueToday) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule, size: 14, color: Colors.amber),
            const SizedBox(width: 4),
            Text(
              strings.dueTodayBadge,
              style: const TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
            const SizedBox(width: 4),
            Text(
              strings.reviewedBadge(card.interval),
              style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = context.watch<CardController>();
    final strings = AppStrings(controller.isEnglish);
    final isEnglish = controller.isEnglish;

    final Set<String> existingTopicCodes = {};
    for (final card in controller.cards) {
      final code = card.topicCode.trim();
      if (code.isNotEmpty) {
        existingTopicCodes.add(code);
      }
    }
    final sortedTopics = existingTopicCodes.toList()..sort();
    final allTopics = ['ALL', ...sortedTopics];

    final currentSelectedTopic = allTopics.contains(_selectedTopic) ? _selectedTopic : 'ALL';

    final totalCards = controller.cards;
    final newCards = totalCards.where((c) => c.repetitions == 0).toList();
    final reviewCards = totalCards.where((c) => c.repetitions > 0 && c.isDueToday).toList();
    final masteredCards = totalCards.where((c) => c.repetitions >= 3 && c.interval >= 6).toList();

    final todayNewCards = newCards.take(_dailyNewCardsLimit).toList();

    final List<Flashcard> allDisplayCards;
    final String listSectionTitle;

    if (currentSelectedTopic == 'ALL') {
      if (reviewCards.isNotEmpty) {
        allDisplayCards = [...reviewCards, ...todayNewCards];
        listSectionTitle = strings.todayGoalTitle(reviewCards.length, todayNewCards.length);
      } else if (todayNewCards.isNotEmpty) {
        allDisplayCards = todayNewCards;
        listSectionTitle = strings.todayNewTitle(todayNewCards.length);
      } else {
        allDisplayCards = [];
        listSectionTitle = strings.homeTitle;
      }
    } else {
      allDisplayCards = controller.getCardsByTopic(currentSelectedTopic);
      listSectionTitle = strings.topicCardsCount(currentSelectedTopic, allDisplayCards.length);
    }

    final visibleCards = allDisplayCards.take(_previewLimit).toList();

    final String studyButtonLabel;
    if (reviewCards.isNotEmpty) {
      studyButtonLabel = strings.studyDueAndNew(reviewCards.length, todayNewCards.length);
    } else if (todayNewCards.isNotEmpty) {
      studyButtonLabel = strings.studyNewToday(todayNewCards.length);
    } else {
      studyButtonLabel = strings.allDoneToday;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.homeTitle),
        centerTitle: false,
      ),
      body: controller.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: () => controller.loadDefaultCards(forceReload: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _statItem(
                                label: strings.statNew,
                                value: '${newCards.length}',
                                color: const Color(0xFF2563EB),
                                icon: Icons.fiber_new_rounded,
                              ),
                            ),
                            Container(width: 1, height: 44, color: theme.dividerColor),
                            Expanded(
                              child: _statItem(
                                label: strings.statReview,
                                value: '${reviewCards.length}',
                                color: reviewCards.isNotEmpty ? AppColors.warning : AppColors.secondary,
                                icon: Icons.schedule_rounded,
                              ),
                            ),
                            Container(width: 1, height: 44, color: theme.dividerColor),
                            Expanded(
                              child: _statItem(
                                label: strings.statMastered,
                                value: '${masteredCards.length}',
                                color: AppColors.secondary,
                                icon: Icons.verified_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: reviewCards.isNotEmpty || todayNewCards.isNotEmpty
                              ? AppColors.primary
                              : AppColors.secondary,
                          foregroundColor: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          reviewCards.isNotEmpty || todayNewCards.isNotEmpty
                              ? Icons.play_arrow_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 22,
                        ),
                        label: Text(
                          studyButtonLabel,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        onPressed: totalCards.isEmpty
                            ? null
                            : () {
                                if (currentSelectedTopic != 'ALL') {
                                  _startStudy(topicCode: currentSelectedTopic);
                                } else {
                                  final targetCount = reviewCards.length + todayNewCards.length;
                                  _startStudy(limit: targetCount > 0 ? targetCount : null);
                                }
                              },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            strings.knowledgeTopics,
                            style: AppTextStyles.subHeading,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          strings.topicsCount(sortedTopics.length),
                          style: AppTextStyles.caption.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: allTopics.length,
                        itemBuilder: (context, index) {
                          final topic = allTopics[index];
                          final isSelected = currentSelectedTopic == topic;

                          final count = topic == 'ALL'
                              ? totalCards.length
                              : controller.cards.where((c) => c.topicCode == topic).length;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                topic == 'ALL' ? '${strings.allTopics} ($count)' : '$topic ($count)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.grey.shade300 : AppColors.textPrimary),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? const Color(0xFF334155) : AppColors.border),
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _selectedTopic = topic;
                                  _previewLimit = 5;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            listSectionTitle,
                            style: AppTextStyles.subHeading.copyWith(fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (currentSelectedTopic != 'ALL' && allDisplayCards.isNotEmpty)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            icon: const Icon(Icons.school_outlined, size: 16),
                            label: Text(
                              strings.studyThisTopic,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () => _startStudy(topicCode: currentSelectedTopic),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (allDisplayCards.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : AppColors.border,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              currentSelectedTopic == 'ALL'
                                  ? Icons.verified_outlined
                                  : Icons.inbox_outlined,
                              size: 44,
                              color: currentSelectedTopic == 'ALL'
                                  ? AppColors.secondary
                                  : theme.hintColor,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              currentSelectedTopic == 'ALL'
                                  ? strings.allDoneMessage
                                  : strings.noCardsInTopic(currentSelectedTopic),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.grey.shade300 : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentSelectedTopic == 'ALL'
                                  ? strings.customStudyHint
                                  : strings.chooseOtherTopic,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: visibleCards.length,
                        itemBuilder: (context, index) {
                          final card = visibleCards[index];
                          final question =
                              isEnglish && card.frontEn != null && card.frontEn!.trim().isNotEmpty
                                  ? card.frontEn!
                                  : card.front;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0.8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isDark ? const Color(0xFF334155) : AppColors.border,
                                width: 0.8,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _showCardPreview(context, card, isDark, strings, isEnglish),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      constraints: const BoxConstraints(minWidth: 46),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF312E81) : AppColors.primaryLight,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        card.topicCode.isNotEmpty ? card.topicCode : 'Chung',
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? const Color(0xFFA5B4FC) : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            question,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.body.copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: isDark ? Colors.white : AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  card.level,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark ? Colors.grey.shade300 : AppColors.textSecondary,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                card.repetitions == 0
                                                    ? strings.notStudied
                                                    : strings.repIntervalInfo(card.repetitions, card.interval),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: theme.hintColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildCardTrailingIcon(card, strings),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (allDisplayCards.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 12),
                          child: Row(
                            children: [
                              if (allDisplayCards.length > _previewLimit)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isDark ? Colors.grey.shade200 : AppColors.primary,
                                      side: BorderSide(
                                        color: isDark ? const Color(0xFF334155) : AppColors.border,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: const Icon(Icons.expand_more, size: 18),
                                    label: Text(
                                      '${strings.seeMore} (${visibleCards.length} / ${allDisplayCards.length})',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _previewLimit += 10;
                                      });
                                    },
                                  ),
                                ),
                              if (_previewLimit > 5) ...[
                                const SizedBox(width: 8),
                                IconButton.outlined(
                                  tooltip: strings.collapse,
                                  style: IconButton.styleFrom(
                                    side: BorderSide(
                                      color: isDark ? const Color(0xFF334155) : AppColors.border,
                                    ),
                                  ),
                                  icon: const Icon(Icons.expand_less, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _previewLimit = 5;
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCardTrailingIcon(Flashcard card, AppStrings strings) {
    if (card.repetitions == 0) {
      return Tooltip(
        message: strings.newCardBadge,
        child: const Icon(Icons.fiber_new_rounded, size: 20, color: Color(0xFF2563EB)),
      );
    } else if (card.isDueToday) {
      return Tooltip(
        message: strings.dueTodayBadge,
        child: const Icon(Icons.schedule_rounded, size: 20, color: AppColors.warning),
      );
    } else {
      return Tooltip(
        message: strings.reviewedBadge(card.interval),
        child: const Icon(Icons.check_circle_outline_rounded, size: 20, color: AppColors.secondary),
      );
    }
  }

  Widget _statItem({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: AppTextStyles.heading.copyWith(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }
}
