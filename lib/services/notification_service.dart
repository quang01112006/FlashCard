import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Khởi tạo notification plugin cho Android / iOS và múi giờ
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      try {
        final offset = DateTime.now().timeZoneOffset;
        final matchingLocation = tz.timeZoneDatabase.locations.values.firstWhere(
          (loc) => loc.currentTimeZone.offset == offset,
          orElse: () => tz.getLocation('Asia/Ho_Chi_Minh'),
        );
        tz.setLocalLocation(matchingLocation);
      } catch (_) {}

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(settings: initSettings);
      _initialized = true;
    } catch (e) {
      debugPrint('Notification initialization warning: $e');
    }
  }

  /// Yêu cầu quyền thông báo trên Android 13+
  static Future<bool> requestPermission() async {
    try {
      await initialize();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        try {
          await android.requestExactAlarmsPermission();
        } catch (_) {}
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Notification permission error: $e');
      return true;
    }
  }

  /// Lên lịch nhắc nhở ôn tập hằng ngày vào đúng mốc giờ đã chọn
  static Future<void> scheduleDailyReminder({
    required TimeOfDay selectedTime,
    String title = 'Flashcard SM-2',
    String body = 'Đã đến giờ ôn tập thẻ hôm nay rồi! Hãy dành 5 phút nhé.',
  }) async {
    try {
      await initialize();
      await cancelReminder();

      final scheduledDateTime = calculateNextReminder(
        now: DateTime.now(),
        selectedTime: selectedTime,
      );
      final tzScheduledDate = tz.TZDateTime(
        tz.local,
        scheduledDateTime.year,
        scheduledDateTime.month,
        scheduledDateTime.day,
        scheduledDateTime.hour,
        scheduledDateTime.minute,
      );

      const androidDetails = AndroidNotificationDetails(
        'daily_study_reminder',
        'Nhắc nhở học tập',
        channelDescription: 'Thông báo nhắc nhở ôn tập thẻ Flashcard SM-2 hằng ngày',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
      const details = NotificationDetails(android: androidDetails);

      try {
        await _plugin.zonedSchedule(
          id: 0,
          title: title,
          body: body,
          scheduledDate: tzScheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        debugPrint('Exact alarm failed, fallback to inexact: $e');
        await _plugin.zonedSchedule(
          id: 0,
          title: title,
          body: body,
          scheduledDate: tzScheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (e) {
      debugPrint('Schedule reminder error: $e');
    }
  }

  /// Hủy thông báo nhắc nhở
  static Future<void> cancelReminder() async {
    try {
      await initialize();
      await _plugin.cancel(id: 0);
    } catch (e) {
      debugPrint('Cancel reminder error: $e');
    }
  }

  /// Tính thời điểm nhắc nhở tiếp theo.
  ///
  /// Nếu giờ đã chọn còn ở phía trước: nhắc hôm nay.
  /// Nếu giờ đã qua hoặc đúng thời điểm hiện tại: nhắc ngày mai.
  static DateTime calculateNextReminder({
    required DateTime now,
    required TimeOfDay selectedTime,
  }) {
    final todayReminder = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (todayReminder.isAfter(now)) {
      return todayReminder;
    }

    return DateTime(
      now.year,
      now.month,
      now.day + 1,
      selectedTime.hour,
      selectedTime.minute,
    );
  }
}
