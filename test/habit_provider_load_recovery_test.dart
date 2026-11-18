import 'dart:async';

import 'package:catholic_habits/models/habit.dart';
import 'package:catholic_habits/providers/habit_provider.dart';
import 'package:catholic_habits/services/firestore_habit_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _habitA = Habit(id: 'a-only', title: 'Account A habit');
const _habitB = Habit(id: 'b-only', title: 'Account B habit');

class _RecoveryStorage implements FirestoreHabitService {
  final loadUids = <String>[];
  final savedUids = <String>[];

  Future<List<Habit>?> Function(String uid) onLoad = (_) async => const [
    _habitA,
  ];

  bool failSave = false;

  @override
  Future<List<Habit>?> loadHabits(String uid) {
    loadUids.add(uid);
    return onLoad(uid);
  }

  @override
  Future<bool?> loadOnboardingComplete(String uid) async => null;

  @override
  Future<void> saveHabits({
    required String uid,
    required List<Habit> habits,
    bool completeOnboarding = false,
  }) async {
    savedUids.add(uid);

    if (failSave) {
      throw StateError('Test seed save failure');
    }
  }
}

void main() {
  late _RecoveryStorage storage;
  late HabitProvider provider;

  setUp(() {
    storage = _RecoveryStorage();
    provider = HabitProvider(storage);
  });

  tearDown(() {
    provider.dispose();
  });

  Future<void> failInitialLoad() async {
    storage.onLoad = (_) async {
      throw StateError('Test load failure');
    };

    await provider.loadHabits('user-a');
  }

  test('failed read exposes an error without seeding a catalog', () async {
    await failInitialLoad();

    expect(provider.isLoading, isFalse);
    expect(provider.isLoaded, isFalse);
    expect(provider.loadError, isNotNull);
    expect(provider.allHabits, isEmpty);
    expect(storage.loadUids, ['user-a']);
    expect(storage.savedUids, isEmpty);
  });

  test(
    'ordinary account sync does not automatically retry a failure',
    () async {
      await failInitialLoad();

      final error = provider.loadError;

      storage.onLoad = (_) async => const [_habitA];

      await provider.loadHabits('user-a');

      expect(storage.loadUids, ['user-a']);
      expect(provider.loadError, error);
      expect(provider.isLoaded, isFalse);
    },
  );

  test('explicit retry clears the error and loads the catalog', () async {
    await failInitialLoad();

    final pending = Completer<List<Habit>?>();
    storage.onLoad = (_) => pending.future;

    final retry = provider.retryLoadHabits('user-a');

    expect(provider.isLoading, isTrue);
    expect(provider.isLoaded, isFalse);
    expect(provider.loadError, isNull);

    pending.complete(const [_habitA]);
    await retry;

    expect(storage.loadUids, ['user-a', 'user-a']);
    expect(storage.savedUids, isEmpty);
    expect(provider.allHabits, const [_habitA]);
    expect(provider.isLoading, isFalse);
    expect(provider.isLoaded, isTrue);
    expect(provider.loadError, isNull);
  });

  test(
    'duplicate and wrong-account retries do not start extra loads',
    () async {
      await failInitialLoad();

      await provider.retryLoadHabits('user-b');

      expect(storage.loadUids, ['user-a']);
      expect(provider.loadError, isNotNull);

      final pending = Completer<List<Habit>?>();
      storage.onLoad = (_) => pending.future;

      final retry = provider.retryLoadHabits('user-a');

      await provider.retryLoadHabits('user-a');
      await provider.retryLoadHabits('user-b');

      expect(storage.loadUids, ['user-a', 'user-a']);

      pending.complete(const [_habitA]);
      await retry;

      await provider.retryLoadHabits('user-a');

      expect(storage.loadUids, ['user-a', 'user-a']);
      expect(provider.allHabits, const [_habitA]);
    },
  );

  test(
    'a failed retry exposes the error and permits another attempt',
    () async {
      await failInitialLoad();

      await provider.retryLoadHabits('user-a');

      expect(provider.isLoading, isFalse);
      expect(provider.isLoaded, isFalse);
      expect(provider.loadError, isNotNull);
      expect(storage.loadUids, ['user-a', 'user-a']);

      storage.onLoad = (_) async => const [_habitA];

      await provider.retryLoadHabits('user-a');

      expect(provider.isLoaded, isTrue);
      expect(provider.loadError, isNull);
      expect(provider.allHabits, const [_habitA]);
      expect(storage.loadUids, ['user-a', 'user-a', 'user-a']);
    },
  );

  test('an empty catalog is a successful load, not an error', () async {
    storage.onLoad = (_) async => const <Habit>[];

    await provider.loadHabits('user-a');

    expect(provider.isLoaded, isTrue);
    expect(provider.isLoading, isFalse);
    expect(provider.loadError, isNull);
    expect(provider.allHabits, isEmpty);
    expect(storage.savedUids, isEmpty);
  });

  test(
    'failed initial seeding stays unavailable until retry succeeds',
    () async {
      storage.onLoad = (_) async => null;
      storage.failSave = true;

      await provider.loadHabits('user-a');

      expect(provider.isLoaded, isFalse);
      expect(provider.isLoading, isFalse);
      expect(provider.loadError, isNotNull);
      expect(provider.allHabits, isEmpty);
      expect(storage.savedUids, ['user-a']);

      storage.failSave = false;

      await provider.retryLoadHabits('user-a');

      expect(provider.isLoaded, isTrue);
      expect(provider.loadError, isNull);
      expect(provider.allHabits, isNotEmpty);
      expect(storage.savedUids, ['user-a', 'user-a']);
    },
  );

  for (final failObsoleteRetry in [false, true]) {
    test(
      failObsoleteRetry
          ? 'obsolete retry failure cannot publish an error into account B'
          : 'obsolete retry success cannot publish habits into account B',
      () async {
        await failInitialLoad();

        final pending = Completer<List<Habit>?>();

        storage.onLoad = (uid) {
          if (uid == 'user-a') return pending.future;
          return Future.value(const [_habitB]);
        };

        final retry = provider.retryLoadHabits('user-a');

        await provider.loadHabits('user-b');

        expect(provider.allHabits, const [_habitB]);
        expect(provider.isLoaded, isTrue);

        if (failObsoleteRetry) {
          pending.completeError(StateError('Obsolete retry failure'));
        } else {
          pending.complete(const [_habitA]);
        }

        await retry;

        expect(provider.allHabits, const [_habitB]);
        expect(provider.isLoaded, isTrue);
        expect(provider.isLoading, isFalse);
        expect(provider.loadError, isNull);
        expect(storage.savedUids, isEmpty);
      },
    );
  }

  test(
    'sign-out clears the load error and disables old-account retry',
    () async {
      await failInitialLoad();

      provider.clear();

      expect(provider.loadError, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.isLoaded, isFalse);
      expect(provider.allHabits, isEmpty);

      await provider.retryLoadHabits('user-a');

      expect(storage.loadUids, ['user-a']);
    },
  );
}
