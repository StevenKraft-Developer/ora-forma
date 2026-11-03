import 'package:catholic_habits/models/group_invitation.dart';
import 'package:catholic_habits/widgets/group_invitation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _testCode = List.filled(4, '0123456789abcdef').join();
final _testExpiry = DateTime.utc(2030, 1, 15, 18, 30);

Future<void> _openDialog(WidgetTester tester, {VoidCallback? onClosed}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => GroupInvitationDialog(
                    groupName: 'Test Brotherhood',
                    invitation: GroupInvitation(
                      code: _testCode,
                      expiresAt: _testExpiry,
                    ),
                  ),
                );

                onClosed?.call();
              },
              child: const Text('Open invitation'),
            );
          },
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open invitation'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the group name and exact selectable invitation code', (
    tester,
  ) async {
    await _openDialog(tester);

    expect(find.text('Group invitation'), findsOneWidget);
    expect(find.text('Test Brotherhood'), findsOneWidget);
    expect(find.text('Invitation code'), findsOneWidget);

    final codeFinder = find.byWidgetPredicate(
      (widget) => widget is SelectableText && widget.data == _testCode,
      description: 'the full selectable invitation code',
    );

    expect(codeFinder, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('formats expiration using local date and time', (tester) async {
    await _openDialog(tester);

    final dialogContext = tester.element(find.byType(GroupInvitationDialog));
    final localExpiry = _testExpiry.toLocal();
    final localizations = MaterialLocalizations.of(dialogContext);
    final date = localizations.formatMediumDate(localExpiry);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localExpiry),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(dialogContext),
    );

    expect(
      find.text('Expires: $date at $time (your local time).'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('explains private sharing, single use, and closing behavior', (
    tester,
  ) async {
    await _openDialog(tester);

    expect(
      find.text(
        'Share this code privately with one person you want '
        'to invite. They can paste it into “Join a group”.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'This invitation can admit one new member. '
        'Closing this dialog does not revoke it. '
        'The code is not displayed again by this screen.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Done closes the dialog and removes the displayed code', (
    tester,
  ) async {
    var closed = false;

    await _openDialog(
      tester,
      onClosed: () {
        closed = true;
      },
    );

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(find.byType(GroupInvitationDialog), findsNothing);
    expect(find.text(_testCode), findsNothing);
    expect(find.text('Open invitation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
