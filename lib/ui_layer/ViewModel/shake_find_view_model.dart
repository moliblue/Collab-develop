import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data_layer/Models/journey.dart';
import '../../data_layer/Models/app_models.dart' as app;
import '../../data_layer/Repositories/shake_find_repository.dart';

class ShakeFindViewModel extends ChangeNotifier {
  ShakeFindViewModel(this._repository);

  final ShakeFindRepository _repository;
  Journey? _journey;
  JourneyMode _selectedMode = JourneyMode.solo;
  TravelPreferences _preferences = const TravelPreferences();
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isListeningForShake = false;
  bool _sensorUnavailable = false;
  bool _gpsUnavailable = false;
  bool _disposed = false;
  String? _message;

  Journey? get journey => _journey;
  JourneyMode get selectedMode => _selectedMode;
  TravelPreferences get preferences => _preferences;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isListeningForShake => _isListeningForShake;
  bool get sensorUnavailable => _sensorUnavailable;
  bool get gpsUnavailable => _gpsUnavailable;
  String? get message => _message;
  bool get hasActiveJourney =>
      _journey != null &&
      _journey!.status != JourneyStatus.completed &&
      _journey!.status != JourneyStatus.cancelled;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (_isInitialized || _isLoading || _disposed) return;
    _isLoading = true;
    _notify();
    try {
      _journey = await _repository.getActiveJourney();
      _message = null;
    } catch (error, stackTrace) {
      debugPrint('Shake & Find initialization failed: $error\n$stackTrace');
      _message = 'Shake & Find could not load. You can try again.';
    } finally {
      _isInitialized = true;
      _isLoading = false;
      _notify();
    }
  }

  void selectMode(JourneyMode mode) {
    if (_isLoading) return;
    _selectedMode = mode;
    _notify();
  }

  void updatePreferences(TravelPreferences preferences) {
    _preferences = preferences;
    _notify();
  }

  Future<void> startShakeDetection() async {
    if (_isLoading || _isListeningForShake || hasActiveJourney) return;
    _sensorUnavailable = false;
    _isListeningForShake = true;
    _message = 'Shake your phone firmly, or use Tap instead.';
    _notify();
    try {
      await _repository.startShakeDetection(
        onShake: () => unawaited(startJourney()),
        onError: _handleSensorError,
      );
    } catch (error, stackTrace) {
      debugPrint('Shake sensor failed to start: $error\n$stackTrace');
      _handleSensorError(error);
    }
  }

  void _handleSensorError(Object error) {
    if (_disposed) return;
    debugPrint('Shake sensor unavailable: $error');
    _isListeningForShake = false;
    _sensorUnavailable = true;
    _message = 'Motion sensing is unavailable. Tap instead to continue.';
    _notify();
  }

  Future<void> stopShakeDetection() async {
    _isListeningForShake = false;
    await _repository.stopShakeDetection();
    _notify();
  }

  Future<void> startJourney() async {
    if (_isLoading || hasActiveJourney || _disposed) return;
    _isLoading = true;
    _isListeningForShake = false;
    _message = 'Finding your mystery destination...';
    _notify();
    try {
      await _repository.stopShakeDetection();
      _journey = await _repository.startJourney(_selectedMode, _preferences);
      _message = 'Your mystery clue is ready.';
    } catch (error, stackTrace) {
      debugPrint('Journey start failed: $error\n$stackTrace');
      _message = 'We could not start your journey. Please try again.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> requestHint() => _runJourneyAction(
    _repository.requestHint,
    failureMessage: 'The extra hint is unavailable right now.',
  );

  Future<void> revealRoute() => _runJourneyAction(
    _repository.revealRoute,
    failureMessage: 'The route could not be revealed. Please try again.',
  );

  Future<void> verifyArrival() async {
    final current = _journey;
    if (current == null || _isLoading || _disposed) return;
    _gpsUnavailable = false;
    _journey = current.copyWith(status: JourneyStatus.verifying);
    await _runJourneyAction(
      _repository.verifyArrival,
      failureMessage: 'GPS is unavailable. Check location services and retry.',
      onFailure: () => _gpsUnavailable = true,
    );
  }

  Future<void> _runJourneyAction(
    Future<Journey> Function(Journey) action, {
    required String failureMessage,
    VoidCallback? onFailure,
  }) async {
    final current = _journey;
    if (current == null || _isLoading || _disposed) return;
    _isLoading = true;
    _message = null;
    _notify();
    try {
      _journey = await action(current);
    } catch (error, stackTrace) {
      debugPrint('Shake & Find action failed: $error\n$stackTrace');
      onFailure?.call();
      _message = failureMessage;
      if (_journey?.status == JourneyStatus.verifying) {
        _journey = current;
      }
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> cancelJourney() async {
    if (_isLoading || _disposed) return;
    _isLoading = true;
    _notify();
    try {
      await _repository.stopShakeDetection();
      await _repository.cancelJourney();
      _journey = null;
      _isListeningForShake = false;
      _message = 'Journey cancelled.';
    } catch (error, stackTrace) {
      debugPrint('Journey cancellation failed: $error\n$stackTrace');
      _message = 'The journey could not be cancelled. Please try again.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void resetJourney() {
    if (_isLoading) return;
    _journey = null;
    _message = null;
    _gpsUnavailable = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_repository.dispose());
    super.dispose();
  }
}

/// UI-only MVVM state for the integrated Mystery Journey prototype.
/// The legacy [ShakeFindViewModel] above remains available for the existing
/// sensor/repository boundary while this model owns deterministic demo flows.
class LegacyMysteryJourneyViewModel extends ChangeNotifier {
  app.MysteryStage _stage = app.MysteryStage.home;
  app.JourneyMode _mode = app.JourneyMode.solo;
  final Set<String> _categories = <String>{'Culture', 'History'};
  double _radius = 15;
  String _time = 'Afternoon';
  bool _journeyActive = false;
  bool _scanning = false;
  bool _matched = false;
  int _roomMemberCount = 1;
  bool _ready = true;
  // The prototype enters the room with the traveller's saved preferences
  // selected. The host can still edit them or choose Surprise Me.
  bool _groupPreferencesSet = true;
  int _hintCount = 0;
  bool _routeRevealed = false;
  final List<String> _messages = <String>[
    'Lucas: The clock tower clue feels right.',
    'Amirah: I’m near Merdeka Square!',
  ];

  app.MysteryStage get stage => _stage;
  app.JourneyMode get mode => _mode;
  Set<String> get categories => Set<String>.unmodifiable(_categories);
  double get radius => _radius;
  String get time => _time;
  bool get journeyActive => _journeyActive;
  bool get scanning => _scanning;
  bool get matched => _matched;
  int get roomMemberCount => _roomMemberCount;
  bool get groupChatUnlocked => _roomMemberCount > 1;
  bool get ready => _ready;
  bool get groupPreferencesSet => _groupPreferencesSet;
  int get hintCount => _hintCount;
  bool get routeRevealed => _routeRevealed;
  List<String> get messages => List<String>.unmodifiable(_messages);

  void setStage(app.MysteryStage value) {
    _stage = value;
    notifyListeners();
  }

  void setMode(app.JourneyMode value) {
    _mode = value;
    notifyListeners();
  }

  void setRadius(double value) {
    _radius = value;
    notifyListeners();
  }

  void setTime(String value) {
    _time = value;
    notifyListeners();
  }

  void setReady(bool value) {
    _ready = value;
    notifyListeners();
  }

  void setGroupPreferences(bool value) {
    _groupPreferencesSet = value;
    notifyListeners();
  }

  void toggleCategory(String value) {
    _categories.contains(value)
        ? _categories.remove(value)
        : _categories.add(value);
    notifyListeners();
  }

  void addMessage(String value) {
    if (value.trim().isEmpty) return;
    _messages.add('You: ${value.trim()}');
    notifyListeners();
  }

  Future<void> scanNearby() async {
    if (_scanning) return;
    _scanning = true;
    _matched = false;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _scanning = false;
    _matched = true;
    _roomMemberCount = 3;
    _stage = app.MysteryStage.groupWaiting;
    notifyListeners();
  }

  void startJourney() {
    _journeyActive = true;
    _stage = app.MysteryStage.active;
    notifyListeners();
  }

  void finishJourney() {
    _journeyActive = false;
    _stage = app.MysteryStage.complete;
    notifyListeners();
  }

  void cancelJourney() {
    _journeyActive = false;
    _hintCount = 0;
    _routeRevealed = false;
    _stage = app.MysteryStage.home;
    notifyListeners();
  }

  void unlockHint() {
    if (_hintCount < 2) {
      _hintCount++;
      notifyListeners();
    }
  }

  void revealRoute() {
    _routeRevealed = true;
    notifyListeners();
  }

  void resetForNewQuest() {
    _hintCount = 0;
    _routeRevealed = false;
    _stage = app.MysteryStage.home;
    notifyListeners();
  }
}

/// Supabase-backed state used by the production Mystery Journey screen.
class MysteryJourneyViewModel extends ChangeNotifier {
  static const String testCompanionUsername = 'test_explorer';

  MysteryJourneyViewModel(this._repository);

  static const unfinishedJourneyMessage =
      'You still have an unfinished Mystery Journey. Complete or cancel it '
      'before starting a new one.';

  final ShakeFindRepository _repository;
  app.MysteryStage _stage = app.MysteryStage.home;
  app.JourneyMode _mode = app.JourneyMode.solo;
  Set<String> _categories = <String>{};
  double _radius = 5;
  String _time = 'Afternoon';
  Journey? _journey;
  JourneyProfile? _profile;
  bool _initialized = false;
  bool _loading = false;
  bool _listening = false;
  bool _sensorUnavailable = false;
  bool _scanning = false;
  bool _ready = false;
  bool _groupPreferencesSet = false;
  List<NearbyGroupRoom> _nearbyRooms = const <NearbyGroupRoom>[];
  bool _monitoring = false;
  ArrivalVerificationUpdate _arrivalVerification =
      const ArrivalVerificationUpdate.idle();
  bool _chatSending = false;
  bool _groupSyncing = false;
  bool _disposed = false;
  String? _message;
  List<GroupChatMessage> _messages = const <GroupChatMessage>[];
  GroupVoteOutcome? _lastVote;
  String? _groupVoteFeedback;
  final Map<GroupVoteType, GroupVoteOutcome> _groupVotes =
      <GroupVoteType, GroupVoteOutcome>{};
  Timer? _groupSyncTimer;
  Timer? _arrivalCountdownTimer;

  app.MysteryStage get stage => _stage;
  app.JourneyMode get mode => _mode;
  Set<String> get categories => Set<String>.unmodifiable(_categories);
  double get radius => _radius;
  String get time => _time;
  Journey? get journey => _journey;
  JourneyProfile? get profile => _profile;
  bool get initialized => _initialized;
  bool get loading => _loading;
  bool get isListeningForShake => _listening;
  bool get sensorUnavailable => _sensorUnavailable;
  String? get message => _message;
  bool get journeyActive =>
      _journey != null &&
      _journey!.status != JourneyStatus.completed &&
      _journey!.status != JourneyStatus.cancelled;
  bool get scanning => _scanning;
  ArrivalVerificationUpdate get arrivalVerification => _arrivalVerification;
  bool get chatSending => _chatSending;
  bool get matched => _journey?.groupRoomId != null;
  List<NearbyGroupRoom> get nearbyRooms =>
      List<NearbyGroupRoom>.unmodifiable(_nearbyRooms);
  int get roomMemberCount => _journey?.members.length ?? 0;
  bool get groupChatUnlocked => roomMemberCount > 1;
  String? get currentUserId => _profile?.userId;
  bool get ready => _ready;
  bool get allRoomMembersReady =>
      members.isNotEmpty && members.every((member) => member.isReady);
  bool get groupPreferencesSet => _groupPreferencesSet;
  int get hintCount => _journey?.additionalHints.length ?? 0;
  bool get hasHintsRemaining => _journey?.hasHintsRemaining ?? false;
  String? get groupVoteFeedback => _groupVoteFeedback;
  bool get routeRevealed => _journey?.exactRouteRevealed ?? false;
  bool get isHost => _journey?.isHost ?? false;
  String get groupPreferenceMode => !_groupPreferencesSet
      ? 'not_set'
      : _journey?.preferences.selectionMode ?? 'edited_preferences';
  List<JourneyMember> get members =>
      _journey?.members ?? const <JourneyMember>[];
  int get groupShakenCount =>
      members.where((member) => member.hasShaken).length;
  bool get currentUserArrived => members.any(
    (member) =>
        member.userId == _profile?.userId &&
        member.participantStatus == 'completed',
  );
  bool get currentUserHasShaken => members.any(
    (member) => member.userId == _profile?.userId && member.hasShaken,
  );
  List<GroupChatMessage> get messages =>
      List<GroupChatMessage>.unmodifiable(_messages);
  GroupVoteOutcome? get lastVote => _lastVote;
  GroupVoteOutcome? voteStatus(GroupVoteType type) {
    final outcome = _groupVotes[type];
    final currentRound = type == GroupVoteType.hint ? hintCount + 1 : 1;
    return outcome?.voteRound == currentRound ? outcome : null;
  }

  bool hasSubmittedVote(GroupVoteType type) =>
      voteStatus(type)?.currentUserVoted == true;

  bool hasTestExplorerVote(GroupVoteType type) =>
      voteStatus(type)?.testExplorerVoted == true;
  bool get hasActiveTestExplorer => members.any(
    (member) =>
        member.displayName.toLowerCase() == 'test explorer' &&
        member.participantStatus == 'active',
  );
  String get clue => _journey?.clue ?? '';
  List<String> get hints => _journey?.additionalHints ?? const <String>[];
  double get distanceMeters => _journey?.distanceMeters ?? 0;
  JourneyDestination? get revealedDestination =>
      _journey?.destinationMayBeRevealed == true ? _journey?.destination : null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize({bool force = false}) async {
    if ((_initialized && !force) || _loading || _disposed) return;
    _loading = true;
    _message = null;
    _notify();
    try {
      await _repository.checkConnection();
      final values = await Future.wait<Object?>(<Future<Object?>>[
        _repository.getSavedPreferences(),
        _repository.getCurrentProfile(),
        _repository.getActiveJourney(),
      ]);
      final preferences = values[0]! as TravelPreferences;
      _profile = values[1]! as JourneyProfile;
      _journey = values[2] as Journey?;
      _categories = preferences.categories.map(_uiCategory).toSet();
      _radius = preferences.radiusKm.clamp(5, 50);
      if (_journey != null) {
        _mode = _journey!.mode == JourneyMode.group
            ? app.JourneyMode.group
            : app.JourneyMode.solo;
        _categories = _journey!.preferences.categories.map(_uiCategory).toSet();
        _radius = _journey!.preferences.radiusKm.clamp(5, 50);
        _groupPreferencesSet = _journey!.groupPreferencesSet;
        _syncOwnReadyFromMembers();
        _stage = app.MysteryStage.home;
        if (_journey!.mode == JourneyMode.group) _startGroupSync();
      }
      _initialized = true;
    } catch (error, stackTrace) {
      debugPrint('Mystery Journey initialization failed: $error\n$stackTrace');
      _message = _friendlyError(error);
      _initialized = true;
    } finally {
      _loading = false;
      _notify();
    }
  }

  void setStage(app.MysteryStage value) {
    if (value == app.MysteryStage.active &&
        _journey?.id.startsWith('waiting:') == true) {
      _stage = app.MysteryStage.groupWaiting;
      _message = 'Waiting room resumed. The host must start the Group Journey.';
      _notify();
      return;
    }
    final startingCurrentGroupRoom =
        value == app.MysteryStage.shake &&
        _journey?.id.startsWith('waiting:') == true;
    if (startingCurrentGroupRoom &&
        (!isHost ||
            roomMemberCount < 2 ||
            !_groupPreferencesSet ||
            !allRoomMembersReady)) {
      _message = !isHost
          ? 'Only the host can start the Group Journey.'
          : roomMemberCount < 2
          ? 'At least two travellers are required to start the Group Journey.'
          : !allRoomMembersReady
          ? 'Everyone must be ready before starting.'
          : 'Set the group preferences before starting the Group Journey.';
      _notify();
      return;
    }
    if (journeyActive &&
        !startingCurrentGroupRoom &&
        (value == app.MysteryStage.shake ||
            value == app.MysteryStage.groupSetup)) {
      remindUnfinishedJourney();
      return;
    }
    _restoreExistingStage(value);
  }

  void _restoreExistingStage(app.MysteryStage value) {
    _stage = value;
    if (value == app.MysteryStage.shake) {
      _sensorUnavailable = false;
      _message = null;
      unawaited(_listenForShake());
    } else if (value == app.MysteryStage.active && journeyActive) {
      _message = null;
      if (currentUserArrived) {
        _setArrivalVerification(
          const ArrivalVerificationUpdate(
            state: ArrivalVerificationState.verified,
          ),
          notify: false,
        );
      }
    } else if (_listening) {
      unawaited(_repository.stopShakeDetection());
      _listening = false;
    }
    if (value == app.MysteryStage.groupSetup) {
      unawaited(scanNearby());
    }
    _notify();
  }

  void remindUnfinishedJourney() {
    _message = unfinishedJourneyMessage;
    _notify();
  }

  void resumeJourney() {
    if (_journey == null) return;
    final current = _journey!;
    if (current.id.startsWith('waiting:')) {
      _stage = app.MysteryStage.groupWaiting;
      _message = 'Waiting room resumed. The host must start the Group Journey.';
      _notify();
      return;
    }
    final ownMember = members.where(
      (member) => member.userId == _profile?.userId,
    );
    final target =
        current.mode == JourneyMode.group &&
            ownMember.isNotEmpty &&
            !ownMember.first.hasShaken
        ? app.MysteryStage.shake
        : app.MysteryStage.active;
    _message = null;
    _restoreExistingStage(target);
  }

  bool _blockNewJourneyWhileActive() {
    if (!journeyActive) return false;
    remindUnfinishedJourney();
    return true;
  }

  void setMode(app.JourneyMode value) {
    if (_loading || journeyActive) return;
    _mode = value;
    _notify();
  }

  void setRadius(double value) {
    _radius = value;
    _notify();
  }

  void setTime(String value) {
    _time = value;
    _notify();
  }

  Future<void> setReady(bool value) async {
    final roomId = _journey?.groupRoomId;
    if (_stage != app.MysteryStage.groupWaiting ||
        roomId == null ||
        _journey?.id.startsWith('waiting:') != true ||
        _loading) {
      return;
    }
    _loading = true;
    _message = null;
    _notify();
    try {
      final updated = await _repository.setGroupRoomReady(roomId, value);
      _journey = _journey?.copyWith(members: updated);
      _syncOwnReadyFromMembers();
    } catch (error) {
      _message = _friendlyError(error);
    } finally {
      _loading = false;
      _notify();
    }
  }

  void _syncOwnReadyFromMembers() {
    final userId = _profile?.userId;
    _ready =
        userId != null &&
        members.any((member) => member.userId == userId && member.isReady);
  }

  void setGroupPreferences(bool value) {
    if (_mode == app.JourneyMode.group && !isHost) return;
    _groupPreferencesSet = value;
    _notify();
  }

  void toggleCategory(String value) {
    if (_mode == app.JourneyMode.group && _journey != null && !isHost) return;
    _categories.contains(value)
        ? _categories.remove(value)
        : _categories.add(value);
    _groupPreferencesSet = true;
    _notify();
  }

  void useSurpriseMe() {
    if (journeyActive) {
      remindUnfinishedJourney();
      return;
    }
    _categories.clear();
    _groupPreferencesSet = true;
    setStage(app.MysteryStage.shake);
  }

  Future<void> addMessage(String value) async {
    if (value.trim().isNotEmpty) await _sendGroupMessage(value);
  }

  Future<void> _sendGroupMessage(String value) async {
    final roomId = _journey?.groupRoomId;
    if (roomId == null || !groupChatUnlocked || _loading || _chatSending) {
      return;
    }
    _chatSending = true;
    _notify();
    try {
      _messages = _orderedMessages(
        await _repository.sendGroupMessage(roomId, value),
      );
      _message = null;
    } catch (error) {
      _message = _friendlyError(error);
    } finally {
      _chatSending = false;
    }
    _notify();
  }

  Future<void> loadGroupMessages() async {
    final roomId = _journey?.groupRoomId;
    if (roomId == null || !groupChatUnlocked) return;
    try {
      _messages = _orderedMessages(await _repository.getGroupMessages(roomId));
    } catch (error) {
      _message = _friendlyError(error);
    }
    _notify();
  }

  Future<void> _listenForShake() async {
    final waitingForGroup = _journey?.id.startsWith('waiting:') == true;
    final revealingSharedGroupJourney =
        _stage == app.MysteryStage.shake &&
        _journey?.mode == JourneyMode.group &&
        !waitingForGroup;
    if (_listening ||
        _loading ||
        (journeyActive && !waitingForGroup && !revealingSharedGroupJourney) ||
        _disposed) {
      return;
    }
    _listening = true;
    _sensorUnavailable = false;
    _notify();
    try {
      await _repository.startShakeDetection(
        onShake: () => unawaited(_handleShake()),
        onError: (Object error) {
          _listening = false;
          _sensorUnavailable = true;
          _message = 'Motion sensing is unavailable. Retry the sensor.';
          _notify();
        },
      );
    } catch (error) {
      _listening = false;
      _sensorUnavailable = true;
      _message = 'Motion sensing is unavailable. Retry the sensor.';
      _notify();
    }
  }

  Future<void> _handleShake() async {
    final current = _journey;
    if (current?.mode == JourneyMode.group &&
        current != null &&
        !current.id.startsWith('waiting:')) {
      if (_loading) return;
      _loading = true;
      _message = null;
      _notify();
      try {
        final updated = await _repository.markGroupParticipantShaken(current);
        _journey = current.copyWith(members: updated);
        await _repository.stopShakeDetection();
        _listening = false;
        _stage = app.MysteryStage.active;
      } catch (error) {
        _message = _friendlyError(error);
      } finally {
        _loading = false;
        _notify();
      }
      return;
    }
    await startJourney();
  }

  Future<void> retryShakeDetection() async {
    if (_stage != app.MysteryStage.shake || _loading || _disposed) return;
    _message = null;
    _sensorUnavailable = false;
    _notify();
    await _listenForShake();
  }

  Future<void> scanNearby() async {
    if (_loading || _scanning || _disposed) return;
    if (_blockNewJourneyWhileActive()) return;
    _scanning = true;
    _message = null;
    _notify();
    try {
      _nearbyRooms = await _repository.findNearbyGroupRooms();
    } catch (error, stackTrace) {
      debugPrint('Nearby room scan failed: $error\n$stackTrace');
      _message = _friendlyError(error);
    } finally {
      _scanning = false;
      _notify();
    }
  }

  Future<void> createGroupRoom() async {
    if (_loading || _disposed) return;
    if (_blockNewJourneyWhileActive()) return;
    _loading = true;
    _message = null;
    _notify();
    try {
      _journey = await _repository.createGroupRoom();
      _mode = app.JourneyMode.group;
      _groupPreferencesSet = false;
      _ready = false;
      _syncOwnReadyFromMembers();
      _stage = app.MysteryStage.groupWaiting;
      _startGroupSync();
    } catch (error, stackTrace) {
      debugPrint('Group room creation failed: $error\n$stackTrace');
      _message = _friendlyError(error);
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> joinGroupRoom(String roomId) async {
    if (_loading || roomId.trim().isEmpty) return;
    if (_blockNewJourneyWhileActive()) return;
    _loading = true;
    _message = null;
    _notify();
    try {
      _journey = await _repository.joinGroupRoom(roomId.trim());
      _mode = app.JourneyMode.group;
      _categories = _journey!.preferences.categories.map(_uiCategory).toSet();
      _radius = _journey!.preferences.radiusKm.clamp(5, 50);
      _groupPreferencesSet = _journey!.groupPreferencesSet;
      _syncOwnReadyFromMembers();
      _stage = app.MysteryStage.groupWaiting;
      _startGroupSync();
    } catch (error) {
      _message = _friendlyError(error);
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> saveGroupPreferences() async {
    final roomId = _journey?.groupRoomId;
    if (roomId == null || !isHost || _loading) return;
    _loading = true;
    _message = null;
    _notify();
    try {
      final preferences = TravelPreferences(
        categories: _categories,
        radiusKm: _radius,
        useSavedPreferences: false,
      );
      await _repository.saveGroupRoomPreferences(roomId, preferences);
      _journey = _journey?.copyWith(
        preferences: preferences,
        groupPreferencesSet: true,
      );
      _groupPreferencesSet = true;
    } catch (error) {
      _message = _friendlyError(error);
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> useSavedGroupPreferences() async {
    final roomId = _journey?.groupRoomId;
    if (roomId == null || !isHost || _loading) return;
    _loading = true;
    _message = null;
    _notify();
    try {
      final saved = await _repository.getSavedPreferences();
      final preferences = saved.copyWith(useSavedPreferences: true);
      await _repository.saveGroupRoomPreferences(roomId, preferences);
      _categories = preferences.categories.map(_uiCategory).toSet();
      _radius = preferences.radiusKm.clamp(5, 50);
      _journey = _journey?.copyWith(
        preferences: preferences,
        groupPreferencesSet: true,
      );
      _groupPreferencesSet = true;
      _message = 'Saved travel preferences applied to this room.';
    } catch (error) {
      _message = _friendlyError(error);
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> useGroupSurpriseMe() async {
    final roomId = _journey?.groupRoomId;
    if (roomId == null || !isHost || _loading) {
      _message = !isHost
          ? 'Only the host can set Group Journey preferences.'
          : 'The room is not ready for preferences yet.';
      _notify();
      return;
    }
    _loading = true;
    _message = null;
    _notify();
    try {
      final preferences = TravelPreferences(
        categories: const <String>{},
        radiusKm: _radius,
        useSavedPreferences: false,
      );
      await _repository.saveGroupRoomPreferences(roomId, preferences);
      _categories.clear();
      _journey = _journey?.copyWith(
        preferences: preferences,
        groupPreferencesSet: true,
      );
      _groupPreferencesSet = true;
      _message =
          'Surprise Me is set for this room. Shake remains locked until the host starts.';
    } catch (error) {
      _message = _friendlyError(error);
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> refreshRoom() async {
    final roomId = _journey?.groupRoomId;
    if (roomId == null || _loading) return;
    try {
      final values = await _repository.refreshGroupMembers(roomId);
      _journey = _journey?.copyWith(members: values);
      _syncOwnReadyFromMembers();
      if (values.length > 1) {
        _messages = _orderedMessages(
          await _repository.getGroupMessages(roomId),
        );
      }
      _notify();
    } catch (error) {
      _message = _friendlyError(error);
      _notify();
    }
  }

  Future<void> addTestGroupMember(String testUsername) async {
    final roomId = _journey?.groupRoomId;
    if (roomId == null || !isHost || _loading) return;
    if (!testUsername.trim().startsWith('test_')) {
      _message = 'Enter a test profile username beginning with test_.';
      _notify();
      return;
    }
    _loading = true;
    _message = null;
    _notify();
    try {
      final members = await _repository.addTestGroupMember(
        roomId,
        testUsername,
      );
      _journey = _journey?.copyWith(members: members);
      _syncOwnReadyFromMembers();
      _message = testUsername == testCompanionUsername
          ? 'Test Explorer joined this waiting room.'
          : 'A real test account was added to this waiting room.';
    } catch (error) {
      _message = _friendlyError(error);
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> addTestCompanion() => addTestGroupMember(testCompanionUsername);

  Future<void> beginGroupJourney() async {
    final roomId = _journey?.groupRoomId;
    if (_loading || roomId == null || !isHost) return;
    _loading = true;
    _message = null;
    _notify();
    var startShakeDetection = false;
    try {
      final currentMembers = await _repository.refreshGroupMembers(roomId);
      _journey = _journey?.copyWith(members: currentMembers);
      _syncOwnReadyFromMembers();
      if (currentMembers.length < 2) {
        _message = 'At least two travellers are required to start.';
      } else if (!_groupPreferencesSet) {
        _message = 'Set the group preferences before starting.';
      } else if (currentMembers.any((member) => !member.isReady)) {
        final count = currentMembers.where((member) => !member.isReady).length;
        _message = count == 1
            ? '1 traveller is not ready yet.'
            : '$count travellers are not ready yet.';
      } else {
        _message = 'Starting the shared Group Journey…';
        _notify();
        final preferences = TravelPreferences(
          categories: _categories,
          radiusKm: _radius,
          useSavedPreferences:
              _journey?.preferences.useSavedPreferences ?? false,
        );
        _journey = await _repository.startJourney(
          JourneyMode.group,
          preferences,
        );
        _groupVotes.clear();
        _groupPreferencesSet = true;
        _ready = false;
        _stage = app.MysteryStage.shake;
        _sensorUnavailable = false;
        _message = null;
        _startGroupSync();
        startShakeDetection = true;
      }
    } catch (error) {
      _message = _friendlyError(error);
    } finally {
      _loading = false;
      _notify();
    }
    if (startShakeDetection) unawaited(_listenForShake());
  }

  Future<void> leaveWaitingRoom() async {
    final roomId = _journey?.groupRoomId;
    if (roomId == null ||
        _journey?.id.startsWith('waiting:') != true ||
        _loading) {
      return;
    }
    final hostWasLeaving = isHost;
    _loading = true;
    _message = null;
    _notify();
    try {
      _groupSyncTimer?.cancel();
      await _repository.leaveGroupRoom(roomId);
      _journey = null;
      _messages = const <GroupChatMessage>[];
      _nearbyRooms = const <NearbyGroupRoom>[];
      _groupPreferencesSet = false;
      _ready = false;
      _stage = app.MysteryStage.home;
      _message = hostWasLeaving
          ? 'Group Room cancelled.'
          : 'You left the waiting room.';
    } catch (error) {
      _message = _friendlyError(error);
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> startJourney() async {
    final waitingForGroup = _journey?.id.startsWith('waiting:') == true;
    if (_loading || _disposed) return;
    if (!waitingForGroup && _blockNewJourneyWhileActive()) return;
    if (_mode == app.JourneyMode.group) {
      if (!isHost) {
        _message = 'Only the host can discover the shared destination.';
        _notify();
        return;
      }
      if (roomMemberCount < 2) {
        _message = 'At least two travellers are required to start.';
        _notify();
        return;
      }
      if (!_groupPreferencesSet) {
        _message = 'Set the group preferences before starting.';
        _notify();
        return;
      }
      if (!allRoomMembersReady) {
        _message = 'Everyone must be ready before starting.';
        _notify();
        return;
      }
    }
    _loading = true;
    _listening = false;
    _sensorUnavailable = false;
    _message = 'Finding your mystery destination…';
    _notify();
    var shouldResumeShakeDetection = false;
    try {
      await _repository.stopShakeDetection();
      _journey = await _repository.startJourney(
        _mode == app.JourneyMode.group ? JourneyMode.group : JourneyMode.solo,
        TravelPreferences(
          categories: _categories,
          radiusKm: _radius,
          useSavedPreferences: false,
        ),
      );
      _groupVotes.clear();
      _groupVoteFeedback = null;
      _stage = app.MysteryStage.active;
      _ready = false;
      _startGroupSync();
      _message = null;
    } catch (error, stackTrace) {
      debugPrint('Journey start failed: $error\n$stackTrace');
      _message = _friendlyError(error);
      shouldResumeShakeDetection = true;
    } finally {
      _loading = false;
      _notify();
      if (shouldResumeShakeDetection &&
          _stage == app.MysteryStage.shake &&
          !_disposed) {
        unawaited(_listenForShake());
      }
    }
  }

  Future<void> _monitorArrival() async {
    final current = _journey;
    if (_monitoring ||
        current == null ||
        (current.mode == JourneyMode.group && currentUserArrived) ||
        current.status == JourneyStatus.completed ||
        current.status == JourneyStatus.cancelled) {
      return;
    }
    _monitoring = true;
    try {
      _journey = await _repository.verifyArrival(
        current,
        onProgress: (update) {
          if (_disposed) return;
          _setArrivalVerification(update, notify: false);
          if (update.distanceMeters case final distance?) {
            _journey = (_journey ?? current).copyWith(
              status: JourneyStatus.verifying,
              distanceMeters: distance,
            );
          }
          _notify();
        },
      );
      if (_journey?.status == JourneyStatus.completed) {
        _groupSyncTimer?.cancel();
        _stage = app.MysteryStage.complete;
        _profile = await _repository.getCurrentProfile();
      }
    } catch (error, stackTrace) {
      debugPrint('Arrival monitoring failed: $error\n$stackTrace');
      _message = _friendlyError(error);
    } finally {
      _monitoring = false;
      _notify();
    }
  }

  Future<void> finishJourney() => _monitorArrival();

  Future<void> simulateArrival({bool testExplorer = false}) async {
    final current = _journey;
    if (!kDebugMode ||
        current == null ||
        current.id.startsWith('waiting:') ||
        current.status == JourneyStatus.completed ||
        current.status == JourneyStatus.cancelled ||
        _loading) {
      return;
    }
    if (testExplorer &&
        (current.mode != JourneyMode.group ||
            !isHost ||
            !hasActiveTestExplorer)) {
      _message =
          'An active Test Explorer participant is required for this test.';
      _notify();
      return;
    }
    _loading = true;
    _message = testExplorer
        ? 'Simulating Test Explorer arrival…'
        : 'Simulating your verified arrival…';
    _notify();
    try {
      _journey = await _repository.simulateArrival(
        current,
        testExplorer: testExplorer,
      );
      if (testExplorer) {
        _message = 'Test Explorer completed this Group Journey.';
      } else {
        _profile = await _repository.getCurrentProfile();
        if (_journey?.status == JourneyStatus.completed) {
          _groupSyncTimer?.cancel();
          _stage = app.MysteryStage.complete;
          _message = 'Arrival verified. Group Journey completed.';
        } else {
          _setArrivalVerification(
            const ArrivalVerificationUpdate(
              state: ArrivalVerificationState.verified,
            ),
            notify: false,
          );
          _stage = app.MysteryStage.active;
          _message =
              'Your arrival is verified. Waiting for the other travellers.';
        }
      }
    } catch (error) {
      _message = _friendlyError(error);
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> testArrivalNow() async {
    final current = _journey;
    if (current == null || current.id.startsWith('waiting:') || _loading) {
      _message = 'Start the Mystery Journey before testing arrival.';
      _notify();
      return;
    }
    if (current.mode == JourneyMode.group && currentUserArrived) {
      _message = 'Your arrival is already verified.';
      _notify();
      return;
    }
    _loading = true;
    _message = 'Checking your real GPS position…';
    _notify();
    try {
      final result = await _repository.checkArrivalNow(current);
      _journey = current.copyWith(distanceMeters: result.distanceMeters);
      if (!result.hasReliableAccuracy) {
        _setArrivalVerification(
          ArrivalVerificationUpdate(
            state: ArrivalVerificationState.waitingForAccuracy,
            distanceMeters: result.distanceMeters,
            accuracyMeters: result.accuracyMeters,
          ),
          notify: false,
        );
        _message = null;
      } else if (result.isInsideArrivalRadius) {
        _setArrivalVerification(
          ArrivalVerificationUpdate(
            state: ArrivalVerificationState.verifying,
            secondsRemaining: 10,
            distanceMeters: result.distanceMeters,
            accuracyMeters: result.accuracyMeters,
          ),
          notify: false,
        );
        _message = null;
      } else {
        _setArrivalVerification(
          ArrivalVerificationUpdate(
            state: ArrivalVerificationState.outsideRange,
            distanceMeters: result.distanceMeters,
            accuracyMeters: result.accuracyMeters,
          ),
          notify: false,
        );
        _message = null;
      }
      if (!_monitoring) unawaited(_monitorArrival());
    } catch (error) {
      _message = _friendlyError(error);
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> cancelJourney() async {
    if (_loading) return;
    final cancelledJourney = _journey;
    _loading = true;
    _notify();
    try {
      await _repository.stopShakeDetection();
      await _repository.cancelJourney();
      _journey = null;
      _groupVotes.clear();
      _setArrivalVerification(
        const ArrivalVerificationUpdate.idle(),
        notify: false,
      );
      _stage = app.MysteryStage.home;
      _message = cancelledJourney?.mode == JourneyMode.group
          ? 'You left the Group Journey. Other travellers can continue.'
          : 'Solo Mystery Journey cancelled.';
    } catch (error) {
      _message = _friendlyError(error);
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> unlockHint() async {
    final current = _journey;
    if (current == null || _loading) return;
    if (!current.hasHintsRemaining) {
      _message = 'All Mystery Hints have been unlocked.';
      _notify();
      return;
    }
    _loading = true;
    _notify();
    try {
      _journey = await _repository.requestHint(current);
      _message = 'A new Mystery Hint has been unlocked.';
    } catch (error) {
      _message = _friendlyError(error);
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<GroupVoteOutcome?> castGroupVote(
    GroupVoteType type, {
    bool simulateTestExplorer = false,
  }) async {
    final current = _journey;
    if (current == null || current.mode != JourneyMode.group || _loading) {
      return null;
    }
    if (current.id.startsWith('waiting:') ||
        current.status == JourneyStatus.idle) {
      _message = 'The host must start the Group Journey before voting.';
      _notify();
      return null;
    }
    if (type == GroupVoteType.hint && !current.hasHintsRemaining) {
      _message = 'All Mystery Hints have been unlocked.';
      _notify();
      return null;
    }
    _loading = true;
    _message = null;
    _notify();
    try {
      _lastVote = await _repository.castGroupVote(
        current,
        type,
        simulateTestExplorer: simulateTestExplorer,
      );
      _groupVotes[type] = _lastVote!;
      _message = null;
      _groupVoteFeedback = _lastVote!.message;
      if (_lastVote!.passed) {
        final refreshed = await _repository.getActiveJourney();
        if (refreshed != null) _journey = refreshed;
      }
      return _lastVote;
    } catch (error) {
      _message = _friendlyError(error);
      return null;
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<GroupVoteOutcome?> simulateTestExplorerVote(GroupVoteType type) =>
      castGroupVote(type, simulateTestExplorer: true);

  void _startGroupSync() {
    _groupSyncTimer?.cancel();
    if (_journey?.mode != JourneyMode.group || _journey?.groupRoomId == null) {
      return;
    }
    unawaited(_syncGroupData());
    _groupSyncTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_syncGroupData()),
    );
  }

  Future<void> _syncGroupData() async {
    if (_groupSyncing || _loading || _disposed) return;
    final roomId = _journey?.groupRoomId;
    if (roomId == null) return;
    _groupSyncing = true;
    try {
      final refreshed = await _repository.getActiveJourney();
      if (refreshed != null && refreshed.groupRoomId == roomId) {
        final wasWaiting = _journey?.id.startsWith('waiting:') == true;
        final previousHintCount = _journey?.additionalHints.length ?? 0;
        final routeWasRevealed = _journey?.exactRouteRevealed ?? false;
        _journey = refreshed;
        _syncOwnReadyFromMembers();
        _groupPreferencesSet = refreshed.groupPreferencesSet;
        _categories = refreshed.preferences.categories.map(_uiCategory).toSet();
        _radius = refreshed.preferences.radiusKm.clamp(5, 50);
        if (refreshed.status == JourneyStatus.completed) {
          _groupSyncTimer?.cancel();
          _stage = app.MysteryStage.complete;
        }
        if (wasWaiting && !refreshed.id.startsWith('waiting:')) {
          _stage = app.MysteryStage.shake;
          _sensorUnavailable = false;
          _message = null;
          unawaited(_listenForShake());
        }
        if (refreshed.members.length > 1) {
          _messages = _orderedMessages(
            await _repository.getGroupMessages(roomId),
          );
        }
        if (!refreshed.id.startsWith('waiting:') &&
            refreshed.status != JourneyStatus.completed &&
            refreshed.status != JourneyStatus.cancelled) {
          if (refreshed.additionalHints.length > previousHintCount) {
            _groupVoteFeedback =
                'Group Hint approved. The next Hint has been unlocked for everyone.';
          } else if (!routeWasRevealed && refreshed.exactRouteRevealed) {
            _groupVoteFeedback =
                'Route Reveal approved. The exact Mystery Destination is now visible to the team.';
          }
          final requests = <Future<GroupVoteOutcome>>[
            if (refreshed.hasHintsRemaining)
              _repository.getGroupVoteStatus(refreshed, GroupVoteType.hint),
            _repository.getGroupVoteStatus(refreshed, GroupVoteType.route),
          ];
          final voteStatuses = await Future.wait<GroupVoteOutcome>(requests);
          if (!refreshed.hasHintsRemaining) {
            _groupVotes.remove(GroupVoteType.hint);
          }
          for (final status in voteStatuses) {
            _groupVotes[status.type] = status;
          }
        }
        _notify();
      } else if (_journey?.id.startsWith('waiting:') == true) {
        _groupSyncTimer?.cancel();
        _journey = null;
        _messages = const <GroupChatMessage>[];
        _groupPreferencesSet = false;
        _ready = false;
        _stage = app.MysteryStage.home;
        _message = 'The Group Room was cancelled by the Host.';
        _notify();
      }
    } catch (error) {
      debugPrint('Group session refresh failed: $error');
    } finally {
      _groupSyncing = false;
    }
  }

  Future<void> revealRoute() async {
    final current = _journey;
    if (current == null || _loading) return;
    _loading = true;
    _notify();
    try {
      _journey = await _repository.revealRoute(current);
      _message = null;
    } catch (error) {
      _message = _friendlyError(error);
    } finally {
      _loading = false;
      _notify();
    }
  }

  void resetForNewQuest() {
    if (journeyActive) return;
    _journey = null;
    _setArrivalVerification(
      const ArrivalVerificationUpdate.idle(),
      notify: false,
    );
    _stage = app.MysteryStage.home;
    _message = null;
    _notify();
  }

  static String _uiCategory(String value) => switch (value) {
    'culture' => 'Culture',
    'history' => 'History',
    'local_food' => 'Local food',
    'art_streets' => 'Art & streets',
    _ => value,
  };

  static List<GroupChatMessage> _orderedMessages(
    List<GroupChatMessage> messages,
  ) => List<GroupChatMessage>.of(messages)
    ..sort((left, right) {
      final time = left.createdAt.compareTo(right.createdAt);
      return time != 0 ? time : left.id.compareTo(right.id);
    });

  void _setArrivalVerification(
    ArrivalVerificationUpdate update, {
    bool notify = true,
  }) {
    _arrivalVerification = update;
    _arrivalCountdownTimer?.cancel();
    _arrivalCountdownTimer = null;
    if (update.state == ArrivalVerificationState.verifying) {
      _arrivalCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_disposed) return;
        final remaining = (_arrivalVerification.secondsRemaining - 1).clamp(
          0,
          10,
        );
        _arrivalVerification = ArrivalVerificationUpdate(
          state: ArrivalVerificationState.verifying,
          secondsRemaining: remaining,
          distanceMeters: _arrivalVerification.distanceMeters,
          accuracyMeters: _arrivalVerification.accuracyMeters,
        );
        if (remaining == 0) {
          _arrivalCountdownTimer?.cancel();
          _arrivalCountdownTimer = null;
        }
        _notify();
      });
    }
    if (notify) _notify();
  }

  static String _friendlyError(Object error) {
    final value = error.toString();
    if (value.startsWith('AuthException(message:')) {
      return 'Please sign in before using Mystery Journey.';
    }
    if (value.contains('Failed host lookup') ||
        value.contains('SocketException') ||
        value.contains('Connection refused') ||
        value.contains('Connection reset by peer') ||
        value.contains('Network is unreachable')) {
      return 'You appear to be offline. Your journey is saved. Check your '
          'connection, then tap Resume to restart arrival monitoring.';
    }
    if (value.contains('JWT expired') ||
        value.contains('PGRST301') ||
        value.contains('Invalid JWT') ||
        value.contains('User from sub claim in JWT does not exist') ||
        value.contains('group_rooms_host_user_id_fkey') ||
        value.contains('401')) {
      return 'Your sign-in session is no longer valid. Sign out, then sign in '
          'again before creating or joining a Group Room.';
    }
    if (value.contains('TimeoutException') ||
        value.contains('timed out') ||
        value.contains('Unable to get current location')) {
      return 'Unable to detect your current location. Enable location services, '
          'move to an open area, then try again.';
    }
    return value.replaceFirst('JourneyDataException: ', '');
  }

  @override
  void dispose() {
    _disposed = true;
    _groupSyncTimer?.cancel();
    _arrivalCountdownTimer?.cancel();
    unawaited(_repository.dispose());
    super.dispose();
  }
}
