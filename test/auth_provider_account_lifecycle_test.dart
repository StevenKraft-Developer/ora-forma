import 'dart:async';

import 'package:catholic_habits/models/app_user.dart';
import 'package:catholic_habits/models/user_profile.dart';
import 'package:catholic_habits/providers/auth_provider.dart';
import 'package:catholic_habits/services/auth_service.dart';
import 'package:catholic_habits/services/user_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _ProfileRequest {
  _ProfileRequest(this.uid);

  final String uid;
  final completer = Completer<UserProfile?>();
}

class _FakeProfileService implements UserProfileService {
  final requests = <_ProfileRequest>[];
  final createdUids = <String>[];
  final createdEmails = <String>[];

  @override
  Future<UserProfile?> getProfile(String uid) {
    final request = _ProfileRequest(uid);
    requests.add(request);
    return request.completer.future;
  }

  @override
  Future<void> createProfile({
    required String uid,
    required String email,
  }) async {
    createdUids.add(uid);
    createdEmails.add(email);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected UserProfileService call: ${invocation.memberName}',
    );
  }
}

void main() {
  late _FakeAuthService authService;
  late _FakeProfileService profileService;
  late AuthProvider provider;
  late bool disposed;

  setUp(() {
    authService = _FakeAuthService();
    profileService = _FakeProfileService();
    provider = AuthProvider(
      authService: authService,
      profileService: profileService,
    );
    disposed = false;
  });

  tearDown(() async {
    if (!disposed) {
      provider.dispose();
    }

    await authService.controller.close();
  });

  test(
    'signed-in event loads and creates the matching missing profile',
    () async {
      var notifications = 0;

      provider.addListener(() {
        notifications++;
      });

      authService.controller.add(
        const AppUser(uid: 'user-a', email: 'user-a@example.com'),
      );

      expect(profileService.requests, hasLength(1));
      expect(profileService.requests.single.uid, 'user-a');

      profileService.requests.single.completer.complete(null);

      await Future<void>.delayed(Duration.zero);

      expect(provider.user?.uid, 'user-a');
      expect(provider.isAuthenticated, isTrue);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(profileService.createdUids, ['user-a']);
      expect(profileService.createdEmails, ['user-a@example.com']);
      expect(notifications, greaterThan(0));
    },
  );

  test('signed-out event clears the user and notifies listeners', () async {
    authService.controller.add(
      const AppUser(uid: 'user-a', email: 'user-a@example.com'),
    );
    profileService.requests.single.completer.complete(null);

    await Future<void>.delayed(Duration.zero);

    var notifications = 0;

    provider.addListener(() {
      notifications++;
    });

    authService.controller.add(null);

    await Future<void>.delayed(Duration.zero);

    expect(provider.user, isNull);
    expect(provider.isAuthenticated, isFalse);
    expect(provider.isLoading, isFalse);
    expect(provider.error, isNull);
    expect(notifications, greaterThan(0));
    expect(profileService.requests, hasLength(1));
  });

  test('disposal unsubscribes from later authentication events', () async {
    provider.dispose();
    disposed = true;

    authService.controller.add(
      const AppUser(uid: 'user-after-disposal', email: 'unused@example.com'),
    );

    await Future<void>.delayed(Duration.zero);

    expect(profileService.requests, isEmpty);
    expect(profileService.createdUids, isEmpty);
  });

  test(
    'account changes notify before profile initialization finishes',
    () async {
      final observedUids = <String?>[];

      provider.addListener(() {
        observedUids.add(provider.user?.uid);
      });

      authService.controller.add(
        const AppUser(uid: 'user-a', email: 'user-a@example.com'),
      );

      expect(observedUids, ['user-a']);
      expect(provider.user?.uid, 'user-a');
      expect(provider.isLoading, isTrue);
      expect(profileService.createdUids, isEmpty);

      profileService.requests.single.completer.complete(null);

      await Future<void>.delayed(Duration.zero);

      expect(provider.isLoading, isFalse);
      expect(profileService.createdUids, ['user-a']);
      expect(provider.profileInitializationError, isNull);
    },
  );

  test(
    'obsolete lookup cannot create a profile or finish the new session',
    () async {
      authService.controller.add(
        const AppUser(uid: 'user-a', email: 'user-a@example.com'),
      );

      authService.controller.add(
        const AppUser(uid: 'user-b', email: 'user-b@example.com'),
      );

      expect(profileService.requests, hasLength(2));
      expect(provider.user?.uid, 'user-b');
      expect(provider.isLoading, isTrue);

      profileService.requests[0].completer.complete(null);

      await Future<void>.delayed(Duration.zero);

      expect(profileService.createdUids, isEmpty);
      expect(provider.user?.uid, 'user-b');
      expect(provider.isLoading, isTrue);

      profileService.requests[1].completer.complete(null);

      await Future<void>.delayed(Duration.zero);

      expect(profileService.createdUids, ['user-b']);
      expect(provider.isLoading, isFalse);
      expect(provider.profileInitializationError, isNull);
    },
  );

  test('sign-out invalidates a pending profile lookup', () async {
    authService.controller.add(
      const AppUser(uid: 'user-a', email: 'user-a@example.com'),
    );

    authService.controller.add(null);

    expect(provider.user, isNull);
    expect(provider.isLoading, isFalse);

    profileService.requests.single.completer.complete(null);

    await Future<void>.delayed(Duration.zero);

    expect(provider.user, isNull);
    expect(profileService.createdUids, isEmpty);
    expect(provider.profileInitializationError, isNull);
  });

  test(
    'disposal prevents pending profile work from notifying or creating',
    () async {
      var notifications = 0;

      provider.addListener(() {
        notifications++;
      });

      authService.controller.add(
        const AppUser(uid: 'user-a', email: 'user-a@example.com'),
      );

      final notificationsBeforeDisposal = notifications;

      provider.dispose();
      disposed = true;

      profileService.requests.single.completer.complete(null);

      await Future<void>.delayed(Duration.zero);

      expect(profileService.createdUids, isEmpty);
      expect(notifications, notificationsBeforeDisposal);
    },
  );

  test(
    'profile initialization failure is handled and can be retried',
    () async {
      authService.controller.add(
        const AppUser(uid: 'user-a', email: 'user-a@example.com'),
      );

      profileService.requests.single.completer.completeError(
        StateError('Test profile lookup failure'),
      );

      await Future<void>.delayed(Duration.zero);

      expect(provider.user?.uid, 'user-a');
      expect(provider.isLoading, isFalse);
      expect(
        provider.profileInitializationError,
        'Your account profile could not be prepared. Please try again.',
      );

      final retry = provider.retryProfileInitialization();

      expect(profileService.requests, hasLength(2));
      expect(provider.isLoading, isTrue);
      expect(provider.profileInitializationError, isNull);

      profileService.requests[1].completer.complete(null);
      await retry;

      expect(profileService.createdUids, ['user-a']);
      expect(provider.isLoading, isFalse);
      expect(provider.profileInitializationError, isNull);
    },
  );
}
