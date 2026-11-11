import 'dart:async';

import 'package:catholic_habits/models/app_user.dart';
import 'package:catholic_habits/models/habit.dart';
import 'package:catholic_habits/providers/auth_provider.dart';
import 'package:catholic_habits/providers/habit_provider.dart';
import 'package:catholic_habits/screens/habits/manage_habits_screen.dart';
import 'package:catholic_habits/services/firestore_habit_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _first = Habit(
  id: 'first',
  title: 'First habit',
  description: 'Existing description',
);

const _accountBHabit = Habit(id: 'b-only', title: 'Account B habit');

// Only the user identity is needed by this screen.
class _TestUser implements AppUser {
  _TestUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

// Keep authentication under explicit test control without starting
// Firebase authentication or profile initialization.
class _TestAuthProvider extends ChangeNotifier implements AuthProvider {
  AppUser? _user = _TestUser('user-a');
  int _version = 1;

  @override
  AppUser? get user => _user;

  @override
  int get sessionVersion => _version;

  @override
  bool get isLoading => false;

  void changeAccount(String uid) {
    _user = _TestUser(uid);
    _version++;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _TestHabitStorage implements FirestoreHabitService {
  final catalogs = <String, List<Habit>>{
    'user-a': const [_first],
    'user-b': const [_accountBHabit],
  };

  final savedUids = <String>[];
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

    final gate = saveGate;
    if (gate != null) await gate.future;

    catalogs[uid] = snapshot;
  }
}

Finder _titleField() => find.byKey(const ValueKey('habit-title'));

Finder _descriptionField() => find.byKey(const ValueKey('habit-description'));

Finder _saveButton() => find.byKey(const ValueKey('save-habit'));

String _fieldText(WidgetTester tester, Finder finder) {
  return tester.widget<TextFormField>(finder).controller!.text;
}

Future<void> _mount(
  WidgetTester tester, {
  required _TestAuthProvider auth,
  required HabitProvider habits,
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1000));

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    habits.dispose();
    auth.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  await habits.loadHabits('user-a');

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<HabitProvider>.value(value: habits),
      ],
      child: MaterialApp(
        home: ManageHabitsScreen(
          uid: 'user-a',
          sessionVersion: auth.sessionVersion,
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _openAddForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('add-habit')));
  await tester.pumpAndSettle();

  expect(_titleField(), findsOneWidget);
}

Future<void> _fillForm(WidgetTester tester) async {
  await tester.enterText(_titleField(), 'Personal Examen');
  await tester.enterText(_descriptionField(), 'Five quiet minutes');
}

void main() {
  testWidgets('failed save preserves input and allows retry', (tester) async {
    final storage = _TestHabitStorage();
    final auth = _TestAuthProvider();
    final habits = HabitProvider(storage);

    await _mount(tester, auth: auth, habits: habits);
    await _openAddForm(tester);
    await _fillForm(tester);

    final gate = Completer<void>();
    storage.saveGate = gate;

    await tester.tap(_saveButton());
    await tester.pump();

    expect(storage.savedUids, ['user-a']);

    gate.completeError(StateError('Test save failure'));
    await tester.pumpAndSettle();

    expect(
      find.text('The habit could not be saved. Please try again.'),
      findsOneWidget,
    );
    expect(_fieldText(tester, _titleField()), 'Personal Examen');
    expect(_fieldText(tester, _descriptionField()), 'Five quiet minutes');
    expect(tester.widget<FilledButton>(_saveButton()).onPressed, isNotNull);
    expect(habits.allHabits, const [_first]);
    expect(storage.catalogs['user-a'], const [_first]);

    storage.saveGate = null;

    await tester.tap(_saveButton());
    await tester.pumpAndSettle();

    expect(storage.savedUids, ['user-a', 'user-a']);
    expect(_saveButton(), findsNothing);
    expect(find.text('Personal Examen'), findsOneWidget);
    expect(habits.activeHabits, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending save disables controls and prevents duplicates', (
    tester,
  ) async {
    final storage = _TestHabitStorage();
    final auth = _TestAuthProvider();
    final habits = HabitProvider(storage);

    await _mount(tester, auth: auth, habits: habits);
    await _openAddForm(tester);
    await _fillForm(tester);

    final gate = Completer<void>();
    storage.saveGate = gate;

    await tester.tap(_saveButton());
    await tester.pump();

    expect(find.text('Saving...'), findsOneWidget);
    expect(tester.widget<FilledButton>(_saveButton()).onPressed, isNull);
    expect(tester.widget<TextFormField>(_titleField()).enabled, isFalse);
    expect(tester.widget<TextFormField>(_descriptionField()).enabled, isFalse);
    expect(storage.savedUids, ['user-a']);

    await tester.tap(_saveButton());
    await tester.tap(_saveButton());
    await tester.pump();

    expect(storage.savedUids, ['user-a']);

    gate.complete();
    await tester.pumpAndSettle();

    expect(_saveButton(), findsNothing);
    expect(storage.savedUids, ['user-a']);
    expect(habits.activeHabits, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  for (final pendingSave in [false, true]) {
    testWidgets(
      pendingSave
          ? 'account change ignores completion of a pending form save'
          : 'account change invalidates an unsubmitted form',
      (tester) async {
        final storage = _TestHabitStorage();
        final auth = _TestAuthProvider();
        final habits = HabitProvider(storage);

        await _mount(tester, auth: auth, habits: habits);
        await _openAddForm(tester);
        await _fillForm(tester);

        Completer<void>? gate;

        if (pendingSave) {
          gate = Completer<void>();
          storage.saveGate = gate;

          await tester.tap(_saveButton());
          await tester.pump();

          expect(storage.savedUids, ['user-a']);
        }

        auth.changeAccount('user-b');
        await habits.loadHabits('user-b');
        await tester.pumpAndSettle();

        const formSessionMessage =
            'Your account session changed. '
            'Close this form and try again.';

        expect(find.text(formSessionMessage), findsOneWidget);
        expect(_titleField(), findsNothing);
        expect(_descriptionField(), findsNothing);
        expect(_saveButton(), findsNothing);
        expect(find.text('Personal Examen'), findsNothing);
        expect(find.text('Five quiet minutes'), findsNothing);
        expect(find.text('First habit'), findsNothing);
        expect(find.text('Account B habit'), findsNothing);

        if (gate != null) {
          gate.complete();
          await tester.pumpAndSettle();
        }

        // An obsolete completion must not close the sheet or display
        // a save error in the new session.
        expect(find.text(formSessionMessage), findsOneWidget);
        expect(
          find.text('The habit could not be saved. Please try again.'),
          findsNothing,
        );
        expect(find.byType(SnackBar), findsNothing);

        expect(storage.savedUids, pendingSave ? ['user-a'] : isEmpty);
        expect(habits.allHabits, const [_accountBHabit]);
        expect(storage.catalogs['user-b'], const [_accountBHabit]);

        await tester.tap(find.widgetWithText(TextButton, 'Close'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Your account session changed. '
            'Close this screen and reopen Manage Habits.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('add-habit')), findsNothing);
        expect(find.text('Account B habit'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
