import 'package:catholic_habits/models/daily_progress.dart';
import 'package:catholic_habits/models/habit.dart';
import 'package:catholic_habits/providers/progress_provider.dart';
import 'package:catholic_habits/services/firestore_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _HistoryService implements FirestoreProgressService {
  _HistoryService(this.history);

  final Map<String, DailyProgress> history;

  @override
  Future<Map<String, DailyProgress>> loadHistory(String uid) async {
    return Map<String, DailyProgress>.from(history);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected progress service call: ${invocation.memberName}',
    );
  }
}

Future<ProgressProvider> _loadedProvider({
  required List<Habit> habits,
  required Map<String, DailyProgress> history,
}) async {
  final provider = ProgressProvider(_HistoryService(history));
  addTearDown(provider.dispose);

  provider.syncAccount(
    uid: 'summary-user',
    activeHabits: habits,
    habitsReady: true,
  );

  await Future<void>.delayed(Duration.zero);

  expect(provider.isLoaded, isTrue);

  return provider;
}

void main() {
  const prayer = Habit(id: 'morning_prayer', title: 'Morning Prayer');

  const custom = Habit(
    id: 'custom-examen',
    title: 'Personal Examen',
    sortOrder: 1,
  );

  test(
    'counts active routine IDs once per day without changing history',
    () async {
      final history = {
        '2026-11-01': DailyProgress(
          dateKey: '2026-11-01',
          completedHabitIds: [prayer.id, prayer.id, 'archived-habit'],
        ),
        '2026-11-02': DailyProgress(
          dateKey: '2026-11-02',
          completedHabitIds: ['deleted-habit'],
        ),
        '2026-11-04': DailyProgress(
          dateKey: '2026-11-04',
          completedHabitIds: [prayer.id, custom.id],
        ),
        '2026-11-05': DailyProgress(
          dateKey: '2026-11-05',
          completedHabitIds: [prayer.id, custom.id],
        ),
        '2026-10-31': DailyProgress(
          dateKey: '2026-10-31',
          completedHabitIds: [prayer.id],
        ),
      };

      final provider = await _loadedProvider(
        habits: [prayer, custom],
        history: history,
      );

      final summary = provider.weeklyRoutineSummary(
        asOf: DateTime(2026, 11, 4),
      );

      expect(summary.activeDays, 2);
      expect(summary.checkIns, 3);
      expect(summary.activeHabits, 2);

      expect(provider.historyByDate['2026-11-01']!.completedHabitIds, [
        prayer.id,
        prayer.id,
        'archived-habit',
      ]);
      expect(provider.historyByDate, hasLength(5));
    },
  );

  test('empty active routine ignores stored historical check-ins', () async {
    final provider = await _loadedProvider(
      habits: [],
      history: {
        '2026-11-04': DailyProgress(
          dateKey: '2026-11-04',
          completedHabitIds: [prayer.id],
        ),
      },
    );

    final summary = provider.weeklyRoutineSummary(asOf: DateTime(2026, 11, 4));

    expect(summary.activeDays, 0);
    expect(summary.checkIns, 0);
    expect(summary.activeHabits, 0);
    expect(provider.historyByDate, hasLength(1));
  });

  test('Sunday includes only Sunday, not Saturday or future Monday', () async {
    final provider = await _loadedProvider(
      habits: [prayer],
      history: {
        for (final key in ['2026-10-31', '2026-11-01', '2026-11-02'])
          key: DailyProgress(dateKey: key, completedHabitIds: [prayer.id]),
      },
    );

    final summary = provider.weeklyRoutineSummary(asOf: DateTime(2026, 11, 1));

    expect(summary.activeDays, 1);
    expect(summary.checkIns, 1);
    expect(summary.activeHabits, 1);
  });

  test(
    'changing the active routine recalculates without deleting history',
    () async {
      final provider = await _loadedProvider(
        habits: [prayer, custom],
        history: {
          '2026-11-04': DailyProgress(
            dateKey: '2026-11-04',
            completedHabitIds: [prayer.id, custom.id],
          ),
        },
      );

      expect(
        provider.weeklyRoutineSummary(asOf: DateTime(2026, 11, 4)).checkIns,
        2,
      );

      provider.syncAccount(
        uid: 'summary-user',
        activeHabits: [custom],
        habitsReady: true,
      );

      await Future<void>.delayed(Duration.zero);

      final summary = provider.weeklyRoutineSummary(
        asOf: DateTime(2026, 11, 4),
      );

      expect(summary.activeDays, 1);
      expect(summary.checkIns, 1);
      expect(summary.activeHabits, 1);

      expect(provider.historyByDate['2026-11-04']!.completedHabitIds, [
        prayer.id,
        custom.id,
      ]);
    },
  );
}
