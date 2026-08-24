import 'package:findit_my/main.dart';
import 'package:findit_my/ui_layer/ViewModel/app_view_model.dart';
import 'package:findit_my/ui_layer/ViewModel/collaborative_planning_view_model.dart';
import 'package:findit_my/data_layer/Models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AppViewModel> pumpApp(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    AppViewModel? viewModel,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final model = viewModel ?? AppViewModel();
    await tester.pumpWidget(FindItMyApp(appViewModel: model));
    await tester.pump(const Duration(milliseconds: 400));
    return model;
  }

  testWidgets('shared shell switches all five primary modules', (
    WidgetTester tester,
  ) async {
    final model = await pumpApp(tester);

    const destinations = <(String, MainTab)>[
      ('tab_discover', MainTab.discover),
      ('tab_map', MainTab.map),
      ('tab_mystery', MainTab.mystery),
      ('tab_plan', MainTab.plan),
      ('tab_profile', MainTab.profile),
    ];
    for (final (key, tab) in destinations) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pump(const Duration(milliseconds: 120));
      expect(model.tab, tab);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('solo Mystery starts through the emulator tap fallback', (
    WidgetTester tester,
  ) async {
    final model = await pumpApp(tester);

    await tester.drag(
      find.byKey(const PageStorageKey<String>('mystery-home')),
      const Offset(0, -520),
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.byKey(const Key('start_mystery')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(model.mystery.stage, MysteryStage.shake);

    await tester.tap(find.byKey(const Key('tap_to_discover')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(model.mystery.stage, MysteryStage.active);
    expect(find.text('Follow the clock’s story'), findsOneWidget);
  });

  testWidgets('Discover bookmarks a place and opens its detail', (
    WidgetTester tester,
  ) async {
    final model = AppViewModel()..selectTab(MainTab.discover);
    await pumpApp(tester, viewModel: model);
    final place = model.discovery.places.firstWhere(
      (HeritagePlace item) => !item.bookmarked,
    );

    final bookmark = find.byKey(Key('bookmark_${place.id}'));
    final discoverScroll = find
        .descendant(
          of: find.byKey(const PageStorageKey<String>('discover-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(bookmark, 280, scrollable: discoverScroll);
    await tester.tap(bookmark);
    await tester.pump(const Duration(milliseconds: 120));
    expect(place.bookmarked, isTrue);

    model.discovery.select(place);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text(place.name), findsWidgets);
    expect(find.byKey(const Key('write_review')), findsOneWidget);
  });

  testWidgets('Plan exposes activity and plan creation workflows', (
    WidgetTester tester,
  ) async {
    final model = AppViewModel()..selectTab(MainTab.plan);
    await pumpApp(tester, viewModel: model);

    await tester.ensureVisible(find.byKey(const Key('open_add_activity')));
    await tester.tap(find.byKey(const Key('open_add_activity')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Add Activity Card'), findsOneWidget);
    Navigator.of(tester.element(find.text('Add Activity Card'))).pop();
    await tester.pump(const Duration(milliseconds: 250));

    model.plan.setSection(PlanSection.history);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.byKey(const Key('open_create_plan')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Create Travel Plan'), findsWidgets);
  });

  testWidgets('Profile reaches badges, login, and registration', (
    WidgetTester tester,
  ) async {
    final model = AppViewModel()..selectTab(MainTab.profile);
    await pumpApp(tester, viewModel: model);

    await tester.ensureVisible(find.byKey(const Key('open_badges')));
    await tester.tap(find.byKey(const Key('open_badges')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Travel Badges'), findsOneWidget);

    model.profile.logout();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(const Key('login_screen')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('open_register')));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.byKey(const Key('open_register')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(const Key('register_screen')), findsOneWidget);
  });

  testWidgets('compact and standard phone widths render without overflow', (
    WidgetTester tester,
  ) async {
    for (final size in <Size>[const Size(360, 800), const Size(430, 932)]) {
      await pumpApp(tester, size: size);
      expect(tester.takeException(), isNull, reason: 'failed at $size');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
