import 'package:flutter/material.dart';
import 'main_navigation_screen.dart';
import 'colors.dart'; // Optional: if you want to use the OraColors class for theming

void main() {
  runApp(const OraFormaApp());
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
