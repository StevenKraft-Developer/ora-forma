import 'package:catholic_habits/home_screen.dart';
import 'package:catholic_habits/models/habit.dart';
import 'package:catholic_habits/providers/habit_provider.dart';
import 'package:catholic_habits/providers/progress_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _HomeHabits extends ChangeNotifier implements HabitProvider {
  _HomeHabits(this.catalog);

  final List<Habit> catalog;

  @override
  bool get isLoaded => true;

  @override
  List<Habit> get activeHabits =>
      catalog.where((habit) => !habit.isArchived).toList();

  @override
  List<Habit> get archivedHabits =>
      catalog.where((habit) => habit.isArchived).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected habit call: ${invocation.memberName}');
  }
}

class _HomeProgress extends ChangeNotifier implements ProgressProvider {
  _HomeProgress(this.totalCount);

  @override
  final int totalCount;

  final toggledIds = <String>[];

  @override
  bool get isLoaded => true;

  @override
  int get completedCount => 0;

  @override
  int get currentStreak => 0;

  @override
  ({int activeDays, int checkIns, int activeHabits}) weeklyRoutineSummary({
    DateTime? asOf,
  }) {
    return (activeDays: 0, checkIns: 0, activeHabits: totalCount);
  }

  // Empty history, without needing to construct progress records.
  @override
  Map<Never, Never> get historyByDate => const <Never, Never>{};

  @override
  bool isHabitCompleted(String habitId) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #toggleHabit) {
      toggledIds.add(invocation.positionalArguments.single as String);
      return Future<void>.value();
    }

    throw UnsupportedError(
      'Unexpected progress call: ${invocation.memberName}',
    );
  }
}

Future<_HomeProgress> _mountHome(
  WidgetTester tester,
  List<Habit> catalog,
) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final habits = _HomeHabits(catalog);
  final progress = _HomeProgress(habits.activeHabits.length);

  addTearDown(habits.dispose);
  addTearDown(progress.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<HabitProvider>.value(value: habits),
        ChangeNotifierProvider<ProgressProvider>.value(value: progress),
      ],
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    ),
  );

  await tester.pumpAndSettle();

  return progress;
}

void main() {
  const prayer = Habit(id: 'morning_prayer', title: 'Morning Prayer');

  const reading = Habit(
    id: 'bible_reading',
    title: 'Bible Reading',
    sortOrder: 1,
  );

  testWidgets('loaded empty catalog shows an empty state, not a spinner', (
    tester,
  ) async {
    await _mountHome(tester, []);

    expect(find.text('No habits have been added yet.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one active habit renders without fixed-index access', (
    tester,
  ) async {
    await _mountHome(tester, [prayer]);

    expect(
      find.byKey(const ValueKey('home-habit-morning_prayer')),
      findsOneWidget,
    );
    expect(find.text('0 of 1 complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two active habits render without fixed-index access', (
    tester,
  ) async {
    await _mountHome(tester, [prayer, reading]);

    expect(
      find.byKey(const ValueKey('home-habit-morning_prayer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-habit-bible_reading')),
      findsOneWidget,
    );
    expect(find.text('0 of 2 complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all archived catalog shows its own empty state', (tester) async {
    await _mountHome(tester, [prayer.copyWith(isArchived: true)]);

    expect(find.text('All your habits are archived.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-habit-morning_prayer')),
      findsNothing,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom habit renders and toggles by its actual ID', (
    tester,
  ) async {
    const custom = Habit(
      id: 'custom-examen',
      title: 'Personal Examen',
      description: 'Five quiet minutes',
    );

    final progress = await _mountHome(tester, [custom]);

    final card = find.byKey(const ValueKey('home-habit-custom-examen'));

    expect(card, findsOneWidget);
    expect(find.text('Personal Examen'), findsOneWidget);
    expect(find.text('Five quiet minutes'), findsOneWidget);

    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pump();

    expect(progress.toggledIds, ['custom-examen']);
    expect(tester.takeException(), isNull);
    expect(find.text('Days practiced'), findsOneWidget);
    expect(find.text('Check-ins'), findsOneWidget);
    expect(find.text('Active habits'), findsOneWidget);
    expect(find.text('Prayer rhythm'), findsNothing);
    expect(find.text('Meals on plan'), findsNothing);
    expect(find.text('Workouts'), findsNothing);
  });
}
