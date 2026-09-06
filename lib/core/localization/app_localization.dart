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
      'Edit profile': 'Sunting profil',
      'Photo, name and travel bio': 'Foto, nama dan biodata perjalanan',
      'Achievements & badges': 'Pencapaian & lencana',
      'Challenges, progress and rewards': 'Cabaran, kemajuan dan ganjaran',
      'Passport stamps': 'Cop pasport',
      'Your verified destination collection': 'Koleksi destinasi disahkan anda',
      'Log out': 'Log keluar',
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
      'Edit profile': '编辑个人资料',
      'Photo, name and travel bio': '照片、姓名和旅行简介',
      'Achievements & badges': '成就与徽章',
      'Challenges, progress and rewards': '挑战、进度和奖励',
      'Passport stamps': '护照印章',
      'Your verified destination collection': '您已验证的目的地收藏',
      'Log out': '退出登录',
    },
    'ta': {
      'Discover': 'கண்டறியுங்கள்',
      'Map': 'வரைபடம்',
      'Mystery': 'மர்மப் பயணம்',
      'Plan': 'திட்டம்',
      'Profile': 'சுயவிவரம்',
      'Language': 'மொழி',
      'Language Settings': 'மொழி அமைப்புகள்',
      'Back': 'பின்செல்',
      'Create plan': 'திட்டம் உருவாக்கு',
      'Export PDF': 'PDF ஏற்றுமதி',
      'Edit profile': 'சுயவிவரத்தைத் திருத்து',
      'Photo, name and travel bio': 'படம், பெயர் மற்றும் பயணக் குறிப்பு',
      'Achievements & badges': 'சாதனைகள் & பதக்கங்கள்',
      'Challenges, progress and rewards':
          'சவால்கள், முன்னேற்றம் மற்றும் வெகுமதிகள்',
      'Passport stamps': 'கடவுச்சீட்டு முத்திரைகள்',
      'Your verified destination collection':
          'உங்கள் சரிபார்க்கப்பட்ட இடங்களின் தொகுப்பு',
      'Log out': 'வெளியேறு',
    },
  };

  String text(String english) =>
      _values[locale.languageCode]?[english] ?? english;
}

extension LocalizedBuildContext on BuildContext {
  String tr(String english) => AppLocalization.of(this).text(english);
}
