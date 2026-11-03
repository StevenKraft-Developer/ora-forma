import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final UserProfileService _profileService;

  StreamSubscription<AppUser?>? _authSubscription;

  AppUser? _user;
  bool _isLoading = true;
  String? _error;
  int _sessionVersion = 0;
  bool _isDisposed = false;
  bool _isPreparingProfile = false;
  String? _profileInitializationError;

  AuthProvider({
    required AuthService authService,
    required UserProfileService profileService,
  }) : _authService = authService,
       _profileService = profileService {
    _authSubscription = _authService.authStateChanges().listen((user) {
      unawaited(_handleAuthUserChanged(user));
    });
  }

  AppUser? get user => _user;

  /// Changes when authentication/profile initialization is restarted
  /// or this provider is disposed.
  int get sessionVersion => _sessionVersion;
  bool get isLoading => _isLoading || _isPreparingProfile;

  String? get profileInitializationError => _profileInitializationError;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  bool _isCurrentSession(int version, String uid) {
    return !_isDisposed && version == _sessionVersion && _user?.uid == uid;
  }

  void _notifyIfActive() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  Future<void> _handleAuthUserChanged(AppUser? user) async {
    if (_isDisposed) return;

    final version = ++_sessionVersion;

    _user = user;
    _isLoading = false;
    _error = null;
    _profileInitializationError = null;
    _isPreparingProfile = user != null;

    // Publish the account change before waiting for profile work.
    // AppGate still sees isLoading while that work is pending.
    _notifyIfActive();

    if (user == null) return;

    try {
      final existingProfile = await _profileService.getProfile(user.uid);

      if (!_isCurrentSession(version, user.uid)) return;

      if (existingProfile == null) {
        await _profileService.createProfile(
          uid: user.uid,
          email: user.email ?? '',
        );

        if (!_isCurrentSession(version, user.uid)) return;
      }
    } catch (_) {
      if (!_isCurrentSession(version, user.uid)) return;

      _profileInitializationError =
          'Your account profile could not be prepared. Please try again.';
    } finally {
      if (_isCurrentSession(version, user.uid)) {
        _isPreparingProfile = false;
        _notifyIfActive();
      }
    }
  }

  Future<void> retryProfileInitialization() async {
    final user = _user;

    if (_isDisposed || user == null || _isPreparingProfile) return;

    await _handleAuthUserChanged(user);
  }

  Future<bool> register({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      _notifyIfActive();

      await _authService.register(email: email, password: password);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      _notifyIfActive();
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    try {
      _isLoading = true;
      _error = null;
      _notifyIfActive();

      await _authService.signIn(email: email, password: password);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      _notifyIfActive();
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _isLoading = true;
      _error = null;
      _notifyIfActive();

      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      _notifyIfActive();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _sessionVersion++;
    _authSubscription?.cancel();
    super.dispose();
  }
}
