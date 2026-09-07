import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data_layer/Models/app_models.dart';
import '../../data_layer/Models/mock_data.dart';
import '../../features/collaborative_planner/services/planner_pdf_service.dart';
import '../../features/collaborative_planner/repositories/collaborative_planner_repository.dart';
import '../../features/collaborative_planner/models/planner_models.dart'
    as planner;
import 'package:uuid/uuid.dart';

enum PlanSection { workspace, history, groups }

class CollaborativePlanningViewModel extends ChangeNotifier {
  CollaborativePlanningViewModel({CollaborativePlannerRepository? repository})
    : repository = repository ?? CollaborativePlannerRepository() {
    _initializeSupabase();
  }
  static const Uuid _uuid = Uuid();
  List<PlanDay> _days = createPlanDays();
  List<Traveller> _travellers = createTravellers();
  List<planner.TravelPlan> _availablePlans = <planner.TravelPlan>[];
  PlanSection _section = PlanSection.workspace;
  int _dayIndex = 0;
  String _planName = 'Malaysia UNESCO Heritage Tour';
  List<String> _planRegions = const <String>[];
  bool _exporting = false;
  final PlannerPdfService _pdfService = PlannerPdfService();
  final CollaborativePlannerRepository repository;
  String? _planId;
  String? _inviteCode;
  int _planRevision = 0;
  bool _planPersisted = false;
  String? _supabaseError;
  bool _supabaseReady = false;
  bool _saving = false;
  Timer? _realtimeDebounce;
  RealtimeChannel? _realtimeChannel;
  int _loadGeneration = 0;
  bool get supabaseReady => _supabaseReady;
  String? get supabaseError => _supabaseError;

  Future<void> refreshAuthenticatedSession() => _initializeSupabase();

  Future<void> _initializeSupabase() async {
    final generation = ++_loadGeneration;
    if (!repository.supabase.isConfigured) {
      notifyListeners();
      return;
    }
    try {
      _supabaseError = null;
      final session = await repository.authenticate();
      final plans = await repository.loadPlans(
        accessToken: session?.accessToken,
      );
      if (generation != _loadGeneration) return;
      _supabaseReady = session != null;
      _availablePlans = plans;
      if (_availablePlans.isNotEmpty) {
        await _loadPlan(_availablePlans.first.id, notify: false);
      } else {
        _section = PlanSection.history;
        _days = <PlanDay>[
          PlanDay(
            id: 'empty-day',
            label: 'Day 1',
            date: DateTime.now(),
            activities: <ActivityItem>[],
          ),
        ];
        _travellers = <Traveller>[];
      }
    } catch (error) {
      _supabaseError = '$error';
    }
    notifyListeners();
  }

  Future<bool> _loadPlan(String planId, {bool notify = true}) async {
    try {
      final loaded = await repository.loadPlan(
        planId,
        accessToken: repository.session?.accessToken,
      );
      if (loaded == null) return false;
      _planId = loaded.id;
      _inviteCode = loaded.inviteCode;
      _planName = loaded.name;
      _planRegions = List<String>.from(loaded.regions);
      _planPersisted = true;
      _planRevision = loaded.revision;
      _days = loaded.days.indexed.map((entry) {
        final (index, day) = entry;
        return PlanDay(
          id: day.id,
          label: 'Day ${index + 1}',
          date: day.date,
          activities: day.activities.map((activity) {
            return ActivityItem(
              id: activity.id,
              time: _databaseTimeToDisplay(activity.startTime),
              title: activity.title,
              location: activity.location,
              category: activity.category,
              latitude: activity.point.latitude,
              longitude: activity.point.longitude,
              notes: activity.description,
              routeDistanceMeters: activity.routeDistanceMeters,
              routeDurationSeconds: activity.routeDurationSeconds,
              routeGeometry: activity.routeGeometry
                  .map((point) => <double>[point.latitude, point.longitude])
                  .toList(),
              transit: activity.routeDurationSeconds == null
                  ? ''
                  : planner.RouteLeg(
                      distanceMeters: activity.routeDistanceMeters ?? 0,
                      durationSeconds: activity.routeDurationSeconds!,
                      geometry: const <planner.GeoPoint>[],
                    ).summary,
            );
          }).toList(),
        );
      }).toList();
      if (_days.isEmpty) {
        _days = <PlanDay>[
          PlanDay(
            id: 'new-0',
            label: 'Day 1',
            date: loaded.startDate,
            activities: <ActivityItem>[],
          ),
        ];
      }
      _travellers = loaded.members.map((member) {
        final isCurrent = member.userId == repository.session?.userId;
        return Traveller(
          userId: member.userId,
          name: isCurrent ? 'You' : member.name,
          initials: isCurrent ? 'ME' : member.initials,
          role: member.role == 'admin' ? 'Admin' : 'Member',
          online: true,
        );
      }).toList();
      _dayIndex = _dayIndex.clamp(0, _days.length - 1);
      _supabaseError = null;
      await _watchCurrentPlan();
      if (notify) notifyListeners();
      return true;
    } catch (error) {
      _supabaseError = '$error';
      if (notify) notifyListeners();
      return false;
    }
  }

  Future<void> _watchCurrentPlan() async {
    await repository.unwatchPlan(_realtimeChannel);
    _realtimeChannel = repository.watchPlan(() {
      _realtimeDebounce?.cancel();
      _realtimeDebounce = Timer(const Duration(milliseconds: 500), () async {
        if (_saving || _planId == null) return;
        _availablePlans = await repository.loadPlans(
          accessToken: repository.session?.accessToken,
        );
        await _loadPlan(_planId!);
      });
    });
  }

  List<PlanDay> get days => List<PlanDay>.unmodifiable(_days);
  List<Traveller> get travellers => List<Traveller>.unmodifiable(_travellers);
  bool get currentUserIsAdmin => _travellers.any(
    (traveller) =>
        traveller.userId == repository.session?.userId &&
        traveller.role == 'Admin',
  );
  bool get hasAnotherAdmin => _travellers.any(
    (traveller) =>
        traveller.userId != repository.session?.userId &&
        traveller.role == 'Admin',
  );
  bool isCurrentTraveller(Traveller traveller) =>
      traveller.userId == repository.session?.userId;
  String inviteCodeForPlan(String name) {
    final matching = _availablePlans.where((plan) => plan.name == name);
    return matching.isEmpty ? inviteCode : matching.first.inviteCode;
  }

  List<String> get history =>
      List<String>.unmodifiable(_availablePlans.map((plan) => plan.name));
  List<planner.TravelPlan> get availablePlans =>
      List<planner.TravelPlan>.unmodifiable(_availablePlans);
  planner.TravelPlan? get currentPlan =>
      _availablePlans.where((plan) => plan.id == _planId).firstOrNull;
  List<String> get planRegions => List<String>.unmodifiable(_planRegions);
  String get planCoverAsset =>
      currentPlan?.coverAsset ??
      planner.TravelPlan.coverAssetForRegion(_planRegions.firstOrNull ?? '');
  DateTime get planStartDate => currentPlan?.startDate ?? _days.first.date;
  DateTime get planEndDate => currentPlan?.endDate ?? _days.last.date;
  int get destinationCount =>
      _days.fold<int>(0, (total, day) => total + day.activities.length);
  PlanSection get section => _section;
  int get dayIndex => _dayIndex.clamp(0, _days.length - 1);
  PlanDay get activeDay => _days[dayIndex];
  String get planName => _planName;
  String get inviteCode =>
      _inviteCode ??
      (_planId == null
          ? 'HERITAGE-2026'
          : 'HERITAGE-${_planId!.substring(0, 6).toUpperCase()}');
  bool get exporting => _exporting;
  int get conflictCount {
    var conflicts = 0;
    final cards = activeDay.activities;
    for (var i = 1; i < cards.length; i++) {
      final previousStart = _timeToMinutes(cards[i - 1].time);
      final currentStart = _timeToMinutes(cards[i].time);
      if (_hasScheduleConflict(previousStart, currentStart, cards[i])) {
        conflicts++;
      }
    }
    return conflicts;
  }

  bool get hasConflict => conflictCount > 0;

  List<String> get conflictDetails {
    final details = <String>[];
    final cards = activeDay.activities;
    for (var i = 1; i < cards.length; i++) {
      final previousStart = _timeToMinutes(cards[i - 1].time);
      final currentStart = _timeToMinutes(cards[i].time);
      final travelMinutes = _travelMinutes(cards[i]);
      final earliestStart =
          previousStart + (travelMinutes > 0 ? travelMinutes : 15);
      if (_hasScheduleConflict(previousStart, currentStart, cards[i])) {
        final routeText = travelMinutes > 0
            ? '$travelMinutes min travel'
            : 'route unavailable; duplicate start time';
        details.add(
          '${cards[i - 1].title} → ${cards[i].title}: '
          '$routeText; earliest feasible start is '
          '${_minutesToTime(_roundUpToQuarterHour(earliestStart))}.',
        );
      }
    }
    return details;
  }

  void setSection(PlanSection value) {
    _section = value;
    notifyListeners();
  }

  void setDay(int value) {
    _dayIndex = value;
    notifyListeners();
  }

  Future<bool> addActivity(ActivityItem value) async {
    activeDay.activities.add(value);
    _sortActiveDay();
    notifyListeners();
    await _refreshTransit();
    final saved = await _persistCurrentPlan();
    if (!saved && activeDay.activities.contains(value)) {
      activeDay.activities.remove(value);
      await _refreshTransit();
    }
    return saved;
  }

  Future<ActivityItem?> addGeocodedActivity({
    required String time,
    required String title,
    required String location,
    required String category,
    required String notes,
  }) async {
    final matches = await repository.searchLocations(location);
    if (matches.isEmpty) return null;
    final place = matches.first;
    final item = ActivityItem(
      id: 'a-${DateTime.now().millisecondsSinceEpoch}',
      time: time,
      title: title,
      location: place.displayName,
      category: category,
      latitude: place.point.latitude,
      longitude: place.point.longitude,
      notes: notes,
    );
    await addActivity(item);
    return item;
  }

  Future<bool> updateActivity(
    ActivityItem target, {
    required String time,
    required String title,
    required String location,
    required String category,
    required double latitude,
    required double longitude,
    required String notes,
  }) async {
    final previousTime = target.time;
    final previousTitle = target.title;
    final previousLocation = target.location;
    final previousCategory = target.category;
    final previousLatitude = target.latitude;
    final previousLongitude = target.longitude;
    final previousNotes = target.notes;
    target.time = time;
    target.title = title;
    target.location = location;
    target.category = category;
    target.latitude = latitude;
    target.longitude = longitude;
    target.notes = notes;
    _sortActiveDay();
    notifyListeners();
    await _refreshTransit();
    final saved = await _persistCurrentPlan();
    if (!saved) {
      target.time = previousTime;
      target.title = previousTitle;
      target.location = previousLocation;
      target.category = previousCategory;
      target.latitude = previousLatitude;
      target.longitude = previousLongitude;
      target.notes = previousNotes;
      _sortActiveDay();
      await _refreshTransit();
    }
    return saved;
  }

  Future<bool> deleteActivity(ActivityItem value) async {
    try {
      final session = await repository.authenticate();
      await repository.deleteCard(
        _scopedId('card', value.id),
        accessToken: session?.accessToken,
      );
    } catch (error) {
      _supabaseError = '$error';
      notifyListeners();
      return false;
    }
    activeDay.activities.remove(value);
    notifyListeners();
    await _refreshTransit();
    return _persistCurrentPlan();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final previousOrder = List<ActivityItem>.of(activeDay.activities);
    final item = activeDay.activities.removeAt(oldIndex);
    activeDay.activities.insert(newIndex, item);
    notifyListeners();
    await _refreshTransit();
    if (!await _persistCurrentPlan()) {
      activeDay.activities
        ..clear()
        ..addAll(previousOrder);
      await _refreshTransit();
    }
  }

  void _sortActiveDay() {
    activeDay.activities.sort(
      (a, b) => _timeToMinutes(a.time).compareTo(_timeToMinutes(b.time)),
    );
  }

  Future<void> _refreshTransit() async {
    final cards = activeDay.activities;
    for (final card in cards) {
      card.transit = '';
      card.routeDistanceMeters = null;
      card.routeDurationSeconds = null;
      card.routeGeometry = <List<double>>[];
    }
    for (var i = 0; i < cards.length - 1; i++) {
      try {
        final route = await repository.osrm.route(<planner.GeoPoint>[
          planner.GeoPoint(cards[i].latitude, cards[i].longitude),
          planner.GeoPoint(cards[i + 1].latitude, cards[i + 1].longitude),
        ]);
        cards[i + 1].transit = route.summary;
        cards[i + 1].routeDistanceMeters = route.distanceMeters;
        cards[i + 1].routeDurationSeconds = route.durationSeconds;
        cards[i + 1].routeGeometry = route.geometry
            .map((point) => <double>[point.latitude, point.longitude])
            .toList();
      } catch (_) {
        cards[i + 1].transit = 'Route data unavailable.';
      }
    }
    notifyListeners();
  }

  Future<bool> addPlace(HeritagePlace place) async {
    final suggestedMinutes = activeDay.activities.isEmpty
        ? 9 * 60
        : activeDay.activities
                  .map((activity) => _timeToMinutes(activity.time))
                  .reduce((a, b) => a > b ? a : b) +
              120;
    final item = ActivityItem(
      id: 'place-${DateTime.now().millisecondsSinceEpoch}',
      time: _minutesToTime(suggestedMinutes),
      title: place.name,
      location: place.address,
      category: place.category,
      latitude: place.latitude,
      longitude: place.longitude,
      notes: place.shortDescription,
    );
    activeDay.activities.add(item);
    _sortActiveDay();
    notifyListeners();
    await _refreshTransit();
    _adjustScheduleForRoutes();
    notifyListeners();
    final saved = await _persistCurrentPlan();
    if (!saved && activeDay.activities.contains(item)) {
      activeDay.activities.remove(item);
      await _refreshTransit();
    }
    return saved;
  }

  Future<bool> addDay(DateTime date) async {
    if (_days.any((day) => _sameDate(day.date, date))) return false;
    final day = PlanDay(
      id: 'day-${date.millisecondsSinceEpoch}',
      label: 'Day ${_days.length + 1}',
      date: date,
      activities: <ActivityItem>[],
    );
    _days.add(day);
    _days.sort((PlanDay a, PlanDay b) => a.date.compareTo(b.date));
    _relabelDays();
    notifyListeners();
    final saved = await _persistCurrentPlan();
    if (!saved) {
      _days.remove(day);
      _relabelDays();
      notifyListeners();
    }
    return saved;
  }

  Future<bool> renameDay(PlanDay day, DateTime date) async {
    if (_days.any((other) => other != day && _sameDate(other.date, date))) {
      return false;
    }
    final previousDate = day.date;
    day.date = date;
    _days.sort((PlanDay a, PlanDay b) => a.date.compareTo(b.date));
    notifyListeners();
    final saved = await _persistCurrentPlan();
    if (!saved) {
      day.date = previousDate;
      _days.sort((a, b) => a.date.compareTo(b.date));
      _relabelDays();
      notifyListeners();
    }
    return saved;
  }

  Future<bool> deleteDay(PlanDay day) async {
    if (_days.length <= 1) return false;
    try {
      final session = await repository.authenticate();
      await repository.deleteDay(
        _scopedId('day', day.id),
        accessToken: session?.accessToken,
      );
    } catch (error) {
      _supabaseError = '$error';
      notifyListeners();
      return false;
    }
    _days.remove(day);
    _dayIndex = 0;
    notifyListeners();
    return _persistCurrentPlan();
  }

  Future<bool> createPlan(
    String name,
    DateTime start,
    int dayCount, {
    required List<String> regions,
  }) async {
    // Invalidate an older initialization/realtime load before creating a new
    // authoritative plan so a slow response cannot overwrite the new card.
    _loadGeneration++;
    final previousPlanId = _planId;
    final previousInviteCode = _inviteCode;
    final previousRevision = _planRevision;
    final previousPlanName = _planName;
    final previousPlanRegions = _planRegions;
    final previousDays = _days;
    final previousSection = _section;
    final previousPersisted = _planPersisted;
    _planId = _uuid.v4();
    _inviteCode = null;
    _planRevision = 0;
    _planPersisted = false;
    _planName = name.trim();
    _planRegions = List<String>.unmodifiable(regions);
    _days = List<PlanDay>.generate(
      dayCount,
      (int i) => PlanDay(
        id: 'new-$i',
        label: 'Day ${i + 1}',
        date: start.add(Duration(days: i)),
        activities: <ActivityItem>[],
      ),
    );
    _dayIndex = 0;
    _section = PlanSection.workspace;
    final saved = await _persistCurrentPlan();
    if (!saved) {
      _planId = previousPlanId;
      _inviteCode = previousInviteCode;
      _planRevision = previousRevision;
      _planName = previousPlanName;
      _planRegions = previousPlanRegions;
      _days = previousDays;
      _section = previousSection;
      _planPersisted = previousPersisted;
      notifyListeners();
    }
    return saved;
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _relabelDays() {
    for (var i = 0; i < _days.length; i++) {
      _days[i].label = 'Day ${i + 1}';
    }
  }

  String _scopedId(String type, String value) {
    _planId ??= _uuid.v4();
    if (RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value)) {
      return value;
    }
    return _uuid.v5(Namespace.url.value, '${_planId!}/$type/$value');
  }

  Future<bool> _persistCurrentPlan() async {
    if (!repository.supabase.isConfigured) {
      _supabaseError =
          'Supabase is not configured. Start the app with SUPABASE_URL and '
          'SUPABASE_PUBLISHABLE_KEY.';
      notifyListeners();
      return false;
    }
    if (_days.isEmpty) return false;
    _saving = true;
    try {
      final session = await repository.authenticate();
      if (session == null) return false;
      _planId ??= _uuid.v4();
      final mappedDays = _days.map((day) {
        final dayId = _scopedId('day', day.id);
        return planner.PlannerDay(
          id: dayId,
          date: day.date,
          activities: day.activities.indexed.map((entry) {
            final (index, card) = entry;
            return planner.PlannerActivity(
              id: _scopedId('card', card.id),
              dayId: dayId,
              title: card.title,
              location: card.location,
              startTime: card.time,
              category: card.category,
              point: planner.GeoPoint(card.latitude, card.longitude),
              description: card.notes,
              position: index,
              routeDistanceMeters: card.routeDistanceMeters,
              routeDurationSeconds: card.routeDurationSeconds,
              routeGeometry: card.routeGeometry
                  .map((point) => planner.GeoPoint(point[0], point[1]))
                  .toList(),
            );
          }).toList(),
        );
      }).toList();
      _planRevision = await repository.savePlan(
        planner.TravelPlan(
          id: _planId!,
          ownerId: session.userId,
          name: _planName,
          startDate: mappedDays.first.date,
          endDate: mappedDays.last.date,
          inviteCode: 'HERITAGE-${_planId!.substring(0, 6).toUpperCase()}',
          regions: _planRegions,
          primaryRegion: _planRegions.firstOrNull,
          revision: _planRevision,
          days: mappedDays,
        ),
        accessToken: session.accessToken,
        create: !_planPersisted,
      );
      _planPersisted = true;
      _inviteCode = 'HERITAGE-${_planId!.substring(0, 6).toUpperCase()}';
      _supabaseReady = true;
      _supabaseError = null;
      final generation = ++_loadGeneration;
      final plans = await repository.loadPlans(
        accessToken: session.accessToken,
      );
      if (generation == _loadGeneration) _availablePlans = plans;
      notifyListeners();
      return true;
    } catch (error) {
      _supabaseError = '$error';
      if ('$error'.contains('changed on another device') && _planId != null) {
        await _loadPlan(_planId!, notify: false);
      }
      notifyListeners();
      return false;
    } finally {
      _saving = false;
    }
  }

  Future<void> openHistoryPlan(String name) async {
    final plan = _availablePlans.where((item) => item.name == name).firstOrNull;
    if (plan == null) return;
    if (await _loadPlan(plan.id)) {
      _section = PlanSection.workspace;
      notifyListeners();
    }
  }

  Future<bool> joinPlan(String code) async {
    try {
      final session = await repository.authenticate();
      final joinedId = await repository.joinPlan(
        code.trim(),
        accessToken: session?.accessToken,
      );
      _availablePlans = await repository.loadPlans(
        accessToken: session?.accessToken,
      );
      final loaded = await _loadPlan('$joinedId');
      if (loaded) _section = PlanSection.workspace;
      notifyListeners();
      return loaded;
    } catch (error) {
      _supabaseError = '$error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePlan(String name) async {
    final matching = _availablePlans.where((plan) => plan.name == name);
    final targetId = matching.isEmpty ? null : matching.first.id;
    if (targetId != null) {
      try {
        final session = await repository.authenticate();
        await repository.deletePlan(
          targetId,
          accessToken: session?.accessToken,
        );
      } catch (error) {
        _supabaseError = '$error';
        notifyListeners();
        return false;
      }
    }
    _availablePlans = await repository.loadPlans(
      accessToken: repository.session?.accessToken,
    );
    if (_availablePlans.isNotEmpty && _planName == name) {
      await _loadPlan(_availablePlans.first.id, notify: false);
    } else if (_availablePlans.isEmpty) {
      _section = PlanSection.history;
    }
    notifyListeners();
    return true;
  }

  Future<bool> isCurrentUserAdminOfPlan(String name) async {
    final matching = _availablePlans.where((plan) => plan.name == name);
    if (matching.isEmpty) return false;
    try {
      final session = await repository.authenticate();
      return repository.isCurrentUserAdmin(
        matching.first.id,
        accessToken: session?.accessToken,
      );
    } catch (error) {
      _supabaseError = '$error';
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> updateRole(Traveller value) async {
    if (_planId == null || value.userId == null) return false;
    final newRole = value.role == 'Admin' ? 'member' : 'admin';
    try {
      await repository.updateMemberRole(
        _planId!,
        value.userId!,
        newRole,
        accessToken: repository.session?.accessToken,
      );
      value.role = newRole == 'admin' ? 'Admin' : 'Member';
      notifyListeners();
      return true;
    } catch (error) {
      _supabaseError = '$error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeTraveller(Traveller value) async {
    if (_planId == null || value.userId == null) return false;
    try {
      await repository.removeMember(
        _planId!,
        value.userId!,
        accessToken: repository.session?.accessToken,
      );
      _travellers.remove(value);
      notifyListeners();
      return true;
    } catch (error) {
      _supabaseError = '$error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> leaveGroup() async {
    if (_planId == null) return false;
    try {
      await repository.leavePlan(
        _planId!,
        newOwnerId: _travellers
            .where(
              (traveller) =>
                  traveller.userId != repository.session?.userId &&
                  traveller.role == 'Admin',
            )
            .firstOrNull
            ?.userId,
        accessToken: repository.session?.accessToken,
      );
      _availablePlans = await repository.loadPlans(
        accessToken: repository.session?.accessToken,
      );
      _section = PlanSection.history;
      notifyListeners();
      return true;
    } catch (error) {
      _supabaseError = '$error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> autoFixConflict() async {
    final previousTimes = <ActivityItem, String>{
      for (final activity in activeDay.activities) activity: activity.time,
    };
    _adjustScheduleForRoutes();
    notifyListeners();
    final saved = await _persistCurrentPlan();
    if (!saved) {
      for (final entry in previousTimes.entries) {
        entry.key.time = entry.value;
      }
      _sortActiveDay();
      notifyListeners();
    }
    return saved;
  }

  void _adjustScheduleForRoutes() {
    final cards = activeDay.activities;
    for (var i = 1; i < cards.length; i++) {
      final previousStart = _timeToMinutes(cards[i - 1].time);
      final currentStart = _timeToMinutes(cards[i].time);
      final travelMinutes = _travelMinutes(cards[i]);
      final earliestStart =
          previousStart + (travelMinutes > 0 ? travelMinutes : 15);
      if (_hasScheduleConflict(previousStart, currentStart, cards[i])) {
        cards[i].time = _minutesToTime(_roundUpToQuarterHour(earliestStart));
      }
    }
  }

  int _travelMinutes(ActivityItem destination) {
    final seconds = destination.routeDurationSeconds;
    if (seconds == null || seconds <= 0) return 0;
    return (seconds / 60).ceil();
  }

  bool _hasScheduleConflict(
    int previousStart,
    int currentStart,
    ActivityItem destination,
  ) {
    if (currentStart <= previousStart) return true;
    final travelMinutes = _travelMinutes(destination);
    return travelMinutes > 0 && currentStart < previousStart + travelMinutes;
  }

  int _roundUpToQuarterHour(int minutes) => ((minutes + 14) ~/ 15) * 15;

  int _timeToMinutes(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return 9 * 60;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!.toUpperCase();
    if (hour == 12) hour = 0;
    if (period == 'PM') hour += 12;
    return hour * 60 + minute;
  }

  String _minutesToTime(int value) {
    final normalized = value % (24 * 60);
    final hour24 = normalized ~/ 60;
    final minute = normalized % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String _databaseTimeToDisplay(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) return value;
    final hour24 = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  Future<Uint8List> exportPdf() async {
    _exporting = true;
    notifyListeners();
    try {
      return await _pdfService.create(planName: _planName, days: _days);
    } finally {
      _exporting = false;
      notifyListeners();
    }
  }

  void reset() {
    _days = createPlanDays();
    _planName = 'Malaysia UNESCO Heritage Tour';
    _planRegions = const <String>[];
    _section = PlanSection.workspace;
    _dayIndex = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    repository.unwatchPlan(_realtimeChannel);
    repository.dispose();
    super.dispose();
  }
}
