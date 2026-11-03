import 'package:catholic_habits/widgets/join_group_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openDialog(
  WidgetTester tester, {
  required ValueChanged<String?> onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                final result = await showDialog<String>(
                  context: context,
                  builder: (_) => const JoinGroupDialog(),
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
  testWidgets('blank and whitespace-only codes are rejected', (tester) async {
    var returned = false;

    await _openDialog(
      tester,
      onResult: (_) {
        returned = true;
      },
    );

    await tester.tap(find.text('Join group'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an invitation code.'), findsOneWidget);
    expect(returned, isFalse);

    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Join group'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an invitation code.'), findsOneWidget);
    expect(find.byType(JoinGroupDialog), findsOneWidget);
    expect(returned, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('codes shorter or longer than 64 are rejected', (tester) async {
    var returned = false;

    await _openDialog(
      tester,
      onResult: (_) {
        returned = true;
      },
    );

    for (final length in [63, 65]) {
      await tester.enterText(
        find.byType(TextFormField),
        List.filled(length, 'a').join(),
      );
      await tester.tap(find.text('Join group'));
      await tester.pumpAndSettle();

      expect(
        find.text('Use the full 64-character lowercase invitation code.'),
        findsOneWidget,
      );
      expect(returned, isFalse);
    }

    expect(find.byType(JoinGroupDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uppercase and non-hexadecimal codes are rejected', (
    tester,
  ) async {
    var returned = false;

    await _openDialog(
      tester,
      onResult: (_) {
        returned = true;
      },
    );

    for (final character in ['A', 'g']) {
      await tester.enterText(
        find.byType(TextFormField),
        List.filled(64, character).join(),
      );
      await tester.tap(find.text('Join group'));
      await tester.pumpAndSettle();

      expect(
        find.text('Use the full 64-character lowercase invitation code.'),
        findsOneWidget,
      );
      expect(returned, isFalse);
    }

    expect(find.byType(JoinGroupDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('internal whitespace is rejected', (tester) async {
    var returned = false;
    final half = List.filled(32, 'a').join();

    await _openDialog(
      tester,
      onResult: (_) {
        returned = true;
      },
    );

    await tester.enterText(find.byType(TextFormField), '$half $half');
    await tester.tap(find.text('Join group'));
    await tester.pumpAndSettle();

    expect(
      find.text('Use the full 64-character lowercase invitation code.'),
      findsOneWidget,
    );
    expect(returned, isFalse);
    expect(find.byType(JoinGroupDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid code is returned with surrounding whitespace trimmed', (
    tester,
  ) async {
    String? result;
    final code = List.filled(4, '0123456789abcdef').join();

    await _openDialog(
      tester,
      onResult: (value) {
        result = value;
      },
    );

    await tester.enterText(find.byType(TextFormField), '  $code  ');
    await tester.tap(find.text('Join group'));
    await tester.pumpAndSettle();

    expect(result, code);
    expect(find.byType(JoinGroupDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel returns no invitation code', (tester) async {
    var returned = false;
    String? result;

    await _openDialog(
      tester,
      onResult: (value) {
        returned = true;
        result = value;
      },
    );

    await tester.enterText(
      find.byType(TextFormField),
      List.filled(64, 'a').join(),
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(returned, isTrue);
    expect(result, isNull);
    expect(find.byType(JoinGroupDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
