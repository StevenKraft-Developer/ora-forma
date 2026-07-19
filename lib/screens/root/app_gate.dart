import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../services/onboarding_storage.dart';
import '../auth/welcome_screen.dart';
import '../../main_navigation_screen.dart';
import '../onboarding/habit_onboarding_screen.dart';
import '../onboarding/profile_setup_screen.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  String? _loadedUid;

  // ---------------------------------------------------------------------------
  // Habit-onboarding completion state.
  //
  // null  → not yet checked (loading indicator shown)
  // false → not complete  (HabitOnboardingScreen shown)
  // true  → complete      (MainNavigationScreen shown)
  //
  // The check is triggered once, in the first build after the auth+profile
  // gates both pass. A guard flag prevents re-triggering on subsequent
  // rebuilds.
  // ---------------------------------------------------------------------------
  bool? _habitOnboardingComplete;
  bool _onboardingCheckStarted = false;

  /// Reads the onboarding flag from SharedPreferences exactly once per
  /// authenticated session and stores the result in [_habitOnboardingComplete].
  void _checkOnboarding() {
    if (_onboardingCheckStarted) return;
    _onboardingCheckStarted = true;

    OnboardingStorage().loadOnboardingComplete().then((complete) {
      if (mounted) {
        setState(() => _habitOnboardingComplete = complete);
      }
    });
  }

  /// Called by [HabitOnboardingScreen] after it has persisted the completion
  /// flag. Flips local state so AppGate re-evaluates and shows the main app.
  void _onOnboardingCompleted() {
    setState(() => _habitOnboardingComplete = true);
  }

  /// Reset onboarding state when the user signs out so a fresh check runs on
  /// next sign-in.
  void _resetOnboardingState() {
    _habitOnboardingComplete = null;
    _onboardingCheckStarted = false;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profileProvider = context.watch<UserProfileProvider>();

    // ── Gate 1: Auth loading ─────────────────────────────────────────────────
    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = authProvider.user;

    // ── Gate 2: Signed out ───────────────────────────────────────────────────
    if (user == null) {
      if (_loadedUid != null) {
        // User just signed out — clear profile and reset onboarding state so
        // the check runs fresh on next sign-in.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<UserProfileProvider>().clear();
        });
        _loadedUid = null;
        _resetOnboardingState();
      }
      return const WelcomeScreen();
    }

    // ── Gate 3: Profile loading / setup ──────────────────────────────────────
    if (_loadedUid != user.uid) {
      _loadedUid = user.uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<UserProfileProvider>().loadProfile(user.uid);
      });
    }

    if (profileProvider.isLoading || profileProvider.profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!profileProvider.isOnboardingComplete) {
      return const ProfileSetupScreen();
    }

    // ── Gate 4: Habit onboarding ─────────────────────────────────────────────
    // Auth and profile are both satisfied. Now check whether the user has
    // completed the habit-onboarding flow.
    _checkOnboarding();

    if (_habitOnboardingComplete == null) {
      // Still reading from SharedPreferences — show a brief loading indicator
      // rather than flashing the wrong screen.
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_habitOnboardingComplete == false) {
      return HabitOnboardingScreen(onCompleted: _onOnboardingCompleted);
    }

    // ── All gates passed: show main app ──────────────────────────────────────
    return const MainNavigationScreen();
  }
}
