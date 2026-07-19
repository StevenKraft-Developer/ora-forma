import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';

class UserProfileProvider extends ChangeNotifier {
  final UserProfileService _profileService;

  UserProfile? _profile;
  bool _isLoading = false;

  UserProfileProvider({required UserProfileService profileService})
      : _profileService = profileService;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isOnboardingComplete => _profile?.onboardingComplete ?? false;

  Future<void> loadProfile(String uid) async {
    _isLoading = true;
    notifyListeners();

    _profile = await _profileService.getProfile(uid);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    _isLoading = true;
    notifyListeners();

    final updatedProfile = UserProfile(
      uid: uid,
      email: email,
      displayName: displayName,
      onboardingComplete: true,
      groupIds: _profile?.groupIds ?? const [],
    );

    await _profileService.saveProfile(updatedProfile);
    _profile = updatedProfile;

    _isLoading = false;
    notifyListeners();
  }

  void clear() {
    _profile = null;
    notifyListeners();
  }
}