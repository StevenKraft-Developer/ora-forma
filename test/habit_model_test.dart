import 'package:catholic_habits/models/habit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const original = Habit(
    id: 'custom-examen',
    title: 'Personal Examen',
    description: 'Five quiet minutes',
    sortOrder: 3,
    isArchived: true,
  );

  test('copyWith preserves unspecified fields', () {
    final updated = original.copyWith(title: 'Evening Examen');

    expect(updated.id, original.id);
    expect(updated.title, 'Evening Examen');
    expect(updated.description, original.description);
    expect(updated.sortOrder, original.sortOrder);
    expect(updated.isArchived, original.isArchived);
    expect(original.title, 'Personal Examen');
  });

  test('copyWith can replace a description', () {
    final updated = original.copyWith(description: 'Ten quiet minutes');

    expect(updated.description, 'Ten quiet minutes');
    expect(updated.id, original.id);
    expect(original.description, 'Five quiet minutes');
  });

  test('null description preserves the existing value by default', () {
    final updated = original.copyWith(description: null);

    expect(updated, original);
  });

  test('clearDescription explicitly removes the description', () {
    final updated = original.copyWith(clearDescription: true);

    expect(updated.description, isNull);
    expect(updated.id, original.id);
    expect(updated.title, original.title);
    expect(updated.sortOrder, original.sortOrder);
    expect(updated.isArchived, original.isArchived);

    final reloaded = Habit.fromJson(updated.toJson());

    expect(reloaded, updated);
    expect(reloaded.description, isNull);
    expect(original.description, 'Five quiet minutes');
  });

  test('clearDescription takes precedence over a supplied value', () {
    final updated = original.copyWith(
      description: 'Ignored replacement',
      clearDescription: true,
    );

    expect(updated.description, isNull);
  });
}
