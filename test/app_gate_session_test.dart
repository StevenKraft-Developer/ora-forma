import 'dart:async';

import 'package:catholic_habits/models/app_user.dart';
import 'package:catholic_habits/models/user_profile.dart';
import 'package:catholic_habits/providers/auth_provider.dart';
import 'package:catholic_habits/providers/user_profile_provider.dart';
import 'package:catholic_habits/screens/root/app_gate.dart';
import 'package:catholic_habits/services/user_profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:catholic_habits/screens/onboarding/habit_onboarding_screen.dart';
import 'package:catholic_habits/models/habit.dart';
import 'package:catholic_habits/providers/habit_provider.dart';
import 'package:catholic_habits/main_navigation_screen.dart';
import 'package:catholic_habits/providers/progress_provider.dart';

class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  AppUser _currentUser = const AppUser(
    uid: 'user-a',
    email: 'user-a@example.com',
  );

  int _version = 1;

  @override
  AppUser? get user => _currentUser;

  @override
  int get sessionVersion => _version;

  @override
  bool get isLoading => false;

  @override
  bool get isAuthenticated => true;

  @override
  String? get profileInitializationError => null;

  @override
  String? get error => null;

  void beginSession(String uid) {
    _currentUser = AppUser(uid: uid, email: '$uid@example.com');
    _version++;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected auth call: ${invocation.memberName}');
  }
}

class _ProfileRequest {
  _ProfileRequest(this.uid);

  final String uid;
  final completer = Completer<UserProfile?>();
}

class _FakeProfileService implements UserProfileService {
  final requests = <_ProfileRequest>[];

  @override
  Future<UserProfile?> getProfile(String uid) {
    final request = _ProfileRequest(uid);
    requests.add(request);
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

class _FakeHabitProvider extends ChangeNotifier implements HabitProvider {
  bool _loading = false;
  bool _loaded = true;
  String? _loadError;

  final retryUids = <String>[];
  Completer<void>? _retry;

  @override
  bool get isLoading => _loading;

  @override
  bool get isLoaded => _loaded;

  @override
  String? get loadError => _loadError;

  @override
  List<Habit> get allHabits => kDefaultCatholicHabitSet;

  void failLoad() {
    _loading = false;
    _loaded = false;
    _loadError = 'Your habits could not be loaded. Please try again.';
    notifyListeners();
  }

  @override
  Future<void> retryLoadHabits(String uid) {
    retryUids.add(uid);
    _loading = true;
    _loaded = false;
    _loadError = null;
    final pending = Completer<void>();
    _retry = pending;
    notifyListeners();
    return pending.future;
  }

  void finishRetry({required bool succeeds}) {
    final pending = _retry!;
    _retry = null;

    _loading = false;
    _loaded = succeeds;
    _loadError = succeeds
        ? null
        : 'Your habits could not be loaded. Please try again.';

    notifyListeners();
    pending.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected habit call: ${invocation.memberName}');
  }
}

class _FakeProgressProvider extends ChangeNotifier implements ProgressProvider {
  @override
  bool get isLoaded => false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Unexpected progress call: ${invocation.memberName}',
    );
  }
}

class _GateHarness {
  final auth = _FakeAuthProvider();
  final service = _FakeProfileService();
  final onboardingRequests = <Completer<bool?>>[];
  final habits = _FakeHabitProvider();
  final progress = _FakeProgressProvider();
  final onboardingUids = <String>[];

  Future<bool?> loadOnboarding(String uid) {
    final request = Completer<bool?>();
    onboardingUids.add(uid);
    onboardingRequests.add(request);
    return request.future;
  }

  late final profiles = UserProfileProvider(profileService: service);

  Future<void> completeCurrentProfile(WidgetTester tester) async {
    service.requests.last.completer.complete(_profile(auth.user!.uid));

    await tester.pump();
    await tester.pump();
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<UserProfileProvider>.value(value: profiles),
          ChangeNotifierProvider<HabitProvider>.value(value: habits),
          ChangeNotifierProvider<ProgressProvider>.value(value: progress),
        ],
        child: MaterialApp(home: AppGate(loadHabitOnboarding: loadOnboarding)),
      ),
    );

    await tester.pump();

    expect(service.requests, hasLength(1));
    expect(service.requests.single.uid, 'user-a');
  }

  Future<void> beginSession(WidgetTester tester, String uid) async {
    auth.beginSession(uid);

    await tester.pump();
    await tester.pump();
  }

  void dispose() {
    profiles.dispose();
    auth.dispose();
    habits.dispose();
    progress.dispose();
  }
}

void main() {
  for (final onboardingComplete in [false, true]) {
    testWidgets(
      onboardingComplete
          ? 'habit load error blocks returning-user routing and retries'
          : 'habit load error blocks onboarding routing and retries',
      (tester) async {
        final harness = _GateHarness();
        addTearDown(harness.dispose);

        harness.habits.failLoad();

        await harness.mount(tester);
        await harness.completeCurrentProfile(tester);

        harness.onboardingRequests.single.complete(onboardingComplete);
        await tester.pumpAndSettle();

        expect(
          find.text('Your habits could not be loaded. Please try again.'),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsOneWidget);
        expect(find.byType(HabitOnboardingScreen), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(harness.habits.retryUids, isEmpty);

        await tester.tap(find.text('Try again'));
        await tester.pump();

        expect(harness.habits.retryUids, ['user-a']);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Try again'), findsNothing);
        expect(find.byType(HabitOnboardingScreen), findsNothing);

        harness.habits.finishRetry(succeeds: false);
        await tester.pumpAndSettle();

        expect(
          find.text('Your habits could not be loaded. Please try again.'),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Retrying habits must not re-read or alter onboarding status.
        expect(harness.onboardingRequests, hasLength(1));
        expect(harness.onboardingUids, ['user-a']);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('successful habit retry resumes the main app', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = _GateHarness();
    addTearDown(harness.dispose);

    harness.habits.failLoad();

    await harness.mount(tester);
    await harness.completeCurrentProfile(tester);

    harness.onboardingRequests.single.complete(true);
    await tester.pumpAndSettle();

    expect(
      find.text('Your habits could not be loaded. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(MainNavigationScreen), findsNothing);
    expect(find.byType(HabitOnboardingScreen), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(harness.habits.retryUids, ['user-a']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(MainNavigationScreen), findsNothing);

    harness.habits.finishRetry(succeeds: true);

    // Progress deliberately remains loading. Pump a bounded number of
    // frames rather than waiting for its spinners to settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MainNavigationScreen), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(HabitOnboardingScreen), findsNothing);
    expect(find.text('Try again'), findsNothing);

    // Habit recovery must preserve the previously read onboarding status.
    expect(harness.onboardingRequests, hasLength(1));
    expect(harness.onboardingUids, ['user-a']);
    expect(harness.habits.retryUids, ['user-a']);
    expect(tester.takeException(), isNull);

    // Unmount the main app before disposing the harness providers.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('successful habit retry resumes onboarding', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = _GateHarness();
    addTearDown(harness.dispose);

    harness.habits.failLoad();

    await harness.mount(tester);
    await harness.completeCurrentProfile(tester);

    harness.onboardingRequests.single.complete(false);
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(HabitOnboardingScreen), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(harness.habits.retryUids, ['user-a']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    harness.habits.finishRetry(succeeds: true);
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsNothing);
    expect(find.byType(HabitOnboardingScreen), findsOneWidget);
    expect(
      tester
          .widget<HabitOnboardingScreen>(find.byType(HabitOnboardingScreen))
          .initialHabits,
      kDefaultCatholicHabitSet,
    );
    expect(harness.onboardingRequests, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('obsolete profile success cannot route the newer session', (
    tester,
  ) async {
    final harness = _GateHarness();
    addTearDown(harness.dispose);

    await harness.mount(tester);
    await harness.beginSession(tester, 'user-b');

    expect(harness.service.requests, hasLength(2));
    expect(harness.service.requests[1].uid, 'user-b');

    harness.service.requests[0].completer.complete(_profile('user-a'));
    await tester.pump();

    expect(harness.profiles.profile, isNull);
    expect(harness.profiles.isLoading, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Try again'), findsNothing);

    harness.service.requests[1].completer.complete(null);
    await tester.pumpAndSettle();

    expect(
      find.text('Your profile is unavailable. Please try again.'),
      findsOneWidget,
    );
    expect(harness.profiles.profile, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('obsolete onboarding read cannot route the newer session', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = _GateHarness();
    addTearDown(harness.dispose);

    await harness.mount(tester);
    await harness.completeCurrentProfile(tester);

    expect(harness.onboardingRequests, hasLength(1));

    await harness.beginSession(tester, 'user-b');
    await harness.completeCurrentProfile(tester);

    expect(harness.onboardingRequests, hasLength(2));

    // An old "complete" result must not send account B to the main app.
    harness.onboardingRequests[0].complete(true);
    await tester.pump();

    expect(find.byType(HabitOnboardingScreen), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    harness.onboardingRequests[1].complete(false);
    await tester.pumpAndSettle();

    expect(find.byType(HabitOnboardingScreen), findsOneWidget);
    expect(harness.profiles.profile?.uid, 'user-b');
    expect(tester.takeException(), isNull);
  });

  testWidgets('obsolete onboarding completion cannot finish a newer session', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = _GateHarness();
    addTearDown(harness.dispose);

    await harness.mount(tester);
    await harness.completeCurrentProfile(tester);

    harness.onboardingRequests.single.complete(false);
    await tester.pumpAndSettle();

    final oldScreen = tester.widget<HabitOnboardingScreen>(
      find.byType(HabitOnboardingScreen),
    );
    final oldCompletion = oldScreen.onCompleted;
    final oldKey = oldScreen.key;

    // Return to the same UID, but in a new authentication session.
    await harness.beginSession(tester, 'user-a');
    await harness.completeCurrentProfile(tester);

    expect(harness.onboardingRequests, hasLength(2));

    harness.onboardingRequests[1].complete(false);
    await tester.pumpAndSettle();

    final currentScreen = tester.widget<HabitOnboardingScreen>(
      find.byType(HabitOnboardingScreen),
    );

    expect(currentScreen.key, isNot(oldKey));

    oldCompletion();
    await tester.pumpAndSettle();

    expect(find.byType(HabitOnboardingScreen), findsOneWidget);
    expect(
      tester
          .widget<HabitOnboardingScreen>(find.byType(HabitOnboardingScreen))
          .key,
      currentScreen.key,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('current onboarding read failure offers a working retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = _GateHarness();
    addTearDown(harness.dispose);

    await harness.mount(tester);
    await harness.completeCurrentProfile(tester);

    harness.onboardingRequests.single.completeError(
      StateError('Test onboarding read failure'),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Your onboarding status could not be checked. Please try again.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(harness.onboardingRequests, hasLength(2));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    harness.onboardingRequests[1].complete(false);
    await tester.pumpAndSettle();

    expect(find.byType(HabitOnboardingScreen), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'obsolete profile failure does not show an error for new account',
    (tester) async {
      final harness = _GateHarness();
      addTearDown(harness.dispose);

      await harness.mount(tester);
      await harness.beginSession(tester, 'user-b');

      harness.service.requests[0].completer.completeError(
        StateError('Obsolete profile failure'),
      );
      await tester.pump();

      expect(
        find.text('Your profile could not be loaded. Please try again.'),
        findsNothing,
      );
      expect(harness.profiles.isLoading, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      harness.service.requests[1].completer.complete(null);
      await tester.pumpAndSettle();

      expect(
        find.text('Your profile is unavailable. Please try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('current profile failure shows retry and starts another load', (
    tester,
  ) async {
    final harness = _GateHarness();
    addTearDown(harness.dispose);

    await harness.mount(tester);

    harness.service.requests.single.completer.completeError(
      StateError('Current profile failure'),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Your profile could not be loaded. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(harness.service.requests, hasLength(2));
    expect(harness.service.requests[1].uid, 'user-a');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    harness.service.requests[1].completer.complete(null);
    await tester.pumpAndSettle();

    expect(
      find.text('Your profile is unavailable. Please try again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('new session with same UID starts a fresh profile load', (
    tester,
  ) async {
    final harness = _GateHarness();
    addTearDown(harness.dispose);

    await harness.mount(tester);

    final originalVersion = harness.auth.sessionVersion;

    await harness.beginSession(tester, 'user-a');

    expect(harness.auth.sessionVersion, greaterThan(originalVersion));
    expect(harness.service.requests, hasLength(2));
    expect(harness.service.requests[1].uid, 'user-a');

    harness.service.requests[0].completer.complete(_profile('user-a'));
    await tester.pump();

    expect(harness.profiles.profile, isNull);
    expect(harness.profiles.isLoading, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    harness.service.requests[1].completer.complete(null);
    await tester.pumpAndSettle();

    expect(
      find.text('Your profile is unavailable. Please try again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing onboarding metadata requires review for each account', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harness = _GateHarness();
    addTearDown(harness.dispose);

    await harness.mount(tester);
    await harness.completeCurrentProfile(tester);

    expect(harness.onboardingUids, ['user-a']);
    expect(harness.onboardingRequests, hasLength(1));

    harness.onboardingRequests[0].complete(null);
    await tester.pumpAndSettle();

    expect(find.byType(HabitOnboardingScreen), findsOneWidget);

    final accountAScreen = tester.widget<HabitOnboardingScreen>(
      find.byType(HabitOnboardingScreen),
    );

    expect(accountAScreen.initialHabits, kDefaultCatholicHabitSet);

    await harness.beginSession(tester, 'user-b');
    await harness.completeCurrentProfile(tester);

    expect(harness.onboardingUids, ['user-a', 'user-b']);
    expect(harness.onboardingRequests, hasLength(2));

    harness.onboardingRequests[1].complete(null);
    await tester.pumpAndSettle();

    expect(find.byType(HabitOnboardingScreen), findsOneWidget);

    final accountBScreen = tester.widget<HabitOnboardingScreen>(
      find.byType(HabitOnboardingScreen),
    );

    expect(accountBScreen.key, isNot(accountAScreen.key));
    expect(tester.takeException(), isNull);
  });
}
