import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'main_navigation_screen.dart';
import 'colors.dart';
import 'providers/progress_provider.dart';
import 'services/progress_storage.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ProgressProvider(ProgressStorage())..loadTodayProgress(),
      child: const OraFormaApp(),
    ),
  );
}

class OraFormaApp extends StatelessWidget {
  const OraFormaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: OraColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: OraColors.background,
      fontFamily: 'Inter',
    );

    return MaterialApp(
      title: 'Ora Forma',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: base.textTheme.apply(
          bodyColor: OraColors.text,
          displayColor: OraColors.text,
        ),
        cardTheme: CardThemeData(
          color: OraColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 2,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        dividerColor: OraColors.background,
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          iconColor: OraColors.primary,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}