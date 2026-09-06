import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../Models/app_models.dart';
import '../Service Managers/Remote Services/supabase_service.dart';

class UserProfileData {
  const UserProfileData({
    required this.id,
    required this.name,
    required this.bio,
    required this.avatarUrl,
    required this.explorerLevel,
    required this.xp,
    required this.streakDays,
    required this.trips,
  });

  final String id;
  final String name;
  final String bio;
  final String? avatarUrl;
  final int explorerLevel;
  final int xp;
  final int streakDays;
  final int trips;

  factory UserProfileData.fromJson(Map<String, dynamic> json) =>
      UserProfileData(
        id: json['id'] as String,
        name: (json['full_name'] ?? json['username'] ?? 'Explorer') as String,
        bio: (json['bio'] ?? '') as String,
        avatarUrl: json['avatar_url'] as String?,
        explorerLevel: (json['explorer_level'] as num?)?.toInt() ?? 1,
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
        trips: (json['trips_completed'] as num?)?.toInt() ?? 0,
      );
}

abstract class ProfileRepository {
  Future<UserProfileData> getCurrentProfile();
  Future<UserProfileData> updateCurrentProfile({
    required String name,
    required String bio,
  });
  Future<UserProfileData> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  });
  Future<UserProfileData> removeAvatar();
  Future<List<BadgeData>> getAchievements();
  Future<List<PassportStampData>> getPassportStamps();
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository({SupabaseService? supabaseService})
    : _supabase = supabaseService ?? const SupabaseService();

  final SupabaseService _supabase;

  @override
  Future<UserProfileData> getCurrentProfile() async {
    final user = _supabase.currentUser;
    if (user == null) throw const AuthException('Please sign in first.');

    final row = await _supabase.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();
    final profile = await _withDisplayAvatar(UserProfileData.fromJson(row));
    if (profile.name == 'Explorer') {
      return UserProfileData(
        id: profile.id,
        name:
            (user.userMetadata?['full_name'] ??
                    user.userMetadata?['display_name'] ??
                    user.email?.split('@').first ??
                    'Explorer')
                as String,
        bio: profile.bio,
        avatarUrl: profile.avatarUrl,
        explorerLevel: profile.explorerLevel,
        xp: profile.xp,
        streakDays: profile.streakDays,
        trips: profile.trips,
      );
    }
    return profile;
  }

  @override
  Future<UserProfileData> updateCurrentProfile({
    required String name,
    required String bio,
  }) async {
    final id = _supabase.requireCurrentUserId();
    final row = await _supabase.client
        .from('profiles')
        .update(<String, dynamic>{'full_name': name, 'bio': bio})
        .eq('id', id)
        .select()
        .single();
    return _withDisplayAvatar(UserProfileData.fromJson(row));
  }

  @override
  Future<UserProfileData> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final requestedExtension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    if (bytes.isEmpty ||
        bytes.lengthInBytes > 5 * 1024 * 1024 ||
        !<String>{'jpg', 'jpeg', 'png'}.contains(requestedExtension)) {
      throw const FormatException(
        'Error: Avatar image must be in JPG or PNG format and smaller than 5MB.',
      );
    }

    final id = _supabase.requireCurrentUserId();
    final previousPath = await _currentAvatarPath(id);
    final extension = requestedExtension;
    final contentType = switch (extension) {
      'png' => 'image/png',
      _ => 'image/jpeg',
    };
    final path =
        '$id/avatar-${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _supabase.client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    final row = await _supabase.client
        .from('profiles')
        .update(<String, dynamic>{'avatar_url': path})
        .eq('id', id)
        .select()
        .single();
    await _removeStoredAvatar(previousPath);
    return _withDisplayAvatar(UserProfileData.fromJson(row));
  }

  @override
  Future<UserProfileData> removeAvatar() async {
    final id = _supabase.requireCurrentUserId();
    final previousPath = await _currentAvatarPath(id);
    final row = await _supabase.client
        .from('profiles')
        .update(<String, dynamic>{'avatar_url': null})
        .eq('id', id)
        .select()
        .single();
    await _removeStoredAvatar(previousPath);
    return UserProfileData.fromJson(row);
  }

  Future<String?> _currentAvatarPath(String id) async {
    final row = await _supabase.client
        .from('profiles')
        .select('avatar_url')
        .eq('id', id)
        .single();
    return (row['avatar_url'] as String?)?.trim();
  }

  Future<void> _removeStoredAvatar(String? path) async {
    if (path == null ||
        path.isEmpty ||
        path.startsWith('http://') ||
        path.startsWith('https://')) {
      return;
    }
    try {
      await _supabase.client.storage.from('avatars').remove(<String>[path]);
    } catch (_) {
      // The profile is already updated; stale-file cleanup can be retried later.
    }
  }

  Future<UserProfileData> _withDisplayAvatar(UserProfileData profile) async {
    final storedValue = profile.avatarUrl?.trim();
    if (storedValue == null || storedValue.isEmpty) return profile;
    final displayUrl =
        storedValue.startsWith('http://') || storedValue.startsWith('https://')
        ? storedValue
        : await _supabase.client.storage
              .from('avatars')
              .createSignedUrl(storedValue, 3600);
    return UserProfileData(
      id: profile.id,
      name: profile.name,
      bio: profile.bio,
      avatarUrl: displayUrl,
      explorerLevel: profile.explorerLevel,
      xp: profile.xp,
      streakDays: profile.streakDays,
      trips: profile.trips,
    );
  }

  @override
  Future<List<BadgeData>> getAchievements() async {
    final id = _supabase.requireCurrentUserId();
    await _supabase.client.rpc('evaluate_my_achievements');
    final rows = await _supabase.client
        .from('achievements')
        .select(
          'id, name, description, rarity, xp_reward, icon_code, '
          'requirement_value, user_achievements!left(progress, unlocked_at)',
        )
        .eq('user_achievements.user_id', id)
        .order('sort_order');

    return (rows as List<dynamic>).map((dynamic value) {
      final row = value as Map<String, dynamic>;
      final joined = row['user_achievements'] as List<dynamic>? ?? const [];
      final state = joined.isEmpty
          ? const <String, dynamic>{}
          : joined.first as Map<String, dynamic>;
      return BadgeData(
        id: row['id'] as String,
        title: row['name'] as String,
        description: row['description'] as String,
        rarity: row['rarity'] as String,
        xp: (row['xp_reward'] as num).toInt(),
        unlocked: state['unlocked_at'] != null,
        icon: (row['icon_code'] as num?)?.toInt() ?? 0xe3d9,
        progress: (state['progress'] as num?)?.toInt() ?? 0,
        requirementValue: (row['requirement_value'] as num?)?.toInt() ?? 1,
        unlockedAt: DateTime.tryParse(state['unlocked_at']?.toString() ?? ''),
      );
    }).toList();
  }

  @override
  Future<List<PassportStampData>> getPassportStamps() async {
    final id = _supabase.requireCurrentUserId();
    final rows = await _supabase.client
        .from('user_passport_stamps')
        .select('id, earned_at, destinations!inner(name)')
        .eq('user_id', id)
        .order('earned_at', ascending: false);

    return (rows as List<dynamic>).map((dynamic value) {
      final row = value as Map<String, dynamic>;
      final destination = row['destinations'] as Map<String, dynamic>;
      return PassportStampData(
        id: row['id'] as String,
        destinationName: destination['name'] as String,
        earnedAt: DateTime.parse(row['earned_at'] as String),
      );
    }).toList();
  }
}
