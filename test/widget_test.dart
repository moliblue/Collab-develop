import 'dart:async';

import 'package:findit_my/data_layer/Models/app_models.dart';
import 'package:findit_my/data_layer/Models/journey.dart' as journey;
import 'package:findit_my/data_layer/Repositories/shake_find_repository.dart';
import 'package:findit_my/data_layer/Service Managers/Remote Services/supabase_service.dart';
import 'package:findit_my/data_layer/Service Managers/device/location_service.dart';
import 'package:findit_my/main.dart';
import 'package:findit_my/ui_layer/ViewModel/app_view_model.dart';
import 'package:findit_my/ui_layer/ViewModel/auth_view_model.dart';
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
    expect(
      model.mystery.arrivalVerification.state,
      journey.ArrivalVerificationState.idle,
    );
    expect(find.text('Arrival not checked yet'), findsOneWidget);
    expect(repository.arrivalCheckCount, 0);

    unawaited(model.mystery.testArrivalNow());
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
    await tester.ensureVisible(find.byTooltip('Send message'));
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
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
    await tester.ensureVisible(find.text('Reveal route'));
    await tester.tap(find.text('Reveal route'));
    await tester.pump();
    await tester.tap(find.text('Reveal Route'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(model.mystery.routeRevealed, isTrue);
    expect(model.map.directionTarget?.id, 'destination-1');
    expect(model.map.directionTarget?.image, isEmpty);
    expect(model.tab, MainTab.map);
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
    expect(
      find.byKey(const Key('add_mystery_destination_to_plan')),
      findsOneWidget,
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
