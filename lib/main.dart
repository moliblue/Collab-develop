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
  const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
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

  runApp(const FindItMyApp());
}

class FindItMyApp extends StatelessWidget {
  const FindItMyApp({super.key, this.viewModel, this.appViewModel});

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
