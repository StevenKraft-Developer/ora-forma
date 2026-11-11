import 'package:flutter/foundation.dart';

import '../models/habit.dart';
import '../services/firestore_habit_service.dart';

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

  final FirestoreHabitService _storage;

  String? _uid;

  int _sessionVersion = 0;
  bool _isDisposed = false;

  bool _isCurrentSession(int version, String uid) {
    return !_isDisposed && version == _sessionVersion && uid == _uid;
  }
  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  List<Habit> _habits = [];
  bool _isLoading = false;
  bool _isLoaded = false;
  bool _isSavingOnboarding = false;
  bool _isSavingCatalog = false;

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
  bool get isSavingOnboarding => _isSavingOnboarding;
  bool get isSaving => _isSavingCatalog;

  /// True when there is at least one habit (active or archived).
  bool get hasHabits => _habits.isNotEmpty;

  /// True when there is at least one non-archived habit.
  bool get hasActiveHabits => _habits.any((h) => !h.isArchived);

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> loadHabits(String uid) async {
    if (_isDisposed) return;
    if (_uid == uid && (_isLoaded || _isLoading)) return;

    final version = ++_sessionVersion;

    _uid = uid;
    _isLoading = true;
    _isLoaded = false;
    _isSavingOnboarding = false;
    _isSavingCatalog = false;
    _habits = [];
    notifyListeners();

    try {
      final stored = await _storage.loadHabits(uid);

      if (!_isCurrentSession(version, uid)) return;

      if (stored == null) {
        final seeded = kDefaultCatholicHabitSet.toList();

        await _storage.saveHabits(uid: uid, habits: seeded);

        if (!_isCurrentSession(version, uid)) return;

        _habits = seeded;
      } else {
        _habits = List<Habit>.from(stored);
      }

      _sortHabits();
      _isLoaded = true;
    } finally {
      if (_isCurrentSession(version, uid)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Catalog mutations
  // ---------------------------------------------------------------------------

  /// Adds a habit after validating and trimming the form values.
  ///
  /// Returns false when invalid, unavailable, busy, or superseded.
  /// Current-session storage failures are rethrown.
  Future<bool> addHabit({
    required String uid,
    required String title,
    String? description,
  }) {
    if (!_canEditCatalog(uid)) return Future.value(false);

    final trimmedTitle = title.trim();
    final trimmedDescription = _cleanDescription(description);

    if (!_validHabitFields(trimmedTitle, trimmedDescription)) {
      return Future.value(false);
    }

    final habit = Habit.create(
      title: trimmedTitle,
      description: trimmedDescription,
      sortOrder: activeHabits.length,
    );

    return _saveCatalog([..._habits, habit], uid: uid);
  }

  /// Updates a habit without changing its ID, order, or archive state.
  ///
  /// This accepts the complete edit form: a null or blank description
  /// explicitly clears the existing description.
  Future<bool> updateHabit({
    required String uid,
    required String habitId,
    required String title,
    required String? description,
  }) {
    if (!_canEditCatalog(uid)) return Future.value(false);

    final trimmedTitle = title.trim();
    final trimmedDescription = _cleanDescription(description);

    if (!_validHabitFields(trimmedTitle, trimmedDescription)) {
      return Future.value(false);
    }

    final index = _findIndexById(habitId);
    if (index == -1) return Future.value(false);

    final updated = _habits[index].copyWith(
      title: trimmedTitle,
      description: trimmedDescription,
      clearDescription: trimmedDescription == null,
    );

    final next = List<Habit>.from(_habits);
    next[index] = updated;

    return _saveCatalog(next, uid: uid);
  }

  /// Archives a habit without deleting its catalog entry or progress history.
  Future<bool> archiveHabit(String habitId, {required String uid}) {
    if (!_canEditCatalog(uid)) return Future.value(false);

    final index = _findIndexById(habitId);
    if (index == -1 || _habits[index].isArchived) {
      return Future.value(false);
    }

    final next = List<Habit>.from(_habits);
    next[index] = next[index].copyWith(isArchived: true);

    return _saveCatalog(_normalizedCatalog(next), uid: uid);
  }

  /// Restores an archived habit at the end of the active routine.
  Future<bool> unarchiveHabit(String habitId, {required String uid}) {
    if (!_canEditCatalog(uid)) return Future.value(false);

    final index = _findIndexById(habitId);
    if (index == -1 || !_habits[index].isArchived) {
      return Future.value(false);
    }

    final restored = _habits[index].copyWith(
      isArchived: false,
      sortOrder: activeHabits.length,
    );

    final next = [
      ...activeHabits,
      restored,
      ...archivedHabits.where((habit) => habit.id != habitId),
    ];

    return _saveCatalog(_normalizedCatalog(next), uid: uid);
  }

  /// Not exposed by the first Manage Habits UI.
  /// Uses the shared save path so it cannot bypass catalog serialization.
  Future<bool> deleteHabit(String habitId, {required String uid}) {
    if (!_canEditCatalog(uid)) return Future.value(false);

    if (_findIndexById(habitId) == -1) {
      return Future.value(false);
    }

    final next = _habits.where((habit) => habit.id != habitId).toList();

    return _saveCatalog(_normalizedCatalog(next), uid: uid);
  }

  /// Not exposed by the first Manage Habits UI.
  /// Accepts ReorderableListView's one-past-end newIndex convention.
  Future<bool> reorderHabits(
    int oldIndex,
    int newIndex, {
    required String uid,
  }) {
    if (!_canEditCatalog(uid)) return Future.value(false);

    final active = List<Habit>.from(activeHabits);

    if (oldIndex < 0 ||
        oldIndex >= active.length ||
        newIndex < 0 ||
        newIndex > active.length) {
      return Future.value(false);
    }

    if (newIndex > oldIndex) newIndex--;

    if (newIndex == oldIndex) return Future.value(false);

    final moved = active.removeAt(oldIndex);
    active.insert(newIndex, moved);

    return _saveCatalog(
      _normalizedCatalog([...active, ...archivedHabits]),
      uid: uid,
    );
  }

  // ---------------------------------------------------------------------------
  // Seed from onboarding (used by HabitOnboardingScreen in Task 6)
  // ---------------------------------------------------------------------------
  /// Saves the selected catalog and onboarding completion for this account.
  ///
  /// Returns false when unavailable, busy, or superseded.
  /// Current-session storage errors are rethrown for the UI to handle.
  Future<bool> seedFromOnboarding(List<Habit> habits, {required String uid}) {
    return _saveCatalog(habits, uid: uid, completeOnboarding: true);
  }

  /// Clears account-specific in-memory data at sign-out.
  /// This deliberately does not delete any Firestore documents.
  void clear() {
    if (_isDisposed) return;

    _sessionVersion++;
    _uid = null;
    _habits = [];
    _isLoading = false;
    _isLoaded = false;
    _isSavingOnboarding = false;
    _isSavingCatalog = false;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------
  bool get _canSaveCatalog =>
      !_isDisposed &&
      _uid != null &&
      _isLoaded &&
      !_isLoading &&
      !_isSavingCatalog;
  bool _canEditCatalog(String uid) {
    return _canSaveCatalog && _uid == uid;
  }

  String? _cleanDescription(String? description) {
    final trimmed = description?.trim();

    if (trimmed == null || trimmed.isEmpty) return null;

    return trimmed;
  }

  bool _validHabitFields(String title, String? description) {
    return title.isNotEmpty &&
        title.length <= 100 &&
        (description == null || description.length <= 300);
  }

  /// Produces a new catalog with contiguous active sort orders.
  /// Archived habits retain their existing values.
  List<Habit> _normalizedCatalog(List<Habit> catalog) {
    final active = catalog.where((habit) => !habit.isArchived).toList();

    final archived = catalog.where((habit) => habit.isArchived).toList();

    return [
      for (var index = 0; index < active.length; index++)
        active[index].copyWith(sortOrder: index),
      ...archived,
    ];
  }

  /// Persists a catalog snapshot before publishing it.
  ///
  /// Returns false when the provider is unavailable, busy, or superseded.
  /// Current-session storage errors are rethrown to the caller.
  Future<bool> _saveCatalog(
    List<Habit> habits, {
    required String uid,
    bool completeOnboarding = false,
  }) async {
    if (!_canSaveCatalog || _uid != uid) return false;

    final version = _sessionVersion;
    final snapshot = List<Habit>.from(habits);

    _isSavingCatalog = true;
    _isSavingOnboarding = completeOnboarding;
    notifyListeners();

    try {
      if (!_isCurrentSession(version, uid)) return false;

      await _storage.saveHabits(
        uid: uid,
        habits: snapshot,
        completeOnboarding: completeOnboarding,
      );

      if (!_isCurrentSession(version, uid)) return false;

      _habits = snapshot;
      _sortHabits();

      return true;
    } catch (_) {
      if (!_isCurrentSession(version, uid)) return false;
      rethrow;
    } finally {
      if (_isCurrentSession(version, uid)) {
        _isSavingCatalog = false;
        _isSavingOnboarding = false;
        notifyListeners();
      }
    }
  }

  /// Sorts [_habits] in-place by [Habit.sortOrder] ascending.
  /// Archived habits sort after active ones because their sortOrder values are
  /// not part of the active sequence, but this keeps the backing list stable.
  void _sortHabits() {
    _habits.sort((a, b) {
      // Active habits sort by sortOrder; archived habits come after.
      if (!a.isArchived && !b.isArchived) {
        return a.sortOrder.compareTo(b.sortOrder);
      }
      if (a.isArchived && !b.isArchived) return 1;
      if (!a.isArchived && b.isArchived) return -1;
      return 0; // both archived — preserve relative order
    });
  }

  /// Reassigns [Habit.sortOrder] to all active habits so the values form the
  /// contiguous sequence {0, 1, 2, …, N−1} where N is the active habit count.
  ///
  /// Archived habits are left unchanged.

  /// Returns the index of the habit with [id] in [_habits], or -1 if absent.
  int _findIndexById(String id) {
    for (int i = 0; i < _habits.length; i++) {
      if (_habits[i].id == id) return i;
    }
    return -1;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _sessionVersion++;
    super.dispose();
  }
}
