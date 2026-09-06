import 'package:findit_my/core/localization/app_localization.dart';
import 'package:findit_my/core/localization/localized_text.dart' as localized;
import 'package:flutter/material.dart' as material;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all supported locales translate replay actions', () {
    for (final code in <String>['ms', 'zh', 'ta']) {
      final localization = AppLocalization(Locale(code));
      expect(
        localization.text('Revisit Challenge'),
        isNot('Revisit Challenge'),
      );
      expect(
        localization.text('Shake Again for a New Place'),
        isNot('Shake Again for a New Place'),
      );
      expect(
        localization.text("You've explored this place before."),
        isNot("You've explored this place before."),
      );
    }
  });

  test('dynamic localization handles countdowns and counts', () {
    const chinese = AppLocalization(Locale('zh'));
    expect(chinese.text('Resend available in 42s'), '42秒后可重新发送');
    expect(chinese.text('981 m away'), '距离 981 米');
    expect(chinese.text('Explored 2 times'), '已探索 2 次');
    expect(chinese.text('3 reviews'), '3 条评价');
    expect(chinese.text('Completed on 6 Sep 2026'), '完成于 6 Sep 2026');
    expect(chinese.text('2 members ready'), '2 位成员已准备');
    expect(chinese.text('Within 15 km'), '15 公里以内');
    expect(chinese.text('Group Shake — 1/2 shaken'), '群组摇动 — 1/2 已完成');
  });

  test('database and user content stays unchanged', () {
    const chinese = AppLocalization(Locale('zh'));
    expect(chinese.text('Kwai Chai Hong'), 'Kwai Chai Hong');
    expect(
      chinese.text('A traveller-written review'),
      'A traveller-written review',
    );
  });

  testWidgets('changing locale updates visible system text', (tester) async {
    Future<void> pumpLocale(String languageCode) => tester.pumpWidget(
      material.MaterialApp(
        locale: Locale(languageCode),
        supportedLocales: const <Locale>[
          Locale('en'),
          Locale('ms'),
          Locale('zh'),
          Locale('ta'),
        ],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const localized.Text('Shake Again for a New Place'),
      ),
    );

    await pumpLocale('zh');
    expect(find.text('再次摇动寻找新地点'), findsOneWidget);
    await pumpLocale('ms');
    expect(find.text('Goncang Lagi untuk Tempat Baharu'), findsOneWidget);
  });
}
