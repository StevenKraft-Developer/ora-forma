import 'package:flutter/foundation.dart';

import '../models/habit.dart';
import '../services/habit_storage.dart';

/// Owns the user's persisted habit list and all CRUD operations on it.
///
/// Lifecycle:
///   Create the provider, then call [loadHabits] once (from main.dart or a
///   ProxyProvider in Task 4). All screens read from the public getters and
///   drive mutations through the public methods.
///
/// Not yet wired into the widget tree — that happens in Task 4.
class HabitProvider extends ChangeNotifier {
  HabitProvider(this._storage);

  final HabitStorage _storage;

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  List<Habit> _habits = [];
  bool _isLoading = false;
  bool _isLoaded = false;

  // ---------------------------------------------------------------------------
  // Public getters — always return defensive copies so callers cannot mutate
  // internal state directly.
  // ---------------------------------------------------------------------------

  /// All habits (active + archived), sorted by [Habit.sortOrder] ascending.
  List<Habit> get allHabits => List.unmodifiable(_habits);

  /// Habits where [Habit.isArchived] is false, sorted by [Habit.sortOrder].
  List<Habit> get activeHabits =>
      List.unmodifiable(_habits.where((h) => !h.isArchived).toList());

  /// Habits where [Habit.isArchived] is true, in insertion order.
  /// Archived habits retain their sortOrder value but are not reordered by the
  /// user, so raw order within the backing list is fine here.
  List<Habit> get archivedHabits =>
      List.unmodifiable(_habits.where((h) => h.isArchived).toList());

  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;

  /// True when there is at least one habit (active or archived).
  bool get hasHabits => _habits.isNotEmpty;

  /// True when there is at least one non-archived habit.
  bool get hasActiveHabits => _habits.any((h) => !h.isArchived);

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Loads habits from [HabitStorage] and seeds defaults on first run.
  ///
  /// Respects the three [HabitStorage.loadHabits] cases:
  ///   - `null`  → first run: seed from [kDefaultCatholicHabitSet], persist.
  ///   - `[]`    → user has no habits (they cleared them); expose empty list,
  ///               do NOT re-seed automatically.
  ///   - `[...]` → normal load; sort by [Habit.sortOrder] and expose.
  ///
  /// Safe to call more than once (guarded by [_isLoaded]).
  Future<void> loadHabits() async {
    if (_isLoaded) return;

    _isLoading = true;
    notifyListeners();

    final stored = await _storage.loadHabits();

    if (stored == null) {
      // --- First run: seed from defaults and persist immediately so the next
      //     launch sees a real list rather than null again.
      final seeded = kDefaultCatholicHabitSet.toList();
      await _storage.saveHabits(seeded);
      _habits = seeded;
    } else {
      // [] or [items] — use whatever was stored (including empty).
      _habits = stored;
    }

    _sortHabits();
    _isLoading = false;
    _isLoaded = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // CRUD — Add
  // ---------------------------------------------------------------------------

  /// Adds a new habit with an auto-generated UUID at the end of the active list.
  ///
  /// [title] is trimmed before use. Does nothing if the trimmed title is empty
  /// or exceeds 100 characters.
  ///
  /// Returns `true` if the habit was added, `false` if validation failed.
  Future<bool> addHabit({
    required String title,
    String? description,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed.length > 100) return false;

    // sortOrder is appended at the end of the current active list.
    final newSortOrder = activeHabits.length;

    final habit = Habit.create(
      title: trimmed,
      description: description?.trim(),
      sortOrder: newSortOrder,
    );

    _habits = [..._habits, habit];
    await _persist();
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------------
  // CRUD — Update
  // ---------------------------------------------------------------------------

  /// Updates the [title] and/or [description] of the habit with [habitId].
  ///
  /// Does not change [id], [sortOrder], or [isArchived].
  /// [title] is trimmed; must be 1–100 characters after trimming.
  ///
  /// Returns `true` if the update was applied, `false` if validation failed or
  /// the habit was not found.
  Future<bool> updateHabit({
    required String habitId,
    required String title,
    String? description,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed.length > 100) return false;

    final index = _findIndexById(habitId);
    if (index == -1) return false;

    final updated = _habits[index].copyWith(
      title: trimmed,
      description: description?.trim(),
    );

    _habits = _replaceAt(index, updated);
    await _persist();
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------------
  // CRUD — Archive / Unarchive
  // ---------------------------------------------------------------------------

  /// Marks the habit with [habitId] as archived.
  ///
  /// Archived habits are hidden from [activeHabits] but remain in [allHabits]
  /// and [archivedHabits]. Historical DailyProgress records are unaffected
  /// (ProgressProvider handles that separately).
  ///
  /// Does nothing if the habit is not found or is already archived.
  Future<void> archiveHabit(String habitId) async {
    final index = _findIndexById(habitId);
    if (index == -1) return;
    if (_habits[index].isArchived) return;

    _habits = _replaceAt(index, _habits[index].copyWith(isArchived: true));
    // Re-normalise active sortOrders so they remain contiguous after the
    // archived habit is removed from the active sequence.
    _normalizeSortOrder();
    await _persist();
    notifyListeners();
  }

  /// Restores an archived habit back to the active list.
  ///
  /// The habit is appended at the end of the current active list.
  /// Does nothing if the habit is not found or is already active.
  Future<void> unarchiveHabit(String habitId) async {
    final index = _findIndexById(habitId);
    if (index == -1) return;
    if (!_habits[index].isArchived) return;

    // sortOrder is appended at the end of the current active list.
    final newSortOrder = activeHabits.length;
    _habits = _replaceAt(
      index,
      _habits[index].copyWith(isArchived: false, sortOrder: newSortOrder),
    );

    await _persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // CRUD — Delete
  // ---------------------------------------------------------------------------

  /// Permanently removes the habit with [habitId] from the provider's list.
  ///
  /// This does NOT clean up DailyProgress history — IDs that no longer exist
  /// in the habit list are treated as orphaned by ProgressProvider (Task 4).
  ///
  /// Does nothing if the habit is not found.
  Future<void> deleteHabit(String habitId) async {
    final index = _findIndexById(habitId);
    if (index == -1) return;

    _habits = [
      ..._habits.sublist(0, index),
      ..._habits.sublist(index + 1),
    ];

    // Re-normalise active sortOrders to keep the sequence contiguous.
    _normalizeSortOrder();
    await _persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Reorder
  // ---------------------------------------------------------------------------

  /// Reorders active habits using the indices produced by [ReorderableListView].
  ///
  /// [ReorderableListView] passes a [newIndex] that is relative to the list
  /// *before* the item is removed, so when moving an item downward the
  /// [newIndex] is one too high — the standard correction is applied here.
  ///
  /// Only active habits are reordered. Archived habits are untouched.
  /// Does nothing if the indices are out of range.
  Future<void> reorderHabits(int oldIndex, int newIndex) async {
    final active = activeHabits; // defensive copy, sorted by sortOrder

    if (oldIndex < 0 ||
        oldIndex >= active.length ||
        newIndex < 0 ||
        newIndex > active.length) {
      return;
    }

    // Standard ReorderableListView correction.
    if (newIndex > oldIndex) newIndex -= 1;

    // Build a new active ordering.
    final reordered = List<Habit>.from(active);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    // Assign new contiguous sortOrders to the reordered active habits.
    final reorderedWithSortOrder = [
      for (int i = 0; i < reordered.length; i++)
        reordered[i].copyWith(sortOrder: i),
    ];

    // Rebuild the full _habits list: updated active habits + archived habits
    // (archived habits keep their existing sortOrder values untouched).
    final archived = archivedHabits;
    _habits = [...reorderedWithSortOrder, ...archived];

    await _persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Seed from onboarding (used by HabitOnboardingScreen in Task 6)
  // ---------------------------------------------------------------------------

  /// Replaces the entire habit list with [habits] and persists immediately.
  ///
  /// Called at the end of the onboarding flow when the user taps "Begin".
  /// [habits] should already have sortOrder values set by the caller.
  Future<void> seedFromOnboarding(List<Habit> habits) async {
    _habits = List<Habit>.from(habits);
    _sortHabits();
    _isLoaded = true;
    await _persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Persists the current [_habits] list to storage.
  Future<void> _persist() async {
    await _storage.saveHabits(_habits);
  }

  /// Sorts [_habits] in-place by [Habit.sortOrder] ascending.
  /// Archived habits sort after active ones because their sortOrder values are
  /// not part of the active sequence, but this keeps the backing list stable.
  void _sortHabits() {
    _habits.sort((a, b) {
      // Active habits sort by sortOrder; archived habits come after.
      if (!a.isArchived && !b.isArchived) return a.sortOrder.compareTo(b.sortOrder);
      if (a.isArchived && !b.isArchived) return 1;
      if (!a.isArchived && b.isArchived) return -1;
      return 0; // both archived — preserve relative order
    });
  }

  /// Reassigns [Habit.sortOrder] to all active habits so the values form the
  /// contiguous sequence {0, 1, 2, …, N−1} where N is the active habit count.
  ///
  /// Archived habits are left unchanged.
  void _normalizeSortOrder() {
    int order = 0;
    _habits = [
      for (final h in _habits)
        h.isArchived ? h : h.copyWith(sortOrder: order++),
    ];
  }

  /// Returns the index of the habit with [id] in [_habits], or -1 if absent.
  int _findIndexById(String id) {
    for (int i = 0; i < _habits.length; i++) {
      if (_habits[i].id == id) return i;
    }
    return -1;
  }

  /// Returns a new list with the element at [index] replaced by [replacement].
  List<Habit> _replaceAt(int index, Habit replacement) {
    return [
      ..._habits.sublist(0, index),
      replacement,
      ..._habits.sublist(index + 1),
    ];
  }
}
