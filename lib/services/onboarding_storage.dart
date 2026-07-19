import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the habit-onboarding flow has been completed.
///
/// Key: [_onboardingCompleteKey]  — stored as a bool via SharedPreferences.
///
/// Default behaviour (first launch):
///   [loadOnboardingComplete] returns `false` when the key is absent, which
///   is the correct default for a first-run device that has never seen the
///   onboarding screen.
///
/// This service has no knowledge of routing or UI. It is a plain read/write
/// wrapper used by AppGate (Task 5) to decide which screen to show.
class OnboardingStorage {
  static const _onboardingCompleteKey = 'onboarding.habit.completed';

  /// Returns `true` if the user has already completed the habit-onboarding
  /// flow, `false` if the key is absent (first run) or was explicitly cleared.
  Future<bool> loadOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    // getBool returns null when the key is absent; ?? false gives first-run default.
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  /// Persists [value] as the onboarding completion flag.
  ///
  /// Typically called with `true` immediately after the user taps "Begin"
  /// on the final onboarding page (Task 6). Can be called with `false` to
  /// programmatically reset onboarding without removing the key entirely
  /// (Profile "Reset" flow in Task 8).
  Future<void> saveOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, value);
  }

  /// Removes the onboarding completion key entirely.
  ///
  /// After this call, [loadOnboardingComplete] returns `false` again.
  /// Prefer this for a full app reset (Profile → Danger Zone).
  Future<void> clearOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingCompleteKey);
  }
}
