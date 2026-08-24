import 'package:flutter/foundation.dart';

class AuthViewModel extends ChangeNotifier {
  bool _busy = false;
  bool _recoverySent = false;
  bool get busy => _busy;
  bool get recoverySent => _recoverySent;

  Future<String?> login(String email, String password) async {
    final format = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (email.trim().isEmpty || password.isEmpty) {
      return 'Please fill in both fields.';
    }
    if (!format.hasMatch(email.trim())) return 'Invalid email format.';
    if (password.length < 8) return 'Password must be at least 8 characters.';
    _busy = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _busy = false;
    notifyListeners();
    if (email.trim().toLowerCase() != 'explorer@gmail.com' ||
        password != 'Password123!') {
      return 'Either email or password is incorrect.';
    }
    return null;
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
    ].any((String value) => value.trim().isEmpty)) {
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
    _busy = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _busy = false;
    notifyListeners();
    return null;
  }

  String? recover(String email) {
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid registered email address.';
    }
    _recoverySent = true;
    notifyListeners();
    return null;
  }

  void resetRecovery() {
    _recoverySent = false;
    notifyListeners();
  }
}
