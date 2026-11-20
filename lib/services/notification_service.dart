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
        final matchingLocation = tz.timeZoneDatabase.locations.values
            .firstWhere(
              (loc) => loc.currentTimeZone.offset == offset,
              orElse: () => tz.getLocation('Asia/Ho_Chi_Minh'),
            );
        tz.setLocalLocation(matchingLocation);
      } catch (_) {}

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
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

  /// Yêu cầu và kiểm tra quyền thông báo trên Android.

  static Future<bool> requestPermission() async {
    try {
      await initialize();

      if (!_initialized) return false;

      final android = _plugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (android == null) return false;

      // Yêu cầu quyền trên Android 13 trở lên.
      await android.requestNotificationsPermission();

      // Kiểm tra trạng thái quyền thực tế sau khi yêu cầu.
      final enabled = await android.areNotificationsEnabled();

      return enabled ?? false;
    } catch (e) {
      debugPrint('Notification permission error: $e');
      return false;
    }
  }


  /// Lên lịch nhắc nhở ôn tập hằng ngày.
  /// Trả về true nếu đặt lịch thành công, false nếu thất bại.
  static Future<bool> scheduleDailyReminder({
    required TimeOfDay selectedTime,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    try {
      await initialize();
      if (!_initialized) return false;

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

      final androidDetails = AndroidNotificationDetails(
        'daily_study_reminder_v2',
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      final details = NotificationDetails(android: androidDetails);

      // Thử hủy lịch cũ trước khi đặt lịch mới.
      await _plugin.cancel(id: 0);

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

      return true;
    } catch (e) {
      debugPrint('Schedule reminder error: $e');
      return false;
    }
  }

  /// Hủy thông báo nhắc nhở.
  static Future<bool> cancelReminder() async {
    try {
      await initialize();
      if (!_initialized) return false;

      await _plugin.cancel(id: 0);
      return true;
    } catch (e) {
      debugPrint('Cancel reminder error: $e');
      return false;
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
