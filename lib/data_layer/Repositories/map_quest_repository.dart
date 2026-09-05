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
