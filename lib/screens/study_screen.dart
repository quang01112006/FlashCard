import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import '../core/app_theme.dart';
import '../l10n/app_strings.dart';
import '../logic/sm2_algorithm.dart';
import '../models/flashcard.dart';
import '../widgets/code_text_view.dart';
import '../widgets/flip_card_widget.dart';
import '../services/manage_card_store.dart';

class StudyScreen extends StatefulWidget {
  final String? topicCode; // Tuỳ chọn: truyền mã chủ đề (ví dụ 'K01') để chỉ học riêng chủ đề đó
  final int? cardLimit;

  const StudyScreen({
    super.key,
    this.topicCode,
    this.deckId = 'flutter-default',
    this.cardLimit,
  });
  final String deckId;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  int _currentIndex = 0;
  bool _isAnswerRevealed = false;
  bool _isSessionInitialized = false;
  List<Flashcard> _sessionCards = [];
  bool _isRating = false;
  bool _isRefreshing = false;

  GlobalKey<FlipCardWidgetState> _flipCardKey =
      GlobalKey<FlipCardWidgetState>();

  // Lưu lại trạng thái của thẻ trước khi đánh giá để hỗ trợ tính năng Hoàn tác (Undo) chuẩn Anki
  Flashcard? _lastRatedCard;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSession(context.watch<CardController>());
  }

  @override
  void didUpdateWidget(covariant StudyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topicCode != widget.topicCode ||
        oldWidget.deckId != widget.deckId) {
      _sessionCards = [];
      _currentIndex = 0;
      _isSessionInitialized = false;
      _lastRatedCard = null;
      _syncSession(context.read<CardController>());
      _isAnswerRevealed = false;
      _flipCardKey = GlobalKey<FlipCardWidgetState>();
    }
  }

  void _syncSession(CardController controller) {
    final previousCurrentId = _currentIndex < _sessionCards.length
        ? _sessionCards[_currentIndex].id
        : null;
    // Lọc chủ đề trước khi chọn thẻ đến hạn để không bị ảnh hưởng bởi chủ đề khác.
    final topicCards = controller
        .cardsInDeck(widget.deckId)
        .where(
          (card) =>
              widget.topicCode == null ||
              widget.topicCode!.isEmpty ||
              card.topicCode == widget.topicCode,
        )
        .toList();
    final dueCards = topicCards.where((card) => card.isDueToday).toList();
    final availableCards = dueCards.isNotEmpty ? dueCards : topicCards;
    final live = {for (final card in topicCards) card.id: card};
    if (_lastRatedCard != null && !live.containsKey(_lastRatedCard!.id)) {
      _lastRatedCard = null;
    }

    if (availableCards.isNotEmpty) {
      if (!_isSessionInitialized || _sessionCards.isEmpty) {
        final cardsToTake = widget.cardLimit != null && widget.cardLimit! > 0
            ? availableCards.take(widget.cardLimit!).toList()
            : List<Flashcard>.from(availableCards);
        _sessionCards = cardsToTake;
        _currentIndex = 0;
        _isSessionInitialized = true;
      } else {
        // Đồng bộ nội dung và bỏ thẻ đã xóa, giữ các thẻ đã học trong phiên.
        final knownIds = _sessionCards.map((card) => card.id).toSet();
        final completed = _sessionCards
            .take(_currentIndex)
            .where((card) => live.containsKey(card.id))
            .map((card) => live[card.id]!)
            .toList();
        final pending = _sessionCards
            .skip(_currentIndex)
            .where((card) => live.containsKey(card.id))
            .map((card) => live[card.id]!)
            .toList();
        _sessionCards = [
          ...completed,
          ...availableCards.where((card) => !knownIds.contains(card.id)),
          ...pending,
        ];
        _currentIndex = completed.length;
      }
    } else if (!controller.isLoading) {
      _sessionCards = [];
      _currentIndex = 0;
      _isSessionInitialized = true;
    }
    final currentId = _currentIndex < _sessionCards.length
        ? _sessionCards[_currentIndex].id
        : null;
    if (currentId != previousCurrentId) {
      _isAnswerRevealed = false;
      _flipCardKey = GlobalKey<FlipCardWidgetState>();
    }
  }

  void _restartSession() {
    setState(() {
      _currentIndex = 0;
      _isAnswerRevealed = false;
      _flipCardKey = GlobalKey<FlipCardWidgetState>();
      _lastRatedCard = null;
    });
  }

  Future<void> _refreshSession() async {
    final controller = context.read<CardController>();
    if (_isRefreshing ||
        _isRating ||
        controller.isSaving ||
        controller.isLoading) {
      return;
    }
    setState(() => _isRefreshing = true);
    try {
      await controller.loadDefaultCards(forceReload: true);
      if (!mounted) return;
      if (controller.loadError != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(controller.loadError!)));
        return;
      }
      setState(() {
        _sessionCards = [];
        _currentIndex = 0;
        _isSessionInitialized = false;
        _lastRatedCard = null;
        _isAnswerRevealed = false;
        _flipCardKey = GlobalKey<FlipCardWidgetState>();
        _syncSession(controller);
      });
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  List<Widget> _sessionActions(CardController controller) {
    final busy =
        _isRating ||
        _isRefreshing ||
        controller.isLoading ||
        controller.isSaving;
    return [
      IconButton(
        key: const ValueKey('study_refresh'),
        tooltip: 'Tải lại phiên học',
        icon: _isRefreshing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        onPressed: busy ? null : _refreshSession,
      ),
      if (_sessionCards.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.undo),
          tooltip: 'Hoàn tác câu vừa đánh giá',
          onPressed: busy || _lastRatedCard == null ? null : _undoLastRating,
        ),
    ];
  }

  void _revealAnswer() {
    if (!_isAnswerRevealed) {
      _flipCardKey.currentState?.flip();
      setState(() {
        _isAnswerRevealed = true;
      });
    }
  }

  /// Hoàn tác câu vừa đánh giá
  Future<void> _undoLastRating() async {
    final controller = context.read<CardController>();
    final cardToRestore = _lastRatedCard;
    if (cardToRestore == null ||
        _isRating ||
        _isRefreshing ||
        controller.isLoading ||
        controller.isSaving) {
      return;
    }
    setState(() => _isRating = true);
    try {
      // Controller chỉ khôi phục SM-2, giữ nội dung mới nhất từ tab Bộ thẻ.
      await controller.updateCard(cardToRestore);
      if (!mounted) return;
      final index = _sessionCards.indexWhere(
        (card) => card.id == cardToRestore.id,
      );
      if (index < 0) return;
      setState(() {
        _currentIndex = index;
        _isAnswerRevealed = false;
        _flipCardKey = GlobalKey<FlipCardWidgetState>();
        _lastRatedCard = null;
      });
      final strings = AppStrings(controller.isEnglish);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.undoSuccess),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (mounted) _showSaveError(error);
    } finally {
      if (mounted) setState(() => _isRating = false);
    }
  }

  Future<void> _onRateCard(ReviewRating rating, Flashcard currentCard) async {
    final controller = context.read<CardController>();
    if (_isRating ||
        _isRefreshing ||
        controller.isLoading ||
        controller.isSaving) {
      return;
    }
    setState(() => _isRating = true);
    // 1. Chạy thuật toán SM-2 tính toán chu kỳ mới
    final sm2Result = SM2Algorithm.calculateWithRating(
      currentRepetitions: currentCard.repetitions,
      currentInterval: currentCard.interval,
      currentEaseFactor: currentCard.easeFactor,
      rating: rating,
    );

    // 2. Tạo đối tượng thẻ mới với thông số đã cập nhật
    final updatedCard = currentCard.copyWith(
      repetitions: sm2Result.repetitions,
      interval: sm2Result.interval,
      easeFactor: sm2Result.easeFactor,
      nextReviewDate: sm2Result.nextReviewDate,
    );

    // 3. Cập nhật vào Store chung và danh sách phiên học
    try {
      await controller.updateCard(updatedCard);
      if (!mounted) return;
      final index = _sessionCards.indexWhere(
        (card) => card.id == currentCard.id,
      );
      setState(() {
        if (index >= 0) {
          _lastRatedCard = currentCard;
          _currentIndex = index + 1;
        }
        _isAnswerRevealed = false;
        _flipCardKey = GlobalKey<FlipCardWidgetState>();
      });
    } catch (error) {
      if (!mounted) return;
      _showSaveError(error);
    } finally {
      if (mounted) setState(() => _isRating = false);
    }
  }

  void _showSaveError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is CardOperationException
              ? error.message
              : 'Không thể lưu kết quả ôn tập. Vui lòng thử lại.',
        ),
      ),
    );
  }

  Widget _title(String text, AppStrings strings) {
    final deck = context.read<CardController>().deckById(widget.deckId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          strings.deckName(deck?.name ?? strings.deletedDeck),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _scrollableMessage(Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(child: child),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = context.watch<CardController>();
    final isEnglish = controller.isEnglish;
    final strings = AppStrings(isEnglish);

    // Trạng thái 0: Đang nạp dữ liệu từ storage / json
    if (controller.isLoading && _sessionCards.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: _title(strings.studySm2Title, strings),
          actions: _sessionActions(controller),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Trạng thái 1: Không có thẻ nào trong phiên học
    if (_sessionCards.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: _title(strings.studySm2Title, strings),
          actions: _sessionActions(controller),
        ),
        body: _scrollableMessage(
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.style_outlined,
                    size: 64,
                    color: isDark ? const Color(0xFF818CF8) : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  strings.noCardsInSession,
                  style: AppTextStyles.subHeading,
                ),
                const SizedBox(height: 8),
                Text(
                  strings.noCardsInSessionHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.hintColor),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Trạng thái 2: Đã hoàn thành hết số thẻ trong phiên
    if (_currentIndex >= _sessionCards.length) {
      return Scaffold(
        appBar: AppBar(
          title: _title(strings.sessionCompleted, strings),
          actions: _sessionActions(controller),
        ),
        body: _scrollableMessage(
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 88,
                  color: AppColors.secondary,
                ),
                const SizedBox(height: 20),
                Text(
                  strings.greatJob,
                  style: AppTextStyles.heading.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.completedMessage(_sessionCards.length),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark
                        ? Colors.grey.shade300
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 50),
                  ),
                  onPressed:
                      _isRating ||
                          _isRefreshing ||
                          controller.isLoading ||
                          controller.isSaving
                      ? null
                      : _restartSession,
                  icon: const Icon(Icons.replay),
                  label: Text(strings.restartStudy),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Trạng thái 3: Đang học
    final currentCard = _sessionCards[_currentIndex];
    final progress = (_currentIndex + 1) / _sessionCards.length;

    // Màu nền thích ứng Dark Mode cho mặt thẻ
    final frontBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final backBgColor = isDark
        ? const Color(0xFF0F291E)
        : const Color(0xFFF0FDF4);
    final borderColor = isDark ? const Color(0xFF334155) : AppColors.border;

    return Scaffold(
      appBar: AppBar(
        title: _title(strings.cardProgress(_currentIndex + 1, _sessionCards.length), strings),
        actions: _sessionActions(controller),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: isDark ? Colors.grey.shade800 : AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Thẻ lật 3D với hiệu ứng chồng thẻ bài
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Lớp thẻ thứ 3 (khi còn >= 3 thẻ trong phiên)
                    if (_currentIndex + 2 < _sessionCards.length)
                      Positioned(
                        top: 20,
                        bottom: 0,
                        left: 20,
                        right: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B).withOpacity(0.5)
                                : const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFC7D2FE),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  isDark ? 0.3 : 0.05,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Lớp thẻ thứ 2 (khi còn >= 2 thẻ trong phiên)
                    if (_currentIndex + 1 < _sessionCards.length)
                      Positioned(
                        top: 10,
                        bottom: 11,
                        left: 10,
                        right: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B).withOpacity(0.85)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  isDark ? 0.35 : 0.07,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Thẻ chính đang học trên cùng
                    Positioned(
                      top: 0,
                      bottom: 22,
                      left: 0,
                      right: 0,
                      child: FlipCardWidget(
                        key: _flipCardKey,
                        onFlipChange: (isBack) {
                          setState(() {
                            _isAnswerRevealed = isBack;
                          });
                        },
                        front: _buildCardContainer(
                          card: currentCard,
                          isBack: false,
                          tag: strings.cardTagQuestion,
                          tagColor: AppColors.primary,
                          content: _getCardFront(currentCard, isEnglish),
                          hint: strings.tapCardToFlipHint,
                          backgroundColor: frontBgColor,
                          borderColor: borderColor,
                          strings: strings,
                          isEnglish: isEnglish,
                        ),
                        back: _buildCardContainer(
                          card: currentCard,
                          isBack: true,
                          tag: strings.cardTagAnswer,
                          tagColor: AppColors.secondary,
                          content: _getCardBack(currentCard, isEnglish),
                          hint: strings.rateCardHint,
                          backgroundColor: backBgColor,
                          borderColor: AppColors.secondary.withOpacity(0.4),
                          strings: strings,
                          isEnglish: isEnglish,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (!_isAnswerRevealed)
                _buildShowAnswerButton(strings)
              else
                _buildRatingButtonsRow(currentCard, strings),
            ],
          ),
        ),
      ),
    );
  }

  /// Nút "Hiện đáp án" ở mặt trước
  Widget _buildShowAnswerButton(AppStrings strings) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        onPressed: _revealAnswer,
        icon: const Icon(Icons.visibility_outlined),
        label: Text(
          strings.showAnswer,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// 4 nút chấm điểm (Kèm dự báo chu kỳ ngày)
  Widget _buildRatingButtonsRow(Flashcard currentCard, AppStrings strings) {
    // Dự báo chu kỳ cho từng mức đánh giá bằng SM2Algorithm
    final againInterval = SM2Algorithm.calculateWithRating(
      currentRepetitions: currentCard.repetitions,
      currentInterval: currentCard.interval,
      currentEaseFactor: currentCard.easeFactor,
      rating: ReviewRating.again,
    ).interval;

    final hardInterval = SM2Algorithm.calculateWithRating(
      currentRepetitions: currentCard.repetitions,
      currentInterval: currentCard.interval,
      currentEaseFactor: currentCard.easeFactor,
      rating: ReviewRating.hard,
    ).interval;

    final goodInterval = SM2Algorithm.calculateWithRating(
      currentRepetitions: currentCard.repetitions,
      currentInterval: currentCard.interval,
      currentEaseFactor: currentCard.easeFactor,
      rating: ReviewRating.good,
    ).interval;

    final easyInterval = SM2Algorithm.calculateWithRating(
      currentRepetitions: currentCard.repetitions,
      currentInterval: currentCard.interval,
      currentEaseFactor: currentCard.easeFactor,
      rating: ReviewRating.easy,
    ).interval;

    return Row(
      children: [
        _buildRatingButton(
          label: strings.ratingAgain,
          intervalText: strings.daysCount(againInterval),
          rating: ReviewRating.again,
          color: AppColors.danger,
          currentCard: currentCard,
        ),
        const SizedBox(width: 8),
        _buildRatingButton(
          label: strings.ratingHard,
          intervalText: strings.daysCount(hardInterval),
          rating: ReviewRating.hard,
          color: AppColors.warning,
          currentCard: currentCard,
        ),
        const SizedBox(width: 8),
        _buildRatingButton(
          label: strings.ratingGood,
          intervalText: strings.daysCount(goodInterval),
          rating: ReviewRating.good,
          color: Colors.blueAccent,
          currentCard: currentCard,
        ),
        const SizedBox(width: 8),
        _buildRatingButton(
          label: strings.ratingEasy,
          intervalText: strings.daysCount(easyInterval),
          rating: ReviewRating.easy,
          color: AppColors.secondary,
          currentCard: currentCard,
        ),
      ],
    );
  }

  /// Nút bấm đánh giá
  Widget _buildRatingButton({
    required String label,
    required String intervalText,
    required ReviewRating rating,
    required Color color,
    required Flashcard currentCard,
  }) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed:
            _isRating ||
                _isRefreshing ||
                context.read<CardController>().isLoading ||
                context.read<CardController>().isSaving
            ? null
            : () => _onRateCard(rating, currentCard),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tên mức đánh giá
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 2),
            // Số ngày dự báo cụ thể
            Text(
              intervalText,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCardFront(Flashcard card, bool isEnglish) {
    if (isEnglish && card.frontEn != null && card.frontEn!.isNotEmpty) {
      return card.frontEn!;
    }
    return card.front;
  }

  String _getCardBack(Flashcard card, bool isEnglish) {
    if (isEnglish && card.backEn != null && card.backEn!.isNotEmpty) {
      return card.backEn!;
    }
    return card.back;
  }

  Widget _buildCardContainer({
    required Flashcard card,
    required bool isBack,
    required String tag,
    required Color tagColor,
    required String content,
    required String hint,
    required Color backgroundColor,
    required Color borderColor,
    required AppStrings strings,
    required bool isEnglish,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      color: backgroundColor,
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            key: PageStorageKey(
              'study_content_${card.id}_${isBack ? 'back' : 'front'}',
            ),
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (card.topicCode.isNotEmpty || card.level.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                              children: [
                                if (card.topicCode.isNotEmpty)
                                  TextSpan(
                                    text: card.topicCode,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                if (card.topicCode.isNotEmpty &&
                                    card.level.isNotEmpty)
                                  const TextSpan(text: ' • '),
                                TextSpan(text: strings.levelLabel(card.level)),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tagColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              color: tagColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.3,
                            ),
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(
                                  isBack
                                      ? Icons.check_circle_outline
                                      : Icons.help_outline,
                                  size: 13,
                                  color: tagColor,
                                ),
                              ),
                              TextSpan(
                                text:
                                    ' ${MediaQuery.textScalerOf(context).scale(11) > 16 ? (isBack ? (isEnglish ? 'ANSWER' : 'ĐÁP ÁN') : (isEnglish ? 'QUESTION' : 'CÂU HỎI')) : tag}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: CodeTextView(
                      text: content,
                      textAlign: TextAlign.left,
                    ),
                  ),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
