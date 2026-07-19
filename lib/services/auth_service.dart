import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth;

  AuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  Stream<AppUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_fromFirebaseUser);
  }

  AppUser? get currentUser => _fromFirebaseUser(_firebaseAuth.currentUser);

  Future<AppUser> register({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = _fromFirebaseUser(credential.user);
    if (user == null) {
      throw Exception('Registration failed.');
    }

    return user;
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = _fromFirebaseUser(credential.user);
    if (user == null) {
      throw Exception('Login failed.');
    }

    return user;
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }

  AppUser? _fromFirebaseUser(User? user) {
    if (user == null) return null;

    return AppUser(
      uid: user.uid,
      email: user.email,
    );
  }
}