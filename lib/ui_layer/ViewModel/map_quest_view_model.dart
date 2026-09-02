import 'package:flutter/foundation.dart';

import '../../data_layer/Models/app_models.dart';
import '../../data_layer/Service Managers/Remote Services/osm_heritage_service.dart';

class MapQuestViewModel extends ChangeNotifier {
  MapQuestViewModel({OsmHeritageService? heritageService})
    : _heritageService = heritageService ?? OsmHeritageService();

  static const double defaultSearchRadiusKm = 5;
  static const int maximumDatasetRadiusMeters = 10000;
  static const List<double> radiusOptionsKm = <double>[0.5, 1, 2, 5, 10];
  final OsmHeritageService _heritageService;
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
}
