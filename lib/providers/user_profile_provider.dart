import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../services/user_profile_service.dart';

class UserProfileProvider extends ChangeNotifier {
  final UserProfileService _profileService;

  UserProfile? _profile;
  String? _uid;
  bool _isLoading = false;
  bool _isDisposed = false;
  int _requestVersion = 0;

  UserProfileProvider({required UserProfileService profileService})
    : _profileService = profileService;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isOnboardingComplete => _profile?.onboardingComplete ?? false;

  bool _isCurrentRequest(int version, String uid) {
    return !_isDisposed && version == _requestVersion && uid == _uid;
  }

  Future<void> loadProfile(String uid) async {
    if (_isDisposed) return;

    final version = ++_requestVersion;

    _uid = uid;
    _profile = null;
    _isLoading = true;
    notifyListeners();

    try {
      final loadedProfile = await _profileService.getProfile(uid);

      if (!_isCurrentRequest(version, uid)) return;

      _profile = loadedProfile;
    } catch (e, st) {
      if (!_isCurrentRequest(version, uid)) return;

      debugPrint('loadProfile failed: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    } finally {
      if (_isCurrentRequest(version, uid)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> completeOnboarding({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    if (_isDisposed) return;

    final updatedProfile = UserProfile(
      uid: uid,
      email: email,
      displayName: displayName,
      onboardingComplete: true,
      groupIds: _profile?.uid == uid ? _profile!.groupIds : const [],
    );

    final version = ++_requestVersion;

    if (_uid != uid) {
      _profile = null;
    }

    _uid = uid;
    _isLoading = true;
    notifyListeners();

    try {
      await _profileService.saveProfile(updatedProfile);

      if (!_isCurrentRequest(version, uid)) return;

      _profile = updatedProfile;
    } catch (e, st) {
      if (!_isCurrentRequest(version, uid)) return;

      debugPrint('completeOnboarding failed: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    } finally {
      if (_isCurrentRequest(version, uid)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void clear() {
    if (_isDisposed) return;

    _requestVersion++;
    _uid = null;
    _profile = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _requestVersion++;
    super.dispose();
  }
}
