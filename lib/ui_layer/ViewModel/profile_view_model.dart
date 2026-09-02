import 'package:flutter/foundation.dart';

import '../../data_layer/Models/app_models.dart';
import '../../data_layer/Models/mock_data.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileStage _stage = ProfileStage.dashboard;
  String _name = 'Amberly';
  String _bio =
      'Heritage enthusiast exploring UNESCO trails and local traditional crafts across Malaysia.';
  String _language = 'English (US)';
  int _xp = 1450;
  int _level = 3;
  int _streakDays = 0;
  String _badgeStatus = 'All';
  BadgeData? _selectedBadge;

  ProfileStage get stage => _stage;
  String get name => _name;
  String get bio => _bio;
  String get language => _language;
  int get xp => _xp;
  int get level => _level;
  int get streakDays => _streakDays;
  int get trips => 8;
  String get badgeStatus => _badgeStatus;
  BadgeData? get selectedBadge => _selectedBadge;
  List<BadgeData> get visibleBadges => badges
      .where(
        (BadgeData b) =>
            _badgeStatus == 'All' ||
            (_badgeStatus == 'Unlocked' ? b.unlocked : !b.unlocked),
      )
      .toList();

  void setStage(ProfileStage value) {
    _stage = value;
    notifyListeners();
  }

  String? updateProfile(String name, String bio) {
    if (name.trim().length < 3 || name.trim().length > 30) {
      return 'Display name must be between 3 and 30 characters.';
    }
    _name = name.trim();
    _bio = bio.trim();
    notifyListeners();
    return null;
  }

  void setLanguage(String value) {
    _language = value;
    notifyListeners();
  }

  void setBadgeStatus(String value) {
    _badgeStatus = value;
    notifyListeners();
  }

  void selectBadge(BadgeData? value) {
    _selectedBadge = value;
    notifyListeners();
  }

  void rewardXp(int amount) {
    _xp += amount;
    notifyListeners();
  }

  void applyJourneyProgress({
    required int xp,
    required int explorerLevel,
    required int streakDays,
  }) {
    _xp = xp;
    _level = explorerLevel;
    _streakDays = streakDays;
    notifyListeners();
  }

  void logout() {
    _stage = ProfileStage.login;
    notifyListeners();
  }

  void authenticated({String? name}) {
    if (name != null && name.trim().isNotEmpty) _name = name.trim();
    _stage = ProfileStage.dashboard;
    notifyListeners();
  }
}
