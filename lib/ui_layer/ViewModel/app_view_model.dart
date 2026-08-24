import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data_layer/Models/app_models.dart';
import 'auth_view_model.dart';
import 'collaborative_planning_view_model.dart';
import 'discovery_view_model.dart';
import 'map_quest_view_model.dart';
import 'profile_view_model.dart';
import 'shake_find_view_model.dart';

enum MainTab { discover, map, mystery, plan, profile }

class AppToastData {
  const AppToastData(this.message, this.color);
  final String message;
  final Color color;
}

class AppViewModel extends ChangeNotifier {
  AppViewModel()
    : mystery = MysteryJourneyViewModel(),
      discovery = DiscoveryViewModel(),
      map = MapQuestViewModel(),
      plan = CollaborativePlanningViewModel(),
      profile = ProfileViewModel(),
      auth = AuthViewModel();

  final MysteryJourneyViewModel mystery;
  final DiscoveryViewModel discovery;
  final MapQuestViewModel map;
  final CollaborativePlanningViewModel plan;
  final ProfileViewModel profile;
  final AuthViewModel auth;
  MainTab _tab = MainTab.mystery;
  MainTab _previousBeforeMap = MainTab.mystery;
  AppToastData? _toast;
  Timer? _toastTimer;

  MainTab get tab => _tab;
  AppToastData? get toast => _toast;

  void selectTab(MainTab value) {
    if (value == MainTab.map && _tab != MainTab.map) _previousBeforeMap = _tab;
    _tab = value;
    notifyListeners();
  }

  void showDirections(HeritagePlace place) {
    map.showDirections(place);
    selectTab(MainTab.map);
    showToast('Showing directions to ${place.name}.', AppColors.primary);
  }

  void showMysteryDirections() {
    final place = discovery.places.firstWhere(
      (HeritagePlace p) => p.id == 'sultan',
    );
    showDirections(place);
  }

  void addToPlan(HeritagePlace place) {
    plan.addPlace(place);
    showToast(
      'Added ${place.name} to ${plan.activeDay.label}.',
      AppColors.teal,
    );
  }

  void showDayRoute(List<ActivityItem> stops) {
    map.showDayRoute(stops);
    selectTab(MainTab.map);
    showToast(
      'Showing ${stops.length} route stops in time order.',
      AppColors.tealDark,
    );
  }

  void back() {
    switch (_tab) {
      case MainTab.mystery:
        if (mystery.stage == MysteryStage.active) {
          mystery.setStage(MysteryStage.home);
        } else if (mystery.stage == MysteryStage.verificationFailed ||
            mystery.stage == MysteryStage.interrupted) {
          mystery.setStage(MysteryStage.active);
        } else {
          mystery.setStage(MysteryStage.home);
        }
        return;
      case MainTab.discover:
        if (discovery.selected != null) {
          discovery.select(null);
        } else if (discovery.section != DiscoverSection.discover) {
          discovery.setSection(DiscoverSection.discover);
        } else {
          selectTab(MainTab.mystery);
        }
        return;
      case MainTab.map:
        map.clearDirections();
        map.clearDayRoute();
        selectTab(_previousBeforeMap);
        return;
      case MainTab.plan:
        if (plan.section != PlanSection.workspace) {
          plan.setSection(PlanSection.workspace);
        } else {
          selectTab(MainTab.mystery);
        }
        return;
      case MainTab.profile:
        if (profile.stage == ProfileStage.badges) {
          profile.setStage(ProfileStage.dashboard);
        } else {
          selectTab(MainTab.mystery);
        }
        return;
    }
  }

  bool get hasNestedScreen => switch (_tab) {
    MainTab.mystery => mystery.stage != MysteryStage.home,
    MainTab.discover =>
      discovery.selected != null ||
          discovery.section != DiscoverSection.discover,
    MainTab.map => true,
    MainTab.plan => plan.section != PlanSection.workspace,
    MainTab.profile => profile.stage != ProfileStage.dashboard,
  };

  void openPassport() {
    profile.setStage(ProfileStage.badges);
    selectTab(MainTab.profile);
  }

  void rewardXp(int amount) {
    profile.rewardXp(amount);
  }

  void showToast(String message, Color color) {
    _toastTimer?.cancel();
    _toast = AppToastData(message, color);
    notifyListeners();
    _toastTimer = Timer(const Duration(seconds: 4), dismissToast);
  }

  void dismissToast() {
    _toastTimer?.cancel();
    _toast = null;
    notifyListeners();
  }

  void resetDemo() {
    discovery.reset();
    plan.reset();
    mystery.cancelJourney();
    map.clearDirections();
    map.clearDayRoute();
    showToast('Demo data reset to prototype defaults.', AppColors.primary);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    mystery.dispose();
    discovery.dispose();
    map.dispose();
    plan.dispose();
    profile.dispose();
    auth.dispose();
    super.dispose();
  }
}
