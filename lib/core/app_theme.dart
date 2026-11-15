import 'package:flutter/material.dart';

/// Bảng màu chuẩn dùng chung cho toàn bộ dự án
class AppColors {
  static const primary = Color(0xFF2563EB); // Xanh dương chủ đạo
  static const primaryLight = Color(0xFFDBEAFE);
  static const secondary = Color(0xFF10B981); // Xanh lá (nút Dễ / Hoàn thành)
  static const warning = Color(0xFFF59E0B); // Vàng cam (nút Khó)
  static const danger = Color(0xFFEF4444); // Đỏ (nút Học lại)

  static const background = Color(0xFFF8FAFC); // Nền xám nhạt hiện đại
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
}

/// Kiểu chữ (Typography) chuẩn
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
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.heading,
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
}
