import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import '../core/app_theme.dart';
import '../l10n/app_strings.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _pickReminderTime(BuildContext context, CardController controller, AppStrings strings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: controller.reminderTime,
    );

    if (picked != null) {
      await controller.setReminder(enabled: true, time: picked);
      if (context.mounted) {
        final formattedTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.reminderSetAt(formattedTime)),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _confirmResetData(BuildContext context, CardController controller, AppStrings strings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.resetConfirmationTitle),
        content: Text(strings.resetConfirmationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await controller.resetAllCards();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(strings.resetSuccess),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(strings.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CardController>();
    final strings = AppStrings(controller.isEnglish);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          strings.settings,
          style: AppTextStyles.heading,
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            strings.settingsDescription,
            style: AppTextStyles.body,
          ),

          const SizedBox(height: 20),

          // LANGUAGE
          _buildSectionTitle(
            strings.language,
            Icons.language,
          ),

          Card(
            child: ListTile(
              leading: const Icon(
                Icons.translate,
                color: AppColors.primary,
              ),
              title: Text(
                strings.language,
                style: AppTextStyles.body,
              ),
              subtitle: Text(
                strings.languageDescription,
                style: AppTextStyles.caption,
              ),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<bool>(
                    isDense: true,
                    value: controller.isEnglish,
                    items: [
                      DropdownMenuItem(
                        value: false,
                        child: Text(strings.vietnamese, overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: true,
                        child: Text(strings.english, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        context.read<CardController>().setLanguage(value);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // APPEARANCE
          _buildSectionTitle(
            strings.appearance,
            Icons.palette_outlined,
          ),

          Card(
            child: SwitchListTile(
              secondary: const Icon(
                Icons.dark_mode_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                strings.darkMode,
                style: AppTextStyles.body,
              ),
              subtitle: Text(
                strings.darkModeDescription,
                style: AppTextStyles.caption,
              ),
              value: controller.isDarkMode,
              activeTrackColor: AppColors.primary,
              onChanged: (value) {
                context.read<CardController>().setDarkMode(value);
              },
            ),
          ),

          const SizedBox(height: 20),

          // NOTIFICATIONS
          _buildSectionTitle(
            strings.notification,
            Icons.notifications_outlined,
          ),

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    Icons.notifications_active_outlined,
                    color: controller.isReminderEnabled ? AppColors.primary : AppColors.textSecondary,
                  ),
                  title: Text(
                    strings.dailyReminder,
                    style: AppTextStyles.body,
                  ),
                  subtitle: Text(
                    controller.isReminderEnabled
                        ? strings.notificationEnabled
                        : strings.dailyReminderDescription,
                    style: AppTextStyles.caption,
                  ),
                  value: controller.isReminderEnabled,
                  activeTrackColor: AppColors.primary,
                  onChanged: (enabled) async {
                    if (enabled) {
                      await NotificationService.requestPermission();
                    }
                    await controller.setReminder(enabled: enabled);
                    if (context.mounted) {
                      final timeStr =
                          '${controller.reminderTime.hour.toString().padLeft(2, '0')}:${controller.reminderTime.minute.toString().padLeft(2, '0')}';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(enabled
                              ? strings.reminderSetAt(timeStr)
                              : strings.notificationDisabled),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                if (controller.isReminderEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.schedule,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      strings.reminderTime,
                      style: AppTextStyles.body,
                    ),
                    subtitle: Text(
                      strings.reminderTimeDescription,
                      style: AppTextStyles.caption,
                    ),
                    trailing: Text(
                      '${controller.reminderTime.hour.toString().padLeft(2, '0')}:${controller.reminderTime.minute.toString().padLeft(2, '0')}',
                      style: AppTextStyles.subHeading.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => _pickReminderTime(context, controller, strings),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // RESET DATA
          _buildSectionTitle(
            strings.resetData,
            Icons.restore,
          ),

          Card(
            child: ListTile(
              leading: const Icon(
                Icons.restore,
                color: AppColors.danger,
              ),
              title: Text(
                strings.resetData,
                style: AppTextStyles.body.copyWith(color: AppColors.danger),
              ),
              subtitle: Text(
                strings.resetDataDescription,
                style: AppTextStyles.caption,
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              onTap: () => _confirmResetData(context, controller, strings),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTextStyles.subHeading,
          ),
        ],
      ),
    );
  }
}
