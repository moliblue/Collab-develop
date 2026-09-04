import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  const SupabaseService({this.clientOverride});

  final SupabaseClient? clientOverride;

  SupabaseClient get client => clientOverride ?? Supabase.instance.client;

  User? get currentUser => client.auth.currentUser;

  String? get currentUserId => currentUser?.id;

  bool get isAuthenticated => currentUser != null;

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
}
