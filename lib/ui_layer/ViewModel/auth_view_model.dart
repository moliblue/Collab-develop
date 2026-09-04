import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data_layer/Service Managers/Remote Services/supabase_service.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({SupabaseService? supabaseService})
    : _supabase = supabaseService ?? const SupabaseService();

  final SupabaseService _supabase;
  bool _busy = false;
  bool _recoverySent = false;
  bool get busy => _busy;
  bool get recoverySent => _recoverySent;
  bool get isAuthenticated => _supabase.isAuthenticated;
  String? get currentEmail => _supabase.currentUser?.email;

  Future<String?> login(String email, String password) async {
    final format = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (email.trim().isEmpty || password.isEmpty) {
      return 'Please fill in both fields.';
    }
    if (!format.hasMatch(email.trim())) return 'Invalid email format.';
    if (password.length < 8) return 'Password must be at least 8 characters.';
    return _run(() async {
      await _supabase.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    });
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String confirmation,
    required String phone,
    required String ic,
  }) async {
    if (<String>[
      name,
      email,
      password,
      confirmation,
      phone,
      ic,
    ].any((value) => value.trim().isEmpty)) {
      return 'Please fill in all required fields.';
    }
    if (name.trim().length < 3 || name.trim().length > 30) {
      return 'Display name must be between 3 and 30 characters.';
    }
    if (!email.contains('@') || !email.contains('.')) {
      return 'Invalid email format.';
    }
    if (password.length < 8) return 'Password must be at least 8 characters.';
    if (password != confirmation) return 'Passwords do not match.';
    return _run(() async {
      final response = await _supabase.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: <String, dynamic>{
          'display_name': name.trim(),
          'phone': phone.trim(),
          'ic': ic.trim(),
        },
      );
      if (response.user == null) {
        throw const AuthException('Account creation did not return a user.');
      }
    });
  }

  Future<String?> recover(String email) async {
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid registered email address.';
    }
    final error = await _run(
      () => _supabase.client.auth.resetPasswordForEmail(email.trim()),
    );
    if (error == null) {
      _recoverySent = true;
      notifyListeners();
    }
    return error;
  }

  Future<void> logout() async {
    await _supabase.client.auth.signOut();
    notifyListeners();
  }

  Future<String?> _run(Future<void> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      await action();
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (_) {
      return 'Authentication service is unavailable. Please try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void resetRecovery() {
    _recoverySent = false;
    notifyListeners();
  }
}
