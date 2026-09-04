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
  Future<Journey> verifyArrival(
    Journey journey, {
    void Function(ArrivalVerificationUpdate update)? onProgress,
  });
  Future<Journey> simulateArrival(Journey journey, {bool testExplorer = false});
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
  Future<List<GroupChatMessage>> getGroupMessages(String roomId);
  Future<List<GroupChatMessage>> sendGroupMessage(
    String roomId,
    String message,
  );
  Future<GroupVoteOutcome> castGroupVote(
    Journey journey,
    GroupVoteType type, {
    bool simulateTestExplorer = false,
  });
  Future<GroupVoteOutcome> getGroupVoteStatus(
    Journey journey,
    GroupVoteType type,
  );
  Future<List<JourneyMember>> refreshGroupMembers(String roomId);
  Future<List<JourneyMember>> markGroupParticipantShaken(Journey journey);
  Future<List<JourneyMember>> setGroupRoomReady(String roomId, bool isReady);
  Future<List<JourneyMember>> addTestGroupMember(
    String roomId,
    String testUsername,
  );
  Future<Journey> joinGroupRoom(String roomId);
  Future<void> leaveGroupRoom(String roomId);
  Future<void> expireGroupJourneyIfNeeded(Journey journey);
  Future<void> dispose();
}
