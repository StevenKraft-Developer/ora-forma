import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../services/onboarding_storage.dart';
import '../../main_navigation_screen.dart';
import '../auth/welcome_screen.dart';
import '../onboarding/habit_onboarding_screen.dart';
import '../onboarding/profile_setup_screen.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key, this.loadHabitOnboarding});

  final Future<bool> Function()? loadHabitOnboarding;

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  int? _sessionVersion;

  bool _profileLoadStarted = false;
  bool _profileLoadComplete = false;
  String? _profileLoadError;

  bool? _habitOnboardingComplete;
  bool _onboardingCheckStarted = false;
  String? _onboardingError;

  bool _isCurrentSession(int version, String? uid) {
    if (!mounted || _sessionVersion != version) return false;

    final auth = context.read<AuthProvider>();

    return auth.sessionVersion == version && auth.user?.uid == uid;
  }

  void _resetSessionState(int version) {
    _sessionVersion = version;

    _profileLoadStarted = false;
    _profileLoadComplete = false;
    _profileLoadError = null;

    _habitOnboardingComplete = null;
    _onboardingCheckStarted = false;
    _onboardingError = null;
  }

  void _scheduleProfileClear(int version, String? uid) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isCurrentSession(version, uid)) return;

      context.read<UserProfileProvider>().clear();
    });
  }

  void _scheduleProfileLoad(int version, String uid) {
    if (_profileLoadStarted) return;
    _profileLoadStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_isCurrentSession(version, uid)) return;

      final profiles = context.read<UserProfileProvider>();

      try {
        profiles.clear();
        await profiles.loadProfile(uid);

        if (!_isCurrentSession(version, uid)) return;

        setState(() {
          _profileLoadComplete = true;
        });
      } catch (_) {
        if (!_isCurrentSession(version, uid)) return;

        setState(() {
          _profileLoadError =
              'Your profile could not be loaded. Please try again.';
        });
      }
    });
  }

  void _checkOnboarding(int version, String uid) {
    if (_onboardingCheckStarted) return;
    _onboardingCheckStarted = true;

    final load =
        widget.loadHabitOnboarding ??
        OnboardingStorage().loadOnboardingComplete;

    Future<bool>.sync(load)
        .then((complete) {
          if (!_isCurrentSession(version, uid)) return;

          setState(() {
            _habitOnboardingComplete = complete;
          });
        })
        .catchError((Object error) {
          if (!_isCurrentSession(version, uid)) return;

          setState(() {
            _onboardingError =
                'Your onboarding status could not be checked. Please try again.';
          });
        });
  }

  void _onOnboardingCompleted(int version, String uid) {
    if (!_isCurrentSession(version, uid)) return;

    setState(() {
      _habitOnboardingComplete = true;
    });
  }

  Widget _loadingScreen() {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Widget _retryScreen({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profiles = context.watch<UserProfileProvider>();
    final version = auth.sessionVersion;
    final user = auth.user;

    // Reset before any loading gate so an intermediate auth-loading
    // state cannot preserve the previous session's routing decisions.
    if (_sessionVersion != version) {
      _resetSessionState(version);
      _scheduleProfileClear(version, user?.uid);
    }

    if (auth.isLoading) {
      return _loadingScreen();
    }

    if (user == null) {
      return const WelcomeScreen();
    }

    final uid = user.uid;

    if (auth.profileInitializationError != null) {
      return _retryScreen(
        message: auth.profileInitializationError!,
        onRetry: () {
          if (!_isCurrentSession(version, uid)) return;

          context.read<AuthProvider>().retryProfileInitialization();
        },
      );
    }

    if (_profileLoadError != null) {
      return _retryScreen(
        message: _profileLoadError!,
        onRetry: () {
          if (!_isCurrentSession(version, uid)) return;

          setState(() {
            _profileLoadStarted = false;
            _profileLoadComplete = false;
            _profileLoadError = null;
          });
        },
      );
    }

    if (!_profileLoadComplete) {
      _scheduleProfileLoad(version, uid);
      return _loadingScreen();
    }

    if (profiles.isLoading) {
      return _loadingScreen();
    }

    final profile = profiles.profile;

    if (profile == null || profile.uid != uid) {
      return _retryScreen(
        message: 'Your profile is unavailable. Please try again.',
        onRetry: () {
          if (!_isCurrentSession(version, uid)) return;

          setState(() {
            _profileLoadStarted = false;
            _profileLoadComplete = false;
            _profileLoadError = null;
          });
        },
      );
    }

    if (!profiles.isOnboardingComplete) {
      return const ProfileSetupScreen();
    }

    if (_onboardingError != null) {
      return _retryScreen(
        message: _onboardingError!,
        onRetry: () {
          if (!_isCurrentSession(version, uid)) return;

          setState(() {
            _onboardingError = null;
            _onboardingCheckStarted = false;
            _habitOnboardingComplete = null;
          });
        },
      );
    }

    _checkOnboarding(version, uid);

    if (_habitOnboardingComplete == null) {
      return _loadingScreen();
    }

    if (_habitOnboardingComplete == false) {
      return HabitOnboardingScreen(
        key: ValueKey('habit-onboarding-$version-$uid'),
        onCompleted: () => _onOnboardingCompleted(version, uid),
      );
    }

    return const MainNavigationScreen();
  }
}
