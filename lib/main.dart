import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'ui_layer/View/app_shell_view.dart';
import 'ui_layer/ViewModel/app_view_model.dart';
import 'ui_layer/ViewModel/auth_view_model.dart';
import 'ui_layer/ViewModel/profile_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final callbackUri = Uri.base;
  final fragmentParameters = _fragmentParameters(callbackUri.fragment);
  final callbackType =
      callbackUri.queryParameters['type'] ?? fragmentParameters['type'];
  // Remember whether the web app opened from an Auth callback before
  // Supabase consumes the one-time PKCE code.
  final openedFromAuthCallback =
      kIsWeb &&
      (callbackUri.queryParameters.containsKey('code') ||
          callbackUri.queryParameters.containsKey('error_code') ||
          fragmentParameters.containsKey('type') ||
          fragmentParameters.containsKey('error_code'));
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter framework error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    debugPrint('Uncaught application error: $error\n$stackTrace');
    return true;
  };
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    throw StateError(
      'Supabase configuration is missing. '
      'Run Flutter with --dart-define-from-file=supabase.env.json',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  AuthNotice? initialAuthNotice;
  var initialPasswordRecovery = false;
  var initialRecoveryError = false;
  // Keep a password-recovery session so the user can update their password.
  // Signup confirmation still returns to Login, as required by the app flow.
  if (openedFromAuthCallback) {
    AuthChangeEvent? callbackEvent;
    try {
      callbackEvent = await Supabase.instance.client.auth.onAuthStateChange
          .firstWhere((state) => state.event != AuthChangeEvent.initialSession)
          .then((state) => state.event)
          .timeout(const Duration(seconds: 5));
    } on Object {
      // AuthViewModel presents expired/invalid recovery links without exposing
      // the underlying Auth exception. An invalid callback has no usable session.
    }
    final hasSession = Supabase.instance.client.auth.currentSession != null;
    final isRecoveryCallback =
        callbackType == 'recovery' ||
        callbackEvent == AuthChangeEvent.passwordRecovery;
    if (isRecoveryCallback) {
      initialPasswordRecovery = hasSession;
      initialRecoveryError = !hasSession;
    } else if (hasSession) {
      initialAuthNotice = const AuthNotice(
        AuthViewModel.verificationSuccessMessage,
        AuthNoticeKind.success,
      );
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } else {
      initialAuthNotice = const AuthNotice(
        AuthViewModel.invalidVerificationLinkMessage,
        AuthNoticeKind.error,
      );
    }
  }
  runApp(
    FindItMyApp(
      initialAuthNotice: initialAuthNotice,
      initialPasswordRecovery: initialPasswordRecovery,
      initialRecoveryError: initialRecoveryError,
    ),
  );
}

Map<String, String> _fragmentParameters(String fragment) {
  if (fragment.isEmpty) return const <String, String>{};
  final query = fragment.contains('?')
      ? fragment.substring(fragment.indexOf('?') + 1)
      : fragment;
  try {
    return Uri.splitQueryString(query);
  } on FormatException {
    return const <String, String>{};
  }
}

class FindItMyApp extends StatelessWidget {
  const FindItMyApp({
    super.key,
    this.viewModel,
    this.appViewModel,
    this.initialAuthNotice,
    this.initialPasswordRecovery = false,
    this.initialRecoveryError = false,
  });

  /// Retained for compatibility with the original Shake & Find smoke test.
  /// Integrated UI state is supplied by [appViewModel] through MVVM.
  final Object? viewModel;
  final AppViewModel? appViewModel;
  final AuthNotice? initialAuthNotice;
  final bool initialPasswordRecovery;
  final bool initialRecoveryError;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
    valueListenable: ProfileViewModel.appLocale,
    builder: (context, locale, _) => MaterialApp(
      title: 'Explore My · FindIt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('ms'),
        Locale('zh'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: AppShellView(
        viewModel:
            appViewModel ??
            AppViewModel(
              authViewModel: AuthViewModel(
                initialNotice: initialAuthNotice,
                initialPasswordRecovery: initialPasswordRecovery,
                initialRecoveryError: initialRecoveryError,
              ),
            ),
      ),
    ),
  );
}
