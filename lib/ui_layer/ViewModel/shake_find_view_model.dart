import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data_layer/Models/shake_find/journey.dart';
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
class MysteryJourneyViewModel extends ChangeNotifier {
  app.MysteryStage _stage = app.MysteryStage.home;
  app.JourneyMode _mode = app.JourneyMode.solo;
  final Set<String> _categories = <String>{'Culture', 'History'};
  double _radius = 15;
  String _time = 'Afternoon';
  bool _journeyActive = false;
  bool _scanning = false;
  bool _matched = false;
  bool _ready = true;
  bool _groupPreferencesSet = false;
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
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 650));
    _scanning = false;
    _matched = true;
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
