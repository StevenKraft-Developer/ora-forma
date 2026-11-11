import 'dart:async';

import 'package:catholic_habits/models/habit.dart';
import 'package:catholic_habits/providers/habit_provider.dart';
import 'package:catholic_habits/services/firestore_habit_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _first = Habit(
  id: 'first',
  title: 'First habit',
  description: 'Existing description',
  sortOrder: 0,
);

const _second = Habit(id: 'second', title: 'Second habit', sortOrder: 1);

const _archived = Habit(
  id: 'archived',
  title: 'Archived habit',
  description: 'Preserve this',
  sortOrder: 7,
  isArchived: true,
);

const _catalog = [_first, _second, _archived];

class _MutationService implements FirestoreHabitService {
  final catalogs = <String, List<Habit>>{
    'user-a': List<Habit>.from(_catalog),
    'user-b': const [Habit(id: 'b-only', title: 'Account B habit')],
  };

  final savedUids = <String>[];
  final savedCatalogs = <List<Habit>>[];
  final completionFlags = <bool>[];

  Completer<void>? saveGate;

  @override
  Future<List<Habit>?> loadHabits(String uid) async {
    return List<Habit>.from(catalogs[uid] ?? const []);
  }

  @override
  Future<bool?> loadOnboardingComplete(String uid) async => null;

  @override
  Future<void> saveHabits({
    required String uid,
    required List<Habit> habits,
    bool completeOnboarding = false,
  }) async {
    final snapshot = List<Habit>.from(habits);

    savedUids.add(uid);
    savedCatalogs.add(snapshot);
    completionFlags.add(completeOnboarding);

    final gate = saveGate;
    if (gate != null) await gate.future;

    catalogs[uid] = snapshot;
  }
}

typedef _Mutation = Future<bool> Function(HabitProvider provider);

final _mutations = <String, _Mutation>{
  'add': (provider) => provider.addHabit(uid: 'user-a', title: 'New habit'),
  'edit': (provider) => provider.updateHabit(
    uid: 'user-a',
    habitId: _first.id,
    title: 'Updated habit',
    description: null,
  ),
  'archive': (provider) => provider.archiveHabit(_first.id, uid: 'user-a'),
  'restore': (provider) => provider.unarchiveHabit(_archived.id, uid: 'user-a'),
};

void main() {
  late _MutationService storage;
  late HabitProvider provider;

  setUp(() async {
    storage = _MutationService();
    provider = HabitProvider(storage);

    await provider.loadHabits('user-a');
  });

  tearDown(() {
    provider.dispose();
  });

  test('add trims values and appends before archived habits', () async {
    final result = await provider.addHabit(
      uid: 'user-a',
      title: '  Personal Examen  ',
      description: '  Five quiet minutes  ',
    );

    expect(result, isTrue);

    final added = provider.activeHabits.last;

    expect(added.id, isNotEmpty);
    expect(_catalog.map((habit) => habit.id), isNot(contains(added.id)));
    expect(added.title, 'Personal Examen');
    expect(added.description, 'Five quiet minutes');
    expect(added.sortOrder, 2);
    expect(added.isArchived, isFalse);
    expect(provider.archivedHabits, [_archived]);
    expect(storage.savedUids, ['user-a']);
    expect(storage.completionFlags, [false]);
  });

  test('edit clears a blank description and preserves identity', () async {
    final result = await provider.updateHabit(
      uid: 'user-a',
      habitId: _first.id,
      title: '  Renamed habit  ',
      description: '   ',
    );

    expect(result, isTrue);

    final updated = provider.activeHabits.first;

    expect(updated.id, _first.id);
    expect(updated.title, 'Renamed habit');
    expect(updated.description, isNull);
    expect(updated.sortOrder, _first.sortOrder);
    expect(updated.isArchived, _first.isArchived);
    expect(provider.activeHabits[1], _second);
    expect(provider.archivedHabits, [_archived]);
    expect(storage.completionFlags, [false]);
  });

  test('archive retains the entry and normalizes active order', () async {
    final result = await provider.archiveHabit(_first.id, uid: 'user-a');

    expect(result, isTrue);
    expect(provider.activeHabits, [_second.copyWith(sortOrder: 0)]);
    expect(
      provider.archivedHabits,
      contains(_first.copyWith(isArchived: true)),
    );
    expect(provider.archivedHabits, contains(_archived));
    expect(provider.allHabits, hasLength(3));
    expect(storage.completionFlags, [false]);
  });

  test('restore appends the same habit to the active routine', () async {
    final result = await provider.unarchiveHabit(_archived.id, uid: 'user-a');

    expect(result, isTrue);
    expect(provider.activeHabits, [
      _first,
      _second,
      _archived.copyWith(isArchived: false, sortOrder: 2),
    ]);
    expect(provider.archivedHabits, isEmpty);
    expect(storage.completionFlags, [false]);
  });

  for (final entry in _mutations.entries) {
    test(
      '${entry.key} preserves visible state when persistence fails',
      () async {
        storage.saveGate = Completer<void>();

        final saving = entry.value(provider);

        expect(provider.isSaving, isTrue);
        expect(provider.allHabits, _catalog);

        final expectation = expectLater(saving, throwsA(isA<StateError>()));

        storage.saveGate!.completeError(StateError('Test mutation failure'));

        await expectation;

        expect(provider.allHabits, _catalog);
        expect(storage.catalogs['user-a'], _catalog);
        expect(provider.isSaving, isFalse);
      },
    );

    test('obsolete ${entry.key} cannot publish into account B', () async {
      storage.saveGate = Completer<void>();

      final saving = entry.value(provider);

      await provider.loadHabits('user-b');

      final accountBCatalog = provider.allHabits;

      storage.saveGate!.complete();

      expect(await saving, isFalse);
      expect(storage.savedUids, ['user-a']);
      expect(provider.allHabits, accountBCatalog);
      expect(provider.allHabits.single.id, 'b-only');
      expect(storage.catalogs['user-b'], accountBCatalog);
      expect(provider.isSaving, isFalse);
    });
  }

  final invalidMutations = <String, _Mutation>{
    'blank add title': (provider) =>
        provider.addHabit(uid: 'user-a', title: ' \t\n '),
    'long add title': (provider) =>
        provider.addHabit(uid: 'user-a', title: List.filled(101, 'x').join()),
    'long add description': (provider) => provider.addHabit(
      uid: 'user-a',
      title: 'Valid title',
      description: List.filled(301, 'x').join(),
    ),
    'blank edit title': (provider) => provider.updateHabit(
      uid: 'user-a',
      habitId: _first.id,
      title: '   ',
      description: null,
    ),
    'long edit description': (provider) => provider.updateHabit(
      uid: 'user-a',
      habitId: _first.id,
      title: 'Valid title',
      description: List.filled(301, 'x').join(),
    ),
  };

  for (final entry in invalidMutations.entries) {
    test('${entry.key} is rejected without saving', () async {
      expect(await entry.value(provider), isFalse);
      expect(storage.savedUids, isEmpty);
      expect(provider.allHabits, _catalog);
      expect(provider.isSaving, isFalse);
    });
  }

  test('management save blocks other mutations and onboarding', () async {
    storage.saveGate = Completer<void>();

    final saving = provider.addHabit(uid: 'user-a', title: 'Pending habit');

    for (final mutation in _mutations.values) {
      expect(await mutation(provider), isFalse);
    }

    expect(await provider.seedFromOnboarding([_first], uid: 'user-a'), isFalse);

    expect(await provider.deleteHabit(_second.id, uid: 'user-a'), isFalse);
    expect(await provider.reorderHabits(0, 2, uid: 'user-a'), isFalse);

    expect(storage.savedUids, ['user-a']);
    expect(provider.allHabits, _catalog);

    storage.saveGate!.complete();

    expect(await saving, isTrue);
    expect(provider.isSaving, isFalse);
    expect(provider.activeHabits, hasLength(3));
  });

  test('onboarding save blocks management mutations', () async {
    storage.saveGate = Completer<void>();

    final saving = provider.seedFromOnboarding([_first], uid: 'user-a');

    for (final mutation in _mutations.values) {
      expect(await mutation(provider), isFalse);
    }

    expect(storage.savedUids, ['user-a']);
    expect(storage.completionFlags, [true]);

    storage.saveGate!.complete();

    expect(await saving, isTrue);
    expect(provider.isSaving, isFalse);
  });

  test('mutation does not notify or publish after disposal', () async {
    final localStorage = _MutationService();
    final localProvider = HabitProvider(localStorage);

    await localProvider.loadHabits('user-a');

    localStorage.saveGate = Completer<void>();

    var notifications = 0;
    localProvider.addListener(() => notifications++);

    final saving = localProvider.archiveHabit(_first.id, uid: 'user-a');

    expect(notifications, 1);

    localProvider.dispose();
    localStorage.saveGate!.complete();

    expect(await saving, isFalse);
    expect(notifications, 1);
  });

  test('wrong-account and signed-out mutations do not save', () async {
    expect(
      await provider.addHabit(uid: 'user-b', title: 'Wrong account'),
      isFalse,
    );

    provider.clear();

    for (final mutation in _mutations.values) {
      expect(await mutation(provider), isFalse);
    }

    expect(storage.savedUids, isEmpty);
    expect(provider.allHabits, isEmpty);
  });
}
