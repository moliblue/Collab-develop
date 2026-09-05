import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'ui_layer/View/app_shell_view.dart';
import 'ui_layer/ViewModel/app_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Remember whether the web app opened from an Auth callback before
  // Supabase consumes the one-time PKCE code.
  final openedFromAuthCallback =
      kIsWeb &&
      (Uri.base.queryParameters.containsKey('code') ||
          Uri.base.fragment.contains('type='));
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

  // Keep a password-recovery session so the user can update their password.
  // Signup confirmation still returns to Login, as required by the app flow.
  if (openedFromAuthCallback) {
    AuthChangeEvent? callbackEvent;
    try {
      callbackEvent = await Supabase
          .instance
          .client
          .auth
          .onAuthStateChange
          .firstWhere((state) => state.event != AuthChangeEvent.initialSession)
          .then((state) => state.event)
          .timeout(const Duration(seconds: 5));
    } on Object {
      // AuthViewModel presents expired/invalid recovery links without exposing
      // the underlying Auth exception. An invalid callback has no usable session.
    }
    if (callbackEvent != AuthChangeEvent.passwordRecovery &&
        Supabase.instance.client.auth.currentSession != null) {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    }
  }
  runApp(const FindItMyApp());
}

class FindItMyApp extends StatelessWidget {
  const FindItMyApp({super.key, this.viewModel, this.appViewModel});

  /// Retained for compatibility with the original Shake & Find smoke test.
  /// Integrated UI state is supplied by [appViewModel] through MVVM.
  final Object? viewModel;
  final AppViewModel? appViewModel;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Explore My · FindIt',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: AppShellView(viewModel: appViewModel ?? AppViewModel()),
  );
}
