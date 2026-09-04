import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService({SupabaseClient? client}) : _injectedClient = client;

  final SupabaseClient? _injectedClient;
  SupabaseClient get _client => _injectedClient ?? Supabase.instance.client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) => _client.auth.signInWithPassword(email: email, password: password);

  Future<int> testHeritageQuestsRead() async {
    final rows = await _client.from('heritage_quests').select();
    return rows.length;
  }

  Future<Map<String, dynamic>?> getQuestCompletionByOsmId({
    required String userId,
    required String osmId,
  }) => _client
      .from('quest_completions')
      .select('id, photo_path')
      .eq('user_id', userId)
      .eq('osm_id', osmId)
      .maybeSingle();

  Future<void> uploadQuestPhoto({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _client.storage
        .from('quest-photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
  }

  Future<Map<String, dynamic>> completePictureQuest({
    required String osmId,
    required String locationName,
    required double latitude,
    required double longitude,
    required String photoPath,
    required String? caption,
  }) async {
    final response = await _client.rpc(
      'complete_picture_quest',
      params: <String, dynamic>{
        'p_osm_id': osmId,
        'p_location_name': locationName,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_photo_path': photoPath,
        'p_caption': caption,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> removeQuestPhoto(String path) async {
    await _client.storage.from('quest-photos').remove(<String>[path]);
  }
}
