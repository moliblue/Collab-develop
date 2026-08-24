import '../Models/shake_find/journey.dart';
import '../Service Managers/device/shake_sensor_service.dart';
import 'shake_find_repository.dart';

class ShakeFindRepositoryImpl implements ShakeFindRepository {
  ShakeFindRepositoryImpl(this._sensorService);

  final ShakeSensorService _sensorService;
  Journey? _activeJourney;

  @override
  Future<Journey?> getActiveJourney() async => _activeJourney;

  @override
  Future<void> startShakeDetection({
    required void Function() onShake,
    required void Function(Object error) onError,
  }) async => _sensorService.startListening(onShake: onShake, onError: onError);

  @override
  Future<void> stopShakeDetection() => _sensorService.stopListening();

  @override
  Future<Journey> startJourney(
    JourneyMode mode,
    TravelPreferences preferences,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _activeJourney = Journey(
      id: 'journey-${DateTime.now().millisecondsSinceEpoch}',
      status: JourneyStatus.active,
      clue: mode == JourneyMode.group
          ? 'Together, find the red-brick keeper of time where the city remembers.'
          : 'I keep time above red bricks, where history whispers near an open square.',
      locationHint: 'Central Kuala Lumpur',
      distanceMeters: preferences.radiusKm * 84,
    );
    return _activeJourney!;
  }

  @override
  Future<Journey> requestHint(Journey journey) async {
    _activeJourney = journey.copyWith(
      clue: '${journey.clue}\n\nHint: Look near Merdeka Square.',
    );
    return _activeJourney!;
  }

  @override
  Future<Journey> revealRoute(Journey journey) async {
    _activeJourney = journey.copyWith(
      status: JourneyStatus.routeRevealed,
      locationHint: 'Sultan Abdul Samad Building, Merdeka Square',
    );
    return _activeJourney!;
  }

  @override
  Future<Journey> verifyArrival(Journey journey) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _activeJourney = journey.copyWith(
      status: JourneyStatus.completed,
      distanceMeters: 18,
    );
    return _activeJourney!;
  }

  @override
  Future<void> cancelJourney() async => _activeJourney = null;

  @override
  Future<void> dispose() => _sensorService.dispose();
}
