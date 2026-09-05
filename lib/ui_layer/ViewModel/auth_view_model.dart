import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data_layer/Service Managers/Remote Services/supabase_service.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({SupabaseService? supabaseService})
    : _supabase = supabaseService ?? const SupabaseService() {
    try {
      _authSubscription = _supabase.client.auth.onAuthStateChange.listen((
        AuthState state,
      ) {
        if (_pendingVerificationEmail != null &&
            state.event == AuthChangeEvent.signedIn) {
          unawaited(_finishEmailConfirmation());
        } else if (!_disposed) {
          notifyListeners();
        }
      });
    } on StateError {
      // Widget tests can provide a fake authentication state without
      // initializing the global Supabase client.
    }
  }

  final SupabaseService _supabase;
  StreamSubscription<AuthState>? _authSubscription;
  bool _busy = false;
  bool _recoverySent = false;
  bool _disposed = false;
  String? _pendingVerificationEmail;
  bool get busy => _busy;
  bool get recoverySent => _recoverySent;
  bool get isAuthenticated => _supabase.isAuthenticated;
  String? get currentEmail => _supabase.currentUser?.email;
  String? get pendingVerificationEmail => _pendingVerificationEmail;

  static const loginSuccessMessage = 'Login successful. Welcome back!';
  static const resetSentMessage =
      'Password reset link has been sent to your registered email address.';
  static const invalidEmailMessage =
      'Error: Invalid email format. Please re-enter a valid email (e.g. user@domain.com).';
  static const invalidPasswordMessage =
      'Error: Invalid password format. Passwords must be at least 8 characters, include an uppercase letter, and a unique symbol.';
  static const missingLoginMessage =
      'Error: Missing input field. Please fill in both fields.';
  static const emailNotFoundMessage = 'Error: Email address not found.';
  static const incorrectCredentialsMessage =
      'Error: Either email or password is incorrect. Please try again.';
  static const registrationSuccessMessage =
      'Account registered successfully! Welcome to the app.';
  static const invalidRegistrationMessage =
      'Error: Please verify registration details and try again.';
  static const duplicateRegistrationMessage =
      'Error: The email or IC number is already registered.';
  static const emailNotConfirmedMessage =
      'Error: Please confirm your email address before signing in.';

  static final RegExp _emailFormat = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
  );

  static bool isValidEmail(String value) => _emailFormat.hasMatch(value.trim());

  static bool isValidPassword(String value) =>
      value.length >= 8 &&
      RegExp(r'[A-Z]').hasMatch(value) &&
      RegExp(r'[^A-Za-z0-9\s]').hasMatch(value) &&
      !RegExp(r'\s').hasMatch(value);

  static bool isValidPhone(String value) =>
      RegExp(r'^\d{10,11}$').hasMatch(value.trim());

  static bool isValidIc(String value) =>
      RegExp(r'^\d{12}$').hasMatch(value.trim());

  Future<String?> login(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      return missingLoginMessage;
    }
    if (!isValidEmail(email)) return invalidEmailMessage;
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
    required DateTime? birthday,
  }) async {
    if (<String>[
      name,
      email,
      password,
      confirmation,
      phone,
      ic,
    ].any((value) => value.trim().isEmpty)) {
      return invalidRegistrationMessage;
    }
    if (name.trim().length < 3 || name.trim().length > 30) {
      return invalidRegistrationMessage;
    }
    if (!isValidEmail(email) ||
        !isValidPassword(password) ||
        password != confirmation ||
        !isValidPhone(phone) ||
        !isValidIc(ic) ||
        birthday == null) {
      return invalidRegistrationMessage;
    }
    return _run(() async {
      final response = await _supabase.client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: _emailRedirectTo,
        data: <String, dynamic>{
          'display_name': name.trim(),
          'full_name': name.trim(),
          'phone': phone.trim(),
          'ic': ic.trim(),
          'birth_date': _dateOnly(birthday),
        },
      );
      if (response.user == null) {
        throw const AuthException('Account creation did not return a user.');
      }
      if (response.user!.identities?.isEmpty ?? false) {
        throw const AuthException(duplicateRegistrationMessage);
      }
      _pendingVerificationEmail = email.trim();
    });
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<String?> resendVerificationEmail() async {
    final email = _pendingVerificationEmail;
    if (email == null) return 'Please register again to request a new code.';
    return _run(() async {
      await _supabase.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: _emailRedirectTo,
      );
    });
  }

  String? get _emailRedirectTo {
    const configured = String.fromEnvironment('AUTH_REDIRECT_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) return '${Uri.base.origin}/';
    return 'com.finditmy.findit_my://login-callback/';
  }

  Future<void> _finishEmailConfirmation() async {
    await _supabase.client.auth.signOut(scope: SignOutScope.local);
    _pendingVerificationEmail = null;
    if (!_disposed) notifyListeners();
  }

  void cancelVerification() {
    _pendingVerificationEmail = null;
    notifyListeners();
  }

  Future<String?> recover(String email) async {
    if (!isValidEmail(email)) return invalidEmailMessage;
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
    _pendingVerificationEmail = null;
    notifyListeners();
  }

  Future<String?> _run(Future<void> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      await action();
      return null;
    } on AuthException catch (error) {
      return _friendlyAuthError(error.message);
    } catch (_) {
      return 'Authentication service is unavailable. Please try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  String _friendlyAuthError(String message) {
    final normalized = message.toLowerCase();
    if (message == duplicateRegistrationMessage ||
        normalized.contains('already registered') ||
        normalized.contains('duplicate key') ||
        normalized.contains('database error saving new user')) {
      return duplicateRegistrationMessage;
    }
    if (message == emailNotFoundMessage) return emailNotFoundMessage;
    if (normalized.contains('email not confirmed')) {
      return emailNotConfirmedMessage;
    }
    if (normalized.contains('invalid login credentials')) {
      return incorrectCredentialsMessage;
    }
    return message;
  }

  void resetRecovery() {
    _recoverySent = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final subscription = _authSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }
}
