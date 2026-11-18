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
      child: Consumer<CardController>(
        builder: (context, controller, _) {
          return MaterialApp(
            title: 'Flashcard SM-2',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: controller.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const MainNavScreen(),
          );
        },
      ),
    );
  }
}
