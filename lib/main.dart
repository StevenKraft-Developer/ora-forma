import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'colors.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/habit_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/user_profile_provider.dart';
import 'screens/root/app_gate.dart';
import 'services/auth_service.dart';
import 'services/firestore_habit_service.dart';
import 'services/firestore_progress_service.dart';
import 'services/user_profile_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final authService = AuthService();
  final userProfileService = UserProfileService();

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<UserProfileService>.value(value: userProfileService),
        // HabitProvider must be registered before ProgressProvider so the
        // ProxyProvider below can depend on it.
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            authService: authService,
            profileService: userProfileService,
          ),
        ),

        ChangeNotifierProxyProvider<AuthProvider, HabitProvider>(
          create: (_) => HabitProvider(FirestoreHabitService()),
          update: (_, authProvider, habitProvider) {
            final uid = authProvider.user?.uid;

            if (uid == null) {
              habitProvider!.clear();
            } else {
              habitProvider!.loadHabits(uid);
            }

            return habitProvider;
          },
        ),

        ChangeNotifierProxyProvider2<
          AuthProvider,
          HabitProvider,
          ProgressProvider
        >(
          create: (_) => ProgressProvider(FirestoreProgressService()),
          update: (_, authProvider, habitProvider, progressProvider) {
            final progress = progressProvider!;

            progress.syncAccount(
              uid: authProvider.user?.uid,
              activeHabits: habitProvider.activeHabits,
              habitsReady: habitProvider.isLoaded,
            );

            return progress;
          },
        ),
        ChangeNotifierProvider(
          create: (_) =>
              UserProfileProvider(profileService: userProfileService),
        ),
      ],
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
      home: const AppGate(),
    );
  }
}
