import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/habit.dart';

class FirestoreHabitService {
  FirestoreHabitService([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _habitsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('habits');
  }

  DocumentReference<Map<String, dynamic>> _metaRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('habits');
  }

  /// Returns null if the user has never initialized a habit catalog.
  ///
  /// Returns an empty list when initialization occurred but the user
  /// intentionally has no habits, preserving the previous storage contract.
  /// Returns null when this account has no explicit onboarding decision.
  ///
  /// Catalog initialization alone does not imply onboarding completion.
  Future<bool?> loadOnboardingComplete(String uid) async {
    final snapshot = await _metaRef(uid).get();
    final value = snapshot.data()?['onboardingCompleted'];

    if (value == null) return null;

    if (value is! bool) {
      throw const FormatException(
        'Habit metadata onboardingCompleted must be a boolean.',
      );
    }

    return value;
  }

  Future<List<Habit>?> loadHabits(String uid) async {
    final metaSnapshot = await _metaRef(uid).get();

    if (!metaSnapshot.exists || metaSnapshot.data()?['initialized'] != true) {
      return null;
    }

    final snapshot = await _habitsRef(uid).orderBy('sortOrder').get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return Habit(
        id: doc.id,
        title: data['title'] as String,
        description: data['description'] as String?,
        sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
        isArchived: data['isArchived'] as bool? ?? false,
      );
    }).toList();
  }

  /// Persists the supplied canonical habit list and records that this user's
  /// habit catalog has been initialized, including when [habits] is empty.
  Future<void> saveHabits({
    required String uid,
    required List<Habit> habits,
    bool completeOnboarding = false,
  }) async {
    final batch = _firestore.batch();
    final habitsRef = _habitsRef(uid);

    final existing = await habitsRef.get();
    final retainedIds = habits.map((habit) => habit.id).toSet();

    for (final document in existing.docs) {
      if (!retainedIds.contains(document.id)) {
        batch.delete(document.reference);
      }
    }

    for (final habit in habits) {
      batch.set(habitsRef.doc(habit.id), {
        'title': habit.title,
        'description': habit.description,
        'sortOrder': habit.sortOrder,
        'isArchived': habit.isArchived,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.set(_metaRef(uid), {
      'initialized': true,
      if (completeOnboarding) 'onboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
