import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data_layer/Models/app_models.dart';
import '../../data_layer/Repositories/shake_find_repository.dart';
import '../../data_layer/Repositories/shake_find_repository_impl.dart';
import '../../data_layer/Service Managers/device/shake_sensor_service.dart';
import '../../features/collaborative_planner/models/planner_messages.dart';
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
  AppViewModel({
    ShakeFindRepository? mysteryRepository,
    AuthViewModel? authViewModel,
  }) : mystery = MysteryJourneyViewModel(
         mysteryRepository ?? ShakeFindRepositoryImpl(ShakeSensorService()),
       ),
       discovery = DiscoveryViewModel(),
       map = MapQuestViewModel(),
       plan = CollaborativePlanningViewModel(),
       profile = ProfileViewModel(),
       auth = authViewModel ?? AuthViewModel() {
    mystery.addListener(_syncMysteryProfile);
    auth.addListener(_handleAuthChanged);
    if (requiresAuthentication) {
      profile.setStage(ProfileStage.login);
    } else {
      unawaited(profile.loadProfile());
    }
  }

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
  String? _profileRefreshedForJourneyId;

  MainTab get tab => _tab;
  AppToastData? get toast => _toast;
  bool get requiresAuthentication =>
      !auth.isAuthenticated || auth.shouldShowResetPassword;

  void _handleAuthChanged() {
    if (auth.shouldShowResetPassword) {
      if (profile.stage != ProfileStage.resetPassword) {
        profile.setStage(ProfileStage.resetPassword);
      }
      notifyListeners();
      return;
    }
    if (requiresAuthentication) {
      if (profile.stage != ProfileStage.login &&
          profile.stage != ProfileStage.register &&
          profile.stage != ProfileStage.verifyEmail &&
          profile.stage != ProfileStage.recover) {
        profile.setStage(ProfileStage.login);
      }
    } else if (profile.stage == ProfileStage.login ||
        profile.stage == ProfileStage.register ||
        profile.stage == ProfileStage.verifyEmail ||
        profile.stage == ProfileStage.recover ||
        profile.stage == ProfileStage.resetPassword) {
      profile.authenticated();
      unawaited(plan.refreshAuthenticatedSession());
    }
    notifyListeners();
  }

  void selectTab(MainTab value) {
    if (value == MainTab.map && _tab != MainTab.map) _previousBeforeMap = _tab;
    _tab = value;
    if (value == MainTab.profile && !requiresAuthentication) {
      unawaited(_refreshProfile());
    }
    notifyListeners();
  }

  void showDirections(HeritagePlace place) {
    map.showDirections(place);
    selectTab(MainTab.map);
    showToast('Showing directions to ${place.name}.', AppColors.primary);
  }

  void showMysteryDirections() {
    final place = _mysteryPlace;
    if (place == null) {
      showToast(
        'Confirm Reveal Exact Route before opening navigation.',
        AppColors.warning,
      );
      return;
    }
    showDirections(place);
  }

  HeritagePlace? get _mysteryPlace {
    final destination = mystery.revealedDestination;
    if (destination == null) return null;
    return HeritagePlace(
      id: destination.id,
      name: destination.name,
      category: destination.category,
      state: '',
      shortDescription: destination.description,
      description: destination.description,
      image: destination.imageUrl?.trim() ?? '',
      distanceKm: mystery.distanceMeters / 1000,
      rating: 0,
      reviewsCount: 0,
      latitude: destination.latitude,
      longitude: destination.longitude,
      address: destination.address,
      hours: '',
    );
  }

  void addMysteryToPlan() {
    final place = _mysteryPlace;
    if (place == null) {
      showToast('Mystery destination is not available yet.', AppColors.warning);
      return;
    }
    addToPlan(place);
  }

  Future<void> addToPlan(HeritagePlace place) async {
    final added = await plan.addPlace(place);
    showToast(
      added
          ? 'Added ${place.name} to ${plan.activeDay.label}.'
          : 'Could not add ${place.name} to the active Plan day.',
      added ? AppColors.teal : AppColors.warning,
    );
  }

  void showDayRoute(List<ActivityItem> stops) {
    map.showDayRoute(stops);
    selectTab(MainTab.map);
    showToast(
      PlannerMessages.redirectRoute(plan.dayIndex + 1),
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
        if (profile.stage == ProfileStage.badges ||
            profile.stage == ProfileStage.passport) {
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
    profile.setStage(ProfileStage.passport);
    selectTab(MainTab.profile);
  }

  void openProfile() {
    profile.setStage(ProfileStage.dashboard);
    selectTab(MainTab.profile);
  }

  Future<void> _refreshProfile() async {
    await profile.loadProfile();
    final unlockMessage = profile.takeAchievementUnlockMessage();
    if (unlockMessage != null) showToast(unlockMessage, AppColors.warning);
  }

  void rewardXp(int _) => unawaited(_refreshProfile());

  void _syncMysteryProfile() {
    final value = mystery.profile;
    if (value == null) return;
    profile.applyJourneyProgress(
      xp: value.xp,
      explorerLevel: value.explorerLevel,
      streakDays: value.streakDays,
    );
    final journey = mystery.journey;
    if (mystery.stage == MysteryStage.complete &&
        journey != null &&
        _profileRefreshedForJourneyId != journey.id) {
      _profileRefreshedForJourneyId = journey.id;
      unawaited(_refreshProfile());
    }
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
    mystery.removeListener(_syncMysteryProfile);
    auth.removeListener(_handleAuthChanged);
    mystery.dispose();
    discovery.dispose();
    map.dispose();
    plan.dispose();
    profile.dispose();
    auth.dispose();
    super.dispose();
  }
}
