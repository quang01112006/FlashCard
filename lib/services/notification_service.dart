
import 'package:flutter/material.dart';

class NotificationService {
  /// Tính thời điểm nhắc nhở tiếp theo.
  ///
  /// Nếu giờ đã chọn còn ở phía trước: nhắc hôm nay.
  /// Nếu giờ đã qua hoặc đúng thời điểm hiện tại: nhắc ngày mai.
  ///
  /// Hàm này chỉ tính thời gian, chưa tạo thông báo Android.
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
