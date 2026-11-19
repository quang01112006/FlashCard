import 'package:flutter/material.dart';
import 'package:flashcard_sm2/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flashcard_sm2/l10n/app_strings.dart';
import 'package:flashcard_sm2/core/app_theme.dart';

void main() {
  group('AppStrings - Vietnamese', () {
    const strings = AppStrings(false);

    test('Returns Vietnamese settings labels', () {
      expect(strings.settings, 'Cài đặt');
      expect(strings.language, 'Ngôn ngữ');
      expect(strings.appearance, 'Giao diện');
    });

    test('Returns Vietnamese notification labels', () {
      expect(strings.notification, 'Thông báo');
      expect(strings.dailyReminder, 'Nhắc nhở ôn tập hằng ngày');
      expect(strings.reminderTime, 'Thời gian nhắc nhở');
    });
  });

  group('AppStrings - English', () {
    const strings = AppStrings(true);

    test('Returns English settings labels', () {
      expect(strings.settings, 'Settings');
      expect(strings.language, 'Language');
      expect(strings.appearance, 'Appearance');
    });

    test('Returns English notification labels', () {
      expect(strings.notification, 'Notifications');
      expect(strings.dailyReminder, 'Daily study reminder');
      expect(strings.reminderTime, 'Reminder time');
    });
  });

  group('AppStrings - Notification messages', () {
    test('Returns Vietnamese notification messages', () {
      const strings = AppStrings(false);

      expect(strings.notificationPermissionDenied, isNotEmpty);
      expect(strings.notificationScheduleFailed, isNotEmpty);
      expect(strings.reminderNotificationTitle, isNotEmpty);
      expect(strings.reminderNotificationBody, isNotEmpty);
      expect(strings.reminderChannelName, isNotEmpty);
      expect(strings.reminderChannelDescription, isNotEmpty);
      expect(strings.resetFailed, isNotEmpty);
    });

    test('Returns English notification messages', () {
      const strings = AppStrings(true);

      expect(strings.notificationPermissionDenied, isNotEmpty);
      expect(strings.notificationScheduleFailed, isNotEmpty);
      expect(strings.reminderNotificationTitle, isNotEmpty);
      expect(strings.reminderNotificationBody, isNotEmpty);
      expect(strings.reminderChannelName, isNotEmpty);
      expect(strings.reminderChannelDescription, isNotEmpty);
      expect(strings.resetFailed, isNotEmpty);
    });
  });

  group('AppTheme - adaptive text styles', () {
    test('Shared text styles do not force light-mode text colors', () {
      expect(AppTextStyles.heading.color, isNull);
      expect(AppTextStyles.subHeading.color, isNull);
      expect(AppTextStyles.body.color, isNull);
      expect(AppTextStyles.caption.color, isNull);
    });
  });

  group('NotificationService - Reminder time calculation', () {
    test('Selected time is later than now: schedule today', () {
      final now = DateTime(2026, 11, 17, 16, 0);

      final result = NotificationService.calculateNextReminder(
        now: now,
        selectedTime: const TimeOfDay(hour: 18, minute: 0),
      );

      expect(result, DateTime(2026, 11, 17, 18, 0));
    });

    test('Selected time has passed: schedule tomorrow', () {
      final now = DateTime(2026, 11, 17, 16, 0);

      final result = NotificationService.calculateNextReminder(
        now: now,
        selectedTime: const TimeOfDay(hour: 15, minute: 0),
      );

      expect(result, DateTime(2026, 11, 18, 15, 0));
    });

    test('Selected time is the current minute: schedule tomorrow', () {
      final now = DateTime(2026, 11, 17, 16, 0, 30);

      final result = NotificationService.calculateNextReminder(
        now: now,
        selectedTime: const TimeOfDay(hour: 16, minute: 0),
      );

      expect(result, DateTime(2026, 11, 18, 16, 0));
    });

    test('Reminder correctly moves to the next year', () {
      final now = DateTime(2026, 12, 31, 23, 0);

      final result = NotificationService.calculateNextReminder(
        now: now,
        selectedTime: const TimeOfDay(hour: 7, minute: 30),
      );

      expect(result, DateTime(2027, 1, 1, 7, 30));
    });
  });
}
