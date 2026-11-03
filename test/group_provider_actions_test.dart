import 'dart:async';

import 'package:catholic_habits/models/group.dart';
import 'package:catholic_habits/models/group_invitation.dart';
import 'package:catholic_habits/providers/group_provider.dart';
import 'package:catholic_habits/services/group_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGroupService implements GroupService {
  final pendingAction = Completer<Object>();
  final actionCalls = <String>[];

  int loadCount = 0;
  List<Group> nextGroups = [];
  Object? loadError;

  @override
  Future<List<Group>> loadGroups(String uid) async {
    loadCount++;

    final error = loadError;
    if (error != null) throw error;

    return List<Group>.from(nextGroups);
  }

  Future<T> _request<T>(String operation) async {
    actionCalls.add(operation);
    return (await pendingAction.future) as T;
  }

  @override
  Future<String> createGroup({required String name, String? description}) {
    return _request<String>('create');
  }

  @override
  Future<GroupInvitation> createGroupInvite({required String groupId}) {
    return _request<GroupInvitation>('invite');
  }

  @override
  Future<JoinGroupResult> joinGroup({required String inviteCode}) {
    return _request<JoinGroupResult>('join');
  }

  @override
  Future<LeaveGroupResult> leaveGroup({required String groupId}) {
    return _request<LeaveGroupResult>('leave');
  }
}

Group _group(String id) {
  return Group(
    id: id,
    name: 'Group $id',
    description: '',
    ownerUid: 'owner',
    role: GroupRole.member,
  );
}

class _ActionCase {
  const _ActionCase(this.name, this.invoke, this.result);

  final String name;
  final Future<Object?> Function(GroupProvider provider) invoke;
  final Object result;
}

void main() {
  final invitation = GroupInvitation(
    code: 'test-code',
    expiresAt: DateTime.utc(2030),
  );

  final cases = <_ActionCase>[
    _ActionCase(
      'create',
      (provider) => provider.createGroup(name: 'New Group'),
      'new-group',
    ),
    _ActionCase(
      'invite',
      (provider) => provider.createGroupInvite(groupId: 'existing'),
      invitation,
    ),
    _ActionCase(
      'join',
      (provider) => provider.joinGroup(inviteCode: 'test-code'),
      const JoinGroupResult(
        groupId: 'joined-group',
        status: JoinGroupStatus.joined,
      ),
    ),
    _ActionCase(
      'leave',
      (provider) => provider.leaveGroup(groupId: 'existing'),
      const LeaveGroupResult(
        groupId: 'existing',
        status: LeaveGroupStatus.left,
      ),
    ),
  ];

  late _FakeGroupService service;
  late GroupProvider provider;

  setUp(() {
    service = _FakeGroupService();
    provider = GroupProvider(service);
  });

  tearDown(() {
    provider.dispose();
  });

  Future<void> loadAccount() async {
    service.nextGroups = [_group('existing')];
    await provider.loadGroups('user-a');
  }

  for (final action in cases) {
    test(
      '${action.name}: signed-out provider does not invoke service',
      () async {
        final result = await action.invoke(provider);

        expect(result, isNull);
        expect(service.actionCalls, isEmpty);
        expect(provider.isSubmitting, isFalse);
      },
    );

    test(
      '${action.name}: pending action blocks another action and refresh',
      () async {
        await loadAccount();

        final pending = action.invoke(provider);

        expect(provider.isSubmitting, isTrue);
        expect(service.actionCalls, [action.name]);

        final duplicate = await action.invoke(provider);
        await provider.refresh();

        expect(duplicate, isNull);
        expect(service.actionCalls, hasLength(1));
        expect(service.loadCount, 1);

        service.pendingAction.complete(action.result);
        await pending;

        expect(provider.isSubmitting, isFalse);
      },
    );

    test(
      '${action.name}: failure sets an error and releases submission state',
      () async {
        await loadAccount();

        final pending = action.invoke(provider);

        service.pendingAction.completeError(
          StateError('Simulated backend failure'),
        );

        final result = await pending;

        expect(result, isNull);
        expect(provider.isSubmitting, isFalse);
        expect(provider.errorMessage, isNotNull);
        expect(provider.selectedGroupId, 'existing');
        expect(service.loadCount, 1);
      },
    );

    test('${action.name}: account switch discards a delayed success', () async {
      await loadAccount();

      final pending = action.invoke(provider);

      service.nextGroups = [_group('b-group')];
      await provider.loadGroups('user-b');

      expect(provider.isSubmitting, isFalse);

      service.pendingAction.complete(action.result);

      expect(await pending, isNull);
      expect(provider.selectedGroupId, 'b-group');
      expect(provider.errorMessage, isNull);
      expect(provider.isSubmitting, isFalse);
      expect(service.loadCount, 2);
    });

    test('${action.name}: sign-out discards a delayed failure', () async {
      await loadAccount();

      final pending = action.invoke(provider);
      provider.clear();

      service.pendingAction.completeError(StateError('Old account failure'));

      expect(await pending, isNull);
      expect(provider.groups, isEmpty);
      expect(provider.isLoaded, isFalse);
      expect(provider.isSubmitting, isFalse);
      expect(provider.errorMessage, isNull);
      expect(service.loadCount, 1);
    });

    test(
      '${action.name}: disposal discards a delayed result without notifying',
      () async {
        final localService = _FakeGroupService();
        final localProvider = GroupProvider(localService);

        await localProvider.loadGroups('user-a');

        var notifications = 0;
        localProvider.addListener(() {
          notifications++;
        });

        final pending = action.invoke(localProvider);
        final beforeDispose = notifications;

        localProvider.dispose();
        localService.pendingAction.complete(action.result);

        expect(await pending, isNull);
        expect(notifications, beforeDispose);
        expect(localService.loadCount, 1);
      },
    );
  }

  test('successful create reloads and selects the new group', () async {
    await loadAccount();

    final pending = provider.createGroup(name: 'New Group');

    service.nextGroups = [_group('existing'), _group('new-group')];
    service.pendingAction.complete('new-group');

    expect(await pending, 'new-group');
    expect(provider.selectedGroupId, 'new-group');
    expect(provider.errorMessage, isNull);
    expect(provider.isSubmitting, isFalse);
    expect(service.loadCount, 2);
  });

  test(
    'successful invitation returns its value without reloading groups',
    () async {
      await loadAccount();

      final pending = provider.createGroupInvite(groupId: 'existing');

      service.pendingAction.complete(invitation);

      expect(await pending, same(invitation));
      expect(provider.selectedGroupId, 'existing');
      expect(provider.isSubmitting, isFalse);
      expect(service.loadCount, 1);
    },
  );

  test('successful join reloads and selects the joined group', () async {
    await loadAccount();

    final pending = provider.joinGroup(inviteCode: 'test-code');

    service.nextGroups = [_group('existing'), _group('joined-group')];
    service.pendingAction.complete(
      const JoinGroupResult(
        groupId: 'joined-group',
        status: JoinGroupStatus.joined,
      ),
    );

    final result = await pending;

    expect(result?.status, JoinGroupStatus.joined);
    expect(provider.selectedGroupId, 'joined-group');
    expect(provider.isSubmitting, isFalse);
    expect(service.loadCount, 2);
  });

  test('successful leave reloads and removes the departed group', () async {
    await loadAccount();

    final pending = provider.leaveGroup(groupId: 'existing');

    service.nextGroups = [];
    service.pendingAction.complete(
      const LeaveGroupResult(
        groupId: 'existing',
        status: LeaveGroupStatus.left,
      ),
    );

    final result = await pending;

    expect(result?.status, LeaveGroupStatus.left);
    expect(provider.groups, isEmpty);
    expect(provider.selectedGroup, isNull);
    expect(provider.isLoaded, isTrue);
    expect(provider.isSubmitting, isFalse);
    expect(service.loadCount, 2);
  });

  test(
    'successful write with failed reload preserves the successful result',
    () async {
      await loadAccount();

      final pending = provider.createGroup(name: 'New Group');

      service.loadError = StateError('Reload failed');
      service.pendingAction.complete('new-group');

      expect(await pending, 'new-group');
      expect(provider.groups, isEmpty);
      expect(provider.isLoaded, isFalse);
      expect(provider.errorMessage, isNotNull);
      expect(provider.isSubmitting, isFalse);
      expect(service.actionCalls, ['create']);
      expect(service.loadCount, 2);
    },
  );
}
