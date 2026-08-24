import 'package:flutter/foundation.dart';

import '../../data_layer/Models/app_models.dart';
import '../../data_layer/Models/mock_data.dart';

enum PlanSection { workspace, history, groups }

class CollaborativePlanningViewModel extends ChangeNotifier {
  List<PlanDay> _days = createPlanDays();
  final List<Traveller> _travellers = createTravellers();
  final List<String> _history = <String>['Malaysia UNESCO Heritage Tour'];
  PlanSection _section = PlanSection.workspace;
  int _dayIndex = 0;
  String _planName = 'Malaysia UNESCO Heritage Tour';
  bool _exporting = false;

  List<PlanDay> get days => List<PlanDay>.unmodifiable(_days);
  List<Traveller> get travellers => List<Traveller>.unmodifiable(_travellers);
  List<String> get history => List<String>.unmodifiable(_history);
  PlanSection get section => _section;
  int get dayIndex => _dayIndex.clamp(0, _days.length - 1);
  PlanDay get activeDay => _days[dayIndex];
  String get planName => _planName;
  bool get exporting => _exporting;
  bool get hasConflict {
    final times = <String>{};
    for (final a in activeDay.activities) {
      if (!times.add(a.time)) return true;
    }
    return false;
  }

  void setSection(PlanSection value) {
    _section = value;
    notifyListeners();
  }

  void setDay(int value) {
    _dayIndex = value;
    notifyListeners();
  }

  void addActivity(ActivityItem value) {
    activeDay.activities.add(value);
    notifyListeners();
  }

  void updateActivity(
    ActivityItem target, {
    required String time,
    required String title,
    required String notes,
  }) {
    target.time = time;
    target.title = title;
    target.notes = notes;
    notifyListeners();
  }

  void deleteActivity(ActivityItem value) {
    activeDay.activities.remove(value);
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    final item = activeDay.activities.removeAt(oldIndex);
    activeDay.activities.insert(newIndex, item);
    notifyListeners();
  }

  void addPlace(HeritagePlace place) {
    activeDay.activities.add(
      ActivityItem(
        id: 'place-${DateTime.now().millisecondsSinceEpoch}',
        time: '03:00 PM',
        title: place.name,
        location: place.address,
        category: 'Culture',
        latitude: place.latitude,
        longitude: place.longitude,
        notes: place.shortDescription,
      ),
    );
    notifyListeners();
  }

  void addDay(DateTime date) {
    _days.add(
      PlanDay(
        id: 'day-${date.millisecondsSinceEpoch}',
        label: 'Day ${_days.length + 1}',
        date: date,
        activities: <ActivityItem>[],
      ),
    );
    _days.sort((PlanDay a, PlanDay b) => a.date.compareTo(b.date));
    for (var i = 0; i < _days.length; i++) {
      _days[i].label = 'Day ${i + 1}';
    }
    notifyListeners();
  }

  void renameDay(PlanDay day, DateTime date) {
    day.date = date;
    _days.sort((PlanDay a, PlanDay b) => a.date.compareTo(b.date));
    notifyListeners();
  }

  void deleteDay(PlanDay day) {
    if (_days.length <= 1) return;
    _days.remove(day);
    _dayIndex = 0;
    notifyListeners();
  }

  void createPlan(String name, DateTime start, int dayCount) {
    _planName = name.trim();
    _days = List<PlanDay>.generate(
      dayCount,
      (int i) => PlanDay(
        id: 'new-$i',
        label: 'Day ${i + 1}',
        date: start.add(Duration(days: i)),
        activities: <ActivityItem>[],
      ),
    );
    if (!_history.contains(_planName)) _history.insert(0, _planName);
    _dayIndex = 0;
    _section = PlanSection.workspace;
    notifyListeners();
  }

  void openHistoryPlan(String name) {
    _planName = name;
    _section = PlanSection.workspace;
    notifyListeners();
  }

  void updateRole(Traveller value) {
    value.role = value.role == 'Admin' ? 'Member' : 'Admin';
    notifyListeners();
  }

  void removeTraveller(Traveller value) {
    _travellers.remove(value);
    notifyListeners();
  }

  void leaveGroup() {
    _travellers.removeWhere((Traveller t) => t.name == 'Amberly');
    notifyListeners();
  }

  void autoFixConflict() {
    if (activeDay.activities.length > 1) {
      activeDay.activities[1].time = '11:00 AM';
    }
    notifyListeners();
  }

  Future<void> exportPdfDemo() async {
    _exporting = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _exporting = false;
    notifyListeners();
  }

  void reset() {
    _days = createPlanDays();
    _planName = 'Malaysia UNESCO Heritage Tour';
    _section = PlanSection.workspace;
    _dayIndex = 0;
    notifyListeners();
  }
}
