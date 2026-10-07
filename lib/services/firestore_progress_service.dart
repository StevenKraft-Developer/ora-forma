import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daily_progress.dart';

class FirestoreProgressService {
  FirestoreProgressService([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _logsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('dailyLogs');
  }

  /// Loads the current day plus the preceding 364 days. This matches the
  /// ProgressProvider's present one-year streak calculation limit.
  Future<Map<String, DailyProgress>> loadHistory(String uid) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 364));

    final snapshot = await _logsRef(uid)
        .where('dateKey', isGreaterThanOrEqualTo: _dateKeyFor(start))
        .orderBy('dateKey')
        .get();

    return {
      for (final document in snapshot.docs)
        document.id: DailyProgress(
          dateKey: document.data()['dateKey'] as String? ?? document.id,
          completedHabitIds: List<String>.from(
            document.data()['completedHabitIds'] as List<dynamic>? ??
                const <dynamic>[],
          ),
        ),
    };
  }

  Future<void> saveTodayProgress({
    required String uid,
    required String dateKey,
    required List<String> completedHabitIds,
  }) {
    return _logsRef(uid).doc(dateKey).set({
      'dateKey': dateKey,
      'completedHabitIds': completedHabitIds.toSet().toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearAllProgressHistory(String uid) async {
    final logs = await _logsRef(uid).get();

    final batch = _firestore.batch();

    for (final document in logs.docs) {
      batch.delete(document.reference);
    }

    await batch.commit();
  }

  String _dateKeyFor(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
