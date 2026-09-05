import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'ui_layer/View/app_shell_view.dart';
import 'ui_layer/ViewModel/app_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase returns to the web app with a one-time PKCE code after the user
  // confirms a signup email. Remember that before Supabase consumes the URL.
  final openedFromEmailConfirmation =
      kIsWeb &&
      (Uri.base.queryParameters.containsKey('code') ||
          Uri.base.fragment.contains('type=signup'));
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

  // Email confirmation proves ownership of the address; the use case still
  // requires the user to enter their credentials on the login screen.
  if (openedFromEmailConfirmation) {
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
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
