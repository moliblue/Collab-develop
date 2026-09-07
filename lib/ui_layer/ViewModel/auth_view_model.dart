import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data_layer/Service Managers/Remote Services/supabase_service.dart';

enum IdentityType { ic, passport }

class AuthRedirectResolver {
  const AuthRedirectResolver._();

  static const androidCallback = 'finditmy://login-callback/';
  static const localhostWebCallback = 'http://localhost:8080/';

  static String resolve({
    String configured = const String.fromEnvironment('AUTH_REDIRECT_URL'),
    bool? web,
    Uri? baseUri,
  }) {
    if (configured.trim().isNotEmpty) return configured.trim();
    if (web ?? kIsWeb) {
      final origin = (baseUri ?? Uri.base).origin;
      return origin.endsWith('/') ? origin : '$origin/';
    }
    return androidCallback;
  }
}

enum AuthNoticeKind { success, error }

class AuthNotice {
  const AuthNotice(this.message, this.kind);
  final String message;
  final AuthNoticeKind kind;
}

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({
    SupabaseService? supabaseService,
    this.verificationResendCooldownSeconds = 60,
    this.verificationResendTick = const Duration(seconds: 1),
    AuthNotice? initialNotice,
    bool initialPasswordRecovery = false,
    bool initialRecoveryError = false,
  }) : _supabase = supabaseService ?? const SupabaseService(),
       _authNotice = initialNotice,
       _passwordRecovery = initialPasswordRecovery,
       _recoveryError = initialRecoveryError
           ? invalidRecoverySessionMessage
           : null {
    try {
      _authSubscription = _supabase.authStateChanges.listen(
        _handleAuthState,
        onError: _handleAuthStateError,
      );
    } on StateError {
      // Widget tests can provide a fake authentication state without
      // initializing the global Supabase client.
    }
  }

  final SupabaseService _supabase;
  final int verificationResendCooldownSeconds;
  final Duration verificationResendTick;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _verificationResendTimer;
  bool _busy = false;
  bool _recoverySent = false;
  bool _passwordRecovery;
  bool _disposed = false;
  String? _pendingVerificationEmail;
  String? _recoveryError;
  String? _verificationError;
  AuthNotice? _authNotice;
  int _verificationResendSecondsRemaining = 0;
  IdentityType _selectedIdentityType = IdentityType.ic;
  String _selectedIssuingCountry = 'MY';
  bool get busy => _busy;
  bool get recoverySent => _recoverySent;
  bool get isPasswordRecovery => _passwordRecovery;
  bool get shouldShowResetPassword =>
      _passwordRecovery || _recoveryError != null;
  String? get recoveryError => _recoveryError;
  String? get verificationError => _verificationError;
  bool get isAuthenticated => _supabase.isAuthenticated;
  String? get currentEmail => _supabase.currentUser?.email;
  String? get pendingVerificationEmail => _pendingVerificationEmail;
  bool get hasAuthNotice => _authNotice != null;
  int get verificationResendSecondsRemaining =>
      _verificationResendSecondsRemaining;
  bool get canResendVerification =>
      _pendingVerificationEmail != null &&
      _verificationResendSecondsRemaining == 0 &&
      !_busy;
  String get verificationResendLabel => _verificationResendSecondsRemaining > 0
      ? 'Resend available in ${_verificationResendSecondsRemaining}s'
      : 'Resend confirmation email';
  IdentityType get selectedIdentityType => _selectedIdentityType;
  String get selectedIssuingCountry => _selectedIssuingCountry;

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
      'Account created. Please verify your email to continue.';
  static const invalidRegistrationMessage =
      'Error: Please verify registration details and try again.';
  static const duplicateRegistrationMessage =
      'Error: The email or identification number is already registered.';
  static const genericRegistrationErrorMessage =
      'Registration could not be completed. Please try again.';
  static const emailRateLimitMessage =
      'Too many authentication emails were requested. Please wait about one hour and try again.';
  static const confirmationEmailFailureMessage =
      'We could not send the confirmation email. Please try again later or contact the project administrator.';
  static const emailNotConfirmedMessage =
      'Error: Please confirm your email address before signing in.';
  static const passwordsDoNotMatchMessage =
      'Error: New password and confirmation do not match.';
  static const invalidRecoverySessionMessage =
      'This password reset link is invalid, expired, or has already been used.';
  static const resetSuccessMessage =
      'Password reset successfully. Please sign in with your new password.';
  static const verificationSuccessMessage =
      'Email verified successfully. Welcome to ExploreMY!';
  static const invalidVerificationLinkMessage =
      'This verification link is invalid or expired. Please request a new confirmation email.';

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
      RegExp(r'^\d{12}$').hasMatch(normalizeIc(value));

  static String normalizeIc(String value) =>
      value.trim().replaceAll(RegExp(r'[\s-]'), '');

  static String normalizePassport(String value) =>
      value.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  static bool isValidPassport(String value) =>
      RegExp(r'^[A-Z0-9]{5,20}$').hasMatch(normalizePassport(value));

  static bool isValidCountryCode(String value) =>
      RegExp(r'^[A-Z]{2}$').hasMatch(value.trim().toUpperCase());

  void selectIdentityType(IdentityType type) {
    if (_selectedIdentityType == type) return;
    _selectedIdentityType = type;
    if (type == IdentityType.ic) _selectedIssuingCountry = 'MY';
    notifyListeners();
  }

  void selectIssuingCountry(String countryCode) {
    final normalized = countryCode.trim().toUpperCase();
    if (_selectedIdentityType != IdentityType.passport ||
        !isValidCountryCode(normalized) ||
        _selectedIssuingCountry == normalized) {
      return;
    }
    _selectedIssuingCountry = normalized;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      return missingLoginMessage;
    }
    if (!isValidEmail(email)) return invalidEmailMessage;
    return _run(() async {
      await _supabase.signInWithPassword(
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
    required String identityNumber,
    required DateTime? birthday,
  }) async {
    if (<String>[
      name,
      email,
      password,
      confirmation,
      phone,
      identityNumber,
    ].any((value) => value.trim().isEmpty)) {
      return invalidRegistrationMessage;
    }
    if (name.trim().length < 3 || name.trim().length > 30) {
      return invalidRegistrationMessage;
    }
    final identityType = _selectedIdentityType;
    final normalizedIdentity = identityType == IdentityType.ic
        ? normalizeIc(identityNumber)
        : normalizePassport(identityNumber);
    final issuingCountry = identityType == IdentityType.ic
        ? 'MY'
        : _selectedIssuingCountry.trim().toUpperCase();
    final identityIsValid = identityType == IdentityType.ic
        ? isValidIc(normalizedIdentity)
        : isValidPassport(normalizedIdentity) &&
              isValidCountryCode(issuingCountry);
    if (!isValidEmail(email) ||
        !isValidPassword(password) ||
        password != confirmation ||
        !isValidPhone(phone) ||
        !identityIsValid ||
        birthday == null) {
      return invalidRegistrationMessage;
    }
    return _run(() async {
      final response = await _supabase.register(
        email: email.trim(),
        password: password,
        redirectTo: authRedirectUrl,
        data: <String, dynamic>{
          'username': name.trim(),
          'display_name': name.trim(),
          'full_name': name.trim(),
          'phone': phone.trim(),
          'identity_type': identityType.name,
          'identity_number': normalizedIdentity,
          'issuing_country': issuingCountry,
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
      _verificationError = null;
      _startVerificationResendCooldown();
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
    if (_busy) return 'Please wait for the current request to finish.';
    if (_verificationResendSecondsRemaining > 0) {
      return verificationResendLabel;
    }
    final error = await _run(() async {
      await _supabase.resendSignupConfirmation(
        email: email,
        redirectTo: authRedirectUrl,
      );
    });
    if (error == null) {
      _verificationError = null;
      _startVerificationResendCooldown();
    }
    return error;
  }

  String get authRedirectUrl => AuthRedirectResolver.resolve();

  Future<void> _finishEmailConfirmation() async {
    _pendingVerificationEmail = null;
    _verificationError = null;
    _verificationResendTimer?.cancel();
    _verificationResendSecondsRemaining = 0;
    _authNotice = const AuthNotice(
      verificationSuccessMessage,
      AuthNoticeKind.success,
    );
    if (!_disposed) notifyListeners();
  }

  void cancelVerification() {
    _pendingVerificationEmail = null;
    _verificationError = null;
    _verificationResendTimer?.cancel();
    _verificationResendSecondsRemaining = 0;
    notifyListeners();
  }

  AuthNotice? takeAuthNotice() {
    final notice = _authNotice;
    _authNotice = null;
    return notice;
  }

  void reportInvalidVerificationLink() {
    _passwordRecovery = false;
    _recoveryError = null;
    _verificationError = invalidVerificationLinkMessage;
    _authNotice = const AuthNotice(
      invalidVerificationLinkMessage,
      AuthNoticeKind.error,
    );
    if (!_disposed) notifyListeners();
  }

  Future<String?> recover(String email) async {
    if (!isValidEmail(email)) return invalidEmailMessage;
    final error = await _run(
      () => _supabase.requestPasswordReset(
        email: email.trim(),
        redirectTo: authRedirectUrl,
      ),
    );
    if (error == null) {
      _recoverySent = true;
      notifyListeners();
    }
    return error;
  }

  Future<String?> resetPassword(String password, String confirmation) async {
    if (!isValidPassword(password)) return invalidPasswordMessage;
    if (password != confirmation) return passwordsDoNotMatchMessage;
    if (!_passwordRecovery || !_supabase.hasCurrentSession) {
      _recoveryError = invalidRecoverySessionMessage;
      notifyListeners();
      return invalidRecoverySessionMessage;
    }
    final error = await _run(() async {
      await _supabase.updatePassword(password);
      await _supabase.signOutLocal();
    });
    if (error == null) {
      _passwordRecovery = false;
      _recoverySent = false;
      _recoveryError = null;
      notifyListeners();
    }
    return error;
  }

  Future<void> logout() async {
    await _supabase.signOut();
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
      return _friendlyAuthError(error);
    } catch (_) {
      return 'Authentication service is unavailable. Please try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  String _friendlyAuthError(AuthException error) {
    final message = error.message;
    final normalized = message.toLowerCase();
    if (normalized.contains('rate limit') ||
        normalized.contains('over_email_send_rate_limit')) {
      return emailRateLimitMessage;
    }
    if (normalized.contains('error sending confirmation email') ||
        normalized.contains('email address not authorized') ||
        normalized.contains('smtp')) {
      return confirmationEmailFailureMessage;
    }
    if (message == duplicateRegistrationMessage ||
        normalized.contains('already registered') ||
        normalized.contains('duplicate key') ||
        normalized.contains('user already registered')) {
      return duplicateRegistrationMessage;
    }
    if (normalized.contains('database error saving new user')) {
      return genericRegistrationErrorMessage;
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
    _recoveryError = null;
    notifyListeners();
  }

  Future<void> cancelPasswordRecovery() async {
    if (_supabase.hasCurrentSession) await _supabase.signOutLocal();
    _passwordRecovery = false;
    _recoverySent = false;
    _recoveryError = null;
    if (!_disposed) notifyListeners();
  }

  void _handleAuthState(AuthState state) {
    if (state.event == AuthChangeEvent.passwordRecovery) {
      _passwordRecovery = state.session != null;
      _recoverySent = false;
      _recoveryError = state.session == null
          ? invalidRecoverySessionMessage
          : null;
    } else if (_pendingVerificationEmail != null &&
        state.event == AuthChangeEvent.signedIn) {
      unawaited(_finishEmailConfirmation());
      return;
    }
    if (!_disposed) notifyListeners();
  }

  void _handleAuthStateError(Object error, StackTrace stackTrace) {
    final message = error.toString().toLowerCase();
    if (message.contains('recovery')) {
      _passwordRecovery = false;
      _recoveryError = invalidRecoverySessionMessage;
      if (!_disposed) notifyListeners();
      return;
    }
    if (message.contains('expired') ||
        message.contains('invalid') ||
        message.contains('pkce') ||
        message.contains('auth code')) {
      reportInvalidVerificationLink();
    }
  }

  void _startVerificationResendCooldown() {
    _verificationResendTimer?.cancel();
    _verificationResendSecondsRemaining = verificationResendCooldownSeconds;
    if (_verificationResendSecondsRemaining <= 0) {
      _verificationResendSecondsRemaining = 0;
      if (!_disposed) notifyListeners();
      return;
    }
    if (!_disposed) notifyListeners();
    _verificationResendTimer = Timer.periodic(verificationResendTick, (timer) {
      if (_verificationResendSecondsRemaining <= 1) {
        _verificationResendSecondsRemaining = 0;
        timer.cancel();
      } else {
        _verificationResendSecondsRemaining--;
      }
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _verificationResendTimer?.cancel();
    final subscription = _authSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }
}
