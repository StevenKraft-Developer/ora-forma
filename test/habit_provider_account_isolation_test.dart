import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:catholic_habits/models/habit.dart';
import 'package:catholic_habits/providers/habit_provider.dart';
import 'package:catholic_habits/services/firestore_habit_service.dart';

class ControlledHabitService implements FirestoreHabitService {
  final loads = <String, Completer<List<Habit>?>>{};
  final savedUids = <String>[];
  final savedHabitLists = <List<Habit>>[];
  final savedOnboardingFlags = <bool>[];
  Completer<void>? saveGate;

  @override
  Future<bool?> loadOnboardingComplete(String uid) async {
    throw UnsupportedError(
      'Onboarding status is not used by these habit-loading tests.',
    );
  }

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
    bool completeOnboarding = false,
  }) async {
    savedUids.add(uid);
    savedHabitLists.add(List<Habit>.from(habits));
    savedOnboardingFlags.add(completeOnboarding);

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

  Future<void> loadAccountA() async {
    final loading = provider.loadHabits('user-a');
    storage.loads['user-a']!.complete([habitA]);
    await loading;
  }

  test('onboarding publishes the selection only after saving', () async {
    await loadAccountA();
    storage.saveGate = Completer<void>();

    final saving = provider.seedFromOnboarding([habitB], uid: 'user-a');

    expect(provider.allHabits, [habitA]);
    expect(provider.isSavingOnboarding, isTrue);
    expect(storage.savedUids, ['user-a']);
    expect(storage.savedHabitLists.single, [habitB]);
    expect(storage.savedOnboardingFlags, [true]);

    storage.saveGate!.complete();

    expect(await saving, isTrue);
    expect(provider.allHabits, [habitB]);
    expect(provider.isSavingOnboarding, isFalse);
  });

  test('failed onboarding save preserves the current catalog', () async {
    await loadAccountA();
    storage.saveGate = Completer<void>();

    final saving = provider.seedFromOnboarding([habitB], uid: 'user-a');

    final expectation = expectLater(saving, throwsA(isA<StateError>()));

    storage.saveGate!.completeError(StateError('Test onboarding save failure'));

    await expectation;

    expect(provider.allHabits, [habitA]);
    expect(provider.isLoaded, isTrue);
    expect(provider.isSavingOnboarding, isFalse);
  });

  test('obsolete onboarding save cannot overwrite account B', () async {
    await loadAccountA();
    storage.saveGate = Completer<void>();

    final saving = provider.seedFromOnboarding([habitA], uid: 'user-a');

    final loadingB = provider.loadHabits('user-b');
    storage.loads['user-b']!.complete([habitB]);
    await loadingB;

    storage.saveGate!.complete();

    expect(await saving, isFalse);
    expect(storage.savedUids, ['user-a']);
    expect(provider.allHabits, [habitB]);
    expect(provider.isSavingOnboarding, isFalse);
  });

  test('same-UID new session rejects an old onboarding result', () async {
    await loadAccountA();
    storage.saveGate = Completer<void>();

    final saving = provider.seedFromOnboarding([habitA], uid: 'user-a');

    provider.clear();

    final reloading = provider.loadHabits('user-a');
    storage.loads['user-a']!.complete([habitB]);
    await reloading;

    storage.saveGate!.complete();

    expect(await saving, isFalse);
    expect(provider.allHabits, [habitB]);
    expect(provider.isSavingOnboarding, isFalse);
  });

  test('repeated onboarding submit does not start a second save', () async {
    await loadAccountA();
    storage.saveGate = Completer<void>();

    final first = provider.seedFromOnboarding([habitB], uid: 'user-a');

    final second = await provider.seedFromOnboarding([habitB], uid: 'user-a');

    expect(second, isFalse);
    expect(storage.savedUids, ['user-a']);

    storage.saveGate!.complete();

    expect(await first, isTrue);
    expect(provider.isSavingOnboarding, isFalse);
  });

  test('onboarding save does not notify after disposal', () async {
    final localStorage = ControlledHabitService();
    final localProvider = HabitProvider(localStorage);

    final loading = localProvider.loadHabits('user-a');
    localStorage.loads['user-a']!.complete([habitA]);
    await loading;

    localStorage.saveGate = Completer<void>();

    var notifications = 0;
    localProvider.addListener(() {
      notifications++;
    });

    final saving = localProvider.seedFromOnboarding([habitB], uid: 'user-a');

    expect(notifications, 1);

    localProvider.dispose();
    localStorage.saveGate!.complete();

    expect(await saving, isFalse);
    expect(notifications, 1);
  });
}
