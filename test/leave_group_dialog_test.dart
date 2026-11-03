import 'package:catholic_habits/widgets/leave_group_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openDialog(
  WidgetTester tester, {
  required ValueChanged<bool?> onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (_) =>
                      const LeaveGroupDialog(groupName: 'Test Brotherhood'),
                );

                onResult(result);
              },
              child: const Text('Open leave dialog'),
            );
          },
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open leave dialog'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the group name and consequences of leaving', (
    tester,
  ) async {
    var returned = false;

    await _openDialog(
      tester,
      onResult: (_) {
        returned = true;
      },
    );

    expect(find.text('Leave group?'), findsOneWidget);
    expect(find.text('Test Brotherhood'), findsOneWidget);
    expect(
      find.text(
        'You will lose access to this group. '
        'The group and other memberships will not be deleted.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'To join again, you will need an available invitation '
        'from the group owner.',
      ),
      findsOneWidget,
    );
    expect(returned, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel returns false and closes the dialog', (tester) async {
    var returned = false;
    bool? result;

    await _openDialog(
      tester,
      onResult: (value) {
        returned = true;
        result = value;
      },
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(returned, isTrue);
    expect(result, isFalse);
    expect(find.byType(LeaveGroupDialog), findsNothing);
    expect(find.text('Open leave dialog'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Leave group returns true and closes the dialog', (tester) async {
    var returned = false;
    bool? result;

    await _openDialog(
      tester,
      onResult: (value) {
        returned = true;
        result = value;
      },
    );

    await tester.tap(find.text('Leave group'));
    await tester.pumpAndSettle();

    expect(returned, isTrue);
    expect(result, isTrue);
    expect(find.byType(LeaveGroupDialog), findsNothing);
    expect(find.text('Open leave dialog'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing without a choice returns null', (tester) async {
    var returned = false;
    bool? result;

    await _openDialog(
      tester,
      onResult: (value) {
        returned = true;
        result = value;
      },
    );

    final dialogContext = tester.element(find.byType(LeaveGroupDialog));
    Navigator.of(dialogContext).pop();

    await tester.pumpAndSettle();

    expect(returned, isTrue);
    expect(result, isNull);
    expect(find.byType(LeaveGroupDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
