import 'dart:async';

import 'package:catholic_habits/models/group.dart';
import 'package:catholic_habits/models/group_invitation.dart';
import 'package:catholic_habits/providers/group_provider.dart';
import 'package:catholic_habits/services/group_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _PendingLoad {
  _PendingLoad(this.uid);

  final String uid;
  final completer = Completer<List<Group>>();
}

class _FakeGroupService implements GroupService {
  final loads = <_PendingLoad>[];

  @override
  Future<List<Group>> loadGroups(String uid) {
    final request = _PendingLoad(uid);
    loads.add(request);
    return request.completer.future;
  }

  @override
  Future<String> createGroup({required String name, String? description}) {
    throw UnimplementedError();
  }

  @override
  Future<GroupInvitation> createGroupInvite({required String groupId}) {
    throw UnimplementedError();
  }

  @override
  Future<JoinGroupResult> joinGroup({required String inviteCode}) {
    throw UnimplementedError();
  }

  @override
  Future<LeaveGroupResult> leaveGroup({required String groupId}) {
    throw UnimplementedError();
  }
}

Group _group(String id, String ownerUid) {
  return Group(
    id: id,
    name: 'Group $id',
    description: '',
    ownerUid: ownerUid,
    role: GroupRole.member,
  );
}

void main() {
  late _FakeGroupService service;
  late GroupProvider provider;

  setUp(() {
    service = _FakeGroupService();
    provider = GroupProvider(service);
  });

  tearDown(() {
    provider.dispose();
  });

  test('an empty successful load is distinct from not loaded', () async {
    expect(provider.isLoaded, isFalse);
    expect(provider.selectedGroup, isNull);

    final loading = provider.loadGroups('user-a');

    expect(provider.isLoading, isTrue);
    expect(service.loads.single.uid, 'user-a');

    service.loads.single.completer.complete([]);
    await loading;

    expect(provider.isLoading, isFalse);
    expect(provider.isLoaded, isTrue);
    expect(provider.hasGroups, isFalse);
    expect(provider.selectedGroupId, isNull);
    expect(provider.errorMessage, isNull);
  });

  test(
    'loads groups, selects by ID, and exposes an unmodifiable list',
    () async {
      final loading = provider.loadGroups('user-a');

      service.loads.single.completer.complete([
        _group('first', 'user-a'),
        _group('second', 'user-a'),
      ]);
      await loading;

      expect(provider.hasGroups, isTrue);
      expect(provider.selectedGroupId, 'first');

      provider.selectGroup('second');
      expect(provider.selectedGroup?.id, 'second');

      provider.selectGroup('missing');
      expect(provider.selectedGroupId, 'second');

      expect(() => provider.groups.clear(), throwsUnsupportedError);
      expect(provider.groups, hasLength(2));
    },
  );

  test(
    'does not duplicate loading or loaded requests for the same account',
    () async {
      final loading = provider.loadGroups('user-a');

      await provider.loadGroups('user-a');
      expect(service.loads, hasLength(1));

      service.loads.single.completer.complete([]);
      await loading;

      await provider.loadGroups('user-a');
      expect(service.loads, hasLength(1));
    },
  );

  test(
    'clear prevents a delayed load from restoring signed-out data',
    () async {
      final loading = provider.loadGroups('user-a');

      provider.clear();

      expect(provider.isLoading, isFalse);
      expect(provider.isLoaded, isFalse);
      expect(provider.groups, isEmpty);

      service.loads.single.completer.complete([_group('old-group', 'user-a')]);
      await loading;

      expect(provider.groups, isEmpty);
      expect(provider.selectedGroup, isNull);
      expect(provider.isLoaded, isFalse);
      expect(provider.errorMessage, isNull);
    },
  );

  test(
    'switching accounts ignores the old account result and loading state',
    () async {
      final loadA = provider.loadGroups('user-a');
      final loadB = provider.loadGroups('user-b');

      expect(service.loads.map((request) => request.uid), ['user-a', 'user-b']);

      service.loads[0].completer.complete([_group('a-group', 'user-a')]);
      await loadA;

      expect(provider.groups, isEmpty);
      expect(provider.isLoading, isTrue);
      expect(provider.isLoaded, isFalse);

      service.loads[1].completer.complete([_group('b-group', 'user-b')]);
      await loadB;

      expect(provider.groups.map((group) => group.id), ['b-group']);
      expect(provider.selectedGroupId, 'b-group');
      expect(provider.isLoading, isFalse);
      expect(provider.isLoaded, isTrue);
    },
  );

  test(
    'a stale failure cannot clear the new account groups or set an error',
    () async {
      final loadA = provider.loadGroups('user-a');
      final loadB = provider.loadGroups('user-b');

      service.loads[1].completer.complete([_group('b-group', 'user-b')]);
      await loadB;

      service.loads[0].completer.completeError(
        StateError('Old account failed'),
      );
      await loadA;

      expect(provider.selectedGroupId, 'b-group');
      expect(provider.groups, hasLength(1));
      expect(provider.errorMessage, isNull);
      expect(provider.isLoaded, isTrue);
      expect(provider.isLoading, isFalse);
    },
  );

  test(
    'a disposed provider ignores a delayed result without notifying',
    () async {
      final localService = _FakeGroupService();
      final localProvider = GroupProvider(localService);
      var notifications = 0;

      localProvider.addListener(() {
        notifications++;
      });

      final loading = localProvider.loadGroups('user-a');
      final beforeDispose = notifications;

      localProvider.dispose();

      localService.loads.single.completer.complete([
        _group('late-group', 'user-a'),
      ]);
      await loading;

      expect(notifications, beforeDispose);
    },
  );

  test(
    'refresh preserves valid selection and falls back when it disappears',
    () async {
      final initial = provider.loadGroups('user-a');

      service.loads[0].completer.complete([
        _group('first', 'user-a'),
        _group('second', 'user-a'),
      ]);
      await initial;

      provider.selectGroup('second');

      final refreshWithSelection = provider.refresh();
      service.loads[1].completer.complete([
        _group('first', 'user-a'),
        _group('second', 'user-a'),
      ]);
      await refreshWithSelection;

      expect(provider.selectedGroupId, 'second');

      final refreshWithoutSelection = provider.refresh();
      service.loads[2].completer.complete([_group('first', 'user-a')]);
      await refreshWithoutSelection;

      expect(provider.selectedGroupId, 'first');

      final refreshEmpty = provider.refresh();
      service.loads[3].completer.complete([]);
      await refreshEmpty;

      expect(provider.isLoaded, isTrue);
      expect(provider.selectedGroupId, isNull);
      expect(provider.selectedGroup, isNull);
    },
  );

  test(
    'failed refresh clears old data and supports a successful retry',
    () async {
      final initial = provider.loadGroups('user-a');

      service.loads[0].completer.complete([_group('first', 'user-a')]);
      await initial;

      final failedRefresh = provider.refresh();
      service.loads[1].completer.completeError(
        StateError('Cannot verify membership'),
      );
      await failedRefresh;

      expect(provider.groups, isEmpty);
      expect(provider.selectedGroup, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.isLoaded, isFalse);
      expect(provider.errorMessage, isNotNull);

      final retry = provider.refresh();

      expect(provider.errorMessage, isNull);
      expect(provider.isLoading, isTrue);

      service.loads[2].completer.complete([_group('recovered', 'user-a')]);
      await retry;

      expect(provider.selectedGroupId, 'recovered');
      expect(provider.isLoaded, isTrue);
      expect(provider.errorMessage, isNull);
    },
  );

  test('refresh without an account does not request data', () async {
    await provider.refresh();

    expect(service.loads, isEmpty);
    expect(provider.groups, isEmpty);
    expect(provider.isLoading, isFalse);
  });

  test('syncAccount defers loading and notifications', () async {
    var notifications = 0;

    provider.addListener(() {
      notifications++;
    });

    provider.syncAccount(uid: 'user-a');

    expect(service.loads, isEmpty);
    expect(notifications, 0);

    await Future<void>.delayed(Duration.zero);

    expect(service.loads, hasLength(1));
    expect(service.loads.single.uid, 'user-a');
    expect(provider.isLoading, isTrue);
    expect(notifications, greaterThan(0));

    service.loads.single.completer.complete([_group('a-group', 'user-a')]);

    await Future<void>.delayed(Duration.zero);

    expect(provider.selectedGroupId, 'a-group');
    expect(provider.isLoaded, isTrue);
    expect(provider.isLoading, isFalse);
  });

  test('syncAccount skips an obsolete scheduled account load', () async {
    provider.syncAccount(uid: 'user-a');
    provider.syncAccount(uid: 'user-b');

    expect(service.loads, isEmpty);

    await Future<void>.delayed(Duration.zero);

    expect(service.loads, hasLength(1));
    expect(service.loads.single.uid, 'user-b');

    service.loads.single.completer.complete([_group('b-group', 'user-b')]);

    await Future<void>.delayed(Duration.zero);

    expect(provider.selectedGroupId, 'b-group');
    expect(provider.isLoaded, isTrue);
  });

  test('syncAccount sign-out cancels a load before it starts', () async {
    provider.syncAccount(uid: 'user-a');
    provider.syncAccount(uid: null);

    await Future<void>.delayed(Duration.zero);

    expect(service.loads, isEmpty);
    expect(provider.groups, isEmpty);
    expect(provider.selectedGroup, isNull);
    expect(provider.isLoading, isFalse);
    expect(provider.isLoaded, isFalse);
    expect(provider.errorMessage, isNull);
  });

  test(
    'syncAccount clears loaded data immediately without notifying inline',
    () async {
      final initialLoad = provider.loadGroups('user-a');

      service.loads.single.completer.complete([_group('a-group', 'user-a')]);
      await initialLoad;

      var notifications = 0;

      provider.addListener(() {
        notifications++;
      });

      provider.syncAccount(uid: 'user-b');

      expect(provider.groups, isEmpty);
      expect(provider.selectedGroup, isNull);
      expect(provider.isLoaded, isFalse);
      expect(provider.errorMessage, isNull);
      expect(notifications, 0);
      expect(service.loads, hasLength(1));

      await Future<void>.delayed(Duration.zero);

      expect(service.loads, hasLength(2));
      expect(service.loads[1].uid, 'user-b');

      service.loads[1].completer.complete([_group('b-group', 'user-b')]);

      await Future<void>.delayed(Duration.zero);

      expect(provider.selectedGroupId, 'b-group');
      expect(provider.isLoaded, isTrue);
    },
  );

  test('syncAccount repeated UID does not duplicate or reset a load', () async {
    provider.syncAccount(uid: 'user-a');
    provider.syncAccount(uid: 'user-a');

    await Future<void>.delayed(Duration.zero);

    expect(service.loads, hasLength(1));

    provider.syncAccount(uid: 'user-a');

    service.loads.single.completer.complete([_group('a-group', 'user-a')]);

    await Future<void>.delayed(Duration.zero);

    provider.syncAccount(uid: 'user-a');

    await Future<void>.delayed(Duration.zero);

    expect(service.loads, hasLength(1));
    expect(provider.selectedGroupId, 'a-group');
    expect(provider.isLoaded, isTrue);
  });

  test(
    'disposal prevents a scheduled syncAccount load from starting',
    () async {
      final localService = _FakeGroupService();
      final localProvider = GroupProvider(localService);

      var notifications = 0;

      localProvider.addListener(() {
        notifications++;
      });

      localProvider.syncAccount(uid: 'user-a');
      localProvider.dispose();

      await Future<void>.delayed(Duration.zero);

      expect(localService.loads, isEmpty);
      expect(notifications, 0);
    },
  );
}
