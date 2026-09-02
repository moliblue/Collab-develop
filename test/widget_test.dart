import 'package:findit_my/data_layer/Models/app_models.dart';
import 'package:findit_my/data_layer/Models/journey.dart' as journey;
import 'package:findit_my/data_layer/Repositories/shake_find_repository.dart';
import 'package:findit_my/data_layer/Service Managers/device/location_service.dart';
import 'package:findit_my/main.dart';
import 'package:findit_my/ui_layer/ViewModel/app_view_model.dart';
import 'package:findit_my/ui_layer/ViewModel/auth_view_model.dart';
import 'package:findit_my/ui_layer/ViewModel/shake_find_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    final (model, _) = await pumpApp(tester);
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
    expect(
      repository.lastTestUsername,
      MysteryJourneyViewModel.testCompanionUsername,
    );
    await tester.pump();
    expect(find.text('Group chat unlocked'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Share a clue guess…'),
      'Testing group chat',
    );
    await tester.ensureVisible(find.byTooltip('Send message'));
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('You: Testing group chat'), findsOneWidget);
    await model.mystery.useGroupSurpriseMe();
    expect(model.mystery.stage, MysteryStage.groupWaiting);
    await model.mystery.startJourney();
    await tester.pump(const Duration(milliseconds: 50));
    expect(repository.startCount, 1);
    expect(model.mystery.journey!.mode, journey.JourneyMode.group);
    expect(model.mystery.journey!.members.length, 2);

    await model.mystery.testArrivalNow();
    expect(repository.arrivalCheckCount, 1);
    expect(model.mystery.message, contains('Inside the 50 m arrival zone'));
  });

  testWidgets('Test Explorer joins safely and host can close room', (
    tester,
  ) async {
    final (model, _) = await pumpApp(tester);
    model.mystery.setMode(JourneyMode.group);
    model.mystery.setStage(MysteryStage.groupSetup);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Create New Waiting Room'));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.ensureVisible(find.byKey(const Key('add_test_group_member')));
    await tester.tap(find.byKey(const Key('add_test_group_member')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(model.mystery.roomMemberCount, 2);

    await tester.ensureVisible(find.byKey(const Key('leave_waiting_room')));
    await tester.tap(find.byKey(const Key('leave_waiting_room')));
    await tester.pump();
    expect(find.text('Close waiting room?'), findsOneWidget);
    await tester.tap(find.text('Close room'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(model.mystery.stage, MysteryStage.home);
    expect(model.mystery.journey, isNull);
    expect(model.mystery.message, 'Waiting room closed.');
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
    await tester.ensureVisible(find.text('Reveal route'));
    await tester.tap(find.text('Reveal route'));
    await tester.pump();
    await tester.tap(find.text('Reveal Route'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(model.mystery.routeRevealed, isTrue);
    expect(model.map.directionTarget?.id, 'destination-1');
    expect(model.tab, MainTab.map);
  });

  testWidgets('compact and standard phone widths render without overflow', (
    tester,
  ) async {
    for (final size in <Size>[const Size(360, 800), const Size(430, 932)]) {
      await pumpApp(tester, size: size);
      expect(tester.takeException(), isNull, reason: 'failed at $size');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}

class FakeShakeFindRepository implements ShakeFindRepository {
  journey.Journey? active;
  int startCount = 0;
  int sensorStartCount = 0;
  int voteCount = 0;
  String? lastTestUsername;
  int arrivalCheckCount = 0;
  Object? startError;
  VoidCallback? shakeCallback;

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

  List<journey.JourneyMember> get twoMembers => const <journey.JourneyMember>[
    journey.JourneyMember(
      userId: 'user-a',
      displayName: 'Traveller A',
      role: 'host',
      status: 'waiting',
    ),
    journey.JourneyMember(
      userId: 'user-b',
      displayName: 'Traveller B',
      role: 'member',
      status: 'waiting',
    ),
  ];

  @override
  Future<bool> checkConnection() async => true;

  @override
  Future<journey.JourneyProfile> getCurrentProfile() async =>
      const journey.JourneyProfile(
        userId: 'user-a',
        explorerLevel: 2,
        xp: 600,
        streakDays: 3,
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
          : const <journey.JourneyMember>[],
      isHost: mode == journey.JourneyMode.group,
    );
    return active!;
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
  Future<journey.Journey> verifyArrival(journey.Journey value) async => value;

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
  Future<void> cancelJourney() async => active = null;

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
  Future<List<String>> getGroupMessages(String roomId) async =>
      const <String>[];

  @override
  Future<List<String>> sendGroupMessage(String roomId, String message) async =>
      <String>['You: $message'];

  @override
  Future<journey.GroupVoteOutcome> castGroupVote(
    journey.Journey value,
    journey.GroupVoteType type,
  ) async {
    voteCount++;
    return journey.GroupVoteOutcome(
      type: type,
      yesVotes: 2,
      requiredVotes: 2,
      memberCount: 2,
      passed: true,
    );
  }

  @override
  Future<List<journey.JourneyMember>> refreshGroupMembers(
    String roomId,
  ) async => twoMembers;

  @override
  Future<List<journey.JourneyMember>> addTestGroupMember(
    String roomId,
    String testUsername,
  ) async {
    lastTestUsername = testUsername;
    return twoMembers;
  }

  @override
  Future<journey.Journey> joinGroupRoom(String roomId) async =>
      createGroupRoom();

  @override
  Future<void> leaveGroupRoom(String roomId) async => active = null;

  @override
  Future<void> expireGroupJourneyIfNeeded(journey.Journey value) async {}

  @override
  Future<void> dispose() async {}
}

class FakeAuthViewModel extends AuthViewModel {
  FakeAuthViewModel({required this.signedIn});

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
