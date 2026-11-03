import 'dart:async';

import 'package:catholic_habits/group_screen.dart';
import 'package:catholic_habits/models/group.dart';
import 'package:catholic_habits/models/group_invitation.dart';
import 'package:catholic_habits/providers/group_provider.dart';
import 'package:catholic_habits/services/group_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _emulatorMode = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: false,
);

class _FakeGroupService implements GroupService {
  final loads = <Completer<List<Group>>>[];

  @override
  Future<List<Group>> loadGroups(String uid) {
    final completer = Completer<List<Group>>();
    loads.add(completer);
    return completer.future;
  }

  @override
  Future<String> createGroup({
    required String name,
    String? description,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<GroupInvitation> createGroupInvite({required String groupId}) async {
    throw UnimplementedError();
  }

  @override
  Future<JoinGroupResult> joinGroup({required String inviteCode}) async {
    throw UnimplementedError();
  }

  @override
  Future<LeaveGroupResult> leaveGroup({required String groupId}) async {
    throw UnimplementedError();
  }
}

Group _group({
  required String id,
  required String name,
  required String description,
  GroupRole role = GroupRole.member,
}) {
  return Group(
    id: id,
    name: name,
    description: description,
    ownerUid: role == GroupRole.owner ? 'user-a' : 'another-owner',
    role: role,
  );
}

Future<void> _pumpScreen(WidgetTester tester, GroupProvider provider) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<GroupProvider>.value(
      value: provider,
      child: const MaterialApp(home: GroupScreen()),
    ),
  );
}

void main() {
  testWidgets(
    'non-emulator build shows unavailable without needing a provider',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: GroupScreen()));

      expect(
        find.text('Groups are not available in this build yet.'),
        findsOneWidget,
      );
      expect(find.byTooltip('Refresh groups'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    skip: _emulatorMode,
  );

  group('emulator membership screen', () {
    late _FakeGroupService service;
    late GroupProvider provider;

    setUp(() {
      service = _FakeGroupService();
      provider = GroupProvider(service);
    });

    tearDown(() {
      provider.dispose();
    });

    testWidgets('shows loading and disables refresh', (tester) async {
      final load = provider.loadGroups('user-a');

      await _pumpScreen(tester, provider);

      expect(find.text('Loading your groups…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final refreshFinder = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Refresh groups',
        description: 'the refresh groups IconButton',
      );

      expect(refreshFinder, findsOneWidget);

      final refresh = tester.widget<IconButton>(refreshFinder);
      expect(refresh.onPressed, isNull);

      service.loads.single.complete([]);
      await load;
      await tester.pumpAndSettle();

      expect(find.text('No groups yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty state refresh requests memberships again', (
      tester,
    ) async {
      final load = provider.loadGroups('user-a');
      service.loads.single.complete([]);
      await load;

      await _pumpScreen(tester, provider);

      expect(find.text('No groups yet'), findsOneWidget);
      expect(find.text('Friday Fraternity'), findsNothing);
      expect(find.text('Early Risers'), findsNothing);
      expect(find.text('Scripture Circle'), findsNothing);

      await tester.tap(find.byTooltip('Refresh groups'));
      await tester.pump();

      expect(service.loads, hasLength(2));
      expect(find.text('Loading your groups…'), findsOneWidget);

      service.loads[1].complete([]);
      await tester.pumpAndSettle();

      expect(find.text('No groups yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('failed loading can be retried successfully', (tester) async {
      final load = provider.loadGroups('user-a');
      service.loads.single.completeError(StateError('Test load failure'));
      await load;

      await _pumpScreen(tester, provider);

      expect(find.text('Group request could not be completed'), findsOneWidget);
      expect(
        find.text('Your groups could not be loaded. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('No groups yet'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(service.loads, hasLength(2));

      service.loads[1].complete([]);
      await tester.pumpAndSettle();

      expect(find.text('No groups yet'), findsOneWidget);
      expect(find.text('Group request could not be completed'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows roles and changes selected group details', (
      tester,
    ) async {
      final load = provider.loadGroups('user-a');
      service.loads.single.complete([
        _group(
          id: 'owned',
          name: 'Owned Group',
          description: 'Owner group description.',
          role: GroupRole.owner,
        ),
        _group(
          id: 'joined',
          name: 'Joined Group',
          description: 'Joined group description.',
        ),
      ]);
      await load;

      await _pumpScreen(tester, provider);

      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Member'), findsOneWidget);
      expect(find.text('Owner group description.'), findsOneWidget);
      expect(find.text('Your role: Owner'), findsOneWidget);
      expect(find.text('Joined group description.'), findsNothing);
      expect(find.text('Create invitation'), findsOneWidget);
      expect(find.text('Leave group'), findsNothing);

      await tester.tap(find.text('Joined Group'));
      await tester.pumpAndSettle();

      expect(provider.selectedGroupId, 'joined');
      expect(find.text('Joined group description.'), findsOneWidget);
      expect(find.text('Your role: Member'), findsOneWidget);
      expect(find.text('Owner group description.'), findsNothing);
      expect(find.text('Create invitation'), findsNothing);
      expect(find.text('Leave group'), findsOneWidget);

      await tester.tap(find.text('Owned Group'));
      await tester.pumpAndSettle();

      expect(provider.selectedGroupId, 'owned');
      expect(find.text('Your role: Owner'), findsOneWidget);
      expect(find.text('Create invitation'), findsOneWidget);
      expect(find.text('Leave group'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('blank description shows the fallback', (tester) async {
      final load = provider.loadGroups('user-a');
      service.loads.single.complete([
        _group(id: 'blank', name: 'Quiet Group', description: '   '),
      ]);
      await load;

      await _pumpScreen(tester, provider);

      expect(find.text('No description provided.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('not-yet-loaded state is distinct from empty membership', (
      tester,
    ) async {
      await _pumpScreen(tester, provider);

      expect(find.text('Getting your groups ready'), findsOneWidget);
      expect(find.text('No groups yet'), findsNothing);
      expect(service.loads, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }, skip: !_emulatorMode);
}
