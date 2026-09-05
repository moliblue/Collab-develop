import 'dart:math' as math;
import 'dart:typed_data';

import '../Models/app_models.dart';
import '../Service Managers/Remote Services/supabase_service.dart';

class MapQuestAuthenticationException implements Exception {
  const MapQuestAuthenticationException();
}

class MapQuestPhotoUploadException implements Exception {
  const MapQuestPhotoUploadException();
}

class MapQuestSubmissionException implements Exception {
  const MapQuestSubmissionException();
}

enum PictureQuestCompletionStatus { completed, alreadyCompleted }

class PictureQuestCompletionResult {
  const PictureQuestCompletionResult({
    required this.status,
    required this.xpAwarded,
  });

  final PictureQuestCompletionStatus status;
  final int xpAwarded;
}

class MapQuestRepository {
  MapQuestRepository({SupabaseService? service})
    : _service = service ?? SupabaseService();

  final SupabaseService _service;
  final math.Random _random = math.Random.secure();

  bool get hasAuthenticatedUser => _service.currentUser != null;

  Future<List<MysteryMapCompletion>> getCompletedMysteries() async {
    final user = _service.currentUser;
    if (user == null) return const <MysteryMapCompletion>[];
    final stampRows = await _service.client
        .from('user_passport_stamps')
        .select(
          'destination_id, earned_at, destinations!inner('
          'id, name, category, latitude, longitude, address, description, image_url)',
        )
        .eq('user_id', user.id)
        .order('earned_at', ascending: false);
    if (stampRows.isEmpty) return const <MysteryMapCompletion>[];

    final completionCounts = <String, int>{};
    final lastCompletedAt = <String, DateTime>{};
    try {
      final participantRows = await _service.client
          .from('journey_participants')
          .select('journey_id, completed_at')
          .eq('user_id', user.id)
          .eq('participant_status', 'completed');
      final journeyIds = participantRows
          .map((row) => row['journey_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList(growable: false);
      if (journeyIds.isNotEmpty) {
        final journeyRows = await _service.client
            .from('mystery_journeys')
            .select('id, destination_id')
            .inFilter('id', journeyIds);
        final destinationByJourney = <String, String>{
          for (final row in journeyRows)
            row['id'].toString(): row['destination_id'].toString(),
        };
        for (final participant in participantRows) {
          final destinationId =
              destinationByJourney[participant['journey_id']?.toString()];
          if (destinationId == null) continue;
          completionCounts.update(
            destinationId,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
          final completedAt = DateTime.tryParse(
            participant['completed_at']?.toString() ?? '',
          );
          if (completedAt != null &&
              (lastCompletedAt[destinationId] == null ||
                  completedAt.isAfter(lastCompletedAt[destinationId]!))) {
            lastCompletedAt[destinationId] = completedAt;
          }
        }
      }
    } catch (_) {
      // Passport stamps remain the authoritative, user-scoped fallback.
    }

    return stampRows
        .map((row) {
          final destination = Map<String, dynamic>.from(
            row['destinations'] as Map,
          );
          final destinationId = row['destination_id'].toString();
          final earnedAt = DateTime.parse(
            row['earned_at'].toString(),
          ).toLocal();
          return MysteryMapCompletion(
            place: HeritagePlace(
              id: destinationId,
              name: destination['name']?.toString() ?? 'Mystery destination',
              category: destination['category']?.toString() ?? '',
              state: '',
              shortDescription: destination['description']?.toString() ?? '',
              description: destination['description']?.toString() ?? '',
              image: destination['image_url']?.toString().trim() ?? '',
              distanceKm: 0,
              rating: 0,
              reviewsCount: 0,
              latitude: (destination['latitude'] as num).toDouble(),
              longitude: (destination['longitude'] as num).toDouble(),
              address: destination['address']?.toString() ?? '',
              hours: '',
            ),
            completedAt: lastCompletedAt[destinationId]?.toLocal() ?? earnedAt,
            completionCount: completionCounts[destinationId] ?? 1,
            passportStampCollected: true,
          );
        })
        .toList(growable: false);
  }

  Future<bool> hasCurrentUserCompletedByOsmId(String osmId) async {
    final user = _service.currentUser;
    if (user == null) throw const MapQuestAuthenticationException();
    final row = await _service.getQuestCompletionByOsmId(
      userId: user.id,
      osmId: osmId,
    );
    return row != null;
  }

  Future<PictureQuestCompletionResult> submitPictureQuest({
    required HeritagePlace place,
    required Uint8List photoBytes,
    required String extension,
    required String? caption,
  }) async {
    final user = _service.currentUser;
    if (user == null) throw const MapQuestAuthenticationException();
    final osmId = place.osmId;
    if (osmId == null ||
        !RegExp(r'^(node|way|relation)/[0-9]+$').hasMatch(osmId)) {
      throw const MapQuestSubmissionException();
    }

    final normalizedExtension = extension.toLowerCase();
    final contentType = switch (normalizedExtension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw const MapQuestPhotoUploadException(),
    };
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = _random
        .nextInt(0x100000000)
        .toRadixString(16)
        .padLeft(8, '0');
    final safeOsmId = osmId.replaceAll('/', '_');
    final photoPath =
        '${user.id}/quest_${safeOsmId}_${timestamp}_$randomSuffix.$normalizedExtension';

    try {
      await _service.uploadQuestPhoto(
        path: photoPath,
        bytes: photoBytes,
        contentType: contentType,
      );
    } catch (_) {
      throw const MapQuestPhotoUploadException();
    }

    try {
      final response = await _service.completePictureQuest(
        osmId: osmId,
        locationName: place.name,
        latitude: place.latitude,
        longitude: place.longitude,
        photoPath: photoPath,
        caption: caption,
      );
      final status = response['status'];
      final xpAwarded = (response['xp_awarded'] as num?)?.toInt() ?? 0;
      if (status == 'completed') {
        return PictureQuestCompletionResult(
          status: PictureQuestCompletionStatus.completed,
          xpAwarded: xpAwarded,
        );
      }
      if (status == 'already_completed') {
        await _removePhotoQuietly(photoPath);
        return const PictureQuestCompletionResult(
          status: PictureQuestCompletionStatus.alreadyCompleted,
          xpAwarded: 0,
        );
      }
      await _removeIfConfirmedUnassociated(
        userId: user.id,
        osmId: osmId,
        photoPath: photoPath,
      );
      throw const MapQuestSubmissionException();
    } on MapQuestSubmissionException {
      rethrow;
    } catch (_) {
      await _removeIfConfirmedUnassociated(
        userId: user.id,
        osmId: osmId,
        photoPath: photoPath,
      );
      throw const MapQuestSubmissionException();
    }
  }

  Future<void> _removeIfConfirmedUnassociated({
    required String userId,
    required String osmId,
    required String photoPath,
  }) async {
    try {
      final completion = await _service.getQuestCompletionByOsmId(
        userId: userId,
        osmId: osmId,
      );
      if (completion == null || completion['photo_path'] != photoPath) {
        await _removePhotoQuietly(photoPath);
      }
    } catch (_) {
      // Keep the photo when association status cannot be confirmed.
    }
  }

  Future<void> _removePhotoQuietly(String photoPath) async {
    try {
      await _service.removeQuestPhoto(photoPath);
    } catch (_) {
      // Orphan cleanup must not replace the primary submission result.
    }
  }
}
