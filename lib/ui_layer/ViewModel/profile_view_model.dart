import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../data_layer/Models/app_models.dart';
import '../../data_layer/Models/mock_data.dart';
import '../../data_layer/Repositories/profile_repository.dart';

class ProfileViewModel extends ChangeNotifier {
  static final ValueNotifier<Locale> appLocale = ValueNotifier<Locale>(
    const Locale('en'),
  );
  ProfileViewModel({ProfileRepository? repository})
    : _repository = repository ?? SupabaseProfileRepository();

  final ProfileRepository _repository;
  ProfileStage _stage = ProfileStage.dashboard;
  String _name = 'Explorer';
  String _bio = '';
  String _language = 'English (US)';
  String? _avatarUrl;
  int _xp = 0;
  int _level = 1;
  int _streakDays = 0;
  int _trips = 0;
  bool _loading = false;
  String? _error;
  List<BadgeData> _achievements = badges;
  String _badgeStatus = 'All';
  String _badgeCategory = 'All Categories';
  BadgeData? _selectedBadge;
  List<PassportStampData> _passportStamps = const <PassportStampData>[];
  bool _hasAchievementSnapshot = false;
  String? _achievementUnlockMessage;

  ProfileStage get stage => _stage;
  String get name => _name;
  String get initials {
    final parts = _name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'EX';
    if (parts.length == 1) {
      final end = parts.first.length < 2 ? parts.first.length : 2;
      return parts.first.substring(0, end).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get bio => _bio;
  String get language => _language;
  String? get avatarUrl => _avatarUrl;
  int get xp => _xp;
  int get level => _level;
  static const int xpPerLevel = 500;
  static const String profileUpdatedMessage = 'Profile updated successfully.';
  static const String avatarValidationMessage =
      'Error: Avatar image must be in JPG or PNG format and smaller than 5MB.';
  static const String noAchievementsMessage =
      'No achievements found matching your selected filter.';
  int get nextLevel => _level + 1;
  int get xpIntoCurrentLevel =>
      (_xp - ((_level - 1) * xpPerLevel)).clamp(0, xpPerLevel).toInt();
  int get xpToNextLevel => xpPerLevel - xpIntoCurrentLevel;
  double get levelProgress => xpIntoCurrentLevel / xpPerLevel;
  int get levelProgressPercent => (levelProgress * 100).round();
  String get nextLevelTitle => switch (nextLevel) {
    2 => 'Curious Traveller',
    3 => 'Heritage Seeker',
    4 => 'Cultural Adventurer',
    5 => 'Heritage Explorer',
    6 => 'Cultural Heritage Master',
    7 => 'Malaysia Trailblazer',
    _ => 'Legendary Explorer',
  };
  int get streakDays => _streakDays;
  int get trips => _trips;
  bool get loading => _loading;
  String? get error => _error;
  String get badgeStatus => _badgeStatus;
  String get badgeCategory => _badgeCategory;
  BadgeData? get selectedBadge => _selectedBadge;
  List<PassportStampData> get passportStamps => _passportStamps;
  List<BadgeData> get visibleBadges => _achievements
      .where(
        (BadgeData b) =>
            (_badgeStatus == 'All' ||
                (_badgeStatus == 'Unlocked' ? b.unlocked : !b.unlocked)) &&
            (_badgeCategory == 'All Categories' || b.rarity == _badgeCategory),
      )
      .toList();

  void setStage(ProfileStage value) {
    _stage = value;
    notifyListeners();
  }

  Future<String?> updateProfile(String name, String bio) async {
    if (name.trim().length < 3 || name.trim().length > 30) {
      return 'Display name must be between 3 and 30 characters.';
    }
    _loading = true;
    notifyListeners();
    try {
      final value = await _repository.updateCurrentProfile(
        name: name.trim(),
        bio: bio.trim(),
      );
      _apply(value);
      return null;
    } catch (error) {
      return 'Could not save your profile: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      _apply(await _repository.uploadAvatar(bytes: bytes, fileName: fileName));
      return null;
    } catch (error) {
      if (error.toString().contains(avatarValidationMessage)) {
        return avatarValidationMessage;
      }
      return 'Could not upload profile photo: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> removeAvatar() async {
    _loading = true;
    notifyListeners();
    try {
      _apply(await _repository.removeAvatar());
      return null;
    } catch (error) {
      return 'Could not remove profile photo: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setLanguage(String value) {
    _language = value;
    appLocale.value = switch (value) {
      'Bahasa Melayu' => const Locale('ms'),
      'Chinese (Simplified)' => const Locale('zh'),
      _ => const Locale('en'),
    };
    notifyListeners();
  }

  void setBadgeStatus(String value) {
    _badgeStatus = value;
    notifyListeners();
  }

  void setBadgeCategory(String value) {
    _badgeCategory = value;
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
    _name = 'Explorer';
    _bio = '';
    _avatarUrl = null;
    _xp = 0;
    _level = 1;
    _streakDays = 0;
    _trips = 0;
    _achievements = badges;
    _badgeStatus = 'All';
    _badgeCategory = 'All Categories';
    _passportStamps = const <PassportStampData>[];
    _hasAchievementSnapshot = false;
    _achievementUnlockMessage = null;
    _error = null;
    _stage = ProfileStage.login;
    notifyListeners();
  }

  void authenticated({String? name}) {
    if (name != null && name.trim().isNotEmpty) _name = name.trim();
    _stage = ProfileStage.dashboard;
    notifyListeners();
    loadProfile();
  }

  Future<void> loadProfile() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _apply(await _repository.getCurrentProfile());
      try {
        final previousUnlockState = <String, bool>{
          for (final achievement in _achievements)
            achievement.id: achievement.unlocked,
        };
        final updatedAchievements = await _repository.getAchievements();
        if (_hasAchievementSnapshot) {
          final newlyUnlocked = updatedAchievements
              .where(
                (achievement) =>
                    achievement.unlocked &&
                    previousUnlockState[achievement.id] == false,
              )
              .toList();
          if (newlyUnlocked.isNotEmpty) {
            final totalXp = newlyUnlocked.fold<int>(
              0,
              (total, achievement) => total + achievement.xp,
            );
            _achievementUnlockMessage = newlyUnlocked.length == 1
                ? 'Achievement Unlocked: ${newlyUnlocked.first.title}! +$totalXp XP'
                : '${newlyUnlocked.length} Achievements Unlocked! +$totalXp XP';
          }
        }
        _achievements = updatedAchievements;
        _hasAchievementSnapshot = true;
        _passportStamps = await _repository.getPassportStamps();
      } catch (_) {
        // Profile remains usable before the achievement migration is applied.
      }
    } catch (error) {
      _error = 'Could not load profile: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String? takeAchievementUnlockMessage() {
    final value = _achievementUnlockMessage;
    _achievementUnlockMessage = null;
    return value;
  }

  void _apply(UserProfileData value) {
    _name = value.name;
    _bio = value.bio;
    _avatarUrl = value.avatarUrl;
    _level = value.explorerLevel;
    _xp = value.xp;
    _streakDays = value.streakDays;
    _trips = value.trips;
  }
}
