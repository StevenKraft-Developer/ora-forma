import 'package:catholic_habits/widgets/create_group_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openDialog(
  WidgetTester tester, {
  required ValueChanged<CreateGroupInput?> onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                final result = await showDialog<CreateGroupInput>(
                  context: context,
                  builder: (_) => const CreateGroupDialog(),
                );

                onResult(result);
              },
              child: const Text('Open dialog'),
            );
          },
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open dialog'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('blank and whitespace-only names are rejected', (tester) async {
    var returned = false;

    await _openDialog(
      tester,
      onResult: (_) {
        returned = true;
      },
    );

    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a group name.'), findsOneWidget);
    expect(returned, isFalse);

    await tester.enterText(find.byType(TextFormField).at(0), '   ');
    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a group name.'), findsOneWidget);
    expect(find.byType(CreateGroupDialog), findsOneWidget);
    expect(returned, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel returns no input', (tester) async {
    var returned = false;
    CreateGroupInput? result;

    await _openDialog(
      tester,
      onResult: (value) {
        returned = true;
        result = value;
      },
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Unsubmitted group',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(returned, isTrue);
    expect(result, isNull);
    expect(find.byType(CreateGroupDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid input is trimmed before returning', (tester) async {
    CreateGroupInput? result;

    await _openDialog(
      tester,
      onResult: (value) {
        result = value;
      },
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      '  Local Brotherhood  ',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      '  A local test description.  ',
    );

    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Local Brotherhood');
    expect(result!.description, 'A local test description.');
    expect(find.byType(CreateGroupDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('name longer than 80 is rejected', (tester) async {
    var returned = false;

    await _openDialog(
      tester,
      onResult: (_) {
        returned = true;
      },
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      List.filled(81, 'a').join(),
    );

    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();

    expect(
      find.text('Use a name with a maximum length of 80.'),
      findsOneWidget,
    );
    expect(find.byType(CreateGroupDialog), findsOneWidget);
    expect(returned, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('description longer than 500 is rejected', (tester) async {
    var returned = false;

    await _openDialog(
      tester,
      onResult: (_) {
        returned = true;
      },
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Valid group name',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      List.filled(501, 'b').join(),
    );

    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();

    expect(
      find.text('Use a description with a maximum length of 500.'),
      findsOneWidget,
    );
    expect(find.byType(CreateGroupDialog), findsOneWidget);
    expect(returned, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('maximum-length trimmed input is accepted', (tester) async {
    CreateGroupInput? result;
    final name = List.filled(80, 'a').join();
    final description = List.filled(500, 'b').join();

    await _openDialog(
      tester,
      onResult: (value) {
        result = value;
      },
    );

    await tester.enterText(find.byType(TextFormField).at(0), '  $name  ');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      '  $description  ',
    );

    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, name);
    expect(result!.description, description);
    expect(find.byType(CreateGroupDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
