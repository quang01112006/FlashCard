import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/card_controller.dart';
import 'core/app_theme.dart';
import 'screens/main_nav_screen.dart';
import 'services/manage_card_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlashcardApp());
}

class FlashcardApp extends StatelessWidget {
  const FlashcardApp({super.key, this.cardStore});

  final ManageCardStore? cardStore;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CardController(store: cardStore)..loadDefaultCards(),
        ),
      ],
      child: Selector<CardController, bool>(
        selector: (_, controller) => controller.isDarkMode,
        builder: (context, isDarkMode, _) {
          return MaterialApp(
            title: 'Memora',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
            themeAnimationDuration: Duration.zero,
            home: const MainNavScreen(),
          );
        },
      ),
    );
  }
}
