import 'package:flutter/foundation.dart';

import '../../data_layer/Models/app_models.dart';

class MapQuestViewModel extends ChangeNotifier {
  String _query = '';
  String _category = 'All';
  double _radius = 25;
  HeritagePlace? _selected;
  HeritagePlace? _directionTarget;
  List<ActivityItem> _routeStops = <ActivityItem>[];
  final Set<String> _completedQuests = <String>{};
  bool _gpsNearby = false;

  String get query => _query;
  String get category => _category;
  double get radius => _radius;
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
    _radius = value;
    notifyListeners();
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
