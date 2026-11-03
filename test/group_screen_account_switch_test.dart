import 'dart:async';

import 'package:catholic_habits/group_screen.dart';
import 'package:catholic_habits/models/app_user.dart';
import 'package:catholic_habits/models/group.dart';
import 'package:catholic_habits/models/user_profile.dart';
import 'package:catholic_habits/providers/auth_provider.dart';
import 'package:catholic_habits/providers/group_provider.dart';
import 'package:catholic_habits/services/auth_service.dart';
import 'package:catholic_habits/services/group_service.dart';
import 'package:catholic_habits/services/user_profile_service.dart';
import 'package:catholic_habits/widgets/create_group_dialog.dart';
import 'package:catholic_habits/widgets/join_group_dialog.dart';
import 'package:catholic_habits/widgets/leave_group_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:catholic_habits/models/group_invitation.dart';
import 'package:catholic_habits/widgets/group_invitation_dialog.dart';

const _emulatorMode = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: false,
);

class _FakeAuthService implements AuthService {
  final controller = StreamController<AppUser?>.broadcast(sync: true);

  @override
  Stream<AppUser?> authStateChanges() => controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected AuthService call: ${invocation.memberName}',
    );
  }
}

class _FakeProfileService implements UserProfileService {
  @override
  Future<UserProfile?> getProfile(String uid) async => null;

  @override
  Future<void> createProfile({
    required String uid,
    required String email,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected UserProfileService call: ${invocation.memberName}',
    );
  }
}

class _FakeGroupService implements GroupService {
  var createCalls = 0;
  var joinCalls = 0;
  var leaveCalls = 0;

  bool ownerMembership = false;

  final invitedGroupIds = <String>[];
  final inviteRequests = <Completer<GroupInvitation>>[];

  @override
  Future<GroupInvitation> createGroupInvite({required String groupId}) {
    invitedGroupIds.add(groupId);

    final request = Completer<GroupInvitation>();
    inviteRequests.add(request);
    return request.future;
  }

  @override
  Future<List<Group>> loadGroups(String uid) async {
    if (uid != 'user-a') return [];

    return [
      Group(
        id: 'joined-group',
        name: 'Joined Group',
        description: 'Account A membership.',
        ownerUid: ownerMembership ? 'user-a' : 'another-owner',
        role: ownerMembership ? GroupRole.owner : GroupRole.member,
      ),
    ];
  }

  @override
  Future<String> createGroup({
    required String name,
    String? description,
  }) async {
    createCalls++;
    return 'unexpected-created-group';
  }

  @override
  Future<JoinGroupResult> joinGroup({required String inviteCode}) async {
    joinCalls++;
    return const JoinGroupResult(
      groupId: 'unexpected-joined-group',
      status: JoinGroupStatus.joined,
    );
  }

  @override
  Future<LeaveGroupResult> leaveGroup({required String groupId}) async {
    leaveCalls++;
    return LeaveGroupResult(groupId: groupId, status: LeaveGroupStatus.left);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected GroupService call: ${invocation.memberName}',
    );
  }
}

Future<void> _mountScreen(
  WidgetTester tester, {
  required AuthProvider auth,
  required GroupProvider groups,
  required _FakeAuthService authService,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<GroupProvider>.value(value: groups),
      ],
      child: const MaterialApp(home: GroupScreen()),
    ),
  );

  authService.controller.add(
    const AppUser(uid: 'user-a', email: 'user-a@example.com'),
  );

  await tester.pumpAndSettle();

  expect(auth.user?.uid, 'user-a');
  expect(groups.selectedGroupId, 'joined-group');
}

Future<void> _switchToAccountB(
  WidgetTester tester,
  _FakeAuthService authService,
) async {
  authService.controller.add(
    const AppUser(uid: 'user-b', email: 'user-b@example.com'),
  );

  await tester.pumpAndSettle();
}

Future<void> _reauthenticateAccountA(
  WidgetTester tester,
  _FakeAuthService authService,
) async {
  authService.controller.add(null);
  await tester.pumpAndSettle();

  authService.controller.add(
    const AppUser(uid: 'user-a', email: 'user-a@example.com'),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Group forms across account switches', () {
    late _FakeAuthService authService;
    late _FakeGroupService groupService;
    late AuthProvider auth;
    late GroupProvider groups;
    late VoidCallback syncGroups;

    void initializeHarness() {
      authService = _FakeAuthService();
      groupService = _FakeGroupService();

      auth = AuthProvider(
        authService: authService,
        profileService: _FakeProfileService(),
      );
      groups = GroupProvider(groupService);

      syncGroups = () {
        groups.syncAccount(uid: auth.user?.uid);
      };

      auth.addListener(syncGroups);
    }

    tearDown(() async {
      auth.removeListener(syncGroups);
      groups.dispose();
      auth.dispose();
      await authService.controller.close();
    });

    testWidgets('old create form cannot submit under another account', (
      tester,
    ) async {
      initializeHarness();

      await _mountScreen(
        tester,
        auth: auth,
        groups: groups,
        authService: authService,
      );

      await tester.tap(find.text('Create a group'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateGroupDialog), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Account A draft',
      );

      await _switchToAccountB(tester, authService);

      expect(auth.user?.uid, 'user-b');

      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();

      expect(groupService.createCalls, 0);
      expect(groups.groups, isEmpty);
      expect(find.byType(CreateGroupDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('old join form cannot submit under another account', (
      tester,
    ) async {
      initializeHarness();
      await _mountScreen(
        tester,
        auth: auth,
        groups: groups,
        authService: authService,
      );

      await tester.tap(find.text('Join a group'));
      await tester.pumpAndSettle();

      expect(find.byType(JoinGroupDialog), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField),
        List.filled(64, 'a').join(),
      );

      await _switchToAccountB(tester, authService);

      expect(auth.user?.uid, 'user-b');

      await tester.tap(find.text('Join group'));
      await tester.pumpAndSettle();

      expect(groupService.joinCalls, 0);
      expect(groups.groups, isEmpty);
      expect(find.byType(JoinGroupDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('old leave confirmation cannot submit under another account', (
      tester,
    ) async {
      initializeHarness();
      await _mountScreen(
        tester,
        auth: auth,
        groups: groups,
        authService: authService,
      );

      final leaveButton = find.widgetWithText(OutlinedButton, 'Leave group');

      await tester.ensureVisible(leaveButton);
      await tester.tap(leaveButton);
      await tester.pumpAndSettle();

      expect(find.byType(LeaveGroupDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LeaveGroupDialog),
          matching: find.text('Joined Group'),
        ),
        findsOneWidget,
      );

      await _switchToAccountB(tester, authService);

      expect(auth.user?.uid, 'user-b');

      final confirmButton = find.descendant(
        of: find.byType(LeaveGroupDialog),
        matching: find.widgetWithText(FilledButton, 'Leave group'),
      );

      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(groupService.leaveCalls, 0);
      expect(groups.groups, isEmpty);
      expect(find.byType(LeaveGroupDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invitation completing after account switch is not displayed', (
      tester,
    ) async {
      initializeHarness();
      groupService.ownerMembership = true;

      await _mountScreen(
        tester,
        auth: auth,
        groups: groups,
        authService: authService,
      );

      final invitationButton = find.widgetWithText(
        OutlinedButton,
        'Create invitation',
      );

      await tester.ensureVisible(invitationButton);
      await tester.tap(invitationButton);
      await tester.pump();

      expect(groupService.invitedGroupIds, ['joined-group']);
      expect(groupService.inviteRequests, hasLength(1));
      expect(groups.isSubmitting, isTrue);

      await _switchToAccountB(tester, authService);

      expect(auth.user?.uid, 'user-b');
      expect(groups.groups, isEmpty);

      final code = List.filled(64, 'a').join();

      groupService.inviteRequests.single.complete(
        GroupInvitation(
          code: code,
          expiresAt: DateTime.utc(2030, 1, 15, 18, 30),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GroupInvitationDialog), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is SelectableText && widget.data == code,
        ),
        findsNothing,
      );
      expect(groups.isSubmitting, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('visible invitation code is hidden after account switch', (
      tester,
    ) async {
      initializeHarness();
      groupService.ownerMembership = true;

      await _mountScreen(
        tester,
        auth: auth,
        groups: groups,
        authService: authService,
      );

      final invitationButton = find.widgetWithText(
        OutlinedButton,
        'Create invitation',
      );

      await tester.ensureVisible(invitationButton);
      await tester.tap(invitationButton);
      await tester.pump();

      final code = List.filled(64, 'b').join();

      groupService.inviteRequests.single.complete(
        GroupInvitation(
          code: code,
          expiresAt: DateTime.utc(2030, 1, 15, 18, 30),
        ),
      );

      await tester.pumpAndSettle();

      final codeFinder = find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == code,
        description: 'the displayed invitation code',
      );

      expect(find.byType(GroupInvitationDialog), findsOneWidget);
      expect(codeFinder, findsOneWidget);

      await _switchToAccountB(tester, authService);

      expect(auth.user?.uid, 'user-b');
      expect(find.byType(GroupInvitationDialog), findsNothing);
      expect(codeFinder, findsNothing);
      expect(find.text('Invitation hidden'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Invitation hidden'), findsNothing);
      expect(find.text('No groups yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'old create form cannot submit after same-account reauthentication',
      (tester) async {
        initializeHarness();

        await _mountScreen(
          tester,
          auth: auth,
          groups: groups,
          authService: authService,
        );

        final originalSession = auth.sessionVersion;

        await tester.tap(find.text('Create a group'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'Old session draft',
        );

        await _reauthenticateAccountA(tester, authService);

        expect(auth.user?.uid, 'user-a');
        expect(auth.sessionVersion, greaterThan(originalSession));
        expect(groups.selectedGroupId, 'joined-group');
        expect(find.byType(CreateGroupDialog), findsOneWidget);

        await tester.tap(find.text('Create group'));
        await tester.pumpAndSettle();

        expect(groupService.createCalls, 0);
        expect(find.byType(CreateGroupDialog), findsNothing);
        expect(groups.selectedGroupId, 'joined-group');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'old join form cannot submit after same-account reauthentication',
      (tester) async {
        initializeHarness();

        await _mountScreen(
          tester,
          auth: auth,
          groups: groups,
          authService: authService,
        );

        final originalSession = auth.sessionVersion;

        await tester.tap(find.text('Join a group'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField),
          List.filled(64, 'a').join(),
        );

        await _reauthenticateAccountA(tester, authService);

        expect(auth.user?.uid, 'user-a');
        expect(auth.sessionVersion, greaterThan(originalSession));
        expect(find.byType(JoinGroupDialog), findsOneWidget);

        await tester.tap(find.text('Join group'));
        await tester.pumpAndSettle();

        expect(groupService.joinCalls, 0);
        expect(find.byType(JoinGroupDialog), findsNothing);
        expect(groups.selectedGroupId, 'joined-group');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'old leave confirmation cannot submit after same-account reauthentication',
      (tester) async {
        initializeHarness();

        await _mountScreen(
          tester,
          auth: auth,
          groups: groups,
          authService: authService,
        );

        final originalSession = auth.sessionVersion;
        final leaveButton = find.widgetWithText(OutlinedButton, 'Leave group');

        await tester.ensureVisible(leaveButton);
        await tester.tap(leaveButton);
        await tester.pumpAndSettle();

        await _reauthenticateAccountA(tester, authService);

        expect(auth.user?.uid, 'user-a');
        expect(auth.sessionVersion, greaterThan(originalSession));
        expect(groups.selectedGroupId, 'joined-group');
        expect(find.byType(LeaveGroupDialog), findsOneWidget);

        final confirmButton = find.descendant(
          of: find.byType(LeaveGroupDialog),
          matching: find.widgetWithText(FilledButton, 'Leave group'),
        );

        await tester.tap(confirmButton);
        await tester.pumpAndSettle();

        expect(groupService.leaveCalls, 0);
        expect(find.byType(LeaveGroupDialog), findsNothing);
        expect(groups.selectedGroupId, 'joined-group');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'pending invitation is not displayed after same-account reauthentication',
      (tester) async {
        initializeHarness();
        groupService.ownerMembership = true;

        await _mountScreen(
          tester,
          auth: auth,
          groups: groups,
          authService: authService,
        );

        final originalSession = auth.sessionVersion;
        final invitationButton = find.widgetWithText(
          OutlinedButton,
          'Create invitation',
        );

        await tester.ensureVisible(invitationButton);
        await tester.tap(invitationButton);
        await tester.pump();

        expect(groupService.inviteRequests, hasLength(1));
        expect(groups.isSubmitting, isTrue);

        await _reauthenticateAccountA(tester, authService);

        expect(auth.user?.uid, 'user-a');
        expect(auth.sessionVersion, greaterThan(originalSession));
        expect(groups.selectedGroupId, 'joined-group');
        expect(groups.selectedGroup?.isOwner, isTrue);

        final code = List.filled(64, 'c').join();

        groupService.inviteRequests.single.complete(
          GroupInvitation(
            code: code,
            expiresAt: DateTime.utc(2030, 1, 15, 18, 30),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(GroupInvitationDialog), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is SelectableText && widget.data == code,
          ),
          findsNothing,
        );
        expect(groups.isSubmitting, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'visible invitation stays hidden after same-account reauthentication',
      (tester) async {
        initializeHarness();
        groupService.ownerMembership = true;

        await _mountScreen(
          tester,
          auth: auth,
          groups: groups,
          authService: authService,
        );

        final originalSession = auth.sessionVersion;
        final invitationButton = find.widgetWithText(
          OutlinedButton,
          'Create invitation',
        );

        await tester.ensureVisible(invitationButton);
        await tester.tap(invitationButton);
        await tester.pump();

        final code = List.filled(64, 'd').join();

        groupService.inviteRequests.single.complete(
          GroupInvitation(
            code: code,
            expiresAt: DateTime.utc(2030, 1, 15, 18, 30),
          ),
        );

        await tester.pumpAndSettle();

        final codeFinder = find.byWidgetPredicate(
          (widget) => widget is SelectableText && widget.data == code,
          description: 'the original session invitation code',
        );

        expect(find.byType(GroupInvitationDialog), findsOneWidget);
        expect(codeFinder, findsOneWidget);

        authService.controller.add(null);
        await tester.pumpAndSettle();

        expect(find.text('Invitation hidden'), findsOneWidget);
        expect(codeFinder, findsNothing);

        authService.controller.add(
          const AppUser(uid: 'user-a', email: 'user-a@example.com'),
        );
        await tester.pumpAndSettle();

        expect(auth.user?.uid, 'user-a');
        expect(auth.sessionVersion, greaterThan(originalSession));
        expect(groups.selectedGroupId, 'joined-group');
        expect(groups.selectedGroup?.isOwner, isTrue);

        expect(find.text('Invitation hidden'), findsOneWidget);
        expect(find.byType(GroupInvitationDialog), findsNothing);
        expect(codeFinder, findsNothing);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        expect(find.text('Invitation hidden'), findsNothing);
        expect(find.text('Your role: Owner'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }, skip: !_emulatorMode);
}
