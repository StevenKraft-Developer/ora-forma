import 'dart:async';

import 'package:catholic_habits/models/user_profile.dart';
import 'package:catholic_habits/providers/user_profile_provider.dart';
import 'package:catholic_habits/services/user_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _ProfileRequest {
  _ProfileRequest(this.uid);

  final String uid;
  final completer = Completer<UserProfile?>();
}

class _SaveRequest {
  _SaveRequest(this.profile);

  final UserProfile profile;
  final completer = Completer<void>();
}

class _FakeProfileService implements UserProfileService {
  final loads = <_ProfileRequest>[];
  final saves = <_SaveRequest>[];

  @override
  Future<UserProfile?> getProfile(String uid) {
    final request = _ProfileRequest(uid);
    loads.add(request);
    return request.completer.future;
  }

  @override
  Future<void> saveProfile(UserProfile profile) {
    final request = _SaveRequest(profile);
    saves.add(request);
    return request.completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected profile call: ${invocation.memberName}');
  }
}

UserProfile _profile(String uid) {
  return UserProfile(
    uid: uid,
    email: '$uid@example.com',
    displayName: uid,
    onboardingComplete: true,
    groupIds: const [],
  );
}

void main() {
  late _FakeProfileService service;
  late UserProfileProvider provider;
  late bool disposed;

  setUp(() {
    service = _FakeProfileService();
    provider = UserProfileProvider(profileService: service);
    disposed = false;
  });

  tearDown(() {
    if (!disposed) {
      provider.dispose();
    }
  });

  test('obsolete load cannot replace the newer account profile', () async {
    final loadA = provider.loadProfile('user-a');
    final loadB = provider.loadProfile('user-b');

    service.loads[1].completer.complete(_profile('user-b'));
    await loadB;

    expect(provider.profile?.uid, 'user-b');
    expect(provider.isLoading, isFalse);

    service.loads[0].completer.complete(_profile('user-a'));
    await loadA;

    expect(provider.profile?.uid, 'user-b');
    expect(provider.isLoading, isFalse);
  });

  test('starting another account load clears the previous profile', () async {
    final loadA = provider.loadProfile('user-a');
    service.loads.single.completer.complete(_profile('user-a'));
    await loadA;

    expect(provider.profile?.uid, 'user-a');

    final loadB = provider.loadProfile('user-b');

    expect(provider.profile, isNull);
    expect(provider.isLoading, isTrue);
    expect(provider.isOnboardingComplete, isFalse);

    service.loads[1].completer.complete(_profile('user-b'));
    await loadB;

    expect(provider.profile?.uid, 'user-b');
  });

  test('clear invalidates a pending profile load', () async {
    final load = provider.loadProfile('user-a');

    provider.clear();

    service.loads.single.completer.complete(_profile('user-a'));
    await load;

    expect(provider.profile, isNull);
    expect(provider.isLoading, isFalse);
    expect(provider.isOnboardingComplete, isFalse);
  });

  test('obsolete load failure does not finish a newer request', () async {
    final loadA = provider.loadProfile('user-a');
    final loadB = provider.loadProfile('user-b');

    service.loads[0].completer.completeError(
      StateError('Obsolete account lookup failure'),
    );
    await loadA;

    expect(provider.profile, isNull);
    expect(provider.isLoading, isTrue);

    service.loads[1].completer.complete(_profile('user-b'));
    await loadB;

    expect(provider.profile?.uid, 'user-b');
    expect(provider.isLoading, isFalse);
  });

  test(
    'old onboarding save cannot replace the newer account profile',
    () async {
      final saveA = provider.completeOnboarding(
        uid: 'user-a',
        email: 'user-a@example.com',
        displayName: 'Account A',
      );

      expect(service.saves.single.profile.uid, 'user-a');

      final loadB = provider.loadProfile('user-b');
      service.loads.single.completer.complete(_profile('user-b'));
      await loadB;

      service.saves.single.completer.complete();
      await saveA;

      expect(provider.profile?.uid, 'user-b');
      expect(provider.isLoading, isFalse);
    },
  );

  test('clear invalidates a pending onboarding save', () async {
    final save = provider.completeOnboarding(
      uid: 'user-a',
      email: 'user-a@example.com',
      displayName: 'Account A',
    );

    provider.clear();

    service.saves.single.completer.complete();
    await save;

    expect(provider.profile, isNull);
    expect(provider.isLoading, isFalse);
    expect(provider.isOnboardingComplete, isFalse);
  });

  test('pending load does not notify after disposal', () async {
    var notifications = 0;

    provider.addListener(() {
      notifications++;
    });

    final load = provider.loadProfile('user-a');
    final beforeDisposal = notifications;

    provider.dispose();
    disposed = true;

    service.loads.single.completer.complete(_profile('user-a'));
    await load;

    expect(notifications, beforeDisposal);
  });

  test('pending onboarding save does not notify after disposal', () async {
    var notifications = 0;

    provider.addListener(() {
      notifications++;
    });

    final save = provider.completeOnboarding(
      uid: 'user-a',
      email: 'user-a@example.com',
      displayName: 'Account A',
    );
    final beforeDisposal = notifications;

    provider.dispose();
    disposed = true;

    service.saves.single.completer.complete();
    await save;

    expect(notifications, beforeDisposal);
  });
}
