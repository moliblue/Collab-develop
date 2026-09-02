import '../Models/journey.dart';

abstract interface class ShakeFindRepository {
  Future<bool> checkConnection();
  Future<JourneyProfile> getCurrentProfile();
  Future<TravelPreferences> getSavedPreferences();
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
  Future<ArrivalCheckResult> checkArrivalNow(Journey journey);
  Future<void> cancelJourney();
  Future<List<NearbyGroupRoom>> findNearbyGroupRooms({
    double radiusMeters = 1000,
  });
  Future<Journey> createGroupRoom();
  Future<void> saveGroupRoomPreferences(
    String roomId,
    TravelPreferences preferences,
  );
  Future<List<String>> getGroupMessages(String roomId);
  Future<List<String>> sendGroupMessage(String roomId, String message);
  Future<GroupVoteOutcome> castGroupVote(Journey journey, GroupVoteType type);
  Future<List<JourneyMember>> refreshGroupMembers(String roomId);
  Future<List<JourneyMember>> addTestGroupMember(
    String roomId,
    String testUsername,
  );
  Future<Journey> joinGroupRoom(String roomId);
  Future<void> leaveGroupRoom(String roomId);
  Future<void> expireGroupJourneyIfNeeded(Journey journey);
  Future<void> dispose();
}
