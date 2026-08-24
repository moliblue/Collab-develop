import '../Models/shake_find/journey.dart';

abstract interface class ShakeFindRepository {
  Future<Journey?> getActiveJourney();
  Future<void> startShakeDetection({
    required void Function() onShake,
    required void Function(Object error) onError,
  });
  Future<void> stopShakeDetection();
  Future<Journey> startJourney(JourneyMode mode, TravelPreferences preferences);
  Future<Journey> requestHint(Journey journey);
  Future<Journey> revealRoute(Journey journey);
  Future<Journey> verifyArrival(Journey journey);
  Future<void> cancelJourney();
  Future<void> dispose();
}
