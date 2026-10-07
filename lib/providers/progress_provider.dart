import 'package:flutter/foundation.dart';

import '../models/daily_progress.dart';
import '../models/habit.dart';
import '../services/firestore_progress_service.dart';

class ProgressProvider extends ChangeNotifier {
  ProgressProvider(this._storage);

  final FirestoreProgressService _storage;

  String? _uid;
  bool _isLoading = false;
  bool _habitsReady = false;
  bool _isDisposed = false;
  int _sessionVersion = 0;
  String? _loadError;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  // ---------------------------------------------------------------------------
  // Active habit list — injected by HabitProvider via updateActiveHabits().
  // Replaces the old hardcoded const list.
  // ProgressProvider no longer owns the habit catalog; it only owns completion
  // state and history.
  // ---------------------------------------------------------------------------
  List<Habit> _activeHabits = [];

  /// The current active habit list. Read-only outside this provider.
  /// Screens that need this list should read from HabitProvider.activeHabits
  /// directly (Task 8); this getter exists so existing progress calculations
  /// and screen references that use progress.habits keep compiling during
  /// the transition.
  List<Habit> get habits => List.unmodifiable(_activeHabits);

  /// Called by the ChangeNotifierProxyProvider in main.dart whenever
  /// HabitProvider notifies. Updates the active habit list and triggers a
  /// progress reload if this is the first time habits arrive.

  /// Receives account identity and habit-catalog readiness together.
  ///
  /// An empty active list is valid once the catalog has finished loading.
  void syncAccount({
    required String? uid,
    required List<Habit> activeHabits,
    required bool habitsReady,
  }) {
    if (_isDisposed) return;

    final accountChanged = _uid != uid;
    final nextHabits = uid == null ? <Habit>[] : List<Habit>.from(activeHabits);
    final nextReady = uid != null && habitsReady;

    final inputsChanged =
        accountChanged ||
        _habitsReady != nextReady ||
        !listEquals(_activeHabits, nextHabits);

    if (accountChanged) {
      _sessionVersion++;
      _uid = uid;
      _completedHabitIds = [];
      _historyByDate = {};
      _isLoaded = false;
      _isLoading = false;
      _loadError = null;
    }

    _activeHabits = nextHabits;
    _habitsReady = nextReady;

    if (_isLoaded) {
      _refreshActiveCompletions();
    }

    final version = _sessionVersion;

    // Defer notifications and loading until after this synchronous proxy update.
    Future.microtask(() async {
      if (!_isCurrentSession(version, uid)) return;

      if (inputsChanged) {
        notifyListeners();
      }

      if (_uid != null &&
          _habitsReady &&
          !_isLoaded &&
          !_isLoading &&
          _loadError == null) {
        await loadTodayProgress();
      }
    });
  }

  void clear() {
    syncAccount(uid: null, activeHabits: const [], habitsReady: false);
  }

  bool _isCurrentSession(int version, String? uid) {
    return !_isDisposed && version == _sessionVersion && uid == _uid;
  }

  /// Derives selectable completions without changing stored history.
  void _refreshActiveCompletions() {
    final activeIds = _activeHabits.map((habit) => habit.id).toSet();
    final savedIds =
        _historyByDate[todayKey]?.completedHabitIds ?? const <String>[];

    _completedHabitIds = savedIds.where(activeIds.contains).toSet().toList();
  }

  List<String> _completedHabitIds = [];
  Map<String, DailyProgress> _historyByDate = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<String> get completedHabitIds => List.unmodifiable(_completedHabitIds);
  Map<String, DailyProgress> get historyByDate =>
      Map.unmodifiable(_historyByDate);

  int get completedCount => _completedHabitIds.length;
  int get totalCount => _activeHabits.length;
  double get completionPercent =>
      _activeHabits.isEmpty ? 0 : completedCount / totalCount;

  int currentStreakForHabit(String habitId) {
    final now = DateTime.now();
    int streak = 0;

    for (int i = 0; i < 365; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final key = _dateKeyFor(date);
      final progress = _historyByDate[key];

      final completed = progress?.completedHabitIds.contains(habitId) ?? false;

      if (completed) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  int longestStreakForHabit(String habitId) {
    final completedDates =
        _historyByDate.values
            .where((progress) => progress.completedHabitIds.contains(habitId))
            .map((progress) {
              final parts = progress.dateKey.split('-');
              return DateTime(
                int.parse(parts[0]),
                int.parse(parts[1]),
                int.parse(parts[2]),
              );
            })
            .toList()
          ..sort();

    if (completedDates.isEmpty) return 0;

    int longest = 1;
    int current = 1;

    for (int i = 1; i < completedDates.length; i++) {
      final previous = completedDates[i - 1];
      final currentDate = completedDates[i];
      final difference = currentDate.difference(previous).inDays;

      if (difference == 1) {
        current++;
        if (current > longest) {
          longest = current;
        }
      } else if (difference > 1) {
        current = 1;
      }
    }

    return longest;
  }

  int currentStreakForHabits(List<String> habitIds) {
    if (habitIds.isEmpty) return 0;

    final now = DateTime.now();
    int streak = 0;

    for (int i = 0; i < 365; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final key = _dateKeyFor(date);
      final progress = _historyByDate[key];
      final completedIds = progress?.completedHabitIds ?? const <String>[];

      final completedAll = habitIds.every((id) => completedIds.contains(id));

      if (completedAll) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  int longestStreakForHabits(List<String> habitIds) {
    if (habitIds.isEmpty) return 0;

    final completedDates =
        _historyByDate.values
            .where(
              (progress) => habitIds.every(
                (id) => progress.completedHabitIds.contains(id),
              ),
            )
            .map((progress) {
              final parts = progress.dateKey.split('-');
              return DateTime(
                int.parse(parts[0]),
                int.parse(parts[1]),
                int.parse(parts[2]),
              );
            })
            .toList()
          ..sort();

    if (completedDates.isEmpty) return 0;

    int longest = 1;
    int current = 1;

    for (int i = 1; i < completedDates.length; i++) {
      final previous = completedDates[i - 1];
      final currentDate = completedDates[i];
      final difference = currentDate.difference(previous).inDays;

      if (difference == 1) {
        current++;
        if (current > longest) {
          longest = current;
        }
      } else if (difference > 1) {
        current = 1;
      }
    }

    return longest;
  }

  String get todayKey => _dateKeyFor(DateTime.now());
  DateTime _startOfWeekSunday(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final daysFromSunday = date.weekday % 7;
    return normalized.subtract(Duration(days: daysFromSunday));
  }

  bool isHabitCompleted(String habitId) {
    return _completedHabitIds.contains(habitId);
  }

  List<bool> get thisWeekCompletion {
    final startOfWeek = _startOfWeekSunday(DateTime.now());

    return List.generate(7, (index) {
      final date = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day + index,
      );
      final key = _dateKeyFor(date);
      final progress = _historyByDate[key];
      return (progress?.completedHabitIds.length ?? 0) > 0;
    });
  }

  int get completedThisWeek {
    final startOfWeek = _startOfWeekSunday(DateTime.now());
    int total = 0;

    for (int i = 0; i < 7; i++) {
      final date = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day + i,
      );
      final key = _dateKeyFor(date);
      total += _historyByDate[key]?.completedHabitIds.length ?? 0;
    }

    return total;
  }

  int get totalThisWeek {
    if (_activeHabits.isEmpty) return 0;
    // Use days elapsed this week (Sun=1 … Sat=7) so the denominator reflects
    // what was actually trackable, not a fixed 7×N.
    final daysElapsed = (DateTime.now().weekday % 7) + 1;
    return _activeHabits.length * daysElapsed;
  }

  double get weeklyCompletionPercent =>
      totalThisWeek == 0 ? 0 : completedThisWeek / totalThisWeek;

  int get currentStreak {
    final now = DateTime.now();
    int streak = 0;

    for (int i = 0; i < 365; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final key = _dateKeyFor(date);
      final progress = _historyByDate[key];

      if (progress != null && progress.completedHabitIds.isNotEmpty) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  int get longestStreak {
    if (_historyByDate.isEmpty) return 0;

    final completedDates =
        _historyByDate.values
            .where((progress) => progress.completedHabitIds.isNotEmpty)
            .map((progress) {
              final parts = progress.dateKey.split('-');
              return DateTime(
                int.parse(parts[0]),
                int.parse(parts[1]),
                int.parse(parts[2]),
              );
            })
            .toList()
          ..sort();

    if (completedDates.isEmpty) return 0;

    int longest = 1;
    int current = 1;

    for (int i = 1; i < completedDates.length; i++) {
      final previous = completedDates[i - 1];
      final currentDate = completedDates[i];
      final difference = currentDate.difference(previous).inDays;

      if (difference == 1) {
        current++;
        if (current > longest) {
          longest = current;
        }
      } else if (difference > 1) {
        current = 1;
      }
    }

    return longest;
  }

  Future<void> loadTodayProgress() async {
    final uid = _uid;

    if (_isDisposed ||
        uid == null ||
        !_habitsReady ||
        _isLoading ||
        _isLoaded) {
      return;
    }

    final version = _sessionVersion;
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      final history = await _storage.loadHistory(uid);

      if (!_isCurrentSession(version, uid)) return;

      _historyByDate = history;
      _refreshActiveCompletions();
      _isLoaded = true;
    } catch (error, stackTrace) {
      if (!_isCurrentSession(version, uid)) return;

      _loadError = 'Could not load your progress. Please try again.';
      debugPrint('Progress load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (_isCurrentSession(version, uid)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> retryLoad() async {
    if (_isDisposed || _uid == null || !_habitsReady || _isLoading) {
      return;
    }

    _loadError = null;
    await loadTodayProgress();
  }

  Future<void> toggleHabit(String habitId) async {
    final uid = _uid;

    if (uid == null) {
      throw StateError('Cannot save progress without an authenticated user.');
    }

    if (!_isLoaded || !_habitsReady) {
      throw StateError('Progress is not ready yet. Please try again shortly.');
    }

    if (!_activeHabits.any((habit) => habit.id == habitId)) {
      return;
    }

    final version = _sessionVersion;
    final dateKey = todayKey;

    final completedIds = {...?_historyByDate[dateKey]?.completedHabitIds};

    if (!completedIds.remove(habitId)) {
      completedIds.add(habitId);
    }

    final updated = DailyProgress(
      dateKey: dateKey,
      completedHabitIds: completedIds.toList(),
    );

    await _storage.saveTodayProgress(
      uid: uid,
      dateKey: dateKey,
      completedHabitIds: updated.completedHabitIds,
    );

    if (!_isCurrentSession(version, uid)) return;

    _historyByDate[dateKey] = updated;
    _refreshActiveCompletions();
    notifyListeners();
  }

  Future<void> clearAllProgress() async {
    final uid = _uid;

    if (uid == null) {
      throw StateError('Cannot clear progress without an authenticated user.');
    }

    if (!_isLoaded || _isLoading) {
      throw StateError('Wait for progress to finish loading before resetting.');
    }

    final version = _sessionVersion;

    await _storage.clearAllProgressHistory(uid);

    if (!_isCurrentSession(version, uid)) return;

    _completedHabitIds = [];
    _historyByDate = {};
    notifyListeners();
  }

  String _dateKeyFor(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  @override
  void dispose() {
    _isDisposed = true;
    _sessionVersion++;
    super.dispose();
  }
}
