class AppStrings {
  final bool isEnglish;

  const AppStrings(this.isEnglish);

  // General
  String get appName => 'FlashCard SM-2';
  String get settings => isEnglish ? 'Settings' : 'Cài đặt';
  String get cancel => isEnglish ? 'Cancel' : 'Hủy';
  String get save => isEnglish ? 'Save' : 'Lưu';
  String get confirm => isEnglish ? 'Confirm' : 'Xác nhận';

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
  String get reminderTime =>
      isEnglish ? 'Reminder time' : 'Thời gian nhắc nhở';
  String get notificationEnabled =>
      isEnglish ? 'Daily reminder enabled' : 'Đã bật nhắc nhở hằng ngày';
  String get notificationDisabled =>
      isEnglish ? 'Daily reminder disabled' : 'Đã tắt nhắc nhở hằng ngày';

  // Reset data
  String get resetData =>
      isEnglish ? 'Reset original data' : 'Khôi phục dữ liệu gốc';
  String get resetDataDescription => isEnglish
      ? 'Restore the original 300 flashcards'
      : 'Khôi phục 300 thẻ Flashcard ban đầu';
  String get resetConfirmationTitle =>
      isEnglish ? 'Reset data?' : 'Khôi phục dữ liệu?';
  String get resetConfirmationMessage => isEnglish
      ? 'Your flashcards will be restored to the original dataset.'
      : 'Dữ liệu thẻ sẽ được khôi phục về bộ dữ liệu ban đầu.';
  String get resetSuccess =>
      isEnglish ? 'Data restored successfully' : 'Khôi phục dữ liệu thành công';

  // Common states
  String get comingSoon => isEnglish ? 'Coming soon' : 'Sẽ được cập nhật';
  String get selected => isEnglish ? 'Selected' : 'Đang chọn';
  String get settingsDescription => isEnglish
      ? 'Customize your flashcard learning experience.'
      : 'Tùy chỉnh trải nghiệm học Flashcard của bạn.';
}