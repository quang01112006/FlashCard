import 'package:flutter/material.dart';
import 'package:flashcard_sm2/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flashcard_sm2/l10n/app_strings.dart';

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

    test('Reminder correctly moves to the next month', () {
      final now = DateTime(2026, 11, 30, 20, 0);

      final result = NotificationService.calculateNextReminder(
        now: now,
        selectedTime: const TimeOfDay(hour: 19, minute: 0),
      );

      expect(result, DateTime(2026, 12, 1, 19, 0));
    });
  });
}