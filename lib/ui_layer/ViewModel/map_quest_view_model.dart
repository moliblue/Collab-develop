import 'package:flutter/foundation.dart';

import '../../data_layer/Models/app_models.dart';
import '../../data_layer/Repositories/map_quest_repository.dart';
import '../../data_layer/Service Managers/Remote Services/heritage_catalog_service.dart';

enum QuestJoinStatus {
  ready,
  unavailable,
  alreadyCompleted,
  authenticationRequired,
  failed,
  busy,
}

class QuestJoinResult {
  const QuestJoinResult(this.status);

  final QuestJoinStatus status;
}

enum QuestSubmissionStatus {
  completed,
  alreadyCompleted,
  uploadFailed,
  authenticationRequired,
  failed,
  busy,
}

class QuestSubmissionResult {
  const QuestSubmissionResult(this.status, {this.xpAwarded = 0});

  final QuestSubmissionStatus status;
  final int xpAwarded;
}

class MapQuestViewModel extends ChangeNotifier {
  MapQuestViewModel({
    HeritageCatalogService? heritageService,
    MapQuestRepository? questRepository,
  }) : _heritageService = heritageService ?? HeritageCatalogService(),
       _questRepository = questRepository ?? MapQuestRepository();

  static const double defaultSearchRadiusKm = 5;
  static const int maximumDatasetRadiusMeters = 10000;
  static const String pictureQuestInstructions =
      'Upload a photo of this heritage location.';
  static const int pictureQuestXp = 100;
  static const List<double> radiusOptionsKm = <double>[0.5, 1, 2, 5, 10];
  final HeritageCatalogService _heritageService;
  final MapQuestRepository _questRepository;
  String _query = '';
  String _category = 'All';
  double _radius = defaultSearchRadiusKm;
  List<HeritagePlace> _nearbyPlaces = <HeritagePlace>[];
  bool _heritageLoading = false;
  bool _heritageLoadAttempted = false;
  String? _heritageIssue;
  HeritagePlace? _selected;
  HeritagePlace? _directionTarget;
  List<ActivityItem> _routeStops = <ActivityItem>[];
  final Set<String> _completedQuests = <String>{};
  bool _gpsNearby = false;
  bool _questLoading = false;
  bool _questSubmitting = false;

  String get query => _query;
  String get category => _category;
  double get radius => _radius;
  int get radiusOptionIndex => radiusOptionsKm.indexOf(_radius);
  List<HeritagePlace> get nearbyPlaces =>
      List<HeritagePlace>.unmodifiable(_nearbyPlaces);
  bool get heritageLoading => _heritageLoading;
  bool get heritageLoadAttempted => _heritageLoadAttempted;
  String? get heritageIssue => _heritageIssue;
  HeritagePlace? get selected => _selected;
  HeritagePlace? get directionTarget => _directionTarget;
  List<ActivityItem> get routeStops =>
      List<ActivityItem>.unmodifiable(_routeStops);
  bool isCompleted(String id) => _completedQuests.contains(id);
  bool get gpsNearby => _gpsNearby;
  bool get questLoading => _questLoading;
  bool get questSubmitting => _questSubmitting;

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setCategory(String value) {
    _category = value;
    notifyListeners();
  }

  void setRadius(double value) {
    _radius = radiusOptionsKm.reduce(
      (double current, double option) =>
          (option - value).abs() < (current - value).abs() ? option : current,
    );
    notifyListeners();
  }

  void setRadiusOption(double index) {
    _radius =
        radiusOptionsKm[index.round().clamp(0, radiusOptionsKm.length - 1)];
    notifyListeners();
  }

  Future<void> loadNearbyHeritage({
    required double latitude,
    required double longitude,
  }) async {
    if (_heritageLoading || _heritageLoadAttempted) return;
    _heritageLoadAttempted = true;
    await _fetchNearbyHeritage(latitude: latitude, longitude: longitude);
  }

  Future<void> retryNearbyHeritage({
    required double latitude,
    required double longitude,
  }) async {
    if (_heritageLoading) return;
    _heritageLoadAttempted = true;
    await _fetchNearbyHeritage(
      latitude: latitude,
      longitude: longitude,
      preserveIssueWhileLoading: true,
    );
  }

  Future<void> _fetchNearbyHeritage({
    required double latitude,
    required double longitude,
    bool preserveIssueWhileLoading = false,
  }) async {
    _heritageLoading = true;
    if (!preserveIssueWhileLoading) _heritageIssue = null;
    notifyListeners();
    try {
      _nearbyPlaces = await _heritageService.fetchNearbyHeritage(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: maximumDatasetRadiusMeters,
      );
      _heritageIssue = null;
    } catch (_) {
      _heritageIssue =
          'Heritage location data is currently unavailable. Please try again later.';
    } finally {
      _heritageLoading = false;
      notifyListeners();
    }
  }

  void select(HeritagePlace? value) {
    _selected = value;
    notifyListeners();
  }

  void showDirections(HeritagePlace value) {
    _directionTarget = value;
    _routeStops = <ActivityItem>[];
    _selected = null;
    notifyListeners();
  }

  void clearDirections() {
    _directionTarget = null;
    notifyListeners();
  }

  void showDayRoute(List<ActivityItem> values) {
    _routeStops = List<ActivityItem>.from(values)
      ..sort((ActivityItem a, ActivityItem b) => a.time.compareTo(b.time));
    _directionTarget = null;
    notifyListeners();
  }

  void clearDayRoute() {
    _routeStops = <ActivityItem>[];
    notifyListeners();
  }

  void simulateNear() {
    _gpsNearby = true;
    notifyListeners();
  }

  void completeQuest(HeritagePlace place) {
    _completedQuests.add(place.id);
    _selected = null;
    notifyListeners();
  }

  Future<QuestJoinResult> prepareQuest(HeritagePlace place) async {
    if (_questLoading) return const QuestJoinResult(QuestJoinStatus.busy);
    final osmId = place.osmId;
    if (osmId == null || osmId.isEmpty) {
      return const QuestJoinResult(QuestJoinStatus.unavailable);
    }
    if (!_questRepository.hasAuthenticatedUser) {
      return const QuestJoinResult(QuestJoinStatus.authenticationRequired);
    }

    _questLoading = true;
    notifyListeners();
    try {
      final completed = await _questRepository.hasCurrentUserCompletedByOsmId(
        osmId,
      );
      return completed
          ? const QuestJoinResult(QuestJoinStatus.alreadyCompleted)
          : const QuestJoinResult(QuestJoinStatus.ready);
    } on MapQuestAuthenticationException {
      return const QuestJoinResult(QuestJoinStatus.authenticationRequired);
    } catch (_) {
      return const QuestJoinResult(QuestJoinStatus.failed);
    } finally {
      _questLoading = false;
      notifyListeners();
    }
  }

  Future<QuestSubmissionResult> submitPictureQuest({
    required HeritagePlace place,
    required Uint8List photoBytes,
    required String extension,
    required String? caption,
  }) async {
    if (_questSubmitting) {
      return const QuestSubmissionResult(QuestSubmissionStatus.busy);
    }
    _questSubmitting = true;
    notifyListeners();
    try {
      final result = await _questRepository.submitPictureQuest(
        place: place,
        photoBytes: photoBytes,
        extension: extension,
        caption: caption,
      );
      return result.status == PictureQuestCompletionStatus.completed
          ? QuestSubmissionResult(
              QuestSubmissionStatus.completed,
              xpAwarded: result.xpAwarded,
            )
          : const QuestSubmissionResult(QuestSubmissionStatus.alreadyCompleted);
    } on MapQuestPhotoUploadException {
      return const QuestSubmissionResult(QuestSubmissionStatus.uploadFailed);
    } on MapQuestAuthenticationException {
      return const QuestSubmissionResult(
        QuestSubmissionStatus.authenticationRequired,
      );
    } catch (_) {
      return const QuestSubmissionResult(QuestSubmissionStatus.failed);
    } finally {
      _questSubmitting = false;
      notifyListeners();
    }
  }
}
