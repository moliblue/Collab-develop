import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Service Managers/Remote Services/supabase_service.dart';

class AuthRepository {
  AuthRepository({SupabaseService? service})
    : _service = service ?? SupabaseService();

  final SupabaseService _service;

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _service.signInWithPassword(
        email: email,
        password: password,
      );
      final session = response.session ?? _service.currentSession;
      final user = response.user ?? _service.currentUser;
      if (session == null || user == null) {
        return 'Login did not create an authenticated session.';
      }

      debugPrint('Supabase authentication successful');
      debugPrint('Supabase currentUser.id: ${user.id}');
      await _runDatabaseConnectionTest();
      return null;
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials')) {
        return 'Either email or password is incorrect.';
      }
      if (message.contains('network') || message.contains('fetch')) {
        return 'Unable to connect to the authentication service.';
      }
      return 'Authentication failed. Please try again.';
    } catch (error) {
      debugPrint('Supabase authentication connection error: $error');
      return 'Unable to connect to the authentication service.';
    }
  }

  Future<void> _runDatabaseConnectionTest() async {
    try {
      final rowCount = await _service.testHeritageQuestsRead();
      debugPrint('Supabase heritage_quests test successful: $rowCount rows');
    } catch (error) {
      debugPrint('Supabase heritage_quests test failed: $error');
    }
  }
}
