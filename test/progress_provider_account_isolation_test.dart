import 'dart:async';

import 'package:catholic_habits/models/daily_progress.dart';
import 'package:catholic_habits/models/habit.dart';
import 'package:catholic_habits/providers/progress_provider.dart';
import 'package:catholic_habits/services/firestore_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

class ControlledProgressService implements FirestoreProgressService {
  final loads = <String, Completer<Map<String, DailyProgress>>>{};
  final savedUids = <String>[];
  final clearedUids = <String>[];

  Completer<void>? saveGate;
  Completer<void>? clearGate;

  @override
  Future<Map<String, DailyProgress>> loadHistory(String uid) {
    final pending = Completer<Map<String, DailyProgress>>();
    loads[uid] = pending;
    return pending.future;
  }

  @override
  Future<void> saveTodayProgress({
    required String uid,
    required String dateKey,
    required List<String> completedHabitIds,
  }) async {
    savedUids.add(uid);

    final gate = saveGate;
    if (gate != null) {
      await gate.future;
    }
  }

  @override
  Future<void> clearAllProgressHistory(String uid) async {
    clearedUids.add(uid);

    final gate = clearGate;
    if (gate != null) {
      await gate.future;
    }
  }
}

Future<void> flushDeferredWork() async {
  await Future<void>.delayed(Duration.zero);
}

Map<String, DailyProgress> historyFor(
  String dateKey,
  List<String> completedIds,
) {
  return {
    dateKey: DailyProgress(dateKey: dateKey, completedHabitIds: completedIds),
  };
}

void main() {
  const habitA = Habit(id: 'habit-a', title: 'Account A habit');
  const habitB = Habit(id: 'habit-b', title: 'Account B habit');

  late ControlledProgressService storage;
  late ProgressProvider provider;

  setUp(() {
    storage = ControlledProgressService();
    provider = ProgressProvider(storage);
  });

  tearDown(() {
    provider.dispose();
  });

  Future<void> startAccount(String uid, Habit habit) async {
    provider.syncAccount(uid: uid, activeHabits: [habit], habitsReady: true);

    await flushDeferredWork();
    expect(storage.loads.containsKey(uid), isTrue);
  }

  Future<void> finishLoad(String uid, List<String> completedIds) async {
    storage.loads[uid]!.complete(historyFor(provider.todayKey, completedIds));

    await flushDeferredWork();
  }

  test('a pending load cannot restore progress after clear', () async {
    await startAccount('user-a', habitA);
    final dateKey = provider.todayKey;

    provider.clear();

    storage.loads['user-a']!.complete(historyFor(dateKey, [habitA.id]));
    await flushDeferredWork();

    expect(provider.habits, isEmpty);
    expect(provider.completedHabitIds, isEmpty);
    expect(provider.historyByDate, isEmpty);
    expect(provider.isLoaded, isFalse);
    expect(provider.isLoading, isFalse);
    expect(provider.loadError, isNull);
  });

  test('a delayed A load cannot overwrite loaded B progress', () async {
    await startAccount('user-a', habitA);
    await startAccount('user-b', habitB);

    await finishLoad('user-b', [habitB.id]);
    await finishLoad('user-a', [habitA.id]);

    expect(provider.habits, [habitB]);
    expect(provider.completedHabitIds, [habitB.id]);
    expect(provider.historyByDate[provider.todayKey]!.completedHabitIds, [
      habitB.id,
    ]);
    expect(provider.isLoaded, isTrue);
    expect(provider.isLoading, isFalse);
  });

  test('an old load cannot end the current account loading state', () async {
    await startAccount('user-a', habitA);
    await startAccount('user-b', habitB);

    await finishLoad('user-a', [habitA.id]);

    expect(provider.habits, [habitB]);
    expect(provider.historyByDate, isEmpty);
    expect(provider.completedHabitIds, isEmpty);
    expect(provider.isLoaded, isFalse);
    expect(provider.isLoading, isTrue);

    await finishLoad('user-b', [habitB.id]);

    expect(provider.completedHabitIds, [habitB.id]);
    expect(provider.isLoading, isFalse);
  });

  test('an old load error cannot become the new account error', () async {
    await startAccount('user-a', habitA);
    await startAccount('user-b', habitB);

    storage.loads['user-a']!.completeError(StateError('Account A load failed'));
    await flushDeferredWork();

    expect(provider.loadError, isNull);
    expect(provider.isLoading, isTrue);

    await finishLoad('user-b', [habitB.id]);

    expect(provider.loadError, isNull);
    expect(provider.completedHabitIds, [habitB.id]);
    expect(provider.isLoaded, isTrue);
  });

  test('a delayed A save cannot change B progress', () async {
    await startAccount('user-a', habitA);
    await finishLoad('user-a', []);

    storage.saveGate = Completer<void>();
    final savingA = provider.toggleHabit(habitA.id);

    expect(storage.savedUids, ['user-a']);

    await startAccount('user-b', habitB);
    await finishLoad('user-b', [habitB.id]);

    storage.saveGate!.complete();
    await savingA;

    expect(provider.habits, [habitB]);
    expect(provider.completedHabitIds, [habitB.id]);
    expect(provider.historyByDate[provider.todayKey]!.completedHabitIds, [
      habitB.id,
    ]);
  });

  test('a delayed A reset cannot clear B progress', () async {
    await startAccount('user-a', habitA);
    await finishLoad('user-a', [habitA.id]);

    storage.clearGate = Completer<void>();
    final clearingA = provider.clearAllProgress();

    expect(storage.clearedUids, ['user-a']);

    await startAccount('user-b', habitB);
    await finishLoad('user-b', [habitB.id]);

    storage.clearGate!.complete();
    await clearingA;

    expect(provider.completedHabitIds, [habitB.id]);
    expect(provider.historyByDate[provider.todayKey]!.completedHabitIds, [
      habitB.id,
    ]);
    expect(provider.isLoaded, isTrue);
  });

  test('progress waits until the habit catalog is ready', () async {
    provider.syncAccount(
      uid: 'user-a',
      activeHabits: const [],
      habitsReady: false,
    );
    await flushDeferredWork();

    expect(storage.loads, isEmpty);
    expect(provider.isLoaded, isFalse);

    provider.syncAccount(
      uid: 'user-a',
      activeHabits: const [],
      habitsReady: true,
    );
    await flushDeferredWork();

    expect(storage.loads.containsKey('user-a'), isTrue);

    storage.loads['user-a']!.complete({});
    await flushDeferredWork();

    expect(provider.isLoaded, isTrue);
    expect(provider.isLoading, isFalse);
    expect(provider.habits, isEmpty);
    expect(provider.completionPercent, 0);
  });

  test('a pending load does not notify after disposal', () async {
    final localStorage = ControlledProgressService();
    final localProvider = ProgressProvider(localStorage);
    var notifications = 0;

    localProvider.addListener(() {
      notifications++;
    });

    localProvider.syncAccount(
      uid: 'user-a',
      activeHabits: [habitA],
      habitsReady: true,
    );
    await flushDeferredWork();

    expect(localStorage.loads.containsKey('user-a'), isTrue);

    final notificationsBeforeDispose = notifications;
    localProvider.dispose();

    localStorage.loads['user-a']!.complete({});
    await flushDeferredWork();

    expect(notifications, notificationsBeforeDispose);
  });
}
