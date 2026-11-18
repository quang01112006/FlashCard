
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/card_controller.dart';
import '../core/app_theme.dart';
import '../l10n/app_strings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            child: ListTile(
              leading: const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.textSecondary,
              ),
              title: Text(
                strings.dailyReminder,
                style: AppTextStyles.body,
              ),
              subtitle: Text(
                strings.comingSoon,
                style: AppTextStyles.caption,
              ),
              trailing: const Icon(
                Icons.schedule,
                color: AppColors.textSecondary,
              ),
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
                color: AppColors.textSecondary,
              ),
              title: Text(
                strings.resetData,
                style: AppTextStyles.body,
              ),
              subtitle: Text(
                strings.resetDataDescription,
                style: AppTextStyles.caption,
              ),
              trailing: const Icon(
                Icons.lock_outline,
                color: AppColors.textSecondary,
              ),
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
