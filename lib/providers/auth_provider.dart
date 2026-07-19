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

  AuthProvider({
    required AuthService authService,
    required UserProfileService profileService,
  })  : _authService = authService,
        _profileService = profileService {
    _authSubscription = _authService.authStateChanges().listen((user) async {
      _user = user;
      _isLoading = false;
      _error = null;

      if (user != null) {
        final existingProfile = await _profileService.getProfile(user.uid);
        if (existingProfile == null) {
          await _profileService.createProfile(
            uid: user.uid,
            email: user.email ?? '',
          );
        }
      }

      notifyListeners();
    });
  }

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  Future<bool> register({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.register(email: email, password: password);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.signIn(email: email, password: password);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}