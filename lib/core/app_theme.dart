import 'package:flutter/material.dart';

/// Bảng màu chuẩn dùng chung cho toàn bộ dự án
class AppColors {
  static const primary = Color(0xFF4F46E5); // Tím chàm (Light Mode)
  static const primaryDark = Color(0xFF818CF8); // Tím sáng Indigo 400 (Dark Mode tương phản cao)
  static const primaryLight = Color(0xFFEEF2FF); // Tím chàm nhạt
  static const primaryLightDark = Color(0xFF312E81); // Tím chàm nền tối
  static const secondary = Color(0xFF10B981); // Xanh ngọc (nút Dễ / Hoàn thành)
  static const warning = Color(0xFFF59E0B); // Vàng cam (nút Khó)
  static const danger = Color(0xFFEF4444); // Đỏ (nút Học lại)

  static const background = Color(0xFFF8FAFC); // xám nhạt
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

  /// Trả về màu primary thích ứng theo Light / Dark Mode
  static Color primaryAdaptive(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? primaryDark
        : primary;
  }
}

/// Kiểu chữ
class AppTextStyles {
  static const heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const subHeading = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 15,
    color: AppColors.textPrimary,
  );

  static const caption = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );
}

/// Cấu hình ThemeData áp dụng trực tiếp vào MaterialApp
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(88, 48), // Đáp ứng tiêu chí vùng chạm >= 48dp
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 1,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primaryDark,
        surface: const Color(0xFF1E293B),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
    );
  }
}
