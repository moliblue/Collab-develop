import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:findit_my/data_layer/Models/app_models.dart';
import 'package:findit_my/data_layer/Repositories/profile_repository.dart';
import 'package:findit_my/ui_layer/ViewModel/profile_view_model.dart';

void main() {
  test('level progress uses XP earned within the current level', () {
    final viewModel = ProfileViewModel();
    addTearDown(viewModel.dispose);

    viewModel.applyJourneyProgress(xp: 2270, explorerLevel: 5, streakDays: 0);

    expect(viewModel.nextLevel, 6);
    expect(viewModel.nextLevelTitle, 'Cultural Heritage Master');
    expect(viewModel.xpIntoCurrentLevel, 270);
    expect(viewModel.xpToNextLevel, 230);
    expect(viewModel.levelProgressPercent, 54);
    expect(viewModel.levelProgress, closeTo(0.54, 0.001));
  });

  test('level progress is clamped to a valid indicator range', () {
    final viewModel = ProfileViewModel();
    addTearDown(viewModel.dispose);

    viewModel.applyJourneyProgress(xp: 5000, explorerLevel: 5, streakDays: 0);

    expect(viewModel.levelProgress, 1);
    expect(viewModel.levelProgressPercent, 100);
    expect(viewModel.xpToNextLevel, 0);
  });

  test('achievement status and category filters work together', () {
    final viewModel = ProfileViewModel();
    addTearDown(viewModel.dispose);

    viewModel.setBadgeCategory('Rare');
    expect(viewModel.visibleBadges, isNotEmpty);
    expect(
      viewModel.visibleBadges.every((badge) => badge.rarity == 'Rare'),
      isTrue,
    );

    viewModel.setBadgeStatus('Locked');
    expect(viewModel.visibleBadges, hasLength(1));
    expect(viewModel.visibleBadges.single.title, 'OSM Contributor');

    viewModel.setBadgeCategory('Common');
    expect(viewModel.visibleBadges, isEmpty);
  });

  test(
    'new achievement produces one unlock notification after refresh',
    () async {
      final repository = _FakeProfileRepository();
      final viewModel = ProfileViewModel(repository: repository);
      addTearDown(viewModel.dispose);

      await viewModel.loadProfile();
      expect(viewModel.takeAchievementUnlockMessage(), isNull);

      repository.unlocked = true;
      await viewModel.loadProfile();
      expect(
        viewModel.takeAchievementUnlockMessage(),
        'Achievement Unlocked: First Shake! +500 XP',
      );
      expect(viewModel.takeAchievementUnlockMessage(), isNull);
    },
  );

  test('passport separates latest five stamps from older history', () async {
    final repository = _FakeProfileRepository();
    final viewModel = ProfileViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.loadProfile();

    expect(viewModel.passportStamps, hasLength(6));
    expect(viewModel.latestPassportStamps, hasLength(5));
    expect(viewModel.latestPassportStamps.first.destinationName, 'Destination 1');
    expect(viewModel.latestPassportStamps.last.destinationName, 'Destination 5');
    expect(viewModel.passportStampHistory, hasLength(1));
    expect(viewModel.passportStampHistory.single.destinationName, 'Destination 6');
  });
}

class _FakeProfileRepository implements ProfileRepository {
  bool unlocked = false;

  @override
  Future<UserProfileData> getCurrentProfile() async => const UserProfileData(
    id: 'user-1',
    name: 'Tester1',
    bio: '',
    avatarUrl: null,
    explorerLevel: 1,
    xp: 0,
    streakDays: 0,
    trips: 0,
  );

  @override
  Future<List<BadgeData>> getAchievements() async => <BadgeData>[
    BadgeData(
      id: 'first-shake',
      title: 'First Shake',
      description: 'Start a Mystery Journey.',
      rarity: 'Common',
      xp: 500,
      unlocked: unlocked,
      icon: 0,
      unlockedAt: unlocked ? DateTime(2026, 9, 5) : null,
    ),
  ];

  @override
  Future<List<PassportStampData>> getPassportStamps() async =>
      List<PassportStampData>.generate(
        6,
        (index) => PassportStampData(
          id: 'stamp-$index',
          destinationName: 'Destination ${index + 1}',
          earnedAt: DateTime(2026, 9, 5).subtract(Duration(days: index)),
        ),
      );

  @override
  Future<UserProfileData> removeAvatar() => getCurrentProfile();

  @override
  Future<UserProfileData> updateCurrentProfile({
    required String name,
    required String bio,
  }) => getCurrentProfile();

  @override
  Future<UserProfileData> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) => getCurrentProfile();
}
