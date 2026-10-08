import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:catholic_habits/models/habit.dart';
import 'package:catholic_habits/providers/habit_provider.dart';
import 'package:catholic_habits/services/firestore_habit_service.dart';

class ControlledHabitService implements FirestoreHabitService {
  final loads = <String, Completer<List<Habit>?>>{};
  final savedUids = <String>[];
  Completer<void>? saveGate;

  @override
  Future<List<Habit>?> loadHabits(String uid) {
    final pending = Completer<List<Habit>?>();
    loads[uid] = pending;
    return pending.future;
  }

  @override
  Future<void> saveHabits({
    required String uid,
    required List<Habit> habits,
  }) async {
    savedUids.add(uid);

    final gate = saveGate;
    if (gate != null) {
      await gate.future;
    }
  }
}

void main() {
  const habitA = Habit(id: 'habit-a', title: 'Account A habit');
  const habitB = Habit(id: 'habit-b', title: 'Account B habit');

  late ControlledHabitService storage;
  late HabitProvider provider;

  setUp(() {
    storage = ControlledHabitService();
    provider = HabitProvider(storage);
  });

  tearDown(() {
    provider.dispose();
  });

  test('a pending load cannot restore habits after clear', () async {
    final loadingA = provider.loadHabits('user-a');

    provider.clear();
    storage.loads['user-a']!.complete([habitA]);

    await loadingA;

    expect(provider.allHabits, isEmpty);
    expect(provider.isLoaded, isFalse);
    expect(provider.isLoading, isFalse);
  });

  test('a delayed A load cannot overwrite loaded B habits', () async {
    final loadingA = provider.loadHabits('user-a');
    final loadingB = provider.loadHabits('user-b');

    storage.loads['user-b']!.complete([habitB]);
    await loadingB;

    storage.loads['user-a']!.complete([habitA]);
    await loadingA;

    expect(provider.allHabits, [habitB]);
    expect(provider.isLoaded, isTrue);
    expect(provider.isLoading, isFalse);
  });

  test('an old load cannot end the current account loading state', () async {
    final loadingA = provider.loadHabits('user-a');
    final loadingB = provider.loadHabits('user-b');

    storage.loads['user-a']!.complete([habitA]);
    await loadingA;

    expect(provider.allHabits, isEmpty);
    expect(provider.isLoaded, isFalse);
    expect(provider.isLoading, isTrue);

    storage.loads['user-b']!.complete([habitB]);
    await loadingB;

    expect(provider.allHabits, [habitB]);
    expect(provider.isLoading, isFalse);
  });

  test(
    'an obsolete missing catalog does not trigger default seeding',
    () async {
      final loadingA = provider.loadHabits('user-a');

      provider.clear();
      storage.loads['user-a']!.complete(null);

      await loadingA;

      expect(storage.savedUids, isEmpty);
      expect(provider.allHabits, isEmpty);
    },
  );

  test('delayed default persistence cannot restore cleared state', () async {
    storage.saveGate = Completer<void>();
    final loadingA = provider.loadHabits('user-a');

    storage.loads['user-a']!.complete(null);
    await Future<void>.delayed(Duration.zero);

    expect(storage.savedUids, ['user-a']);

    provider.clear();
    storage.saveGate!.complete();

    await loadingA;

    expect(provider.allHabits, isEmpty);
    expect(provider.isLoaded, isFalse);
    expect(provider.isLoading, isFalse);
  });

  test('a pending load does not notify after disposal', () async {
    final localStorage = ControlledHabitService();
    final localProvider = HabitProvider(localStorage);
    var notifications = 0;

    localProvider.addListener(() {
      notifications++;
    });

    final loading = localProvider.loadHabits('user-a');
    expect(notifications, 1);

    localProvider.dispose();
    localStorage.loads['user-a']!.complete([habitA]);

    await loading;

    expect(notifications, 1);
  });
}
