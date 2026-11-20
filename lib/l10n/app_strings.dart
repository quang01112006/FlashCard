class AppStrings {
  final bool isEnglish;

  const AppStrings(this.isEnglish);

  // General
  String get appName => 'FlashCard SM-2';
  String get settings => isEnglish ? 'Settings' : 'Cài đặt';
  String get cancel => isEnglish ? 'Cancel' : 'Hủy';
  String get save => isEnglish ? 'Save' : 'Lưu';
  String get confirm => isEnglish ? 'Confirm' : 'Xác nhận';

  // Navigation
  String get navHome => isEnglish ? 'Home' : 'Trang chủ';
  String get navStudy => isEnglish ? 'Study' : 'Học thẻ';
  String get navDecks => isEnglish ? 'Decks' : 'Bộ thẻ';
  String get navSettings => isEnglish ? 'Settings' : 'Cài đặt';

  // Language
  String get language => isEnglish ? 'Language' : 'Ngôn ngữ';
  String get languageDescription =>
      isEnglish ? 'Choose your preferred language' : 'Chọn ngôn ngữ sử dụng';
  String get vietnamese => 'Tiếng Việt';
  String get english => 'English';

  // Appearance
  String get appearance => isEnglish ? 'Appearance' : 'Giao diện';
  String get darkMode => isEnglish ? 'Dark mode' : 'Chế độ tối';
  String get darkModeDescription =>
      isEnglish ? 'Use a dark interface' : 'Sử dụng giao diện nền tối';
  String get lightMode => isEnglish ? 'Light mode' : 'Chế độ sáng';

  // Notifications
  String get notification => isEnglish ? 'Notifications' : 'Thông báo';
  String get dailyReminder =>
      isEnglish ? 'Daily study reminder' : 'Nhắc nhở ôn tập hằng ngày';
  String get dailyReminderDescription => isEnglish
      ? 'Receive a reminder to review your flashcards every day'
      : 'Nhận thông báo nhắc bạn ôn tập thẻ mỗi ngày';
  String get reminderTime => isEnglish ? 'Reminder time' : 'Thời gian nhắc nhở';
  String get reminderTimeDescription => isEnglish
      ? 'Tap to choose your reminder time'
      : 'Chạm để chọn giờ nhắc nhở';
  String get notificationEnabled =>
      isEnglish ? 'Daily reminder enabled' : 'Đã bật nhắc nhở hằng ngày';
  String get notificationDisabled =>
      isEnglish ? 'Daily reminder disabled' : 'Đã tắt nhắc nhở hằng ngày';
  String reminderSetAt(String time) => isEnglish
      ? 'Reminder scheduled for $time'
      : 'Đã hẹn giờ nhắc nhở vào lúc $time';
  String get notificationPermissionDenied => isEnglish
      ? 'Notification permission was not granted. Reminders remain disabled.'
      : 'Bạn chưa cấp quyền thông báo. Nhắc nhở vẫn đang tắt.';

  String get notificationScheduleFailed => isEnglish
      ? 'Could not schedule the reminder. Please check notification permissions.'
      : 'Không thể đặt lịch nhắc nhở. Vui lòng kiểm tra quyền thông báo.';

  String get reminderNotificationTitle =>
      isEnglish ? 'Flashcard study reminder' : 'Nhắc nhở học Flashcard';

  String get reminderNotificationBody => isEnglish
      ? 'It is time to review your flashcards. Spend five minutes learning today!'
      : 'Đã đến giờ ôn tập thẻ hôm nay rồi! Hãy dành 5 phút nhé.';

  String get reminderChannelName =>
      isEnglish ? 'Daily study reminder' : 'Nhắc nhở học tập';

  String get reminderChannelDescription => isEnglish
      ? 'Daily reminder to review your Flashcard SM-2 cards'
      : 'Thông báo nhắc nhở ôn tập thẻ Flashcard SM-2 hằng ngày';

  // Reset data
  String get resetData =>
      isEnglish ? 'Reset original data' : 'Khôi phục dữ liệu gốc';
  String get resetDataDescription => isEnglish
      ? 'Restore the original 300 flashcards'
      : 'Khôi phục 300 thẻ Flashcard ban đầu';
  String get resetConfirmationTitle =>
      isEnglish ? 'Reset data?' : 'Khôi phục dữ liệu?';
  String get resetConfirmationMessage => isEnglish
      ? 'Your flashcards will be restored to the original dataset. Custom cards may be reset.'
      : 'Dữ liệu thẻ sẽ được khôi phục về bộ dữ liệu ban đầu 300 câu hỏi.';
  String get resetSuccess =>
      isEnglish ? 'Data restored successfully' : 'Khôi phục dữ liệu thành công';
  String get resetFailed => isEnglish
      ? 'Could not restore the original data. Please try again.'
      : 'Không thể khôi phục dữ liệu gốc. Vui lòng thử lại.';

  // Home Screen
  String get homeTitle => isEnglish ? 'Home' : 'Trang chủ';
  String get statNew => isEnglish ? 'New' : 'Thẻ mới';
  String get statReview => isEnglish ? 'Due review' : 'Cần ôn lại';
  String get statMastered => isEnglish ? 'Mastered' : 'Đã thuộc';
  String get statTotal => isEnglish ? 'Total' : 'Tổng số';
  String get knowledgeTopics =>
      isEnglish ? 'Knowledge topics' : 'Khối kiến thức';
  String topicsCount(int count) =>
      isEnglish ? '$count topics' : '$count chủ đề';
  String get allTopics => isEnglish ? 'All' : 'Tất cả';
  String get startReview => isEnglish ? 'Start review' : 'Bắt đầu ôn tập';
  String studyNewToday(int n) =>
      isEnglish ? 'Study $n new cards today' : 'Học $n thẻ mới hôm nay';
  String studyDueAndNew(int due, int n) => isEnglish
      ? 'Review ($due due + $n new)'
      : 'Bắt đầu ôn tập ($due ôn lại + $n mới)';
  String get allDoneToday => isEnglish
      ? 'All done for today! Custom study'
      : 'Đã hoàn thành hôm nay! Ôn tập tự do';
  String get allDoneMessage => isEnglish
      ? 'You have completed today\'s study goal'
      : 'Bạn đã hoàn thành mục tiêu học tập hôm nay';
  String get customStudyHint => isEnglish
      ? 'Tap "Custom study" above to practice more'
      : 'Nhấn nút "Ôn tập tự do" phía trên để ôn luyện thêm';
  String noCardsInTopic(String topic) =>
      isEnglish ? 'No cards in $topic' : 'Không có thẻ nào trong khối $topic';
  String get chooseOtherTopic => isEnglish
      ? 'Please choose another topic or import cards'
      : 'Hãy chọn khối khác hoặc nhập thêm thẻ mới';
  String topicCardsCount(String topic, int count) =>
      isEnglish ? 'Topic $topic ($count cards)' : 'Khối $topic ($count thẻ)';
  String todayGoalTitle(int due, int n) => isEnglish
      ? 'Today\'s goal ($due review + $n new)'
      : 'Mục tiêu hôm nay ($due ôn lại + $n mới)';
  String todayNewTitle(int n) =>
      isEnglish ? 'Today\'s new cards ($n cards)' : 'Thẻ mới hôm nay ($n thẻ)';
  String get studyThisTopic => isEnglish ? 'Study this' : 'Học khối này';
  String get seeMore => isEnglish ? 'See more' : 'Xem thêm';
  String get collapse => isEnglish ? 'Collapse' : 'Thu gọn';
  String get questionLabel => isEnglish ? 'QUESTION' : 'CÂU HỎI';
  String get answerLabel => isEnglish ? 'ANSWER' : 'ĐÁP ÁN';
  String studyTopicAction(String topic) =>
      isEnglish ? 'Study topic $topic' : 'Ôn tập khối $topic';
  String get notStudied => isEnglish ? 'Not studied' : 'Chưa học';
  String repIntervalInfo(int reps, int days) =>
      isEnglish ? 'Rep: $reps • ${days}d' : 'Lặp: $reps • ${days}d';
  String get dueTodayBadge => isEnglish ? 'Due today' : 'Cần ôn hôm nay';
  String get newCardBadge => isEnglish ? 'New' : 'Thẻ mới';
  String reviewedBadge(int days) =>
      isEnglish ? 'Reviewed (${days}d)' : 'Đã ôn (${days}d)';

  // Study Screen
  String get showAnswer => isEnglish ? 'Show Answer' : 'Hiện đáp án';
  String get ratingAgain => isEnglish ? 'Again' : 'Học lại';
  String get ratingHard => isEnglish ? 'Hard' : 'Khó';
  String get ratingGood => isEnglish ? 'Good' : 'Tốt';
  String get ratingEasy => isEnglish ? 'Easy' : 'Dễ';
  String daysCount(int days) => isEnglish ? '$days days' : '$days ngày';
  String cardProgress(int current, int total) =>
      isEnglish ? 'Card $current / $total' : 'Thẻ $current / $total';
  String get currentStudyingDeck => isEnglish ? 'Studying deck' : 'Bộ đang học';
  String get studySm2Title => isEnglish ? 'Study SM-2' : 'Học thẻ SM-2';
  String get cardTagQuestion => isEnglish ? 'QUESTION' : 'CÂU HỎI';
  String get cardTagAnswer =>
      isEnglish ? 'ANSWER & EXPLANATION' : 'ĐÁP ÁN & GIẢI THÍCH';
  String get tapCardToFlipHint => isEnglish
      ? 'Tap card or press Show Answer below'
      : 'Chạm vào thẻ hoặc bấm nút Hiện đáp án bên dưới';
  String get rateCardHint => isEnglish
      ? 'Rate your recall below to schedule next review'
      : 'Chọn mức độ nhớ bên dưới để lên lịch ôn tiếp theo';
  String get noDecksToStudy => isEnglish
      ? 'No decks to study. Please create one in Decks tab.'
      : 'Chưa có bộ thẻ để học. Hãy tạo bộ mới ở tab Bộ thẻ.';
  String get deckDeletedSelectOther => isEnglish
      ? 'Current deck was deleted. Please select another.'
      : 'Bộ đang học đã bị xóa. Hãy chọn bộ khác.';
  String get selectDeckToStudy => isEnglish
      ? 'Select a deck to start studying.'
      : 'Chọn một bộ thẻ để bắt đầu học.';
  String get deletedDeck => isEnglish ? 'Deleted deck' : 'Bộ thẻ đã xóa';
  String get restartStudy =>
      isEnglish ? 'Restart from beginning' : 'Ôn tập lại từ đầu';
  String get sessionCompleted =>
      isEnglish ? 'Session completed' : 'Hoàn thành phiên học';
  String get greatJob => isEnglish ? 'Great job!' : 'Tuyệt vời!';
  String completedMessage(int count) => isEnglish
      ? 'You completed the review session with $count cards.'
      : 'Bạn đã hoàn thành phiên ôn tập với $count thẻ.';
  String get noCardsInSession => isEnglish
      ? 'No cards in this study session!'
      : 'Chưa có thẻ nào trong phiên học!';
  String get noCardsInSessionHint => isEnglish
      ? 'Come back later or add new cards to start studying.'
      : 'Hãy quay lại sau hoặc thêm thẻ mới để bắt đầu học tập.';
  String get undoSuccess =>
      isEnglish ? 'Undone last rated card' : 'Đã hoàn tác câu vừa đánh giá';

  // Decks Screen
  String get decksTitle => isEnglish ? 'Decks' : 'Các bộ thẻ';
  String get createDeck => isEnglish ? 'Create deck' : 'Tạo bộ thẻ';
  String get manageDeck => isEnglish ? 'Manage deck' : 'Quản lý bộ thẻ';
  String cardsCount(int n) => isEnglish ? '$n questions' : '$n câu hỏi';
  String get studyThisDeck => isEnglish ? 'Study this deck' : 'Học bộ này';
  String get noDecksYet => isEnglish
      ? 'No decks yet. Tap + to create one.'
      : 'Chưa có bộ thẻ. Nhấn + để tạo bộ mới.';
  String get renameDeck =>
      isEnglish ? 'Rename / description' : 'Đổi tên / mô tả';
  String get deleteDeck => isEnglish ? 'Delete deck' : 'Xóa bộ thẻ';

  // Bloom Levels & Topics
  String get generalTopic => isEnglish ? 'General' : 'Chung';
  String get retry => isEnglish ? 'Retry' : 'Thử lại';
  String levelLabel(String level) {
    if (!isEnglish) return level;
    final lower = level.toLowerCase();
    if (lower.contains('nhớ') || lower.contains('nhận biết') || lower.contains('nhan biet')) {
      return 'Remember';
    }
    if (lower.contains('hiểu') || lower.contains('hieu')) {
      return 'Understand';
    }
    if (lower.contains('vận dụng') || lower.contains('van dung')) {
      return 'Apply';
    }
    return level;
  }

  // Common states
  String get comingSoon => isEnglish ? 'Coming soon' : 'Sẽ được cập nhật';
  String get selected => isEnglish ? 'Selected' : 'Đang chọn';
  String get settingsDescription => isEnglish
      ? 'Customize your flashcard learning experience.'
      : 'Tùy chỉnh trải nghiệm học Flashcard của bạn.';
}
