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
    return MaterialApp(
      title: 'Ora Forma',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: OraColors.primary,
          brightness: Brightness.light,
          background: OraColors.background,
        ),
        scaffoldBackgroundColor: OraColors.background,
        fontFamily: 'Inter',
      ),
      home: const MainNavigationScreen(),
    );
  }
}