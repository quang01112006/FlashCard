import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import '../core/app_theme.dart';
import '../l10n/app_strings.dart';
import '../models/flashcard.dart';
import 'study_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onNavigateToStudy;
  final ValueChanged<String>? onStudyDeck;
  final VoidCallback? onNavigateToDecks;

  const HomeScreen({
    super.key,
    this.onNavigateToStudy,
    this.onStudyDeck,
    this.onNavigateToDecks,
  });

  void _startStudy(BuildContext context, {String? deckId}) {
    if (deckId != null && onStudyDeck != null) {
      onStudyDeck!(deckId);
      return;
    }
    if (onNavigateToStudy != null) {
      onNavigateToStudy!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => deckId != null
            ? StudyScreen(deckId: deckId)
            : const StudyScreen(),
      ),
    );
  }

  String _getGreeting(AppStrings strings) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return strings.greetingMorning;
    } else if (hour < 18) {
      return strings.greetingAfternoon;
    } else {
      return strings.greetingEvening;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = context.watch<CardController>();
    final strings = AppStrings(controller.isEnglish);

    final totalCards = controller.cards;
    final newCards = totalCards.where((c) => c.repetitions == 0).toList();
    final reviewCards = totalCards.where((c) => c.repetitions > 0 && c.isDueToday).toList();
    final studiedCards = totalCards.where((c) => c.repetitions > 0).toList();

    final streak = controller.streak;

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
                    // ==========================================
                    // KHỐI 1: HEADER + HUY HIỆU STREAK
                    // ==========================================
                    _buildHeaderAndStreak(context, isDark, strings, streak),
                    const SizedBox(height: 16),

                    // ==========================================
                    // KHỐI 2: BẢNG 3 CHỈ SỐ + NÚT CTA CHÍNH
                    // ==========================================
                    _buildStatsAndCta(context, isDark, strings, reviewCards, studiedCards, newCards),
                    const SizedBox(height: 20),

                    // ==========================================
                    // KHỐI 3: BIỂU ĐỒ PHÂN BỔ MỨC ĐỘ GHI NHỚ SM-2
                    // ==========================================
                    _buildSm2RetentionChart(context, isDark, strings, totalCards),
                    const SizedBox(height: 20),

                    // ==========================================
                    // KHỐI 4: THẺ "TIẾP TỤC HỌC THEO BỘ"
                    // ==========================================
                    _buildContinueStudyingDecks(context, isDark, strings, controller),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // ==========================================
  // KHỐI 1: Header + Huy hiệu Streak
  // ==========================================
  Widget _buildHeaderAndStreak(BuildContext context, bool isDark, AppStrings strings, int streak) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(strings),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                strings.greetingSub,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade400 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Huy hiệu Streak chuỗi ngày học. Flexible để chữ lớn trên màn hẹp không đẩy hàng tràn.
        Flexible(
          child: Tooltip(
            message: strings.streakHint,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF7C2D12), const Color(0xFF431407)]
                      : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFFEA580C) : const Color(0xFFFDBA74),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEA580C).withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFEA580C),
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      strings.streakDays(streak),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // KHỐI 2: Bảng 3 chỉ số + Nút CTA chính
  // ==========================================
  Widget _buildStatsAndCta(
    BuildContext context,
    bool isDark,
    AppStrings strings,
    List<Flashcard> reviewCards,
    List<Flashcard> studiedCards,
    List<Flashcard> newCards,
  ) {
    final theme = Theme.of(context);
    final reviewCount = reviewCards.length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Bảng 3 chỉ số phản ánh tiến độ học tập thực tế
            Row(
              children: [
                Expanded(
                  child: _buildStatColumn(
                    label: strings.statNew,
                    value: '${newCards.length}',
                    color: const Color(0xFF2563EB),
                    icon: Icons.fiber_new_rounded,
                  ),
                ),
                Container(width: 1, height: 44, color: theme.dividerColor),
                Expanded(
                  child: _buildStatColumn(
                    label: strings.statReview,
                    value: '$reviewCount',
                    color: reviewCount > 0
                        ? const Color(0xFFEA580C)
                        : (isDark ? Colors.grey.shade400 : AppColors.textSecondary),
                    icon: Icons.schedule_rounded,
                  ),
                ),
                Container(width: 1, height: 44, color: theme.dividerColor),
                Expanded(
                  child: _buildStatColumn(
                    label: strings.statStudied,
                    value: '${studiedCards.length}',
                    color: const Color(0xFF16A34A),
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Nút CTA to chính "Bắt đầu ôn tập hôm nay"
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                key: const ValueKey('home_start_study_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _startStudy(context),
                icon: const Icon(Icons.play_arrow_rounded, size: 26),
                label: Text(
                  reviewCount > 0
                      ? '${strings.startReview} ($reviewCount)'
                      : (newCards.isNotEmpty
                          ? strings.studyNewToday(math.min(20, newCards.length))
                          : strings.allDoneToday),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ==========================================
  // KHỐI 3: Biểu đồ cột phân bổ mức độ ghi nhớ SM-2
  // ==========================================
  Widget _buildSm2RetentionChart(
    BuildContext context,
    bool isDark,
    AppStrings strings,
    List<Flashcard> cards,
  ) {
    final total = cards.length;

    // Phân loại thẻ theo chu kỳ interval SM-2
    final countNew = cards.where((c) => c.repetitions == 0).length;
    final countLearning = cards.where((c) => c.repetitions > 0 && c.interval < 7).length;
    final countRetained = cards.where((c) => c.interval >= 7 && c.interval <= 20).length;
    final countMastered = cards.where((c) => c.interval > 20).length;

    final maxVal = math.max(1, [countNew, countLearning, countRetained, countMastered].reduce(math.max));

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_graph_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.retentionTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              strings.retentionSub,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),

            // Các cột biểu đồ
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildChartBar(
                    label: strings.levelNew,
                    sub: '0d',
                    count: countNew,
                    maxVal: maxVal,
                    total: total,
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                  ),
                  _buildChartBar(
                    label: strings.levelLearning,
                    sub: '1–6d',
                    count: countLearning,
                    maxVal: maxVal,
                    total: total,
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
                  _buildChartBar(
                    label: strings.levelRetained,
                    sub: '7–20d',
                    count: countRetained,
                    maxVal: maxVal,
                    total: total,
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                  ),
                  _buildChartBar(
                    label: strings.levelMastered,
                    sub: '>20d',
                    count: countMastered,
                    maxVal: maxVal,
                    total: total,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartBar({
    required String label,
    required String sub,
    required int count,
    required int maxVal,
    required int total,
    required Color color,
    required bool isDark,
  }) {
    final double barHeight = math.max(6.0, (count / maxVal) * 64.0);

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Con số trên đầu cột
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: count > 0 ? color : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            ),
          ),
          const SizedBox(height: 4),

          // Vùng thanh biểu đồ (căn đáy)
          SizedBox(
            height: 68,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: barHeight,
                width: 26,
                decoration: BoxDecoration(
                  color: count > 0 ? color : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Nhãn cột
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Chu kỳ ngày SM-2 (0d, 1-6d, 7-20d, >20d)
          Text(
            sub,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // KHỐI 4: Thẻ "Tiếp tục học theo bộ"
  // ==========================================
  Widget _buildContinueStudyingDecks(
    BuildContext context,
    bool isDark,
    AppStrings strings,
    CardController controller,
  ) {
    final decks = controller.decks;

    if (decks.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.collections_bookmark_outlined,
                  size: 40,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  strings.noDecksYet,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Sắp xếp các bộ thẻ: Bộ nào có thẻ cần ôn (due) đưa lên trước
    final sortedDecks = List.of(decks)..sort((a, b) {
      final aDue = controller.cardsInDeck(a.id).where((c) => c.isDueToday).length;
      final bDue = controller.cardsInDeck(b.id).where((c) => c.isDueToday).length;
      return bDue.compareTo(aDue);
    });

    final previewDecks = sortedDecks.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.school_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                strings.continueStudying,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            if (decks.length > 3 && onNavigateToDecks != null)
              Flexible(
                child: TextButton(
                  onPressed: onNavigateToDecks,
                  child: Text(
                    strings.viewAllDecks,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Danh sách 1 - 3 thẻ bộ học
        ...previewDecks.map((deck) {
          final deckCards = controller.cardsInDeck(deck.id);
          final dueInDeck = deckCards.where((c) => c.isDueToday).length;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark ? const Color(0xFF334155) : AppColors.border,
                width: 0.8,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: dueInDeck > 0
                      ? (isDark ? const Color(0xFF7C2D12).withOpacity(0.5) : const Color(0xFFFFF7ED))
                      : (isDark ? const Color(0xFF064E3B).withOpacity(0.5) : const Color(0xFFF0FDF4)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.collections_bookmark_rounded,
                  color: dueInDeck > 0 ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                  size: 22,
                ),
              ),
              title: Text(
                deck.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                dueInDeck > 0
                    ? strings.dueInDeckCount(dueInDeck)
                    : '${deckCards.length} ${strings.cardsCount(deckCards.length).split(' ').last} • ${strings.allCaughtUpInDeck}',
                style: TextStyle(
                  fontSize: 12,
                  color: dueInDeck > 0
                      ? const Color(0xFFEA580C)
                      : (isDark ? Colors.grey.shade400 : AppColors.textSecondary),
                  fontWeight: dueInDeck > 0 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: dueInDeck > 0 ? AppColors.primary : (isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                  foregroundColor: dueInDeck > 0 ? Colors.white : (isDark ? Colors.grey.shade200 : AppColors.textPrimary),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _startStudy(context, deckId: deck.id),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.studyNow,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 14),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
