import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class UserProfileService {
  final FirebaseFirestore _firestore;

  UserProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<void> createProfile({
    required String uid,
    required String email,
  }) async {
    final profile = UserProfile(
      uid: uid,
      email: email,
      displayName: '',
      onboardingComplete: false,
      groupIds: const [],
    );

    await _users.doc(uid).set(profile.toMap());
  }

  Future<UserProfile?> getProfile(String uid) async {
    final doc = await _users.doc(uid).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return UserProfile.fromMap(uid, doc.data()!);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _users.doc(profile.uid).set(profile.toMap(), SetOptions(merge: true));
  }
}