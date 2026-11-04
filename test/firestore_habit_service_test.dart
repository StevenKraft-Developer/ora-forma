import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:catholic_habits/models/habit.dart';
import 'package:catholic_habits/services/firestore_habit_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreHabitService service;

  const userA = 'user-a';
  const userB = 'user-b';

  const prayer = Habit(
    id: 'morning_prayer',
    title: 'Morning Prayer',
    sortOrder: 0,
  );

  const reading = Habit(
    id: 'bible_reading',
    title: 'Bible Reading',
    sortOrder: 1,
  );

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = FirestoreHabitService(firestore);
  });

  test('missing metadata returns no onboarding decision', () async {
    expect(await service.loadOnboardingComplete(userA), isNull);
  });

  test('initialized catalog alone does not imply completion', () async {
    await service.saveHabits(uid: userA, habits: [prayer]);

    expect(await service.loadOnboardingComplete(userA), isNull);
    expect(await service.loadHabits(userA), [prayer]);
  });

  test('explicit false remains distinct from missing completion', () async {
    await firestore.doc('users/$userA/meta/habits').set({
      'initialized': true,
      'onboardingCompleted': false,
    });

    expect(await service.loadOnboardingComplete(userA), isFalse);
  });

  test('invalid completion value throws rather than skipping setup', () async {
    await firestore.doc('users/$userA/meta/habits').set({
      'initialized': true,
      'onboardingCompleted': 'true',
    });

    await expectLater(
      service.loadOnboardingComplete(userA),
      throwsA(isA<FormatException>()),
    );
  });

  test('onboarding save replaces the catalog and records completion', () async {
    await service.saveHabits(uid: userA, habits: [prayer, reading]);

    final selectedReading = reading.copyWith(sortOrder: 0);

    await service.saveHabits(
      uid: userA,
      habits: [selectedReading],
      completeOnboarding: true,
    );

    expect(await service.loadHabits(userA), [selectedReading]);
    expect(await service.loadOnboardingComplete(userA), isTrue);

    final removedHabit = await firestore
        .doc('users/$userA/habits/${prayer.id}')
        .get();

    expect(removedHabit.exists, isFalse);

    final metadata = await firestore.doc('users/$userA/meta/habits').get();

    expect(metadata.data()!['initialized'], isTrue);
    expect(metadata.data()!['onboardingCompleted'], isTrue);
  });

  test('normal save preserves completion and unrelated metadata', () async {
    await firestore.doc('users/$userA/meta/habits').set({
      'initialized': true,
      'onboardingCompleted': true,
      'marker': 'preserve-me',
    });

    await service.saveHabits(uid: userA, habits: [prayer]);

    final metadata = await firestore.doc('users/$userA/meta/habits').get();

    expect(metadata.data()!['onboardingCompleted'], isTrue);
    expect(metadata.data()!['marker'], 'preserve-me');
    expect(await service.loadHabits(userA), [prayer]);
  });

  test('saving account A does not change account B', () async {
    await service.saveHabits(uid: userB, habits: [reading]);

    await service.saveHabits(
      uid: userA,
      habits: [prayer],
      completeOnboarding: true,
    );

    expect(await service.loadHabits(userA), [prayer]);
    expect(await service.loadOnboardingComplete(userA), isTrue);

    expect(await service.loadHabits(userB), [reading]);
    expect(await service.loadOnboardingComplete(userB), isNull);
  });

  test('empty initialized catalog stays empty on reload', () async {
    await service.saveHabits(
      uid: userA,
      habits: [prayer],
      completeOnboarding: true,
    );

    await service.saveHabits(uid: userA, habits: []);

    expect(await service.loadHabits(userA), isEmpty);
    expect(await service.loadOnboardingComplete(userA), isTrue);
  });
}
