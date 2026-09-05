import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  const SupabaseService({this.clientOverride});

  final SupabaseClient? clientOverride;

  SupabaseClient get client => clientOverride ?? Supabase.instance.client;

  Session? get currentSession => client.auth.currentSession;

  User? get currentUser => client.auth.currentUser;

  String? get currentUserId => currentUser?.id;

  bool get isAuthenticated => currentUser != null;

  bool get hasCurrentSession => currentSession != null;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<void> requestPasswordReset({
    required String email,
    required String redirectTo,
  }) => client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);

  Future<void> updatePassword(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> signOutLocal() =>
      client.auth.signOut(scope: SignOutScope.local);

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String redirectTo,
    required Map<String, dynamic> data,
  }) => client.auth.signUp(
    email: email,
    password: password,
    emailRedirectTo: redirectTo,
    data: data,
  );

  Future<void> resendSignupConfirmation({
    required String email,
    required String redirectTo,
  }) => client.auth.resend(
    type: OtpType.signup,
    email: email,
    emailRedirectTo: redirectTo,
  );

  Future<void> signOut() => client.auth.signOut();

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) => client.auth.signInWithPassword(email: email, password: password);

  String requireCurrentUserId() {
    final id = currentUserId;
    if (id == null) {
      throw const AuthException(
        'Please sign in before starting a Mystery Journey.',
      );
    }
    return id;
  }

  Future<bool> canReadDestinations() async {
    await client.from('destinations').select('id').limit(1);
    return true;
  }

  Future<Map<String, dynamic>?> getQuestCompletionByOsmId({
    required String userId,
    required String osmId,
  }) => client
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
    await client.storage
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
    final response = await client.rpc(
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
    await client.storage.from('quest-photos').remove(<String>[path]);
  }
}
