import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/foundation.dart';
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
import 'providers/group_provider.dart';
import 'services/firestore_group_service.dart';
import 'services/group_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const useFirebaseEmulators = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
    defaultValue: false,
  );

  const emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );

  if (useFirebaseEmulators) {
    if (kReleaseMode) {
      throw StateError('Firebase emulator mode is disabled in release builds.');
    }

    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'fake-api-key',
          appId: '1:1234567890:web:demo',
          messagingSenderId: '1234567890',
          projectId: 'demo-catholic-habits',
          authDomain: 'demo-catholic-habits.firebaseapp.com',
        ),
      );
    } else {
      await Firebase.initializeApp(demoProjectId: 'demo-catholic-habits');
    }

    if (Firebase.app().options.projectId != 'demo-catholic-habits') {
      throw StateError('The app did not initialize with the demo project.');
    }

    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);

    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);

    FirebaseFunctions.instance.useFunctionsEmulator(emulatorHost, 5001);
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  final authService = AuthService();
  final userProfileService = UserProfileService();

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<UserProfileService>.value(value: userProfileService),
        Provider<GroupService>(create: (_) => FirestoreGroupService()),
        // HabitProvider must be registered before ProgressProvider so the
        // ProxyProvider below can depend on it.
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            authService: authService,
            profileService: userProfileService,
          ),
        ),
        ChangeNotifierProxyProvider<AuthProvider, GroupProvider>(
          lazy: false,
          create: (context) => GroupProvider(context.read<GroupService>()),
          update: (_, authProvider, groupProvider) {
            final groups = groupProvider!;

            groups.syncAccount(
              uid: useFirebaseEmulators ? authProvider.user?.uid : null,
            );

            return groups;
          },
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
