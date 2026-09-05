import 'dart:math';

import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Models/journey.dart';
import '../Service Managers/Remote Services/supabase_service.dart';
import '../Service Managers/device/location_service.dart';
import '../Service Managers/device/shake_sensor_service.dart';
import 'shake_find_repository.dart';

class JourneyDataException implements Exception {
  const JourneyDataException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ShakeFindRepositoryImpl implements ShakeFindRepository {
  ShakeFindRepositoryImpl(
    this._sensorService, {
    SupabaseService? supabaseService,
    LocationService? locationService,
    Random? random,
  }) : _supabase = supabaseService ?? const SupabaseService(),
       _location = locationService ?? const LocationService(),
       _random = random ?? Random.secure();

  static const double acceptedAccuracyMeters = 30;
  static const double arrivalRadiusMeters = 50;
  static const Duration arrivalDwell = Duration(seconds: 10);
  static const int completionXp = 100;
  static const String defaultTestingRoomId =
      '1bf4271d-2e49-4380-afc1-3d1bf75869ba';
  final ShakeSensorService _sensorService;
  final SupabaseService _supabase;
  final LocationService _location;
  final Random _random;
  Journey? _activeJourney;
  bool _creatingJourney = false;
  bool _completingParticipant = false;

  SupabaseClient get _client => _supabase.client;

  @override
  Future<bool> checkConnection() => _supabase.canReadDestinations();

  @override
  Future<JourneyProfile> getCurrentProfile() async {
    final userId = _supabase.requireCurrentUserId();
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) {
      throw const JourneyDataException(
        'Your traveller profile could not be found.',
      );
    }
    return JourneyProfile(
      userId: userId,
      explorerLevel: _asInt(row['explorer_level'], fallback: 1),
      xp: _asInt(row['xp']),
      streakDays: _asInt(row['streak_days']),
    );
  }

  @override
  Future<TravelPreferences> getSavedPreferences() async {
    final userId = _supabase.requireCurrentUserId();
    final row = await _client
        .from('user_preferences')
        .select('id, discovery_radius_km')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return const TravelPreferences();
    final categories = <String>{};
    final preferenceId = row['id']?.toString();
    if (preferenceId != null) {
      final categoryRows = await _client
          .from('user_preference_categories')
          .select('category')
          .eq('preference_id', preferenceId);
      for (final value in categoryRows) {
        final category = value['category']?.toString();
        if (category != null) categories.add(category);
      }
    }
    return TravelPreferences(
      categories: categories,
      radiusKm: _asDouble(row['discovery_radius_km'], fallback: 5),
      useSavedPreferences: true,
    );
  }

  @override
  Future<Journey?> getActiveJourney() async {
    final userId = _supabase.requireCurrentUserId();
    final rows = await _client
        .from('journey_participants')
        .select()
        .eq('user_id', userId)
        .eq('participant_status', 'active')
        .limit(2);
    if (rows.isEmpty) {
      final cached = _activeJourney;
      if (cached?.mode == JourneyMode.group &&
          !cached!.id.startsWith('waiting:')) {
        final refreshed = await _loadJourney(cached.id);
        _activeJourney = refreshed;
        return refreshed;
      }
      final activeGroup = await _loadActiveGroupRoomForParticipant(userId);
      if (activeGroup != null) {
        _activeJourney = activeGroup;
        return activeGroup;
      }
      _activeJourney = await _loadWaitingGroupRoom(userId);
      return _activeJourney;
    }
    if (rows.length > 1) {
      throw const JourneyDataException(
        'Multiple active journeys were found. Please contact support.',
      );
    }
    final participant = Map<String, dynamic>.from(rows.single);
    final journey = await _loadJourney(
      participant['journey_id'].toString(),
      participant: participant,
    );
    await expireGroupJourneyIfNeeded(journey);
    if (journey.groupDeadline != null &&
        !journey.groupDeadline!.isAfter(DateTime.now())) {
      _activeJourney = null;
      return null;
    }
    _activeJourney = journey;
    return journey;
  }

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
    if (_creatingJourney) {
      throw const JourneyDataException('A journey is already being created.');
    }
    _creatingJourney = true;
    try {
      final existing = await getActiveJourney();
      final isWaitingHost =
          mode == JourneyMode.group &&
          existing?.id.startsWith('waiting:') == true &&
          existing?.isHost == true;
      if (existing != null && !isWaitingHost) {
        if (mode == JourneyMode.group &&
            existing.mode == JourneyMode.group &&
            existing.isHost &&
            existing.groupRoomId != null) {
          return existing;
        }
        throw const JourneyDataException(
          'Resume or cancel your active journey before starting another.',
        );
      }
      if (mode == JourneyMode.group) {
        return _startSharedGroupJourney(preferences);
      }
      return _createSoloJourney(preferences);
    } finally {
      _creatingJourney = false;
    }
  }

  Future<Journey> _createSoloJourney(TravelPreferences preferences) async {
    final userId = _supabase.requireCurrentUserId();
    final location = await _location.getFreshLocation();
    final selection = await _selectDestination(
      preferences,
      location,
      userId: userId,
    );
    final destination = selection.destination;
    final clue = await _initialClue(
      destination.id,
      previouslyUsedClueIds: selection.previouslyUsedClueIds,
    );
    final totalHintCount = await _additionalHintCount(destination.id);
    String? journeyId;
    try {
      final journeyRow = await _client
          .from('mystery_journeys')
          .insert(<String, dynamic>{
            'mode': 'solo',
            'destination_id': destination.id,
            'initial_clue_id': clue['id'],
            'selection_mode': preferences.selectionMode,
            'discovery_radius_km': preferences.radiusKm.round(),
            'status': 'active',
            'exact_route_revealed': false,
          })
          .select()
          .single();
      journeyId = journeyRow['id'].toString();
      final participant = await _client
          .from('journey_participants')
          .insert(<String, dynamic>{
            'journey_id': journeyId,
            'user_id': userId,
            'participant_status': 'active',
          })
          .select()
          .single();
      await _saveJourneyCategories(journeyId, preferences.categories);
      final result = Journey(
        id: journeyId,
        participantId: participant['id'].toString(),
        status: JourneyStatus.active,
        mode: JourneyMode.solo,
        clue: _clueText(clue),
        locationHint: 'Within ${preferences.radiusKm.toStringAsFixed(0)} km',
        distanceMeters: _location.distanceBetween(
          location,
          destination.latitude,
          destination.longitude,
        ),
        destination: destination,
        preferences: preferences,
        totalHintCount: totalHintCount,
        isRevisit: selection.isRevisit,
      );
      _activeJourney = result;
      return result;
    } catch (_) {
      if (journeyId != null) {
        await _client.from('mystery_journeys').delete().eq('id', journeyId);
      }
      rethrow;
    }
  }

  Future<_DestinationSelection> _selectDestination(
    TravelPreferences preferences,
    LocationReading location, {
    required String userId,
  }) async {
    final rows = await _client
        .from('destinations')
        .select()
        .eq('is_active', true);
    final categories = preferences.categories.map(_databaseCategory).toSet();
    final candidates = rows
        .map(JourneyDestination.fromJson)
        .where((destination) {
          if (categories.isNotEmpty &&
              !categories.contains(destination.category)) {
            return false;
          }
          return _location.distanceBetween(
                location,
                destination.latitude,
                destination.longitude,
              ) <=
              preferences.radiusKm * 1000;
        })
        .toList(growable: false);
    if (candidates.isEmpty) {
      throw const JourneyDataException(
        'No active mystery destination matches these preferences and radius.',
      );
    }
    final history = await _completedDestinationHistory(userId);
    final visitedIds = history.map((visit) => visit.destinationId).toSet();
    final recentIds = <String>{};
    for (final visit in history) {
      recentIds.add(visit.destinationId);
      if (recentIds.length == 5) break;
    }
    final pool = mysteryDestinationSelectionPool(
      candidates,
      completedDestinationIds: visitedIds,
      recentDestinationIds: recentIds,
    );
    final destination = pool[_random.nextInt(pool.length)];
    return _DestinationSelection(
      destination: destination,
      isRevisit: visitedIds.contains(destination.id),
      previouslyUsedClueIds: history
          .where((visit) => visit.destinationId == destination.id)
          .map((visit) => visit.initialClueId)
          .whereType<String>()
          .toSet(),
    );
  }

  Future<List<_CompletedDestinationVisit>> _completedDestinationHistory(
    String userId,
  ) async {
    final participantRows = await _client
        .from('journey_participants')
        .select('journey_id, completed_at')
        .eq('user_id', userId)
        .eq('participant_status', 'completed')
        .order('completed_at', ascending: false);
    if (participantRows.isEmpty) return const <_CompletedDestinationVisit>[];
    final journeyIds = participantRows
        .map((row) => row['journey_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    if (journeyIds.isEmpty) return const <_CompletedDestinationVisit>[];
    final journeyRows = await _client
        .from('mystery_journeys')
        .select('id, destination_id, initial_clue_id')
        .inFilter('id', journeyIds);
    final journeysById = <String, Map<String, dynamic>>{
      for (final row in journeyRows)
        row['id'].toString(): Map<String, dynamic>.from(row),
    };
    return participantRows
        .map((participant) {
          final journey = journeysById[participant['journey_id']?.toString()];
          final destinationId = journey?['destination_id']?.toString();
          if (journey == null || destinationId == null) return null;
          return _CompletedDestinationVisit(
            destinationId: destinationId,
            initialClueId: journey['initial_clue_id']?.toString(),
            completedAt:
                DateTime.tryParse(
                  participant['completed_at']?.toString() ?? '',
                ) ??
                DateTime.fromMillisecondsSinceEpoch(0),
          );
        })
        .whereType<_CompletedDestinationVisit>()
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _initialClue(
    String destinationId, {
    Set<String> previouslyUsedClueIds = const <String>{},
  }) async {
    final rows = await _client
        .from('destination_clues')
        .select()
        .eq('destination_id', destinationId)
        .eq('clue_type', 'initial')
        .order('clue_order');
    if (rows.isEmpty) {
      throw const JourneyDataException(
        'This destination does not have an initial mystery clue.',
      );
    }
    final unusedRows = rows
        .where((row) => !previouslyUsedClueIds.contains(row['id'].toString()))
        .toList(growable: false);
    final pool = unusedRows.isNotEmpty ? unusedRows : rows;
    return Map<String, dynamic>.from(pool[_random.nextInt(pool.length)]);
  }

  Future<int> _additionalHintCount(String destinationId) async {
    final rows = await _client
        .from('destination_clues')
        .select('id')
        .eq('destination_id', destinationId)
        .eq('clue_type', 'additional');
    return rows.length;
  }

  Future<void> _saveJourneyCategories(
    String journeyId,
    Set<String> values,
  ) async {
    if (values.isEmpty) return;
    await _client
        .from('journey_preference_categories')
        .insert(
          values
              .map(
                (value) => <String, dynamic>{
                  'journey_id': journeyId,
                  'category': _databaseCategory(value),
                },
              )
              .toList(growable: false),
        );
  }

  @override
  Future<Journey> requestHint(Journey journey) async {
    final participantId = _participantId(journey);
    final clueRows = await _client
        .from('destination_clues')
        .select()
        .eq('destination_id', journey.destination!.id)
        .eq('clue_type', 'additional')
        .order('clue_order');
    final unlockRows = await _client
        .from('participant_hint_unlocks')
        .select()
        .eq('participant_id', participantId);
    final unlocked = unlockRows
        .map((row) => row['clue_id']?.toString())
        .whereType<String>()
        .toSet();
    Map<String, dynamic>? next;
    for (final row in clueRows) {
      if (!unlocked.contains(row['id'].toString())) {
        next = Map<String, dynamic>.from(row);
        break;
      }
    }
    if (next == null) {
      throw const JourneyDataException('All Mystery Hints have been unlocked.');
    }
    await _client.from('participant_hint_unlocks').insert(<String, dynamic>{
      'participant_id': participantId,
      'clue_id': next['id'],
    });
    final result = journey.copyWith(
      additionalHints: <String>[...journey.additionalHints, _clueText(next)],
    );
    _activeJourney = result;
    return result;
  }

  @override
  Future<Journey> revealRoute(Journey journey) async {
    final rows = await _client
        .from('mystery_journeys')
        .update(<String, dynamic>{'exact_route_revealed': true})
        .eq('id', journey.id)
        .eq('status', 'active')
        .select('id');
    if (rows.isEmpty) {
      throw const JourneyDataException('This journey is no longer active.');
    }
    final result = journey.copyWith(
      status: JourneyStatus.routeRevealed,
      exactRouteRevealed: true,
      locationHint: journey.destination?.address ?? journey.locationHint,
    );
    _activeJourney = result;
    return result;
  }

  @override
  Future<Journey> verifyArrival(
    Journey journey, {
    void Function(ArrivalVerificationUpdate update)? onProgress,
  }) async {
    final destination = journey.destination;
    if (destination == null) {
      throw const JourneyDataException('Journey destination is unavailable.');
    }
    final participantId = _participantId(journey);
    final dwellTracker = ArrivalDwellTracker(
      maximumAccuracyMeters: acceptedAccuracyMeters,
      arrivalRadiusMeters: arrivalRadiusMeters,
      requiredDwell: arrivalDwell,
    );
    DateTime? lastOutsideRecord;
    DateTime? poorAccuracySince;
    var verificationStarted = false;
    var interruptedByExit = false;
    await for (final reading in _location.watchLocation()) {
      final distance = _location.distanceBetween(
        reading,
        destination.latitude,
        destination.longitude,
      );
      _activeJourney = journey.copyWith(
        status: JourneyStatus.verifying,
        distanceMeters: distance,
      );
      final decision = dwellTracker.evaluate(
        accuracyMeters: reading.accuracy,
        distanceMeters: distance,
        at: reading.timestamp,
      );
      if (decision.progress == ArrivalProgress.poorAccuracy) {
        verificationStarted = false;
        interruptedByExit = false;
        onProgress?.call(
          ArrivalVerificationUpdate(
            state: ArrivalVerificationState.waitingForAccuracy,
            distanceMeters: distance,
            accuracyMeters: reading.accuracy,
          ),
        );
        poorAccuracySince ??= reading.timestamp;
        if (reading.timestamp.difference(poorAccuracySince) >=
            const Duration(seconds: 30)) {
          throw const JourneyDataException(
            'GPS accuracy is still above 30m. Move to an open area and retry.',
          );
        }
        continue;
      }
      poorAccuracySince = null;
      if (decision.progress == ArrivalProgress.outsideRadius) {
        if (verificationStarted) interruptedByExit = true;
        verificationStarted = false;
        onProgress?.call(
          ArrivalVerificationUpdate(
            state: interruptedByExit
                ? ArrivalVerificationState.interrupted
                : ArrivalVerificationState.outsideRange,
            distanceMeters: distance,
            accuracyMeters: reading.accuracy,
          ),
        );
        final now = DateTime.now();
        if (lastOutsideRecord == null ||
            now.difference(lastOutsideRecord) >= const Duration(seconds: 10)) {
          await _recordArrival(
            participantId,
            reading,
            distance,
            'not_within_range',
          );
          lastOutsideRecord = now;
        }
        continue;
      }
      if (decision.progress != ArrivalProgress.verified) {
        verificationStarted = true;
        interruptedByExit = false;
        onProgress?.call(
          ArrivalVerificationUpdate(
            state: ArrivalVerificationState.verifying,
            secondsRemaining: (decision.remaining.inMilliseconds / 1000).ceil(),
            distanceMeters: distance,
            accuracyMeters: reading.accuracy,
          ),
        );
        continue;
      }
      onProgress?.call(
        ArrivalVerificationUpdate(
          state: ArrivalVerificationState.verified,
          secondsRemaining: 0,
          distanceMeters: distance,
          accuracyMeters: reading.accuracy,
        ),
      );
      return _completeJourney(journey, reading, distance);
    }
    throw const JourneyDataException('Location monitoring ended unexpectedly.');
  }

  @override
  Future<ArrivalCheckResult> checkArrivalNow(Journey journey) async {
    final destination = journey.destination;
    if (destination == null || journey.id.startsWith('waiting:')) {
      throw const JourneyDataException(
        'Start the Mystery Journey before testing arrival.',
      );
    }
    final reading = await _location.getFreshLocation();
    return ArrivalCheckResult(
      distanceMeters: _location.distanceBetween(
        reading,
        destination.latitude,
        destination.longitude,
      ),
      accuracyMeters: reading.accuracy,
    );
  }

  Future<Journey> _completeJourney(
    Journey journey,
    LocationReading reading,
    double distance,
  ) async {
    if (_completingParticipant) return _activeJourney ?? journey;
    _completingParticipant = true;
    try {
      return _completeParticipant(
        journey,
        latitude: reading.latitude,
        longitude: reading.longitude,
        distanceMeters: distance,
      );
    } finally {
      _completingParticipant = false;
    }
  }

  @override
  Future<Journey> simulateArrival(
    Journey journey, {
    bool testExplorer = false,
  }) async {
    if (!kDebugMode) {
      throw const JourneyDataException(
        'Arrival simulation is only available in debug builds.',
      );
    }
    final destination = journey.destination;
    if (destination == null || journey.id.startsWith('waiting:')) {
      throw const JourneyDataException(
        'Start the Mystery Journey before simulating arrival.',
      );
    }
    if (testExplorer &&
        (journey.mode != JourneyMode.group || !journey.isHost)) {
      throw const JourneyDataException(
        'Only the Group Journey host can simulate Test Explorer arrival.',
      );
    }
    return _completeParticipant(
      journey,
      latitude: destination.latitude,
      longitude: destination.longitude,
      distanceMeters: 0,
      testExplorer: testExplorer,
    );
  }

  Future<Journey> _completeParticipant(
    Journey journey, {
    required double latitude,
    required double longitude,
    required double distanceMeters,
    bool testExplorer = false,
  }) async {
    await _client.rpc(
      'complete_journey_participant',
      params: <String, dynamic>{
        'p_journey_id': journey.id,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_distance_meters': distanceMeters,
        'p_simulate_test_explorer': testExplorer,
      },
    );
    if (testExplorer) {
      final members = journey.groupRoomId == null
          ? journey.members
          : await _loadGroupMembers(journey.groupRoomId!);
      final result = journey.copyWith(members: members);
      _activeJourney = result;
      return result;
    }
    final result = await _loadJourney(journey.id);
    _activeJourney = result.copyWith(distanceMeters: distanceMeters);
    return _activeJourney!;
  }

  Future<void> _recordArrival(
    String participantId,
    LocationReading reading,
    double distance,
    String status, {
    DateTime? verifiedAt,
  }) => _client.from('arrival_verifications').insert(<String, dynamic>{
    'participant_id': participantId,
    'latitude': reading.latitude,
    'longitude': reading.longitude,
    'distance_meters': distance,
    'verification_status': status,
    if (verifiedAt != null) 'verified_at': verifiedAt.toIso8601String(),
  });

  @override
  Future<void> cancelJourney() async {
    final journey = _activeJourney ?? await getActiveJourney();
    if (journey == null) return;
    if (journey.id.startsWith('waiting:') && journey.groupRoomId != null) {
      await _leaveGroupRoom(journey.groupRoomId!);
      _activeJourney = null;
      return;
    }
    if (journey.mode == JourneyMode.group && journey.groupRoomId != null) {
      await _leaveGroupRoom(journey.groupRoomId!);
      _activeJourney = null;
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('journey_participants')
        .update(<String, dynamic>{
          'participant_status': 'cancelled',
          'cancelled_at': now,
        })
        .eq('id', _participantId(journey))
        .eq('participant_status', 'active');
    if (journey.mode == JourneyMode.solo) {
      await _client
          .from('mystery_journeys')
          .update(<String, dynamic>{'status': 'cancelled'})
          .eq('id', journey.id)
          .eq('status', 'active');
    }
    _activeJourney = null;
  }

  @override
  Future<List<NearbyGroupRoom>> findNearbyGroupRooms({
    double radiusMeters = 1000,
  }) async {
    final userId = _supabase.requireCurrentUserId();
    if (kDebugMode) {
      debugPrint(
        'Nearby room scan: user=$userId radius=${radiusMeters.round()}m',
      );
    }
    late final LocationReading location;
    late final List<Map<String, dynamic>> rows;
    try {
      location = await _location.getFreshLocation();
      rows = await _waitingRoomRows(userId);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Nearby room scan failed before filtering: '
          '${error.runtimeType}: $error',
        );
      }
      rethrow;
    }
    if (kDebugMode) {
      debugPrint(
        'Nearby room scan location: lat=${location.latitude}, '
        'lng=${location.longitude}, accuracy=${location.accuracy}m; '
        'raw waiting rooms=${rows.length}',
      );
    }
    final nearbyRooms = <NearbyGroupRoom>[];
    var invalidCoordinates = 0;
    var expired = 0;
    var outsideRadius = 0;
    var alreadyMember = 0;
    var full = 0;
    for (final row in rows) {
      final latitude = _asDouble(row['host_latitude'], fallback: double.nan);
      final longitude = _asDouble(row['host_longitude'], fallback: double.nan);
      if (!latitude.isFinite || !longitude.isFinite) {
        invalidCoordinates++;
        continue;
      }
      final expiresAt = DateTime.tryParse(row['expires_at']?.toString() ?? '');
      if (expiresAt != null && !expiresAt.isAfter(DateTime.now().toUtc())) {
        expired++;
        continue;
      }
      final distance = _location.distanceBetween(location, latitude, longitude);
      final isDebugTestingRoom =
          kDebugMode && row['id'].toString() == defaultTestingRoomId;
      if (distance > radiusMeters && !isDebugTestingRoom) {
        outsideRadius++;
        continue;
      }
      final members = await _loadGroupMembers(row['id'].toString());
      if (members.any((member) => member.userId == userId)) {
        alreadyMember++;
        continue;
      }
      const capacity = 4;
      if (members.length >= capacity) {
        full++;
        continue;
      }
      final roomPreferences = _roomPreferences(row['preferences']);
      final labels = roomPreferences == null
          ? const <String>[]
          : <String>[
              if (roomPreferences.categories.isEmpty)
                'Surprise Me'
              else
                ...roomPreferences.categories.map(_displayCategory),
              'Within ${roomPreferences.radiusKm.round()} km',
            ];
      nearbyRooms.add(
        NearbyGroupRoom(
          id: row['id'].toString(),
          memberCount: members.length,
          capacity: capacity,
          distanceMeters: distance,
          preferenceLabels: labels,
        ),
      );
    }
    nearbyRooms.sort(
      (left, right) => left.distanceMeters.compareTo(right.distanceMeters),
    );
    if (kDebugMode) {
      debugPrint(
        'Nearby room scan result: visible=${nearbyRooms.length}, '
        'invalidCoordinates=$invalidCoordinates, expired=$expired, '
        'outsideRadius=$outsideRadius, alreadyMember=$alreadyMember, full=$full',
      );
    }
    return nearbyRooms;
  }

  Future<List<Map<String, dynamic>>> _waitingRoomRows(String userId) async {
    const baseFields =
        'id, host_user_id, status, host_latitude, host_longitude, expires_at';
    try {
      return await _client
          .from('group_rooms')
          .select('$baseFields, preferences')
          .eq('status', 'waiting')
          .neq('host_user_id', userId);
    } on PostgrestException catch (error) {
      if (error.code != '42703' && error.code != 'PGRST204') rethrow;
      return _client
          .from('group_rooms')
          .select(baseFields)
          .eq('status', 'waiting')
          .neq('host_user_id', userId);
    }
  }

  @override
  Future<Journey> createGroupRoom() async => _createGroupRoom();

  @override
  Future<void> saveGroupRoomPreferences(
    String roomId,
    TravelPreferences preferences,
  ) async {
    final userId = _supabase.requireCurrentUserId();
    final rows = await _client
        .from('group_rooms')
        .update(<String, dynamic>{
          'preference_mode': preferences.selectionMode,
          'preferences': <String, dynamic>{
            'selection_mode': preferences.selectionMode,
            'categories': preferences.categories
                .map(_databaseCategory)
                .toList(growable: false),
            'radius_km': preferences.radiusKm.round(),
          },
        })
        .eq('id', roomId)
        .eq('host_user_id', userId)
        .eq('status', 'waiting')
        .select('id');
    if (rows.isEmpty) {
      throw const JourneyDataException(
        'Only the host can set preferences for an open waiting room.',
      );
    }
  }

  @override
  Future<List<GroupChatMessage>> getGroupMessages(String roomId) async {
    final userId = _supabase.requireCurrentUserId();
    final rows = await _client
        .from('group_chat_messages')
        .select('id, user_id, message, created_at')
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .order('id', ascending: true)
        .limit(100);
    final userIds = rows
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .toSet();
    final senderNames = <String, String>{};
    if (userIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, username')
          .inFilter('id', userIds.toList(growable: false));
      for (final profile in profiles) {
        final profileId = profile['id']?.toString();
        final username = profile['username']?.toString().trim();
        if (profileId != null && username?.isNotEmpty == true) {
          senderNames[profileId] = username!;
        }
      }
    }
    return rows
        .map((row) {
          final senderId = row['user_id'].toString();
          return GroupChatMessage(
            id: row['id'].toString(),
            userId: senderId,
            senderName: senderNames[senderId] ?? _shortId(senderId),
            message: row['message']?.toString() ?? '',
            createdAt:
                DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
            isCurrentUser: senderId == userId,
          );
        })
        .toList(growable: false)
      ..sort((left, right) {
        final time = left.createdAt.compareTo(right.createdAt);
        return time != 0 ? time : left.id.compareTo(right.id);
      });
  }

  @override
  Future<List<GroupChatMessage>> sendGroupMessage(
    String roomId,
    String message,
  ) async {
    final value = message.trim();
    if (value.isEmpty) return getGroupMessages(roomId);
    if (value.length > 500) {
      throw const JourneyDataException(
        'Group chat messages must be 500 characters or fewer.',
      );
    }
    await _client.from('group_chat_messages').insert(<String, dynamic>{
      'room_id': roomId,
      'user_id': _supabase.requireCurrentUserId(),
      'message': value,
    });
    return getGroupMessages(roomId);
  }

  @override
  Future<GroupVoteOutcome> castGroupVote(
    Journey journey,
    GroupVoteType type, {
    bool simulateTestExplorer = false,
  }) async {
    if (journey.mode != JourneyMode.group || journey.groupRoomId == null) {
      throw const JourneyDataException(
        'Group voting is only available in an active Group Journey.',
      );
    }
    if (type == GroupVoteType.hint && !journey.hasHintsRemaining) {
      throw const JourneyDataException('All Mystery Hints have been unlocked.');
    }
    final response = await _client.rpc(
      'cast_group_action_vote',
      params: <String, dynamic>{
        'p_journey_id': journey.id,
        'p_vote_type': type.name,
        'p_vote_round': type == GroupVoteType.hint
            ? journey.additionalHints.length + 1
            : 1,
        'p_simulate_test_explorer': simulateTestExplorer,
      },
    );
    return _groupVoteOutcome(type, response);
  }

  @override
  Future<GroupVoteOutcome> getGroupVoteStatus(
    Journey journey,
    GroupVoteType type,
  ) async {
    if (journey.mode != JourneyMode.group || journey.groupRoomId == null) {
      throw const JourneyDataException(
        'Group voting is only available in an active Group Journey.',
      );
    }
    final response = await _client.rpc(
      'get_group_action_vote_status',
      params: <String, dynamic>{
        'p_journey_id': journey.id,
        'p_vote_type': type.name,
        'p_vote_round': type == GroupVoteType.hint
            ? journey.additionalHints.length + 1
            : 1,
      },
    );
    return _groupVoteOutcome(type, response);
  }

  GroupVoteOutcome _groupVoteOutcome(GroupVoteType type, dynamic response) {
    final value = Map<String, dynamic>.from(response as Map);
    return GroupVoteOutcome(
      type: type,
      yesVotes: _asInt(value['yes_votes']),
      requiredVotes: _asInt(value['required_votes']),
      memberCount: _asInt(value['member_count']),
      passed: value['passed'] == true,
      voteRound: _asInt(value['vote_round'], fallback: 1),
      currentUserVoted: value['current_user_voted'] == true,
      testExplorerVoted: value['test_explorer_voted'] == true,
      alreadyVoted: value['already_voted'] == true,
    );
  }

  @override
  Future<List<JourneyMember>> refreshGroupMembers(String roomId) =>
      _loadGroupMembers(roomId);

  @override
  Future<List<JourneyMember>> markGroupParticipantShaken(
    Journey journey,
  ) async {
    final roomId = journey.groupRoomId;
    if (journey.mode != JourneyMode.group ||
        roomId == null ||
        journey.id.startsWith('waiting:')) {
      throw StateError('An active shared group journey is required.');
    }
    final userId = _supabase.requireCurrentUserId();
    final updatedRows = await _client
        .from('journey_participants')
        .update(<String, dynamic>{
          'shaken_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('journey_id', journey.id)
        .eq('user_id', userId)
        .eq('participant_status', 'active')
        .isFilter('shaken_at', null)
        .select('id');
    if (updatedRows.isEmpty) {
      final participant = await _client
          .from('journey_participants')
          .select('shaken_at')
          .eq('journey_id', journey.id)
          .eq('user_id', userId)
          .maybeSingle();
      if (participant == null || participant['shaken_at'] == null) {
        throw const JourneyDataException(
          'Your shared journey participant could not be marked as shaken.',
        );
      }
    }
    return _loadGroupMembers(roomId);
  }

  @override
  Future<List<JourneyMember>> setGroupRoomReady(
    String roomId,
    bool isReady,
  ) async {
    _supabase.requireCurrentUserId();
    await _client.rpc(
      'set_group_room_ready',
      params: <String, dynamic>{'p_room_id': roomId, 'p_is_ready': isReady},
    );
    return _loadGroupMembers(roomId);
  }

  @override
  Future<List<JourneyMember>> addTestGroupMember(
    String roomId,
    String testUsername,
  ) async {
    final testUserId = await _client.rpc(
      'add_group_test_member',
      params: <String, dynamic>{
        'p_room_id': roomId,
        'p_test_username': testUsername.trim(),
      },
    );
    await _client
        .from('group_room_members')
        .update(<String, dynamic>{'is_ready': true})
        .eq('room_id', roomId)
        .eq('user_id', testUserId.toString())
        .neq('member_status', 'left');
    return _loadGroupMembers(roomId);
  }

  @override
  Future<Journey> joinGroupRoom(String roomId) => _joinGroupRoom(roomId);

  @override
  Future<void> leaveGroupRoom(String roomId) => _leaveGroupRoom(roomId);

  @override
  Future<void> expireGroupJourneyIfNeeded(Journey journey) =>
      _expireGroupJourneyIfNeeded(journey);

  Future<Journey> _createGroupRoom() async {
    final userId = _supabase.requireCurrentUserId();
    if (kDebugMode) {
      debugPrint(
        'Create group room: user=$userId preferenceMode=saved_preferences',
      );
    }
    if (await getActiveJourney() != null) {
      throw const JourneyDataException(
        'Resume or leave your current journey room first.',
      );
    }
    late final LocationReading location;
    late final Map<String, dynamic> room;
    try {
      location = await _location.getFreshLocation();
      if (kDebugMode) {
        debugPrint(
          'Create group room location: lat=${location.latitude}, '
          'lng=${location.longitude}, accuracy=${location.accuracy}m',
        );
      }
      room = await _client
          .from('group_rooms')
          .insert(<String, dynamic>{
            'host_user_id': userId,
            'status': 'waiting',
            'preference_mode': 'saved_preferences',
            'host_latitude': location.latitude,
            'host_longitude': location.longitude,
          })
          .select()
          .single();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Create group room failed: ${error.runtimeType}: $error');
      }
      rethrow;
    }
    final roomId = room['id'].toString();
    if (kDebugMode) debugPrint('Create group room result: room=$roomId');
    try {
      await _client.from('group_room_members').insert(<String, dynamic>{
        'room_id': roomId,
        'user_id': userId,
        'role': 'host',
        'member_status': 'waiting',
        'is_ready': false,
      });
    } catch (_) {
      await _client.from('group_rooms').delete().eq('id', roomId);
      rethrow;
    }
    final result = Journey(
      id: 'waiting:$roomId',
      status: JourneyStatus.idle,
      mode: JourneyMode.group,
      clue: '',
      locationHint: 'Waiting room',
      distanceMeters: 0,
      groupRoomId: roomId,
      preferences:
          _roomPreferences(room['preferences']) ?? const TravelPreferences(),
      groupPreferencesSet: _roomPreferences(room['preferences']) != null,
      members: await _loadGroupMembers(roomId),
      isHost: true,
    );
    _activeJourney = result;
    return result;
  }

  Future<List<JourneyMember>> _loadGroupMembers(String roomId) async {
    final room = await _client
        .from('group_rooms')
        .select('journey_id')
        .eq('id', roomId)
        .maybeSingle();
    final journeyId = room?['journey_id']?.toString();
    final participantStatuses = <String, String>{};
    final participantShakeTimes = <String, DateTime>{};
    if (journeyId != null && journeyId.isNotEmpty) {
      final participants = await _client
          .from('journey_participants')
          .select('user_id, participant_status, shaken_at')
          .eq('journey_id', journeyId);
      for (final participant in participants) {
        final participantUserId = participant['user_id'].toString();
        participantStatuses[participantUserId] =
            participant['participant_status']?.toString() ?? 'active';
        final shakenAt = DateTime.tryParse(
          participant['shaken_at']?.toString() ?? '',
        );
        if (shakenAt != null) {
          participantShakeTimes[participantUserId] = shakenAt;
        }
      }
    }
    final rows = await _client
        .from('group_room_members')
        .select()
        .eq('room_id', roomId)
        .neq('member_status', 'left');
    final members = <JourneyMember>[];
    for (final row in rows) {
      final memberUserId = row['user_id'].toString();
      final profile = await _client
          .from('profiles')
          .select('username, full_name, avatar_url')
          .eq('id', memberUserId)
          .maybeSingle();
      final fullName = profile?['full_name']?.toString().trim();
      final username = profile?['username']?.toString().trim();
      members.add(
        JourneyMember(
          userId: memberUserId,
          displayName: username?.isNotEmpty == true
              ? username!
              : fullName?.isNotEmpty == true
              ? fullName!
              : _shortId(memberUserId),
          role: row['role']?.toString() ?? 'member',
          status: row['member_status']?.toString() ?? 'waiting',
          participantStatus: participantStatuses[memberUserId],
          shakenAt: participantShakeTimes[memberUserId],
          avatarUrl: profile?['avatar_url']?.toString(),
          isReady: row['is_ready'] == true,
        ),
      );
    }
    return members;
  }

  Future<Journey> _joinGroupRoom(String roomId) async {
    final userId = _supabase.requireCurrentUserId();
    final room = await _client
        .from('group_rooms')
        .select()
        .eq('id', roomId)
        .single();
    final existingMembership = await _client
        .from('group_room_members')
        .select()
        .eq('room_id', roomId)
        .eq('user_id', userId)
        .maybeSingle();
    final existingStatus = existingMembership?['member_status']?.toString();
    final journeyId = room['journey_id']?.toString();
    if (room['status'] == 'active' &&
        journeyId != null &&
        existingMembership != null &&
        existingStatus != 'left') {
      final participant = await _client
          .from('journey_participants')
          .select()
          .eq('journey_id', journeyId)
          .eq('user_id', userId)
          .maybeSingle();
      if (participant != null &&
          participant['participant_status']?.toString() != 'cancelled') {
        final resumed = await _loadJourney(
          journeyId,
          participant: Map<String, dynamic>.from(participant),
        );
        await expireGroupJourneyIfNeeded(resumed);
        _activeJourney = resumed;
        return resumed;
      }
    }
    if (room['status'] != 'waiting' || room['journey_id'] != null) {
      throw const JourneyDataException(
        'This room has started or is no longer available.',
      );
    }
    final expiresAt = DateTime.tryParse(room['expires_at']?.toString() ?? '');
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const JourneyDataException('This waiting room has expired.');
    }
    if (existingMembership != null && existingStatus != 'left') {
      final resumed = await _waitingJourneyFromRoom(room, userId);
      _activeJourney = resumed;
      return resumed;
    }
    if (await getActiveJourney() != null) {
      throw const JourneyDataException(
        'Resume or leave your current journey room first.',
      );
    }
    final members = await _loadGroupMembers(roomId);
    if (members.length >= 4) {
      throw const JourneyDataException('This nearby room is already full.');
    }
    final hostLatitude = _asDouble(room['host_latitude'], fallback: double.nan);
    final hostLongitude = _asDouble(
      room['host_longitude'],
      fallback: double.nan,
    );
    if (!hostLatitude.isFinite || !hostLongitude.isFinite) {
      throw const JourneyDataException(
        'This room does not have a valid nearby location.',
      );
    }
    final location = await _location.getFreshLocation();
    final distance = _location.distanceBetween(
      location,
      hostLatitude,
      hostLongitude,
    );
    final isDebugTestingRoom = kDebugMode && roomId == defaultTestingRoomId;
    if (distance > 1000 && !isDebugTestingRoom) {
      throw const JourneyDataException(
        'This room is no longer within the 1 km nearby area.',
      );
    }
    if (existingMembership == null) {
      await _client.from('group_room_members').insert(<String, dynamic>{
        'room_id': roomId,
        'user_id': userId,
        'role': 'member',
        'member_status': 'waiting',
        'is_ready': false,
      });
    } else {
      await _client
          .from('group_room_members')
          .update(<String, dynamic>{
            'role': 'member',
            'member_status': 'waiting',
            'is_ready': false,
            'left_at': null,
            'joined_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', existingMembership['id'])
          .eq('user_id', userId)
          .eq('member_status', 'left');
    }
    final result = await _waitingJourneyFromRoom(room, userId);
    _activeJourney = result;
    return result;
  }

  Future<Journey> _waitingJourneyFromRoom(
    Map<String, dynamic> room,
    String userId,
  ) async {
    final roomId = room['id'].toString();
    return Journey(
      id: 'waiting:$roomId',
      status: JourneyStatus.idle,
      mode: JourneyMode.group,
      clue: '',
      locationHint: 'Waiting room',
      distanceMeters: 0,
      groupRoomId: roomId,
      preferences:
          _roomPreferences(room['preferences']) ?? const TravelPreferences(),
      groupPreferencesSet: _roomPreferences(room['preferences']) != null,
      members: await _loadGroupMembers(roomId),
      isHost: room['host_user_id'].toString() == userId,
    );
  }

  Future<Journey> _startSharedGroupJourney(
    TravelPreferences preferences,
  ) async {
    final current = _activeJourney;
    final roomId = current?.groupRoomId;
    if (roomId == null) {
      throw const JourneyDataException('Create or join a group room first.');
    }
    final userId = _supabase.requireCurrentUserId();
    final room = await _client
        .from('group_rooms')
        .select()
        .eq('id', roomId)
        .single();
    if (room['status'] != 'waiting' ||
        room['host_user_id'].toString() != userId) {
      throw const JourneyDataException(
        'Only the host of a waiting room can discover the destination.',
      );
    }
    final members = await _loadGroupMembers(roomId);
    if (members.length < 2) {
      throw const JourneyDataException(
        'At least two travellers are required to start.',
      );
    }
    if (members.any((member) => !member.isReady)) {
      throw const JourneyDataException(
        'Everyone must be ready before starting.',
      );
    }
    final location = await _location.getFreshLocation();
    final selection = await _selectDestination(
      preferences,
      location,
      userId: userId,
    );
    final destination = selection.destination;
    final clue = await _initialClue(
      destination.id,
      previouslyUsedClueIds: selection.previouslyUsedClueIds,
    );
    final totalHintCount = await _additionalHintCount(destination.id);
    final activatedAt = DateTime.now().toUtc();
    final deadline = activatedAt.add(const Duration(hours: 24));
    final waitingRoomExpiresAt = room['expires_at']?.toString();
    String? journeyId;
    var roomActivated = false;
    try {
      final row = await _client
          .from('mystery_journeys')
          .insert(<String, dynamic>{
            'mode': 'group',
            'destination_id': destination.id,
            'initial_clue_id': clue['id'],
            'selection_mode': preferences.selectionMode,
            'discovery_radius_km': preferences.radiusKm.round(),
            'status': 'active',
            'exact_route_revealed': false,
          })
          .select()
          .single();
      journeyId = row['id'].toString();
      await _client.rpc(
        'activate_group_room',
        params: <String, dynamic>{
          'p_room_id': roomId,
          'p_journey_id': journeyId,
          'p_activated_at': activatedAt.toIso8601String(),
          'p_expires_at': deadline.toIso8601String(),
        },
      );
      roomActivated = true;
      await _client
          .from('journey_participants')
          .insert(
            members
                .map(
                  (member) => <String, dynamic>{
                    'journey_id': journeyId,
                    'user_id': member.userId,
                    'participant_status': 'active',
                  },
                )
                .toList(growable: false),
          );
      await _saveJourneyCategories(journeyId, preferences.categories);
      final ownParticipant = await _client
          .from('journey_participants')
          .select('id, user_id')
          .eq('journey_id', journeyId)
          .eq('user_id', userId)
          .single();
      final result = Journey(
        id: journeyId,
        participantId: ownParticipant['id'].toString(),
        status: JourneyStatus.active,
        mode: JourneyMode.group,
        clue: _clueText(clue),
        locationHint: 'Shared mystery area',
        distanceMeters: _location.distanceBetween(
          location,
          destination.latitude,
          destination.longitude,
        ),
        destination: destination,
        preferences: preferences,
        totalHintCount: totalHintCount,
        groupRoomId: roomId,
        groupDeadline: deadline.toLocal(),
        members: members,
        isHost: true,
        isRevisit: selection.isRevisit,
      );
      _activeJourney = result;
      return result;
    } catch (_) {
      if (journeyId != null) {
        await _client
            .from('journey_participants')
            .delete()
            .eq('journey_id', journeyId);
        if (roomActivated) {
          await _client
              .from('group_rooms')
              .update(<String, dynamic>{
                'journey_id': null,
                'status': 'waiting',
                'activated_at': null,
                'expires_at': waitingRoomExpiresAt,
              })
              .eq('id', roomId)
              .eq('host_user_id', userId)
              .eq('journey_id', journeyId);
          await _client
              .from('group_room_members')
              .update(<String, dynamic>{
                'member_status': 'waiting',
                'is_ready': false,
              })
              .eq('room_id', roomId)
              .eq('member_status', 'active');
        }
        await _client.from('mystery_journeys').delete().eq('id', journeyId);
      }
      rethrow;
    }
  }

  Future<void> _leaveGroupRoom(String roomId) async {
    _supabase.requireCurrentUserId();
    await _client.rpc(
      'leave_group_room',
      params: <String, dynamic>{'p_room_id': roomId},
    );
    _activeJourney = null;
  }

  Future<void> _expireGroupJourneyIfNeeded(Journey journey) async {
    final deadline = journey.groupDeadline;
    if (journey.mode != JourneyMode.group ||
        deadline == null ||
        deadline.isAfter(DateTime.now())) {
      return;
    }
    if (journey.groupRoomId != null) {
      await _client.rpc(
        'expire_group_room',
        params: <String, dynamic>{'p_room_id': journey.groupRoomId},
      );
    }
  }

  Future<Journey?> _loadWaitingGroupRoom(String userId) async {
    final memberships = await _client
        .from('group_room_members')
        .select()
        .eq('user_id', userId)
        .neq('member_status', 'left');
    for (final membership in memberships) {
      final roomId = membership['room_id'].toString();
      final room = await _client
          .from('group_rooms')
          .select()
          .eq('id', roomId)
          .maybeSingle();
      if (room == null ||
          room['status'] != 'waiting' ||
          room['journey_id'] != null) {
        continue;
      }
      final expiresAt = DateTime.tryParse(room['expires_at']?.toString() ?? '');
      if (expiresAt != null && !expiresAt.isAfter(DateTime.now().toUtc())) {
        await _client.rpc(
          'expire_group_room',
          params: <String, dynamic>{'p_room_id': roomId},
        );
        continue;
      }
      return Journey(
        id: 'waiting:$roomId',
        status: JourneyStatus.idle,
        mode: JourneyMode.group,
        clue: '',
        locationHint: 'Waiting room',
        distanceMeters: 0,
        groupRoomId: roomId,
        preferences:
            _roomPreferences(room['preferences']) ?? const TravelPreferences(),
        groupPreferencesSet: _roomPreferences(room['preferences']) != null,
        members: await _loadGroupMembers(roomId),
        isHost: room['host_user_id'].toString() == userId,
      );
    }
    return null;
  }

  Future<Journey?> _loadActiveGroupRoomForParticipant(String userId) async {
    final memberships = await _client
        .from('group_room_members')
        .select('room_id')
        .eq('user_id', userId)
        .neq('member_status', 'left');
    for (final membership in memberships) {
      final room = await _client
          .from('group_rooms')
          .select('journey_id')
          .eq('id', membership['room_id'])
          .eq('status', 'active')
          .maybeSingle();
      final journeyId = room?['journey_id']?.toString();
      if (journeyId == null || journeyId.isEmpty) continue;
      final participant = await _client
          .from('journey_participants')
          .select()
          .eq('journey_id', journeyId)
          .eq('user_id', userId)
          .neq('participant_status', 'cancelled')
          .maybeSingle();
      if (participant != null) {
        return _loadJourney(
          journeyId,
          participant: Map<String, dynamic>.from(participant),
        );
      }
    }
    return null;
  }

  Future<Journey> _loadJourney(
    String journeyId, {
    Map<String, dynamic>? participant,
  }) async {
    final userId = _supabase.requireCurrentUserId();
    participant ??= await _client
        .from('journey_participants')
        .select()
        .eq('journey_id', journeyId)
        .eq('user_id', userId)
        .single();
    final row = await _client
        .from('mystery_journeys')
        .select()
        .eq('id', journeyId)
        .single();
    final destinationRow = await _client
        .from('destinations')
        .select()
        .eq('id', row['destination_id'])
        .single();
    final clueRow = await _client
        .from('destination_clues')
        .select()
        .eq('id', row['initial_clue_id'])
        .single();
    final additionalClueRows = await _client
        .from('destination_clues')
        .select('id')
        .eq('destination_id', row['destination_id'])
        .eq('clue_type', 'additional');
    final categoryRows = await _client
        .from('journey_preference_categories')
        .select()
        .eq('journey_id', journeyId);
    final unlockRows = await _client
        .from('participant_hint_unlocks')
        .select()
        .eq('participant_id', participant['id']);
    final hints = <String>[];
    for (final unlock in unlockRows) {
      final clueId = unlock['clue_id'];
      if (clueId == null) continue;
      final hint = await _client
          .from('destination_clues')
          .select()
          .eq('id', clueId)
          .maybeSingle();
      if (hint != null) hints.add(_clueText(hint));
    }
    final mode = row['mode'] == 'group' ? JourneyMode.group : JourneyMode.solo;
    String? roomId;
    DateTime? deadline;
    var isHost = false;
    var members = const <JourneyMember>[];
    if (mode == JourneyMode.group) {
      final room = await _client
          .from('group_rooms')
          .select()
          .eq('journey_id', journeyId)
          .maybeSingle();
      if (room != null) {
        roomId = room['id'].toString();
        isHost = room['host_user_id'].toString() == userId;
        deadline = DateTime.tryParse(
          room['expires_at']?.toString() ?? '',
        )?.toLocal();
        members = await _loadGroupMembers(roomId);
      }
    }
    final participantStatus = participant['participant_status']?.toString();
    final exact = row['exact_route_revealed'] == true;
    final sharedJourneyCompleted = row['status']?.toString() == 'completed';
    final status = mode == JourneyMode.group
        ? sharedJourneyCompleted
              ? JourneyStatus.completed
              : exact
              ? JourneyStatus.routeRevealed
              : JourneyStatus.active
        : participantStatus == 'completed'
        ? JourneyStatus.completed
        : participantStatus == 'cancelled'
        ? JourneyStatus.cancelled
        : exact
        ? JourneyStatus.routeRevealed
        : JourneyStatus.active;
    final destination = JourneyDestination.fromJson(destinationRow);
    final startedAt =
        DateTime.tryParse(row['started_at']?.toString() ?? '') ??
        DateTime.now();
    final isRevisit = (await _completedDestinationHistory(userId)).any(
      (visit) =>
          visit.destinationId == destination.id &&
          visit.completedAt.isBefore(startedAt),
    );
    return Journey(
      id: journeyId,
      participantId: participant['id'].toString(),
      status: status,
      mode: mode,
      clue: _clueText(clueRow),
      locationHint: exact ? destination.address : 'Mystery area',
      distanceMeters: 0,
      destination: destination,
      preferences: TravelPreferences(
        categories: categoryRows
            .map((value) => value['category'].toString())
            .toSet(),
        radiusKm: _asDouble(row['discovery_radius_km'], fallback: 5),
        useSavedPreferences: row['selection_mode'] == 'saved_preferences',
      ),
      additionalHints: hints,
      totalHintCount: additionalClueRows.length,
      exactRouteRevealed: exact,
      groupRoomId: roomId,
      groupDeadline: deadline,
      members: members,
      isHost: isHost,
      isRevisit: isRevisit,
      completedAt: DateTime.tryParse(
        participant['completed_at']?.toString() ?? '',
      ),
    );
  }

  String _participantId(Journey journey) {
    final value = journey.participantId;
    if (value == null) {
      throw const JourneyDataException('Journey participant is unavailable.');
    }
    return value;
  }

  static int _asInt(dynamic value, {int fallback = 0}) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
  static double _asDouble(dynamic value, {double fallback = 0}) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
  static String _clueText(Map<String, dynamic> row) =>
      (row['clue_text'] ?? row['clue'] ?? row['content'] ?? '').toString();
  static TravelPreferences? _roomPreferences(dynamic value) {
    if (value is! Map || value.isEmpty) return null;
    final categories = value['categories'];
    return TravelPreferences(
      categories: categories is List
          ? categories.map((item) => item.toString()).toSet()
          : const <String>{},
      radiusKm: _asDouble(value['radius_km'], fallback: 5),
      useSavedPreferences: value['selection_mode'] == 'saved_preferences',
    );
  }

  static String _displayCategory(String value) => switch (value) {
    'culture' => 'Culture',
    'history' => 'History',
    'local_food' => 'Local food',
    'art_streets' => 'Art & streets',
    _ => value,
  };

  static String _databaseCategory(String value) => switch (value) {
    'Culture & Heritage' || 'Culture' || 'culture' => 'culture',
    'Historical Monuments' || 'History' || 'history' => 'history',
    'Food & Night Markets' || 'Local food' || 'local_food' => 'local_food',
    'Street Art & Architecture' ||
    'Art & streets' ||
    'art_streets' => 'art_streets',
    _ => value,
  };
  static String _shortId(String value) =>
      value.length <= 8 ? value : 'Traveller ${value.substring(0, 6)}';

  @override
  Future<void> dispose() => _sensorService.dispose();
}

@visibleForTesting
List<JourneyDestination> mysteryDestinationSelectionPool(
  List<JourneyDestination> candidates, {
  required Set<String> completedDestinationIds,
  required Set<String> recentDestinationIds,
}) {
  final unvisited = candidates
      .where((destination) => !completedDestinationIds.contains(destination.id))
      .toList(growable: false);
  if (unvisited.isNotEmpty) return unvisited;
  final olderVisits = candidates
      .where(
        (destination) =>
            completedDestinationIds.contains(destination.id) &&
            !recentDestinationIds.contains(destination.id),
      )
      .toList(growable: false);
  return olderVisits.isNotEmpty ? olderVisits : candidates;
}

class _DestinationSelection {
  const _DestinationSelection({
    required this.destination,
    required this.isRevisit,
    required this.previouslyUsedClueIds,
  });

  final JourneyDestination destination;
  final bool isRevisit;
  final Set<String> previouslyUsedClueIds;
}

class _CompletedDestinationVisit {
  const _CompletedDestinationVisit({
    required this.destinationId,
    required this.initialClueId,
    required this.completedAt,
  });

  final String destinationId;
  final String? initialClueId;
  final DateTime completedAt;
}
