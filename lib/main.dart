import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'ui_layer/View/app_shell_view.dart';
import 'ui_layer/ViewModel/app_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter framework error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    debugPrint('Uncaught application error: $error\n$stackTrace');
    return true;
  };

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'Missing Supabase configuration. Start Flutter with '
      '--dart-define=SUPABASE_URL=<url> and '
      '--dart-define=SUPABASE_ANON_KEY=<public-anon-or-publishable-key>.',
    );
  }

  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
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
