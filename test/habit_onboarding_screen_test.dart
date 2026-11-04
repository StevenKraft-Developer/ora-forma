import 'dart:async';

import 'package:catholic_habits/models/habit.dart';
import 'package:catholic_habits/screens/onboarding/habit_onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _prayer = Habit(
  id: 'morning_prayer',
  title: 'Morning Prayer',
  sortOrder: 0,
);

const _custom = Habit(
  id: 'custom-examen',
  title: 'Personal Examen',
  description: 'Five quiet minutes',
  sortOrder: 1,
);

const _archived = Habit(
  id: 'archived-reading',
  title: 'Older Reading Habit',
  description: 'Keep this catalog entry',
  sortOrder: 7,
  isArchived: true,
);

const _catalog = [_prayer, _custom, _archived];

Future<void> _mount(
  WidgetTester tester, {
  List<Habit> initialHabits = _catalog,
  required Future<bool> Function(List<Habit>) onSave,
  required VoidCallback onCompleted,
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: HabitOnboardingScreen(
        initialHabits: initialHabits,
        onSave: onSave,
        onCompleted: onCompleted,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await tester.pumpAndSettle();
}

Finder _startButton() {
  return find.widgetWithText(FilledButton, 'Start my daily rule');
}

void main() {
  testWidgets('does not save until final confirmation', (tester) async {
    var saves = 0;
    var completions = 0;

    await _mount(
      tester,
      onSave: (_) async {
        saves++;
        return true;
      },
      onCompleted: () => completions++,
    );

    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(saves, 0);

    await _next(tester);

    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(saves, 0);

    await _next(tester);

    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(saves, 0);
    expect(completions, 0);

    await tester.tap(_startButton());
    await tester.pumpAndSettle();

    expect(saves, 1);
    expect(completions, 1);
  });

  testWidgets('requires at least one selected habit', (tester) async {
    var saves = 0;

    await _mount(
      tester,
      initialHabits: const [_prayer],
      onSave: (_) async {
        saves++;
        return true;
      },
      onCompleted: () {},
    );

    await _next(tester);

    await tester.tap(
      find.byKey(const ValueKey('onboarding-habit-morning_prayer')),
    );
    await tester.pumpAndSettle();

    await _next(tester);

    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('Choose at least one habit to continue.'), findsOneWidget);
    expect(saves, 0);

    await tester.tap(
      find.byKey(const ValueKey('onboarding-habit-morning_prayer')),
    );
    await tester.pumpAndSettle();

    await _next(tester);

    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(saves, 0);
  });

  testWidgets('preserves custom and archived habits when saving', (
    tester,
  ) async {
    List<Habit>? saved;

    await _mount(
      tester,
      onSave: (habits) async {
        saved = List<Habit>.from(habits);
        return true;
      },
      onCompleted: () {},
    );

    await _next(tester);

    final customTile = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('onboarding-habit-custom-examen')),
    );
    final archivedTile = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('onboarding-habit-archived-reading')),
    );

    expect(customTile.value, isTrue);
    expect(archivedTile.value, isFalse);

    await tester.tap(
      find.byKey(const ValueKey('onboarding-habit-morning_prayer')),
    );
    await tester.pumpAndSettle();

    await _next(tester);
    await tester.tap(_startButton());
    await tester.pumpAndSettle();

    expect(saved, hasLength(3));

    final byId = {for (final habit in saved!) habit.id: habit};

    expect(byId[_prayer.id], _prayer.copyWith(isArchived: true));
    expect(byId[_custom.id], _custom.copyWith(sortOrder: 0));
    expect(byId[_archived.id], _archived);
  });

  testWidgets('failed save displays an error and allows retry', (tester) async {
    var attempts = 0;
    var completions = 0;

    await _mount(
      tester,
      onSave: (_) async {
        attempts++;

        if (attempts == 1) {
          throw StateError('Test save failure');
        }

        return true;
      },
      onCompleted: () => completions++,
    );

    await _next(tester);
    await _next(tester);

    await tester.tap(_startButton());
    await tester.pumpAndSettle();

    expect(
      find.text('Your routine could not be saved. Please try again.'),
      findsOneWidget,
    );
    expect(attempts, 1);
    expect(completions, 0);

    await tester.tap(_startButton());
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(completions, 1);
    expect(
      find.text('Your routine could not be saved. Please try again.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('false save result does not complete onboarding', (tester) async {
    var completions = 0;

    await _mount(
      tester,
      onSave: (_) async => false,
      onCompleted: () => completions++,
    );

    await _next(tester);
    await _next(tester);

    await tester.tap(_startButton());
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Your routine could not be saved for this session. '
        'Please try again.',
      ),
      findsOneWidget,
    );
    expect(completions, 0);
    expect(_startButton(), findsOneWidget);
  });

  testWidgets(
    'pending save disables controls and ignores disposed completion',
    (tester) async {
      final pending = Completer<bool>();
      var saves = 0;
      var completions = 0;

      await _mount(
        tester,
        onSave: (_) {
          saves++;
          return pending.future;
        },
        onCompleted: () => completions++,
      );

      await _next(tester);
      await _next(tester);

      await tester.tap(_startButton());
      await tester.pump();

      final savingButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Saving...'),
      );
      final backButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Back'),
      );

      expect(savingButton.onPressed, isNull);
      expect(backButton.onPressed, isNull);
      expect(saves, 1);
      expect(completions, 0);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      pending.complete(true);
      await tester.pumpAndSettle();

      expect(saves, 1);
      expect(completions, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
