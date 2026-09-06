import 'package:flutter/widgets.dart';

class AppLocalization {
  const AppLocalization(this.locale);

  final Locale locale;

  static AppLocalization of(BuildContext context) =>
      AppLocalization(Localizations.localeOf(context));

  static const Map<String, Map<String, String>> _values = {
    'ms': {
      'Discover': 'Terokai',
      'Map': 'Peta',
      'Mystery': 'Misteri',
      'Plan': 'Pelan',
      'Profile': 'Profil',
      'Language': 'Bahasa',
      'Language Settings': 'Tetapan Bahasa',
      'Back': 'Kembali',
      'Create plan': 'Cipta pelan',
      'Export PDF': 'Eksport PDF',
    },
    'zh': {
      'Discover': '探索',
      'Map': '地图',
      'Mystery': '神秘之旅',
      'Plan': '行程',
      'Profile': '个人资料',
      'Language': '语言',
      'Language Settings': '语言设置',
      'Back': '返回',
      'Create plan': '创建行程',
      'Export PDF': '导出 PDF',
    },
  };

  String text(String english) =>
      _values[locale.languageCode]?[english] ?? english;
}

extension LocalizedBuildContext on BuildContext {
  String tr(String english) => AppLocalization.of(this).text(english);
}
