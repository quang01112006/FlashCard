import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import '../core/app_theme.dart';
import '../logic/sm2_algorithm.dart';
import '../models/flashcard.dart';
import '../widgets/code_text_view.dart';
import '../widgets/flip_card_widget.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  int _currentIndex = 0;
  bool _isAnswerRevealed = false;
  bool _isSessionInitialized = false;
  List<Flashcard> _sessionCards = [];

  GlobalKey<FlipCardWidgetState> _flipCardKey =
      GlobalKey<FlipCardWidgetState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.watch<CardController>();
    final availableCards = controller.dueCards.isNotEmpty
        ? controller.dueCards
        : controller.cards;

    if (availableCards.isNotEmpty) {
      if (!_isSessionInitialized || _sessionCards.isEmpty) {
        _sessionCards = List.from(availableCards);
        _isSessionInitialized = true;
      }
    } else if (!controller.isLoading) {
      _sessionCards = [];
      _isSessionInitialized = true;
    }
  }

  void _restartSession() {
    final controller = context.read<CardController>();
    final availableCards = controller.dueCards.isNotEmpty
        ? controller.dueCards
        : controller.cards;

    setState(() {
      _sessionCards = List.from(availableCards);
      _currentIndex = 0;
      _isAnswerRevealed = false;
      _flipCardKey = GlobalKey<FlipCardWidgetState>();
    });
  }

  void _revealAnswer() {
    if (!_isAnswerRevealed) {
      _flipCardKey.currentState?.flip();
      setState(() {
        _isAnswerRevealed = true;
      });
    }
  }

  void _onRateCard(ReviewRating rating, Flashcard currentCard) {
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
    context.read<CardController>().updateCard(updatedCard);
    _sessionCards[_currentIndex] = updatedCard;

    // 4. Chuyển sang câu tiếp theo, reset trạng thái lật thẻ
    setState(() {
      _currentIndex++;
      _isAnswerRevealed = false;
      _flipCardKey =
          GlobalKey<
            FlipCardWidgetState
          >(); // Tạo key mới để thẻ câu sau tự động úp về mặt trước
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = context.watch<CardController>();
    final isEnglish = controller.isEnglish;

    // Trạng thái 0: Đang nạp dữ liệu từ storage / json
    if (controller.isLoading && _sessionCards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Học thẻ SM-2')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Trạng thái 1: Không có thẻ nào trong phiên học
    if (_sessionCards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Học thẻ SM-2')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 72, color: theme.hintColor),
                const SizedBox(height: 16),
                const Text(
                  'Chưa có thẻ nào trong phiên học!',
                  style: AppTextStyles.subHeading,
                ),
                const SizedBox(height: 8),
                Text(
                  'Hãy quay lại sau hoặc thêm thẻ mới để bắt đầu học tập.',
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
        appBar: AppBar(title: const Text('Hoàn thành phiên học')),
        body: Center(
          child: Padding(
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
                  'Tuyệt vời!',
                  style: AppTextStyles.heading.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bạn đã hoàn thành phiên ôn tập với ${_sessionCards.length} thẻ.',
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
                  onPressed: _restartSession,
                  icon: const Icon(Icons.replay),
                  label: const Text('Ôn tập lại từ đầu'),
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
        title: Text('Thẻ ${_currentIndex + 1} / ${_sessionCards.length}'),
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
                          tag: 'CÂU HỎI',
                          tagColor: AppColors.primary,
                          content: _getCardFront(currentCard, isEnglish),
                          hint:
                              'Chạm vào thẻ hoặc bấm nút Hiện đáp án bên dưới',
                          backgroundColor: frontBgColor,
                          borderColor: borderColor,
                        ),
                        back: _buildCardContainer(
                          card: currentCard,
                          isBack: true,
                          tag: 'ĐÁP ÁN & GIẢI THÍCH',
                          tagColor: AppColors.secondary,
                          content: _getCardBack(currentCard, isEnglish),
                          hint: 'Chọn mức độ nhớ bên dưới để lên lịch ôn tiếp theo',
                          backgroundColor: backBgColor,
                          borderColor: AppColors.secondary.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (!_isAnswerRevealed)
                _buildShowAnswerButton()
              else
                _buildRatingButtonsRow(currentCard),
            ],
          ),
        ),
      ),
    );
  }

  /// Nút "Hiện đáp án" ở mặt trước
  Widget _buildShowAnswerButton() {
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
        label: const Text(
          'Hiện đáp án',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// 4 nút chấm điểm (Kèm dự báo chu kỳ ngày)
  Widget _buildRatingButtonsRow(Flashcard currentCard) {
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
          label: 'Học lại',
          intervalText: '$againInterval ngày',
          rating: ReviewRating.again,
          color: AppColors.danger,
          currentCard: currentCard,
        ),
        const SizedBox(width: 8),
        _buildRatingButton(
          label: 'Khó',
          intervalText: '$hardInterval ngày',
          rating: ReviewRating.hard,
          color: AppColors.warning,
          currentCard: currentCard,
        ),
        const SizedBox(width: 8),
        _buildRatingButton(
          label: 'Tốt',
          intervalText: '$goodInterval ngày',
          rating: ReviewRating.good,
          color: Colors.blueAccent,
          currentCard: currentCard,
        ),
        const SizedBox(width: 8),
        _buildRatingButton(
          label: 'Dễ',
          intervalText: '$easyInterval ngày',
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
        onPressed: () => _onRateCard(rating, currentCard),
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
  }) {
    final hasTopic = card.topicCode.isNotEmpty;
    final hasLevel = card.level.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      color: backgroundColor,
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Header bên trong thẻ
            Row(
              children: [
                if (hasTopic || hasLevel)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasTopic)
                          Text(
                            card.topicCode,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        if (hasTopic && hasLevel)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '•',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (hasLevel)
                          Text(
                            card.level,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  const SizedBox.shrink(),

                const Spacer(),

                // Tag định danh CÂU HỎI hoặc ĐÁP ÁN
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tagColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBack
                            ? Icons.check_circle_outline
                            : Icons.help_outline,
                        size: 13,
                        color: tagColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tag,
                        style: TextStyle(
                          color: tagColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Nội dung câu hỏi/đáp án
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: CodeTextView(text: content, textAlign: TextAlign.left),
                ),
              ),
            ),

            const SizedBox(height: 8),
            // Gợi ý nhỏ ở chân thẻ
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
    );
  }
}
