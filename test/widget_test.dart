import 'dart:async';

import 'package:findit_my/data_layer/Models/app_models.dart';
import 'package:findit_my/data_layer/Models/journey.dart' as journey;
import 'package:findit_my/data_layer/Repositories/map_quest_repository.dart';
import 'package:findit_my/data_layer/Repositories/shake_find_repository.dart';
import 'package:findit_my/data_layer/Repositories/shake_find_repository_impl.dart';
import 'package:findit_my/data_layer/Service Managers/Remote Services/supabase_service.dart';
import 'package:findit_my/data_layer/Service Managers/device/location_service.dart';
import 'package:findit_my/main.dart';
import 'package:findit_my/ui_layer/ViewModel/app_view_model.dart';
import 'package:findit_my/ui_layer/ViewModel/auth_view_model.dart';
import 'package:findit_my/ui_layer/ViewModel/map_quest_view_model.dart';
import 'package:findit_my/ui_layer/ViewModel/shake_find_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('UC102 arrival verification', () {
    test('rejects accuracy worse than 30 metres', () {
      final tracker = ArrivalDwellTracker();
      final result = tracker.evaluate(
        accuracyMeters: 30.1,
        distanceMeters: 10,
        at: DateTime(2026),
      );
      expect(result.progress, ArrivalProgress.poorAccuracy);
    });

    test('requires ten continuous seconds inside 50 metres', () {
      final tracker = ArrivalDwellTracker();
      final start = DateTime(2026);
      expect(
        tracker
            .evaluate(accuracyMeters: 10, distanceMeters: 50, at: start)
            .progress,
        ArrivalProgress.dwelling,
      );
      expect(
        tracker
            .evaluate(
              accuracyMeters: 10,
              distanceMeters: 49,
              at: start.add(const Duration(seconds: 9)),
            )
            .progress,
        ArrivalProgress.dwelling,
      );
      expect(
        tracker
            .evaluate(
              accuracyMeters: 10,
              distanceMeters: 49,
              at: start.add(const Duration(seconds: 10)),
            )
            .progress,
        ArrivalProgress.verified,
      );
    });

    test('leaving the radius resets dwell to zero', () {
      final tracker = ArrivalDwellTracker();
      final start = DateTime(2026);
      tracker.evaluate(accuracyMeters: 10, distanceMeters: 20, at: start);
      expect(
        tracker
            .evaluate(
              accuracyMeters: 10,
              distanceMeters: 51,
              at: start.add(const Duration(seconds: 8)),
            )
            .progress,
        ArrivalProgress.outsideRadius,
      );
      expect(
        tracker
            .evaluate(
              accuracyMeters: 10,
              distanceMeters: 20,
              at: start.add(const Duration(seconds: 12)),
            )
            .remaining,
        const Duration(seconds: 10),
      );
    });

    test('poor GPS accuracy resets dwell to zero', () {
      final tracker = ArrivalDwellTracker();
      final start = DateTime(2026);
      tracker.evaluate(accuracyMeters: 8, distanceMeters: 20, at: start);
      expect(
        tracker
            .evaluate(
              accuracyMeters: 31,
              distanceMeters: 20,
              at: start.add(const Duration(seconds: 7)),
            )
            .progress,
        ArrivalProgress.poorAccuracy,
      );
      expect(
        tracker
            .evaluate(
              accuracyMeters: 8,
              distanceMeters: 20,
              at: start.add(const Duration(seconds: 8)),
            )
            .remaining,
        const Duration(seconds: 10),
      );
    });
  });

  group('Mystery replayability', () {
    const destinations = <journey.JourneyDestination>[
      journey.JourneyDestination(
        id: 'a',
        name: 'A',
        category: 'culture',
        latitude: 3,
        longitude: 101,
        address: 'A',
        description: 'A',
      ),
      journey.JourneyDestination(
        id: 'b',
        name: 'B',
        category: 'history',
        latitude: 3.1,
        longitude: 101.1,
        address: 'B',
        description: 'B',
      ),
      journey.JourneyDestination(
        id: 'c',
        name: 'C',
        category: 'culture',
        latitude: 3.2,
        longitude: 101.2,
        address: 'C',
        description: 'C',
      ),
    ];

    test('prioritizes destinations never completed by the user', () {
      final pool = mysteryDestinationSelectionPool(
        destinations,
        completedDestinationIds: const <String>{'a', 'b'},
        recentDestinationIds: const <String>{'a'},
      );
      expect(pool.map((value) => value.id), <String>['c']);
    });

    test('falls back to older visits before recent destinations', () {
      final pool = mysteryDestinationSelectionPool(
        destinations,
        completedDestinationIds: const <String>{'a', 'b', 'c'},
        recentDestinationIds: const <String>{'a', 'b'},
      );
      expect(pool.map((value) => value.id), <String>['c']);
    });

    test('allows any candidate when every destination is recent', () {
      final pool = mysteryDestinationSelectionPool(
        destinations,
        completedDestinationIds: const <String>{'a', 'b', 'c'},
        recentDestinationIds: const <String>{'a', 'b', 'c'},
      );
      expect(pool, destinations);
    });

    test(
      'temporarily excludes a rejected revisit when an alternative exists',
      () {
        final pool = mysteryDestinationSelectionPool(
          destinations,
          completedDestinationIds: const <String>{'a', 'b', 'c'},
          recentDestinationIds: const <String>{'a', 'b', 'c'},
          excludedDestinationId: 'a',
        );
        expect(pool.map((destination) => destination.id), isNot(contains('a')));
        expect(pool, isNotEmpty);
      },
    );
  });

  test('completed Mystery pins refresh through the Map ViewModel', () async {
    final repository = FakeMapQuestRepository();
    final model = MapQuestViewModel(questRepository: repository);
    addTearDown(model.dispose);

    await model.refreshCompletedMysteries();

    expect(repository.completedMysteryRequests, 1);
    expect(model.completedMysteries.single.place.id, 'completed-place');
    expect(model.completedMysteries.single.completionCount, 2);
    model.selectCompletedMystery(model.completedMysteries.single);
    expect(model.selected?.id, 'completed-place');
    expect(model.selectedMysteryCompletion, isNotNull);
  });

  test('Map Mystery state hides spoilers and exposes only revealed state', () {
    final repository = FakeMapQuestRepository();
    final model = MapQuestViewModel(questRepository: repository);
    addTearDown(model.dispose);
    final place = repository.completions.single.place;

    model.setMysteryJourneyState(
      destination: place,
      revealed: false,
      completed: false,
    );
    expect(model.shouldHideForActiveMystery(place), isTrue);
    expect(model.revealedActiveMysteryDestination, isNull);

    model.setMysteryJourneyState(
      destination: place,
      revealed: true,
      completed: false,
    );
    expect(model.shouldHideForActiveMystery(place), isTrue);
    expect(model.revealedActiveMysteryDestination?.id, place.id);

    model.setMysteryJourneyState(
      destination: place,
      revealed: true,
      completed: true,
    );
    expect(model.shouldHideForActiveMystery(place), isFalse);
    expect(model.revealedActiveMysteryDestination, isNull);
  });

  test(
    'completed Mystery history remains scoped to each Map ViewModel',
    () async {
      final completedRepository = FakeMapQuestRepository();
      final newUserRepository = FakeMapQuestRepository()..completions.clear();
      final completedUser = MapQuestViewModel(
        questRepository: completedRepository,
      );
      final newUser = MapQuestViewModel(questRepository: newUserRepository);
      addTearDown(completedUser.dispose);
      addTearDown(newUser.dispose);

      await completedUser.refreshCompletedMysteries();
      await newUser.refreshCompletedMysteries();

      expect(completedUser.completedMysteries, hasLength(1));
      expect(newUser.completedMysteries, isEmpty);
    },
  );

  group('password recovery', () {
    test('auth redirect resolver uses web origin and Android manifest URI', () {
      expect(
        AuthRedirectResolver.resolve(
          web: true,
          baseUri: Uri.parse('http://localhost:8080/register'),
        ),
        AuthRedirectResolver.localhostWebCallback,
      );
      expect(
        AuthRedirectResolver.resolve(web: false),
        'finditmy://login-callback/',
      );
      expect(
        AuthRedirectResolver.resolve(
          configured: 'https://example.com/auth/',
          web: false,
        ),
        'https://example.com/auth/',
      );
    });

    test('rejects invalid email without sending a recovery request', () async {
      final service = FakeRecoverySupabaseService();
      final auth = AuthViewModel(supabaseService: service);
      addTearDown(auth.dispose);
      addTearDown(service.dispose);

      expect(
        await auth.recover('not-an-email'),
        AuthViewModel.invalidEmailMessage,
      );
      expect(service.recoveryRequests, 0);
    });

    test('valid request uses the configured auth callback', () async {
      final service = FakeRecoverySupabaseService();
      final auth = AuthViewModel(supabaseService: service);
      addTearDown(auth.dispose);
      addTearDown(service.dispose);

      expect(await auth.recover('traveller@example.com'), isNull);
      expect(service.recoveryRequests, 1);
      expect(service.lastRecoveryEmail, 'traveller@example.com');
      expect(service.lastRedirectTo, AuthRedirectResolver.androidCallback);
      expect(auth.recoverySent, isTrue);
    });

    test(
      'recovery event enters reset mode and normal sign-in does not',
      () async {
        final service = FakeRecoverySupabaseService();
        final auth = AuthViewModel(supabaseService: service);
        addTearDown(auth.dispose);
        addTearDown(service.dispose);

        service.emit(AuthChangeEvent.signedIn, hasSession: true);
        await Future<void>.delayed(Duration.zero);
        expect(auth.isPasswordRecovery, isFalse);

        service.emit(AuthChangeEvent.passwordRecovery, hasSession: true);
        await Future<void>.delayed(Duration.zero);
        expect(auth.isPasswordRecovery, isTrue);
        expect(auth.shouldShowResetPassword, isTrue);
      },
    );

    test('new password policy and confirmation are enforced', () async {
      final service = FakeRecoverySupabaseService();
      final auth = AuthViewModel(supabaseService: service);
      addTearDown(auth.dispose);
      addTearDown(service.dispose);
      service.emit(AuthChangeEvent.passwordRecovery, hasSession: true);
      await Future<void>.delayed(Duration.zero);

      expect(
        await auth.resetPassword('short!', 'short!'),
        AuthViewModel.invalidPasswordMessage,
      );
      expect(
        await auth.resetPassword('lowercase!', 'lowercase!'),
        AuthViewModel.invalidPasswordMessage,
      );
      expect(
        await auth.resetPassword('NoSymbol1', 'NoSymbol1'),
        AuthViewModel.invalidPasswordMessage,
      );
      expect(
        await auth.resetPassword('Has Space!', 'Has Space!'),
        AuthViewModel.invalidPasswordMessage,
      );
      expect(
        await auth.resetPassword('ValidPass!', 'DifferentPass!'),
        AuthViewModel.passwordsDoNotMatchMessage,
      );
      expect(service.passwordUpdates, 0);
    });

    test(
      'valid password updates once, signs out, and clears recovery',
      () async {
        final service = FakeRecoverySupabaseService();
        final auth = AuthViewModel(supabaseService: service);
        addTearDown(auth.dispose);
        addTearDown(service.dispose);
        service.emit(AuthChangeEvent.passwordRecovery, hasSession: true);
        await Future<void>.delayed(Duration.zero);

        expect(await auth.resetPassword('ValidPass!', 'ValidPass!'), isNull);
        expect(service.passwordUpdates, 1);
        expect(service.localSignOuts, 1);
        expect(auth.isPasswordRecovery, isFalse);
        expect(auth.recoverySent, isFalse);
      },
    );

    test('invalid or expired recovery session is rejected safely', () async {
      final service = FakeRecoverySupabaseService();
      final auth = AuthViewModel(supabaseService: service);
      addTearDown(auth.dispose);
      addTearDown(service.dispose);
      service.emit(AuthChangeEvent.passwordRecovery, hasSession: false);
      await Future<void>.delayed(Duration.zero);

      expect(auth.shouldShowResetPassword, isTrue);
      expect(auth.recoveryError, AuthViewModel.invalidRecoverySessionMessage);
      expect(
        await auth.resetPassword('ValidPass!', 'ValidPass!'),
        AuthViewModel.invalidRecoverySessionMessage,
      );
      expect(service.passwordUpdates, 0);
    });

    test('signup confirmation and normal login remain separate', () async {
      final service = FakeRecoverySupabaseService();
      final auth = AuthViewModel(supabaseService: service);
      addTearDown(auth.dispose);
      addTearDown(service.dispose);

      expect(await auth.login('traveller@example.com', 'ValidPass!'), isNull);
      expect(service.loginRequests, 1);
      expect(auth.isPasswordRecovery, isFalse);

      expect(
        await auth.register(
          name: 'Traveller One',
          email: 'new@example.com',
          password: 'ValidPass!',
          confirmation: 'ValidPass!',
          phone: '0123456789',
          identityNumber: '010101010101',
          birthday: DateTime(2001),
        ),
        isNull,
      );
      expect(service.lastRegistrationData?['username'], 'Traveller One');
      expect(service.lastRegistrationData?['identity_type'], 'ic');
      expect(service.lastRegistrationData?['identity_number'], '010101010101');
      expect(service.lastRegistrationData?['issuing_country'], 'MY');
      expect(
        service.lastRegistrationRedirectTo,
        AuthRedirectResolver.androidCallback,
      );
      service.emit(AuthChangeEvent.signedIn, hasSession: true);
      await Future<void>.delayed(Duration.zero);
      expect(service.localSignOuts, 1);
      expect(auth.isPasswordRecovery, isFalse);
      expect(
        auth.takeAuthNotice()?.message,
        AuthViewModel.verificationSuccessMessage,
      );
      expect(auth.takeAuthNotice(), isNull);
    });

    test('verification resend cooldown enables and restarts safely', () async {
      final service = FakeRecoverySupabaseService();
      final auth = AuthViewModel(
        supabaseService: service,
        verificationResendCooldownSeconds: 2,
        verificationResendTick: const Duration(milliseconds: 2),
      );
      addTearDown(auth.dispose);
      addTearDown(service.dispose);

      expect(
        await auth.register(
          name: 'Traveller One',
          email: 'new@example.com',
          password: 'ValidPass!',
          confirmation: 'ValidPass!',
          phone: '0123456789',
          identityNumber: '010101010101',
          birthday: DateTime(2001),
        ),
        isNull,
      );
      expect(auth.canResendVerification, isFalse);
      expect(auth.verificationResendLabel, 'Resend available in 2s');
      await Future<void>.delayed(const Duration(milliseconds: 8));
      expect(auth.canResendVerification, isTrue);

      expect(await auth.resendVerificationEmail(), isNull);
      expect(service.verificationResends, 1);
      expect(auth.verificationResendSecondsRemaining, 2);
      expect(auth.canResendVerification, isFalse);
    });

    test('invalid signup link stays separate from password recovery', () {
      final service = FakeRecoverySupabaseService();
      final auth = AuthViewModel(supabaseService: service);
      addTearDown(auth.dispose);
      addTearDown(service.dispose);

      auth.reportInvalidVerificationLink();
      expect(auth.isPasswordRecovery, isFalse);
      expect(auth.shouldShowResetPassword, isFalse);
      expect(
        auth.takeAuthNotice()?.message,
        AuthViewModel.invalidVerificationLinkMessage,
      );
    });

    test('initial verification success is surfaced once by the app', () {
      final service = FakeRecoverySupabaseService();
      final auth = AuthViewModel(
        supabaseService: service,
        initialNotice: const AuthNotice(
          AuthViewModel.verificationSuccessMessage,
          AuthNoticeKind.success,
        ),
      );
      final model = AppViewModel(
        mysteryRepository: FakeShakeFindRepository(),
        authViewModel: auth,
      );
      addTearDown(model.dispose);
      addTearDown(service.dispose);

      expect(model.toast?.message, AuthViewModel.verificationSuccessMessage);
      expect(auth.takeAuthNotice(), isNull);
      expect(model.profile.stage, ProfileStage.login);
    });

    testWidgets('recovery event renders the dedicated reset screen', (
      tester,
    ) async {
      final service = FakeRecoverySupabaseService();
      final auth = AuthViewModel(supabaseService: service);
      final model = AppViewModel(
        mysteryRepository: FakeShakeFindRepository(),
        authViewModel: auth,
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(FindItMyApp(appViewModel: model));

      service.emit(AuthChangeEvent.passwordRecovery, hasSession: true);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('reset_password_screen')), findsOneWidget);
      expect(find.byKey(const Key('reset_new_password')), findsOneWidget);
      expect(find.byKey(const Key('reset_password_submit')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('reset_new_password')),
        'ValidPass!',
      );
      await tester.enterText(
        find.byKey(const Key('reset_confirm_password')),
        'ValidPass!',
      );
      await tester.tap(find.byKey(const Key('reset_password_submit')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('login_screen')), findsOneWidget);
      expect(find.text(AuthViewModel.resetSuccessMessage), findsOneWidget);
    });

    test(
      'passport registration normalizes and submits document metadata',
      () async {
        final service = FakeRecoverySupabaseService();
        final auth = AuthViewModel(supabaseService: service);
        addTearDown(auth.dispose);
        addTearDown(service.dispose);

        auth.selectIdentityType(IdentityType.passport);
        auth.selectIssuingCountry('sg');
        expect(
          await auth.register(
            name: 'Passport Traveller',
            email: 'passport@example.com',
            password: 'ValidPass!',
            confirmation: 'ValidPass!',
            phone: '0123456789',
            identityNumber: 'a12-345 678',
            birthday: DateTime(2001),
          ),
          isNull,
        );
        expect(service.lastRegistrationData?['identity_type'], 'passport');
        expect(service.lastRegistrationData?['identity_number'], 'A12345678');
        expect(service.lastRegistrationData?['issuing_country'], 'SG');
        expect(service.lastRegistrationData, isNot(contains('ic')));
      },
    );

    test('identity validators keep IC and passport rules separate', () {
      expect(AuthViewModel.isValidIc('010101-01-0101'), isTrue);
      expect(AuthViewModel.isValidIc('A12345678'), isFalse);
      expect(AuthViewModel.isValidPassport('A12345678'), isTrue);
      expect(AuthViewModel.isValidPassport('12'), isFalse);
      expect(AuthViewModel.isValidPassport('ABC@123'), isFalse);
    });

    test(
      'unrelated signup database failures are not mapped to duplicate M10',
      () async {
        final service = FakeRecoverySupabaseService()
          ..registrationError = const AuthException(
            'Database error saving new user',
          );
        final auth = AuthViewModel(supabaseService: service);
        addTearDown(auth.dispose);
        addTearDown(service.dispose);

        expect(
          await auth.register(
            name: 'Traveller One',
            email: 'new@example.com',
            password: 'ValidPass!',
            confirmation: 'ValidPass!',
            phone: '0123456789',
            identityNumber: '010101010101',
            birthday: DateTime(2001),
          ),
          AuthViewModel.genericRegistrationErrorMessage,
        );
      },
    );

    test(
      'signup email failures use actionable messages instead of raw JSON',
      () async {
        final service = FakeRecoverySupabaseService()
          ..registrationError = const AuthException(
            '{"code":"unexpected_failure","message":"Error sending confirmation email"}',
          );
        final auth = AuthViewModel(supabaseService: service);
        addTearDown(auth.dispose);
        addTearDown(service.dispose);

        expect(
          await auth.register(
            name: 'Traveller One',
            email: 'new@example.com',
            password: 'ValidPass!',
            confirmation: 'ValidPass!',
            phone: '0123456789',
            identityNumber: '010101010101',
            birthday: DateTime(2001),
          ),
          AuthViewModel.confirmationEmailFailureMessage,
        );

        service.registrationError = const AuthException(
          'email rate limit exceeded',
        );
        expect(
          await auth.register(
            name: 'Traveller One',
            email: 'new@example.com',
            password: 'ValidPass!',
            confirmation: 'ValidPass!',
            phone: '0123456789',
            identityNumber: '010101010101',
            birthday: DateTime(2001),
          ),
          AuthViewModel.emailRateLimitMessage,
        );
      },
    );

    test(
      'proven duplicate identity failure maps to generic M10 wording',
      () async {
        final service = FakeRecoverySupabaseService()
          ..registrationError = const AuthException(
            'Identification number is already registered',
          );
        final auth = AuthViewModel(supabaseService: service);
        addTearDown(auth.dispose);
        addTearDown(service.dispose);

        expect(
          await auth.register(
            name: 'Traveller One',
            email: 'new@example.com',
            password: 'ValidPass!',
            confirmation: 'ValidPass!',
            phone: '0123456789',
            identityNumber: '010101010101',
            birthday: DateTime(2001),
          ),
          AuthViewModel.duplicateRegistrationMessage,
        );
      },
    );

    testWidgets(
      'registration shows exactly one identity document field at a time',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final auth = FakeAuthViewModel(signedIn: false);
        final model = AppViewModel(
          mysteryRepository: FakeShakeFindRepository(),
          authViewModel: auth,
        );
        await tester.pumpWidget(FindItMyApp(appViewModel: model));
        await tester.pump(const Duration(milliseconds: 50));
        model.profile.setStage(ProfileStage.register);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('register_ic')), findsOneWidget);
        expect(find.byKey(const Key('register_passport')), findsNothing);
        expect(find.byKey(const Key('register_issuing_country')), findsNothing);

        await tester.tap(find.text('Passport'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('register_ic')), findsNothing);
        expect(find.byKey(const Key('register_passport')), findsOneWidget);
        expect(
          find.byKey(const Key('register_issuing_country')),
          findsOneWidget,
        );

        await tester.tap(find.text('Malaysian IC'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('register_ic')), findsOneWidget);
        expect(find.byKey(const Key('register_passport')), findsNothing);
      },
    );
  });

  Future<(AppViewModel, FakeShakeFindRepository)> pumpApp(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    AppViewModel? viewModel,
    FakeShakeFindRepository? repository,
    FakeAuthViewModel? authViewModel,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fake = repository ?? FakeShakeFindRepository();
    final fakeAuth = authViewModel ?? FakeAuthViewModel(signedIn: true);
    final model =
        viewModel ??
        AppViewModel(mysteryRepository: fake, authViewModel: fakeAuth);
    await tester.pumpWidget(FindItMyApp(appViewModel: model));
    await tester.pump(const Duration(milliseconds: 50));
    return (model, fake);
  }

  Future<void> scrollToArrival(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('test_real_arrival')),
      240,
      scrollable: find.descendant(
        of: find.byKey(const PageStorageKey<String>('mystery-active')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
  }

  testWidgets('authentication gate blocks modules until sign in', (
    tester,
  ) async {
    final auth = FakeAuthViewModel(signedIn: false);
    final (model, _) = await pumpApp(tester, authViewModel: auth);

    expect(find.byKey(const Key('authentication_gate')), findsOneWidget);
    expect(find.byKey(const Key('tab_mystery')), findsNothing);
    expect(find.byKey(const Key('login_screen')), findsOneWidget);

    auth.signInForTest();
    await tester.pump(const Duration(milliseconds: 100));
    expect(model.requiresAuthentication, isFalse);
    expect(find.byKey(const Key('authentication_gate')), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('shared shell switches all five primary modules', (tester) async {
    final (model, repository) = await pumpApp(tester);
    const destinations = <(String, MainTab)>[
      ('tab_discover', MainTab.discover),
      ('tab_map', MainTab.map),
      ('tab_mystery', MainTab.mystery),
      ('tab_plan', MainTab.plan),
      ('tab_profile', MainTab.profile),
    ];
    for (final (key, tab) in destinations) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pump(const Duration(milliseconds: 30));
      expect(model.tab, tab);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arrival UI counts down, resets, and verifies', (tester) async {
    final repository = FakeShakeFindRepository();
    repository.active = journey.Journey(
      id: 'journey-arrival',
      participantId: 'participant-a',
      status: journey.JourneyStatus.active,
      mode: journey.JourneyMode.solo,
      clue: 'A real database clue',
      locationHint: 'Mystery area',
      distanceMeters: 70,
      destination: repository.destination,
    );
    repository.arrivalMonitoringUpdates
        .addAll(const <journey.ArrivalVerificationUpdate>[
          journey.ArrivalVerificationUpdate(
            state: journey.ArrivalVerificationState.outsideRange,
            distanceMeters: 70,
            accuracyMeters: 8,
          ),
          journey.ArrivalVerificationUpdate(
            state: journey.ArrivalVerificationState.waitingForAccuracy,
            distanceMeters: 40,
            accuracyMeters: 35,
          ),
          journey.ArrivalVerificationUpdate(
            state: journey.ArrivalVerificationState.verifying,
            secondsRemaining: 10,
            distanceMeters: 40,
            accuracyMeters: 8,
          ),
          journey.ArrivalVerificationUpdate(
            state: journey.ArrivalVerificationState.verifying,
            secondsRemaining: 7,
            distanceMeters: 40,
            accuracyMeters: 8,
          ),
          journey.ArrivalVerificationUpdate(
            state: journey.ArrivalVerificationState.interrupted,
            distanceMeters: 55,
            accuracyMeters: 8,
          ),
          journey.ArrivalVerificationUpdate(
            state: journey.ArrivalVerificationState.verifying,
            secondsRemaining: 10,
            distanceMeters: 30,
            accuracyMeters: 8,
          ),
          journey.ArrivalVerificationUpdate(
            state: journey.ArrivalVerificationState.verified,
            distanceMeters: 30,
            accuracyMeters: 8,
          ),
        ]);
    final (model, _) = await pumpApp(tester, repository: repository);

    model.mystery.resumeJourney();
    await tester.pump();
    await scrollToArrival(tester);
    expect(
      model.mystery.arrivalVerification.state,
      journey.ArrivalVerificationState.idle,
    );
    expect(find.text('Arrival not checked yet'), findsOneWidget);
    expect(repository.arrivalCheckCount, 0);

    await tester.tap(find.byKey(const Key('test_real_arrival')));
    await tester.pump();
    expect(
      model.mystery.arrivalVerification.state,
      journey.ArrivalVerificationState.outsideRange,
    );
    expect(find.text('Outside arrival range'), findsOneWidget);
    expect(find.textContaining('70m from destination'), findsOneWidget);
    expect(find.textContaining('remaining'), findsNothing);

    await tester.pump(repository.arrivalUpdateDelay);
    expect(
      model.mystery.arrivalVerification.state,
      journey.ArrivalVerificationState.waitingForAccuracy,
    );
    expect(find.text('Waiting for better GPS accuracy'), findsOneWidget);
    expect(find.textContaining('GPS accuracy: 35m'), findsOneWidget);
    expect(find.textContaining('Distance: 40m'), findsOneWidget);

    await tester.pump(repository.arrivalUpdateDelay);
    expect(find.text('Verifying arrival'), findsOneWidget);
    expect(find.textContaining('10s remaining'), findsOneWidget);
    await tester.pump(repository.arrivalUpdateDelay);
    expect(find.textContaining('7s remaining'), findsOneWidget);

    await tester.pump(repository.arrivalUpdateDelay);
    expect(
      model.mystery.arrivalVerification.state,
      journey.ArrivalVerificationState.interrupted,
    );
    expect(find.text('Verification interrupted.'), findsOneWidget);
    expect(find.textContaining('55m from destination'), findsOneWidget);

    await tester.pump(repository.arrivalUpdateDelay);
    expect(find.textContaining('10s remaining'), findsOneWidget);
    await tester.pump(repository.arrivalUpdateDelay);
    expect(
      model.mystery.arrivalVerification.state,
      journey.ArrivalVerificationState.verified,
    );
    await tester.pump(repository.arrivalUpdateDelay);
    expect(model.mystery.stage, MysteryStage.complete);
    expect(
      find.byKey(const Key('generic_mystery_completion_visual')),
      findsOneWidget,
    );
    expect(
      find.image(const AssetImage('assets/sultan_abdul_samad.png')),
      findsNothing,
    );
  });

  testWidgets('Arrival countdown updates while the location is unchanged', (
    tester,
  ) async {
    final repository = FakeShakeFindRepository();
    repository.active = journey.Journey(
      id: 'journey-standing-still',
      participantId: 'participant-a',
      status: journey.JourneyStatus.active,
      mode: journey.JourneyMode.solo,
      clue: 'A real database clue',
      locationHint: 'Mystery area',
      distanceMeters: 21,
      destination: repository.destination,
    );
    repository.arrivalUpdateDelay = const Duration(seconds: 12);
    repository.arrivalMonitoringUpdates.add(
      const journey.ArrivalVerificationUpdate(
        state: journey.ArrivalVerificationState.verifying,
        secondsRemaining: 10,
        distanceMeters: 21,
        accuracyMeters: 9,
      ),
    );
    final (model, _) = await pumpApp(tester, repository: repository);

    model.mystery.resumeJourney();
    await tester.pump();
    await scrollToArrival(tester);
    expect(find.text('Arrival not checked yet'), findsOneWidget);
    expect(repository.arrivalCheckCount, 0);

    unawaited(model.mystery.testArrivalNow());
    await tester.pump();
    expect(find.textContaining('10s remaining'), findsOneWidget);
    expect(find.textContaining('Distance: 21m'), findsOneWidget);
    expect(find.textContaining('GPS accuracy: 9m'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('9s remaining'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('7s remaining'), findsOneWidget);
    expect(model.mystery.stage, MysteryStage.active);
    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
  });

  testWidgets(
    'Solo shake creates once and resumes the same hidden destination',
    (tester) async {
      final (model, repository) = await pumpApp(tester);
      await tester.drag(
        find.byKey(const PageStorageKey<String>('mystery-home')),
        const Offset(0, -520),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('start_mystery')));
      await tester.pump();
      expect(model.mystery.stage, MysteryStage.shake);

      expect(repository.shakeCallback, isNotNull);
      expect(find.text('Simulate Phone Shake Action'), findsNothing);
      expect(find.byKey(const Key('shake_sensor_status')), findsOneWidget);
      repository.shakeCallback!();
      await tester.pump(const Duration(milliseconds: 50));
      expect(repository.startCount, 1);
      expect(model.mystery.stage, MysteryStage.active);
      expect(find.text('A real database clue'), findsOneWidget);
      expect(find.text('Test Heritage Place'), findsNothing);

      final originalId = model.mystery.journey!.id;
      model.mystery.setStage(MysteryStage.home);
      await model.mystery.initialize(force: true);
      await tester.pump();
      await tester.drag(
        find.byKey(const PageStorageKey<String>('mystery-home')),
        const Offset(0, 1000),
      );
      await tester.pump();
      expect(model.mystery.journey!.id, originalId);
      expect(model.mystery.journeyActive, isTrue);
      expect(find.text('Mystery journey in progress'), findsOneWidget);
      expect(find.text('Choose how to begin'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pump();
      expect(model.mystery.stage, MysteryStage.active);
      expect(model.mystery.journey!.id, originalId);
      expect(model.mystery.journey!.destination!.id, 'destination-1');
      expect(model.mystery.message, isNull);
      expect(repository.startCount, 1);

      model.mystery.setStage(MysteryStage.home);
      await tester.pump();
      await tester.drag(
        find.byKey(const PageStorageKey<String>('mystery-home')),
        const Offset(0, -600),
      );
      await tester.pump();
      final startButton = tester.widget<FilledButton>(
        find.byKey(const Key('start_mystery')),
      );
      expect(startButton.onPressed, isNotNull);
      expect(
        startButton.style?.backgroundColor?.resolve(const <WidgetState>{}),
        const Color(0xFFE0E4E7),
      );
      final editButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Edit'),
      );
      expect(editButton.onPressed, isNull);
      await tester.tap(find.byKey(const Key('start_mystery')));
      await tester.pump();
      expect(model.mystery.stage, MysteryStage.home);
      expect(repository.startCount, 1);
      expect(
        find.text(MysteryJourneyViewModel.unfinishedJourneyMessage),
        findsWidgets,
      );
      expect(find.text('Detailed preferences'), findsNothing);

      model.mystery.useSurpriseMe();
      await model.mystery.startJourney();
      await model.mystery.createGroupRoom();
      await model.mystery.joinGroupRoom('room-nearby');
      expect(model.mystery.journey!.id, originalId);
      expect(model.mystery.stage, MysteryStage.home);
      expect(repository.startCount, 1);
      expect(
        model.mystery.message,
        MysteryJourneyViewModel.unfinishedJourneyMessage,
      );
    },
  );

  testWidgets('Group room locks one member and starts one shared journey', (
    tester,
  ) async {
    final (model, repository) = await pumpApp(tester);
    model.mystery.setMode(JourneyMode.group);
    await tester.pump();
    expect(find.text('My travel mood'), findsNothing);
    model.mystery.setStage(MysteryStage.groupSetup);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Join with Room ID'), findsNothing);
    expect(find.text('Continue Solo Instead'), findsNothing);
    expect(find.text('Waiting Room ROOM-N'), findsOneWidget);
    expect(find.text('Culture'), findsOneWidget);
    await tester.tap(find.text('Create New Waiting Room'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(model.mystery.roomMemberCount, 1);
    expect(model.mystery.isHost, isTrue);
    expect(find.text('Group chat unlocked'), findsNothing);

    model.mystery.setStage(MysteryStage.home);
    model.mystery.resumeJourney();
    await tester.pump();
    expect(model.mystery.stage, MysteryStage.groupWaiting);
    expect(model.mystery.journey!.id, 'waiting:room-1');

    final waitingVote = await model.mystery.castGroupVote(
      journey.GroupVoteType.hint,
    );
    expect(waitingVote, isNull);
    expect(repository.voteCount, 0);
    expect(
      model.mystery.message,
      'The host must start the Group Journey before voting.',
    );

    await model.mystery.addTestCompanion();
    expect(model.mystery.roomMemberCount, 2);
    expect(find.byKey(const Key('add_test_group_member')), findsNothing);
    expect(
      repository.lastTestUsername,
      MysteryJourneyViewModel.testCompanionUsername,
    );
    await tester.pump();
    await tester.drag(
      find.byKey(const PageStorageKey<String>('mystery-group-waiting')),
      const Offset(0, -500),
    );
    await tester.pump();
    expect(find.text('Group Chat'), findsOneWidget);
    final groupChatTile = find.ancestor(
      of: find.text('Group Chat'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: groupChatTile,
        matching: find.byIcon(Icons.expand_more),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Share a clue guess…'),
      'Testing group chat',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Testing group chat'), findsOneWidget);
    await model.mystery.useGroupSurpriseMe();
    expect(model.mystery.stage, MysteryStage.groupWaiting);
    await model.mystery.beginGroupJourney();
    expect(model.mystery.stage, MysteryStage.groupWaiting);
    expect(model.mystery.message, '1 traveller is not ready yet.');
    expect(repository.startCount, 0);

    await model.mystery.setReady(true);
    expect(model.mystery.allRoomMembersReady, isTrue);
    await model.mystery.beginGroupJourney();
    await tester.pump(const Duration(milliseconds: 50));
    expect(model.mystery.stage, MysteryStage.shake);
    expect(repository.startCount, 1);
    expect(find.text('I’m Ready'), findsNothing);
    expect(find.text('Room ready check'), findsNothing);

    repository.shakeCallback!();
    await tester.pump(const Duration(milliseconds: 50));
    expect(repository.startCount, 1);
    expect(repository.groupShakeWriteCount, 1);
    expect(model.mystery.journey!.mode, journey.JourneyMode.group);
    expect(model.mystery.journey!.members.length, 2);
    expect(find.text('I’m Ready'), findsNothing);
    expect(find.text('Ready'), findsNothing);

    final activeList = find.byKey(
      const PageStorageKey<String>('mystery-active'),
    );
    final activeScrollable = find.descendant(
      of: activeList,
      matching: find.byType(Scrollable),
    );
    final activeScrollState = tester.state<ScrollableState>(
      activeScrollable.first,
    );
    activeScrollState.position.jumpTo(
      activeScrollState.position.maxScrollExtent,
    );
    await tester.pump();
    expect(find.text('Developer Testing'), findsNothing);
    expect(find.byKey(const Key('simulate_my_arrival')), findsNothing);
    expect(
      find.byKey(const Key('simulate_test_explorer_hint_vote')),
      findsNothing,
    );
    await model.mystery.testArrivalNow();
    expect(repository.arrivalCheckCount, 1);
    expect(
      model.mystery.arrivalVerification.state,
      journey.ArrivalVerificationState.verifying,
    );
    expect(model.mystery.arrivalVerification.secondsRemaining, 10);
  });

  testWidgets('Test Explorer joins safely and host can close room', (
    tester,
  ) async {
    final (model, repository) = await pumpApp(tester);
    model.mystery.setMode(JourneyMode.group);
    model.mystery.setStage(MysteryStage.groupSetup);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Create New Waiting Room'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('I’m Ready'), findsOneWidget);
    expect(find.byKey(const Key('add_test_group_member')), findsNothing);

    expect(find.text('Developer Testing'), findsNothing);
    await model.mystery.addTestCompanion();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(model.mystery.roomMemberCount, 2);

    await tester.tap(find.byKey(const Key('leave_waiting_room')));
    await tester.pump();
    expect(find.text('Close waiting room?'), findsOneWidget);
    await tester.tap(find.text('Close room'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(model.mystery.stage, MysteryStage.home);
    expect(model.mystery.mode, JourneyMode.solo);
    expect(model.mystery.journey, isNull);
    expect(model.mystery.message, 'Group Room cancelled.');
    expect(repository.waitingRoomEnded, isTrue);
    expect(repository.allMembershipsLeft, isTrue);
  });

  testWidgets('Group member detects the shared journey and reaches shake', (
    tester,
  ) async {
    final repository = FakeShakeFindRepository();
    repository.active = journey.Journey(
      id: 'waiting:room-1',
      status: journey.JourneyStatus.idle,
      mode: journey.JourneyMode.group,
      clue: '',
      locationHint: 'Waiting room',
      distanceMeters: 0,
      groupRoomId: 'room-1',
      members: repository.twoMembers,
      isHost: false,
      groupPreferencesSet: true,
    );
    final (model, _) = await pumpApp(tester, repository: repository);
    model.mystery.resumeJourney();
    expect(model.mystery.stage, MysteryStage.groupWaiting);

    repository.active = journey.Journey(
      id: 'shared-journey-1',
      participantId: 'participant-b',
      status: journey.JourneyStatus.active,
      mode: journey.JourneyMode.group,
      clue: 'A shared database clue',
      locationHint: 'Mystery area',
      distanceMeters: 0,
      destination: repository.destination,
      groupRoomId: 'room-1',
      members: <journey.JourneyMember>[
        repository.twoMembers.first,
        journey.JourneyMember(
          userId: repository.twoMembers.last.userId,
          displayName: repository.twoMembers.last.displayName,
          role: repository.twoMembers.last.role,
          status: 'active',
          participantStatus: 'active',
          shakenAt: DateTime.utc(2026, 9, 4),
        ),
      ],
      isHost: false,
      groupPreferencesSet: true,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(model.mystery.stage, MysteryStage.shake);
    expect(model.mystery.journey!.id, 'shared-journey-1');
    expect(repository.sensorStartCount, greaterThan(0));
    expect(find.text('Group Shake — 1/2 shaken'), findsOneWidget);
    expect(find.text('Traveller A'), findsOneWidget);
    expect(find.text('Test Explorer'), findsOneWidget);

    repository.shakeCallback!();
    await tester.pump(const Duration(milliseconds: 50));
    expect(repository.groupShakeWriteCount, 1);
    expect(model.mystery.stage, MysteryStage.active);
    expect(model.mystery.journey!.id, 'shared-journey-1');
    expect(model.mystery.journey!.destination!.id, 'destination-1');
  });

  testWidgets('Active unshaken group journey resumes its shake stage', (
    tester,
  ) async {
    final repository = FakeShakeFindRepository();
    repository.active = journey.Journey(
      id: 'shared-journey-1',
      participantId: 'participant-a',
      status: journey.JourneyStatus.active,
      mode: journey.JourneyMode.group,
      clue: 'A shared database clue',
      locationHint: 'Mystery area',
      distanceMeters: 0,
      destination: repository.destination,
      groupRoomId: 'room-1',
      members: repository.twoMembers,
      isHost: true,
      groupPreferencesSet: true,
    );
    final (model, _) = await pumpApp(tester, repository: repository);

    model.mystery.resumeJourney();
    await tester.pump();

    expect(model.mystery.stage, MysteryStage.shake);
    expect(model.mystery.message, isNull);
    expect(model.mystery.journey!.id, 'shared-journey-1');
    expect(model.mystery.journey!.destination!.id, 'destination-1');
    expect(repository.startCount, 0);
    expect(repository.sensorStartCount, greaterThan(0));
  });

  testWidgets('Active shaken group journey resumes its active stage', (
    tester,
  ) async {
    final repository = FakeShakeFindRepository();
    repository.active = journey.Journey(
      id: 'shared-journey-1',
      participantId: 'participant-a',
      status: journey.JourneyStatus.active,
      mode: journey.JourneyMode.group,
      clue: 'A shared database clue',
      locationHint: 'Mystery area',
      distanceMeters: 250,
      destination: repository.destination,
      groupRoomId: 'room-1',
      members: <journey.JourneyMember>[
        journey.JourneyMember(
          userId: 'user-a',
          displayName: 'Traveller A',
          role: 'host',
          status: 'active',
          participantStatus: 'active',
          shakenAt: DateTime.utc(2026, 9, 4),
        ),
        journey.JourneyMember(
          userId: 'user-b',
          displayName: 'Test Explorer',
          role: 'member',
          status: 'active',
          participantStatus: 'active',
        ),
      ],
      isHost: true,
      groupPreferencesSet: true,
    );
    final (model, _) = await pumpApp(tester, repository: repository);

    model.mystery.resumeJourney();
    await tester.pump();
    await scrollToArrival(tester);

    expect(model.mystery.stage, MysteryStage.active);
    expect(model.mystery.message, isNull);
    expect(model.mystery.journey!.id, 'shared-journey-1');
    expect(model.mystery.journey!.destination!.id, 'destination-1');
    expect(repository.startCount, 0);
    expect(repository.arrivalCheckCount, 0);
    expect(
      model.mystery.arrivalVerification.state,
      journey.ArrivalVerificationState.idle,
    );
    expect(find.text('Arrival not checked yet'), findsOneWidget);
  });

  testWidgets('Group chat aligns users and groups consecutive senders', (
    tester,
  ) async {
    final repository = FakeShakeFindRepository();
    final (model, _) = await pumpApp(tester, repository: repository);
    await model.mystery.createGroupRoom();
    await model.mystery.addTestCompanion();
    repository.chatMessages.addAll(<journey.GroupChatMessage>[
      journey.GroupChatMessage(
        id: 'other-3',
        userId: 'user-b',
        senderName: 'test_explorer',
        message: 'Okay',
        createdAt: DateTime(2026, 1, 1, 0, 0, 3),
        isCurrentUser: false,
      ),
      journey.GroupChatMessage(
        id: 'other-1',
        userId: 'user-b',
        senderName: 'test_explorer',
        message: 'Hi',
        createdAt: DateTime(2026),
        isCurrentUser: false,
      ),
      journey.GroupChatMessage(
        id: 'other-2',
        userId: 'user-b',
        senderName: 'test_explorer',
        message: 'Ready?',
        createdAt: DateTime(2026, 1, 1, 0, 0, 1),
        isCurrentUser: false,
      ),
      journey.GroupChatMessage(
        id: 'self-1',
        userId: 'user-a',
        senderName: 'test_explorer_1',
        message: 'Yes',
        createdAt: DateTime(2026, 1, 1, 0, 0, 2),
        isCurrentUser: true,
      ),
    ]);
    await model.mystery.loadGroupMessages();
    expect(model.mystery.messages.map((message) => message.message), <String>[
      'Hi',
      'Ready?',
      'Yes',
      'Okay',
    ]);
    await tester.pump();
    await tester.drag(
      find.byKey(const PageStorageKey<String>('mystery-group-waiting')),
      const Offset(0, -500),
    );
    await tester.pump();
    final groupChatTile = find.ancestor(
      of: find.text('Group Chat'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: groupChatTile,
        matching: find.byIcon(Icons.expand_more),
      ),
    );
    await tester.pump();

    expect(find.text('test_explorer'), findsNWidgets(2));
    expect(find.text('test_explorer_1'), findsOneWidget);
    expect(
      tester
          .widget<Align>(find.byKey(const Key('group-chat-message-other-1')))
          .alignment,
      Alignment.centerLeft,
    );
    expect(
      tester
          .widget<Align>(find.byKey(const Key('group-chat-message-self-1')))
          .alignment,
      Alignment.centerRight,
    );
  });

  testWidgets('Leaving and rejoining the same waiting room is idempotent', (
    tester,
  ) async {
    final (model, repository) = await pumpApp(tester);
    model.mystery.setMode(JourneyMode.group);

    await model.mystery.joinGroupRoom('room-nearby');
    expect(repository.membershipInsertCount, 1);
    await model.mystery.leaveWaitingRoom();
    expect(repository.membershipLeft, isTrue);

    await model.mystery.joinGroupRoom('room-nearby');
    expect(repository.membershipInsertCount, 1);
    expect(repository.membershipLeft, isFalse);
    expect(model.mystery.isHost, isFalse);
  });

  testWidgets('Active host leave keeps the shared journey available', (
    tester,
  ) async {
    final (model, repository) = await pumpApp(tester);
    model.mystery.setMode(JourneyMode.group);
    await model.mystery.createGroupRoom();
    await model.mystery.addTestCompanion();
    await model.mystery.useGroupSurpriseMe();
    await model.mystery.setReady(true);
    await model.mystery.startJourney();

    await model.mystery.cancelJourney();
    expect(repository.hostParticipantCancelled, isTrue);
    expect(repository.membershipLeft, isTrue);
    expect(repository.sharedJourneyStillActive, isTrue);
    expect(repository.groupRoomClosed, isFalse);
  });

  testWidgets('Group votes persist once and Test Explorer reaches majority', (
    tester,
  ) async {
    final (model, repository) = await pumpApp(tester);
    model.mystery.setMode(JourneyMode.group);
    await model.mystery.createGroupRoom();
    await model.mystery.addTestCompanion();
    await model.mystery.useGroupSurpriseMe();
    await model.mystery.setReady(true);
    await model.mystery.startJourney();

    final hostHint = await model.mystery.castGroupVote(
      journey.GroupVoteType.hint,
    );
    expect(hostHint!.yesVotes, 1);
    expect(hostHint.passed, isFalse);
    expect(model.mystery.hintCount, 0);

    final duplicateHint = await model.mystery.castGroupVote(
      journey.GroupVoteType.hint,
    );
    expect(duplicateHint!.alreadyVoted, isTrue);
    expect(duplicateHint.yesVotes, 1);

    final testHint = await model.mystery.simulateTestExplorerVote(
      journey.GroupVoteType.hint,
    );
    expect(testHint!.passed, isTrue);
    expect(model.mystery.hintCount, 1);

    final hostRoute = await model.mystery.castGroupVote(
      journey.GroupVoteType.route,
    );
    expect(hostRoute!.yesVotes, 1);
    expect(model.mystery.routeRevealed, isFalse);

    final testRoute = await model.mystery.simulateTestExplorerVote(
      journey.GroupVoteType.route,
    );
    expect(testRoute!.passed, isTrue);
    expect(model.mystery.routeRevealed, isTrue);
    expect(repository.voteCount, 5);
  });

  testWidgets('Remote Group vote progress and approval synchronize', (
    tester,
  ) async {
    final (model, repository) = await pumpApp(tester);
    model.mystery.setMode(JourneyMode.group);
    await model.mystery.createGroupRoom();
    await model.mystery.addTestCompanion();
    await model.mystery.useGroupSurpriseMe();
    await model.mystery.setReady(true);
    await model.mystery.startJourney();

    await model.mystery.castGroupVote(journey.GroupVoteType.hint);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.textContaining('Group Hint vote active'),
      220,
      scrollable: find.descendant(
        of: find.byKey(const PageStorageKey<String>('mystery-active')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.textContaining('Group Hint vote active'), findsOneWidget);
    expect(find.textContaining('1/2 Yes votes'), findsOneWidget);

    await repository.castGroupVote(
      repository.active!,
      journey.GroupVoteType.hint,
      simulateTestExplorer: true,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(model.mystery.groupVoteFeedback, contains('Group Hint approved'));
    expect(find.textContaining('Group Hint approved'), findsOneWidget);
  });

  testWidgets('Exhausted Solo and Group hints cannot start another action', (
    tester,
  ) async {
    final soloRepository = FakeShakeFindRepository();
    soloRepository.active = journey.Journey(
      id: 'solo-no-hints',
      participantId: 'participant-a',
      status: journey.JourneyStatus.active,
      mode: journey.JourneyMode.solo,
      clue: 'A real database clue',
      locationHint: 'Mystery area',
      distanceMeters: 100,
      destination: soloRepository.destination,
      additionalHints: const <String>['One', 'Two', 'Three'],
      totalHintCount: 3,
    );
    final (soloModel, _) = await pumpApp(tester, repository: soloRepository);
    soloModel.mystery.resumeJourney();
    await soloModel.mystery.unlockHint();
    await tester.pump();
    expect(soloModel.mystery.message, 'All Mystery Hints have been unlocked.');
    expect(find.text('All Mystery Hints have been unlocked.'), findsWidgets);

    final groupRepository = FakeShakeFindRepository();
    groupRepository.active = journey.Journey(
      id: 'group-no-hints',
      participantId: 'participant-a',
      status: journey.JourneyStatus.active,
      mode: journey.JourneyMode.group,
      clue: 'A shared clue',
      locationHint: 'Mystery area',
      distanceMeters: 100,
      destination: groupRepository.destination,
      additionalHints: const <String>['One', 'Two', 'Three'],
      totalHintCount: 3,
      groupRoomId: 'room-1',
      members: groupRepository.twoMembers,
      isHost: true,
    );
    final groupModel = MysteryJourneyViewModel(groupRepository);
    await groupModel.initialize();
    final voteCount = groupRepository.voteCount;
    final outcome = await groupModel.castGroupVote(journey.GroupVoteType.hint);
    expect(outcome, isNull);
    expect(groupRepository.voteCount, voteCount);
    expect(groupModel.message, 'All Mystery Hints have been unlocked.');
    groupModel.dispose();
  });

  testWidgets(
    'failed journey creation restores shake listening without sensor error',
    (tester) async {
      final repository = FakeShakeFindRepository()
        ..startError = StateError('No matching destination is available.');
      final (model, _) = await pumpApp(tester, repository: repository);
      await tester.drag(
        find.byKey(const PageStorageKey<String>('mystery-home')),
        const Offset(0, -520),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('start_mystery')));
      await tester.pump();

      expect(repository.sensorStartCount, 1);
      repository.shakeCallback!();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repository.startCount, 1);
      expect(repository.sensorStartCount, 2);
      expect(model.mystery.isListeningForShake, isTrue);
      expect(model.mystery.sensorUnavailable, isFalse);
      expect(find.text('Motion sensor active'), findsOneWidget);
      expect(find.text('Motion sensor unavailable'), findsNothing);
      expect(find.textContaining('No matching destination'), findsOneWidget);
    },
  );

  testWidgets('exact route confirmation maps the assigned destination', (
    tester,
  ) async {
    final (model, repository) = await pumpApp(tester);
    await tester.drag(
      find.byKey(const PageStorageKey<String>('mystery-home')),
      const Offset(0, -520),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('start_mystery')));
    await tester.pump();
    expect(repository.shakeCallback, isNotNull);
    repository.shakeCallback!();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.scrollUntilVisible(
      find.text('Reveal route'),
      220,
      scrollable: find.descendant(
        of: find.byKey(const PageStorageKey<String>('mystery-active')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Reveal route'));
    await tester.pump();
    await tester.tap(find.text('Reveal Route'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(model.mystery.routeRevealed, isTrue);
    expect(model.map.directionTarget?.id, 'destination-1');
    expect(model.map.directionTarget?.image, isEmpty);
    expect(model.tab, MainTab.map);
  });

  testWidgets('journey progress only adds Route after it is revealed', (
    tester,
  ) async {
    final repository = FakeShakeFindRepository();
    repository.active = journey.Journey(
      id: 'dynamic-progress',
      participantId: 'participant-a',
      status: journey.JourneyStatus.active,
      mode: journey.JourneyMode.solo,
      clue: 'A real database clue',
      locationHint: 'Mystery area',
      distanceMeters: 1200,
      destination: repository.destination,
    );
    final (model, _) = await pumpApp(tester, repository: repository);
    model.mystery.resumeJourney();
    await tester.pump();

    expect(find.text('Journey progress'), findsOneWidget);
    expect(find.text('Route'), findsNothing);

    await model.mystery.revealRoute();
    await tester.pump();

    expect(find.text('Route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a repeated destination is clearly marked as a revisit', (
    tester,
  ) async {
    final repository = FakeShakeFindRepository();
    repository.active = journey.Journey(
      id: 'revisit-journey',
      participantId: 'participant-a',
      status: journey.JourneyStatus.active,
      mode: journey.JourneyMode.solo,
      clue: 'A different clue for a familiar place',
      locationHint: 'Mystery area',
      distanceMeters: 1200,
      destination: repository.destination,
      isRevisit: true,
    );
    final (model, _) = await pumpApp(tester, repository: repository);
    model.mystery.resumeJourney();
    await tester.pump();

    expect(find.text('Revisit Challenge'), findsOneWidget);
    expect(
      find.textContaining("You've explored this place before"),
      findsOneWidget,
    );
  });

  testWidgets(
    'provisional Solo revisit can be accepted without a second start',
    (tester) async {
      final repository = FakeShakeFindRepository();
      repository.active = journey.Journey(
        id: 'provisional:destination-1',
        status: journey.JourneyStatus.active,
        mode: journey.JourneyMode.solo,
        clue: 'A fresh clue',
        locationHint: 'Mystery area',
        distanceMeters: 1000,
        destination: repository.destination,
        isRevisit: true,
      );
      final (model, _) = await pumpApp(tester, repository: repository);
      model.mystery.resumeJourney();
      await tester.pump();

      expect(find.text('Play This Revisit'), findsOneWidget);
      expect(find.text('Shake Again for a New Place'), findsOneWidget);
      await tester.tap(find.text('Play This Revisit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.revisitAcceptCount, 1);
      expect(repository.startCount, 0);
      expect(model.mystery.journey?.id, 'accepted-revisit');
    },
  );

  testWidgets(
    'rejecting a provisional revisit returns to shake without writes',
    (tester) async {
      final repository = FakeShakeFindRepository();
      repository.active = journey.Journey(
        id: 'provisional:destination-1',
        status: journey.JourneyStatus.active,
        mode: journey.JourneyMode.solo,
        clue: 'A fresh clue',
        locationHint: 'Mystery area',
        distanceMeters: 1000,
        destination: repository.destination,
        isRevisit: true,
      );
      final (model, _) = await pumpApp(tester, repository: repository);
      model.mystery.resumeJourney();
      await tester.pump();
      await tester.tap(find.text('Shake Again for a New Place'));
      await tester.pump();

      expect(repository.revisitRejectCount, 1);
      expect(repository.startCount, 0);
      expect(model.mystery.journey, isNull);
      expect(model.mystery.stage, MysteryStage.shake);
    },
  );

  testWidgets('adjusting preferences discards the provisional revisit', (
    tester,
  ) async {
    final repository = FakeShakeFindRepository();
    repository.active = journey.Journey(
      id: 'provisional:destination-1',
      status: journey.JourneyStatus.active,
      mode: journey.JourneyMode.solo,
      clue: 'A fresh clue',
      locationHint: 'Mystery area',
      distanceMeters: 1000,
      destination: repository.destination,
      isRevisit: true,
    );
    final (model, _) = await pumpApp(tester, repository: repository);
    model.mystery.resumeJourney();
    await tester.pump();
    await tester.tap(find.text('Adjust Preferences'));
    await tester.pump();

    expect(repository.revisitRejectCount, 1);
    expect(repository.startCount, 0);
    expect(model.mystery.journey, isNull);
    expect(model.mystery.stage, MysteryStage.home);
    expect(model.mystery.journeyActive, isFalse);
  });

  testWidgets('Solo arrival simulation completes once and awards XP once', (
    tester,
  ) async {
    final (model, repository) = await pumpApp(tester);
    model.mystery.setMode(JourneyMode.solo);
    await model.mystery.startJourney();

    await model.mystery.simulateArrival();
    await tester.pump();
    expect(model.mystery.stage, MysteryStage.complete);
    expect(model.mystery.revealedDestination?.id, 'destination-1');
    expect(find.text('Journey Complete'), findsOneWidget);
    await tester.drag(
      find.byKey(const PageStorageKey<String>('mystery-complete')),
      const Offset(0, -420),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('add_mystery_destination_to_plan')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('add_mystery_destination_to_plan')),
          )
          .onPressed,
      isNotNull,
    );
    expect(repository.profileXp, 700);
    expect(repository.profileStreak, 4);

    await model.mystery.simulateArrival();
    expect(repository.profileXp, 700);
    expect(repository.profileStreak, 4);
  });

  testWidgets('Group arrival simulation completes each participant safely', (
    tester,
  ) async {
    final (model, repository) = await pumpApp(tester);
    model.mystery.setMode(JourneyMode.group);
    await model.mystery.createGroupRoom();
    await model.mystery.addTestCompanion();
    await model.mystery.useGroupSurpriseMe();
    await model.mystery.setReady(true);
    await model.mystery.startJourney();

    await model.mystery.simulateArrival(testExplorer: true);
    expect(repository.profileXp, 600);
    expect(repository.groupRoomClosed, isFalse);
    expect(
      model.mystery.members
          .singleWhere((member) => member.displayName == 'Test Explorer')
          .participantStatus,
      'completed',
    );

    await model.mystery.simulateArrival();
    expect(repository.profileXp, 700);
    expect(repository.groupRoomClosed, isTrue);
    expect(model.mystery.stage, MysteryStage.complete);
  });

  testWidgets('Group traveller arrival waits for remaining participants', (
    tester,
  ) async {
    final (model, repository) = await pumpApp(tester);
    model.mystery.setMode(JourneyMode.group);
    await model.mystery.createGroupRoom();
    await model.mystery.addTestCompanion();
    await model.mystery.useGroupSurpriseMe();
    await model.mystery.setReady(true);
    await model.mystery.startJourney();

    await model.mystery.simulateArrival();

    expect(repository.groupRoomClosed, isFalse);
    expect(model.mystery.currentUserArrived, isTrue);
    expect(model.mystery.stage, MysteryStage.active);
    expect(
      model.mystery.message,
      'Your arrival is verified. Waiting for the other travellers.',
    );
  });

  testWidgets('Joined testing room remains a non-host waiting member', (
    tester,
  ) async {
    final (model, repository) = await pumpApp(tester);
    model.mystery.setMode(JourneyMode.group);
    await model.mystery.joinGroupRoom('room-nearby');

    expect(model.mystery.isHost, isFalse);
    expect(model.mystery.stage, MysteryStage.groupWaiting);
    await model.mystery.startJourney();
    expect(repository.startCount, 0);
    expect(
      model.mystery.message,
      'Only the host can discover the shared destination.',
    );
  });

  testWidgets('completed Mystery details reuse the existing Map place sheet', (
    tester,
  ) async {
    final mapRepository = FakeMapQuestRepository();
    final mapViewModel = MapQuestViewModel(questRepository: mapRepository);
    await mapViewModel.refreshCompletedMysteries();
    final model = AppViewModel(
      mysteryRepository: FakeShakeFindRepository(),
      authViewModel: FakeAuthViewModel(signedIn: true),
      mapViewModel: mapViewModel,
    );
    await pumpApp(tester, viewModel: model);
    model.selectTab(MainTab.map);
    await tester.pump(const Duration(milliseconds: 100));

    mapViewModel.selectCompletedMystery(mapViewModel.completedMysteries.single);
    await tester.pump();

    expect(find.byKey(const Key('completed_mystery_details')), findsOneWidget);
    expect(find.text('Mystery Journey Completed ✓'), findsOneWidget);
    expect(find.text('Explored 2 times'), findsOneWidget);
  });

  testWidgets('Map renders hidden, revealed, and completed Mystery states', (
    tester,
  ) async {
    final mapRepository = FakeMapQuestRepository();
    final mapViewModel = MapQuestViewModel(questRepository: mapRepository);
    await mapViewModel.refreshCompletedMysteries();
    final place = mapRepository.completions.single.place;
    final model = AppViewModel(
      mysteryRepository: FakeShakeFindRepository(),
      authViewModel: FakeAuthViewModel(signedIn: true),
      mapViewModel: mapViewModel,
    );
    await pumpApp(tester, viewModel: model);
    model.selectTab(MainTab.map);

    mapViewModel.setMysteryJourneyState(
      destination: place,
      revealed: false,
      completed: false,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.bySemanticsLabel('${place.name}, active Mystery destination'),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel('${place.name}, completed Mystery Journey'),
      findsNothing,
    );

    mapViewModel.setMysteryJourneyState(
      destination: place,
      revealed: true,
      completed: false,
    );
    await tester.pump();
    expect(
      find.bySemanticsLabel('${place.name}, active Mystery destination'),
      findsOneWidget,
    );

    mapViewModel.setMysteryJourneyState(
      destination: place,
      revealed: true,
      completed: true,
    );
    await tester.pump();
    expect(
      find.bySemanticsLabel('${place.name}, active Mystery destination'),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel('${place.name}, completed Mystery Journey'),
      findsOneWidget,
    );
  });

  testWidgets('compact and standard phone widths render without overflow', (
    tester,
  ) async {
    for (final size in <Size>[
      const Size(360, 800),
      const Size(430, 932),
      const Size(800, 1200),
    ]) {
      await pumpApp(tester, size: size);
      expect(tester.takeException(), isNull, reason: 'failed at $size');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets(
    'active mystery card wraps long destination content on narrow phones',
    (tester) async {
      final repository = FakeShakeFindRepository();
      repository.active = journey.Journey(
        id: 'journey-long-content',
        participantId: 'participant-a',
        status: journey.JourneyStatus.routeRevealed,
        mode: journey.JourneyMode.solo,
        clue:
            'Follow the old workshop trail where generations of local craftspeople '
            'preserved a lesser-known Malaysian heritage tradition.',
        locationHint:
            'The Traditional Craft Workshop, Jalan Warisan Perusahaan Kampung, '
            'Kuala Lumpur, Wilayah Persekutuan Kuala Lumpur',
        distanceMeters: 128,
        exactRouteRevealed: true,
        destination: repository.destination,
        additionalHints: const <String>[
          'Look beside the long row of restored shophouses where handmade metalwork '
              'is still demonstrated by local artisans.',
        ],
      );
      final (model, _) = await pumpApp(
        tester,
        repository: repository,
        size: const Size(320, 800),
      );

      model.mystery.resumeJourney();
      await tester.pump();

      await tester.scrollUntilVisible(
        find.textContaining('Traditional Craft Workshop'),
        220,
        scrollable: find.descendant(
          of: find.byKey(const PageStorageKey<String>('mystery-active')),
          matching: find.byType(Scrollable),
        ),
      );

      expect(find.textContaining('Traditional Craft Workshop'), findsOneWidget);
      expect(find.textContaining('Look beside the long row'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('active group action row fits a narrow phone', (tester) async {
    final (model, repository) = await pumpApp(
      tester,
      size: const Size(320, 800),
    );

    model.mystery.setMode(JourneyMode.group);
    await model.mystery.createGroupRoom();
    await model.mystery.addTestCompanion();
    await model.mystery.useGroupSurpriseMe();
    await model.mystery.setReady(true);
    await model.mystery.beginGroupJourney();
    repository.shakeCallback!();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.scrollUntilVisible(
      find.text('Request Group Hint'),
      220,
      scrollable: find.descendant(
        of: find.byKey(const PageStorageKey<String>('mystery-active')),
        matching: find.byType(Scrollable),
      ),
    );

    expect(find.text('Request Group Hint'), findsOneWidget);
    expect(find.text('Vote to Reveal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class FakeShakeFindRepository implements ShakeFindRepository {
  journey.Journey? active;
  int startCount = 0;
  int sensorStartCount = 0;
  int voteCount = 0;
  String? lastTestUsername;
  int arrivalCheckCount = 0;
  int profileXp = 600;
  int profileStreak = 3;
  bool groupRoomClosed = false;
  bool membershipExists = false;
  bool membershipLeft = false;
  int membershipInsertCount = 0;
  bool waitingRoomEnded = false;
  bool allMembershipsLeft = false;
  bool hostParticipantCancelled = false;
  bool sharedJourneyStillActive = false;
  bool hostReady = false;
  bool companionReady = true;
  bool groupHasCompanion = false;
  int groupShakeWriteCount = 0;
  final List<journey.GroupChatMessage> chatMessages =
      <journey.GroupChatMessage>[];
  final List<journey.ArrivalVerificationUpdate> arrivalMonitoringUpdates =
      <journey.ArrivalVerificationUpdate>[];
  Duration arrivalUpdateDelay = const Duration(milliseconds: 20);
  Object? startError;
  VoidCallback? shakeCallback;
  final Map<String, Set<String>> groupVotes = <String, Set<String>>{};
  int revisitAcceptCount = 0;
  int revisitRejectCount = 0;

  journey.JourneyDestination get destination =>
      const journey.JourneyDestination(
        id: 'destination-1',
        name: 'Test Heritage Place',
        category: 'culture',
        latitude: 3.1486,
        longitude: 101.6932,
        address: 'Kuala Lumpur',
        description: 'A test heritage story.',
      );

  List<journey.JourneyMember> get twoMembers => <journey.JourneyMember>[
    journey.JourneyMember(
      userId: 'user-a',
      displayName: 'Traveller A',
      role: 'host',
      status: 'waiting',
      isReady: hostReady,
    ),
    journey.JourneyMember(
      userId: 'user-b',
      displayName: 'Test Explorer',
      role: 'member',
      status: 'waiting',
      isReady: companionReady,
    ),
  ];

  @override
  Future<bool> checkConnection() async => true;

  @override
  Future<journey.JourneyProfile> getCurrentProfile() async =>
      journey.JourneyProfile(
        userId: 'user-a',
        explorerLevel: 2,
        xp: profileXp,
        streakDays: profileStreak,
      );

  @override
  Future<journey.TravelPreferences> getSavedPreferences() async =>
      const journey.TravelPreferences(
        categories: <String>{'culture'},
        radiusKm: 5,
        useSavedPreferences: true,
      );

  @override
  Future<journey.Journey?> getActiveJourney() async => active;

  @override
  Future<void> startShakeDetection({
    required VoidCallback onShake,
    required void Function(Object error) onError,
  }) async {
    sensorStartCount++;
    shakeCallback = onShake;
  }

  @override
  Future<void> stopShakeDetection() async {}

  @override
  Future<journey.Journey> startJourney(
    journey.JourneyMode mode,
    journey.TravelPreferences preferences,
  ) async {
    startCount++;
    final error = startError;
    if (error != null) throw error;
    active = journey.Journey(
      id: 'journey-1',
      participantId: 'participant-a',
      status: journey.JourneyStatus.active,
      mode: mode,
      clue: 'A real database clue',
      locationHint: 'Mystery area',
      distanceMeters: 1200,
      destination: destination,
      preferences: preferences,
      groupRoomId: mode == journey.JourneyMode.group ? 'room-1' : null,
      members: mode == journey.JourneyMode.group
          ? twoMembers
                .map(
                  (member) => journey.JourneyMember(
                    userId: member.userId,
                    displayName: member.displayName,
                    role: member.role,
                    status: member.status,
                    participantStatus: 'active',
                  ),
                )
                .toList(growable: false)
          : const <journey.JourneyMember>[],
      isHost: mode == journey.JourneyMode.group,
    );
    return active!;
  }

  @override
  Future<journey.Journey> acceptSoloRevisit(
    journey.Journey provisionalJourney,
  ) async {
    revisitAcceptCount++;
    active = journey.Journey(
      id: 'accepted-revisit',
      participantId: 'participant-a',
      status: journey.JourneyStatus.active,
      mode: journey.JourneyMode.solo,
      clue: provisionalJourney.clue,
      locationHint: provisionalJourney.locationHint,
      distanceMeters: provisionalJourney.distanceMeters,
      destination: provisionalJourney.destination,
      preferences: provisionalJourney.preferences,
      isRevisit: true,
    );
    return active!;
  }

  @override
  Future<void> rejectSoloRevisit(journey.Journey provisionalJourney) async {
    revisitRejectCount++;
    active = null;
  }

  @override
  Future<journey.Journey> requestHint(journey.Journey value) async {
    active = value.copyWith(
      additionalHints: <String>[...value.additionalHints, 'An extra clue'],
    );
    return active!;
  }

  @override
  Future<journey.Journey> revealRoute(journey.Journey value) async {
    active = value.copyWith(
      status: journey.JourneyStatus.routeRevealed,
      exactRouteRevealed: true,
      locationHint: destination.address,
    );
    return active!;
  }

  @override
  Future<journey.Journey> verifyArrival(
    journey.Journey value, {
    void Function(journey.ArrivalVerificationUpdate update)? onProgress,
  }) async {
    for (final update in arrivalMonitoringUpdates) {
      onProgress?.call(update);
      await Future<void>.delayed(arrivalUpdateDelay);
    }
    if (arrivalMonitoringUpdates.isNotEmpty &&
        arrivalMonitoringUpdates.last.state ==
            journey.ArrivalVerificationState.verified) {
      active = value.copyWith(
        status: journey.JourneyStatus.completed,
        distanceMeters:
            arrivalMonitoringUpdates.last.distanceMeters ??
            value.distanceMeters,
        completedAt: DateTime(2026),
      );
      return active!;
    }
    return value;
  }

  @override
  Future<journey.Journey> simulateArrival(
    journey.Journey value, {
    bool testExplorer = false,
  }) async {
    if (testExplorer) {
      final members = value.members
          .map(
            (member) => member.displayName == 'Test Explorer'
                ? journey.JourneyMember(
                    userId: member.userId,
                    displayName: member.displayName,
                    role: member.role,
                    status: member.status,
                    participantStatus: 'completed',
                  )
                : member,
          )
          .toList(growable: false);
      groupRoomClosed = !members.any(
        (member) => member.participantStatus == 'active',
      );
      active = value.copyWith(members: members);
      return active!;
    }
    if (value.status == journey.JourneyStatus.completed) return value;
    profileXp += 100;
    profileStreak += 1;
    final members = value.members
        .map(
          (member) => member.userId == 'user-a'
              ? journey.JourneyMember(
                  userId: member.userId,
                  displayName: member.displayName,
                  role: member.role,
                  status: member.status,
                  participantStatus: 'completed',
                )
              : member,
        )
        .toList(growable: false);
    groupRoomClosed =
        value.mode == journey.JourneyMode.group &&
        !members.any((member) => member.participantStatus == 'active');
    active = value.copyWith(
      status: value.mode == journey.JourneyMode.group && !groupRoomClosed
          ? journey.JourneyStatus.active
          : journey.JourneyStatus.completed,
      distanceMeters: 0,
      completedAt: DateTime.now(),
      members: members,
    );
    return active!;
  }

  @override
  Future<journey.ArrivalCheckResult> checkArrivalNow(
    journey.Journey value,
  ) async {
    arrivalCheckCount++;
    return const journey.ArrivalCheckResult(
      distanceMeters: 40,
      accuracyMeters: 8,
    );
  }

  @override
  Future<void> cancelJourney() async {
    final current = active;
    if (current?.mode == journey.JourneyMode.group &&
        current?.groupRoomId != null) {
      await leaveGroupRoom(current!.groupRoomId!);
      return;
    }
    active = null;
  }

  @override
  Future<List<journey.NearbyGroupRoom>> findNearbyGroupRooms({
    double radiusMeters = 1000,
  }) async => const <journey.NearbyGroupRoom>[
    journey.NearbyGroupRoom(
      id: 'room-nearby',
      memberCount: 2,
      distanceMeters: 320,
      preferenceLabels: <String>['Culture', 'Within 10 km'],
    ),
  ];

  @override
  Future<journey.Journey> createGroupRoom() async {
    membershipExists = true;
    membershipLeft = false;
    hostReady = false;
    groupHasCompanion = false;
    active = journey.Journey(
      id: 'waiting:room-1',
      status: journey.JourneyStatus.idle,
      mode: journey.JourneyMode.group,
      clue: '',
      locationHint: 'Waiting room',
      distanceMeters: 0,
      groupRoomId: 'room-1',
      members: <journey.JourneyMember>[twoMembers.first],
      isHost: true,
    );
    return active!;
  }

  @override
  Future<void> saveGroupRoomPreferences(
    String roomId,
    journey.TravelPreferences preferences,
  ) async {}

  @override
  Future<List<journey.GroupChatMessage>> getGroupMessages(
    String roomId,
  ) async => List<journey.GroupChatMessage>.unmodifiable(chatMessages);

  @override
  Future<List<journey.GroupChatMessage>> sendGroupMessage(
    String roomId,
    String message,
  ) async {
    chatMessages.add(
      journey.GroupChatMessage(
        id: 'message-1',
        userId: 'user-a',
        senderName: 'Traveller A',
        message: message,
        createdAt: DateTime(2026),
        isCurrentUser: true,
      ),
    );
    return List<journey.GroupChatMessage>.unmodifiable(chatMessages);
  }

  @override
  Future<journey.GroupVoteOutcome> castGroupVote(
    journey.Journey value,
    journey.GroupVoteType type, {
    bool simulateTestExplorer = false,
  }) async {
    voteCount++;
    final round = type == journey.GroupVoteType.hint
        ? value.additionalHints.length + 1
        : 1;
    final key = '${type.name}:$round';
    final voters = groupVotes.putIfAbsent(key, () => <String>{});
    final voter = simulateTestExplorer ? 'user-b' : 'user-a';
    final alreadyVoted = !voters.add(voter);
    final passed = voters.length >= 2;
    if (passed && type == journey.GroupVoteType.hint) {
      final current = active ?? value;
      if (current.additionalHints.length < round) {
        active = current.copyWith(
          additionalHints: <String>[
            ...current.additionalHints,
            'Group hint $round',
          ],
        );
      }
    } else if (passed && type == journey.GroupVoteType.route) {
      active = (active ?? value).copyWith(
        status: journey.JourneyStatus.routeRevealed,
        exactRouteRevealed: true,
        locationHint: destination.address,
      );
    }
    return _fakeVoteOutcome(type, round, alreadyVoted: alreadyVoted);
  }

  @override
  Future<journey.GroupVoteOutcome> getGroupVoteStatus(
    journey.Journey value,
    journey.GroupVoteType type,
  ) async {
    final round = type == journey.GroupVoteType.hint
        ? value.additionalHints.length + 1
        : 1;
    return _fakeVoteOutcome(type, round);
  }

  journey.GroupVoteOutcome _fakeVoteOutcome(
    journey.GroupVoteType type,
    int round, {
    bool alreadyVoted = false,
  }) {
    final voters = groupVotes['${type.name}:$round'] ?? const <String>{};
    return journey.GroupVoteOutcome(
      type: type,
      yesVotes: voters.length,
      requiredVotes: 2,
      memberCount: 2,
      passed: voters.length >= 2,
      voteRound: round,
      currentUserVoted: voters.contains('user-a'),
      testExplorerVoted: voters.contains('user-b'),
      alreadyVoted: alreadyVoted,
    );
  }

  @override
  Future<List<journey.JourneyMember>> refreshGroupMembers(
    String roomId,
  ) async => groupHasCompanion
      ? twoMembers
      : <journey.JourneyMember>[twoMembers.first];

  @override
  Future<List<journey.JourneyMember>> markGroupParticipantShaken(
    journey.Journey value,
  ) async {
    groupShakeWriteCount++;
    final updated = value.members
        .map(
          (member) => member.userId == 'user-a'
              ? journey.JourneyMember(
                  userId: member.userId,
                  displayName: member.displayName,
                  role: member.role,
                  status: member.status,
                  participantStatus: member.participantStatus,
                  shakenAt: DateTime.utc(2026, 9, 4),
                  avatarUrl: member.avatarUrl,
                  isReady: member.isReady,
                )
              : member,
        )
        .toList(growable: false);
    active = value.copyWith(members: updated);
    return updated;
  }

  @override
  Future<List<journey.JourneyMember>> setGroupRoomReady(
    String roomId,
    bool isReady,
  ) async {
    hostReady = isReady;
    return refreshGroupMembers(roomId);
  }

  @override
  Future<List<journey.JourneyMember>> addTestGroupMember(
    String roomId,
    String testUsername,
  ) async {
    lastTestUsername = testUsername;
    groupHasCompanion = true;
    return twoMembers;
  }

  @override
  Future<journey.Journey> joinGroupRoom(String roomId) async {
    if (active?.id == 'waiting:$roomId' && !membershipLeft) return active!;
    if (!membershipExists) membershipInsertCount++;
    membershipExists = true;
    membershipLeft = false;
    groupHasCompanion = true;
    active = journey.Journey(
      id: 'waiting:$roomId',
      status: journey.JourneyStatus.idle,
      mode: journey.JourneyMode.group,
      clue: '',
      locationHint: 'Waiting room',
      distanceMeters: 0,
      groupRoomId: roomId,
      members: twoMembers,
      isHost: false,
    );
    return active!;
  }

  @override
  Future<void> leaveGroupRoom(String roomId) async {
    final current = active;
    membershipLeft = true;
    if (current?.id.startsWith('waiting:') == true && current!.isHost) {
      waitingRoomEnded = true;
      allMembershipsLeft = true;
    } else if (current?.mode == journey.JourneyMode.group &&
        current?.status == journey.JourneyStatus.active &&
        current?.isHost == true) {
      hostParticipantCancelled = true;
      sharedJourneyStillActive = current!.members.any(
        (member) =>
            member.userId != 'user-a' && member.participantStatus == 'active',
      );
    }
    active = null;
  }

  @override
  Future<void> expireGroupJourneyIfNeeded(journey.Journey value) async {}

  @override
  Future<void> dispose() async {}
}

class FakeMapQuestRepository extends MapQuestRepository {
  int completedMysteryRequests = 0;
  final List<MysteryMapCompletion> completions = <MysteryMapCompletion>[
    MysteryMapCompletion(
      place: HeritagePlace(
        id: 'completed-place',
        name: 'Completed Heritage Place',
        category: 'Cultural Heritage',
        state: 'Penang',
        shortDescription: 'A completed Mystery destination.',
        description: 'A completed Mystery destination.',
        image: '',
        distanceKm: 0,
        rating: 0,
        reviewsCount: 0,
        latitude: 5.4182,
        longitude: 100.3411,
        address: 'George Town, Penang',
        hours: '',
      ),
      completedAt: DateTime(2026, 9, 6),
      completionCount: 2,
      passportStampCollected: true,
    ),
  ];

  @override
  Future<List<MysteryMapCompletion>> getCompletedMysteries() async {
    completedMysteryRequests++;
    return List<MysteryMapCompletion>.from(completions);
  }
}

class FakeAuthViewModel extends AuthViewModel {
  FakeAuthViewModel({required this.signedIn})
    : super(
        supabaseService: SupabaseService(
          clientOverride: SupabaseClient(
            'http://localhost',
            'widget-test-anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        ),
      );

  bool signedIn;

  @override
  bool get isAuthenticated => signedIn;

  @override
  String? get currentEmail => signedIn ? 'test@example.com' : null;

  void signInForTest() {
    signedIn = true;
    notifyListeners();
  }

  @override
  Future<void> logout() async {
    signedIn = false;
    notifyListeners();
  }
}

class FakeRecoverySupabaseService extends SupabaseService {
  FakeRecoverySupabaseService()
    : super(
        clientOverride: SupabaseClient(
          'http://localhost',
          'password-recovery-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final StreamController<AuthState> controller =
      StreamController<AuthState>.broadcast();
  bool sessionAvailable = false;
  int recoveryRequests = 0;
  int passwordUpdates = 0;
  int localSignOuts = 0;
  int loginRequests = 0;
  int verificationResends = 0;
  String? lastRecoveryEmail;
  String? lastRedirectTo;
  String? lastRegistrationRedirectTo;
  Map<String, dynamic>? lastRegistrationData;
  AuthException? registrationError;

  static const User fakeUser = User(
    id: 'auth-test-user',
    appMetadata: <String, dynamic>{},
    userMetadata: <String, dynamic>{},
    aud: 'authenticated',
    email: 'traveller@example.com',
    createdAt: '2026-01-01T00:00:00Z',
  );

  static final Session fakeSession = Session(
    accessToken: 'test-session-value',
    tokenType: 'bearer',
    user: fakeUser,
  );

  @override
  Stream<AuthState> get authStateChanges => controller.stream;

  @override
  bool get hasCurrentSession => sessionAvailable;

  @override
  bool get isAuthenticated => sessionAvailable;

  @override
  User? get currentUser => sessionAvailable ? fakeUser : null;

  void emit(AuthChangeEvent event, {required bool hasSession}) {
    sessionAvailable = hasSession;
    controller.add(AuthState(event, hasSession ? fakeSession : null));
  }

  @override
  Future<void> requestPasswordReset({
    required String email,
    required String redirectTo,
  }) async {
    recoveryRequests++;
    lastRecoveryEmail = email;
    lastRedirectTo = redirectTo;
  }

  @override
  Future<void> updatePassword(String password) async {
    passwordUpdates++;
  }

  @override
  Future<void> signOutLocal() async {
    localSignOuts++;
    sessionAvailable = false;
  }

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    loginRequests++;
    sessionAvailable = true;
    return AuthResponse(session: fakeSession, user: fakeUser);
  }

  @override
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String redirectTo,
    required Map<String, dynamic> data,
  }) async {
    final error = registrationError;
    if (error != null) throw error;
    lastRegistrationRedirectTo = redirectTo;
    lastRegistrationData = data;
    return AuthResponse(user: fakeUser);
  }

  @override
  Future<void> resendSignupConfirmation({
    required String email,
    required String redirectTo,
  }) async {
    verificationResends++;
    lastRedirectTo = redirectTo;
  }

  void dispose() {
    unawaited(controller.close());
  }
}
