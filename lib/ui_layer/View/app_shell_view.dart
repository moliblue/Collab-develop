import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../ViewModel/app_view_model.dart';
import '../ViewModel/collaborative_planning_view_model.dart';
import 'discover_module_view.dart';
import 'map_module_view.dart';
import 'mystery_journey_view.dart';
import 'plan_module_view.dart';
import 'profile_module_view.dart';
import 'shared/app_widgets.dart';

class AppShellView extends StatefulWidget {
  const AppShellView({super.key, required this.viewModel});
  final AppViewModel viewModel;
  @override
  State<AppShellView> createState() => _AppShellViewState();
}

class _AppShellViewState extends State<AppShellView> {
  @override
  void dispose() {
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final merged = Listenable.merge(<Listenable>[
      vm,
      vm.mystery,
      vm.discovery,
      vm.map,
      vm.plan,
      vm.profile,
      vm.auth,
    ]);
    return AnimatedBuilder(
      animation: merged,
      builder: (BuildContext context, _) => vm.requiresAuthentication
          ? PopScope(
              canPop: false,
              child: Scaffold(
                key: const Key('authentication_gate'),
                body: SafeArea(
                  child: Stack(
                    children: <Widget>[
                      ProfileModuleView(
                        viewModel: vm.profile,
                        authViewModel: vm.auth,
                        notify: vm.showToast,
                      ),
                      if (vm.toast != null)
                        _Toast(data: vm.toast!, onDismiss: vm.dismissToast),
                    ],
                  ),
                ),
              ),
            )
          : PopScope(
              canPop: !vm.hasNestedScreen,
              onPopInvokedWithResult: (bool didPop, Object? result) {
                if (!didPop && vm.hasNestedScreen) vm.back();
              },
              child: Scaffold(
                backgroundColor: const Color(0xFFEAF2F7),
                body: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: ColoredBox(
                        color: AppColors.background,
                        child: Stack(
                          children: <Widget>[
                            Column(
                              children: <Widget>[
                                _Header(
                                  viewModel: vm,
                                  onProfileTap: vm.openProfile,
                                ),
                                Expanded(
                                  child: IndexedStack(
                                    index: vm.tab.index,
                                    children: <Widget>[
                                      DiscoverModuleView(
                                        viewModel: vm.discovery,
                                        onDirections: vm.showDirections,
                                        onAddToPlan: vm.addToPlan,
                                        notify: vm.showToast,
                                      ),
                                      MapModuleView(
                                        viewModel: vm.map,
                                        active: vm.tab == MainTab.map,
                                        onBack: vm.back,
                                        onXpReward: vm.rewardXp,
                                        notify: vm.showToast,
                                      ),
                                      MysteryJourneyView(
                                        viewModel: vm.mystery,
                                        onViewPassport: vm.openPassport,
                                        onDirections: vm.showMysteryDirections,
                                        notify: vm.showToast,
                                      ),
                                      PlanModuleView(
                                        viewModel: vm.plan,
                                        bookmarks: vm.discovery.bookmarks,
                                        recommendations: vm.discovery.places,
                                        onDiscover: () =>
                                            vm.selectTab(MainTab.discover),
                                        onViewRoute: vm.showDayRoute,
                                        notify: vm.showToast,
                                      ),
                                      ProfileModuleView(
                                        viewModel: vm.profile,
                                        authViewModel: vm.auth,
                                        notify: vm.showToast,
                                      ),
                                    ],
                                  ),
                                ),
                                _BottomNavigation(viewModel: vm),
                              ],
                            ),
                            if (vm.toast != null)
                              _Toast(
                                data: vm.toast!,
                                onDismiss: vm.dismissToast,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.viewModel, required this.onProfileTap});
  final AppViewModel viewModel;
  final VoidCallback onProfileTap;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
    ),
    child: Row(
      children: <Widget>[
        if ((viewModel.hasNestedScreen && viewModel.tab != MainTab.map) ||
            viewModel.tab == MainTab.plan)
          IconButton(
            tooltip: 'Back',
            onPressed: viewModel.hasNestedScreen
                ? viewModel.back
                : () => viewModel.selectTab(MainTab.discover),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.elevated,
              side: const BorderSide(color: AppColors.border),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 19),
          )
        else ...<Widget>[
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.explore_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
        ],
        if (viewModel.tab == MainTab.plan) ...<Widget>[
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: viewModel.plan.planName,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                items: viewModel.plan.history
                    .map(
                      (String p) => DropdownMenuItem<String>(
                        value: p,
                        child: Text(p, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (String? p) {
                  if (p != null) viewModel.plan.openHistoryPlan(p);
                },
              ),
            ),
          ),
          IconButton(
            tooltip: 'Export PDF',
            onPressed: () => viewModel.showToast(
              'Use the trip export button in My trip.',
              AppColors.primary,
            ),
            icon: const Icon(Icons.download_rounded, size: 19),
          ),
          IconButton(
            tooltip: 'Create plan',
            onPressed: () => viewModel.plan.setSection(PlanSection.history),
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
          ),
        ] else ...<Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _title(viewModel.tab),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.25,
                  ),
                ),
                const Text(
                  'Explore Malaysia your way',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
        IconButton(
          tooltip: 'Open profile',
          onPressed: onProfileTap,
          style: IconButton.styleFrom(backgroundColor: AppColors.elevated),
          icon: InitialsAvatar(
            viewModel.profile.initials,
            radius: 14,
            color: AppColors.softBlue,
            imageUrl: viewModel.profile.avatarUrl,
          ),
        ),
      ],
    ),
  );

  String _title(MainTab tab) => switch (tab) {
    MainTab.discover => 'Discover',
    MainTab.map => 'Explore map',
    MainTab.mystery => 'Mystery Journey',
    MainTab.plan => 'My trip',
    MainTab.profile => 'Traveller profile',
  };
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({required this.viewModel});
  final AppViewModel viewModel;
  @override
  Widget build(BuildContext context) => NavigationBar(
    height: 68,
    selectedIndex: viewModel.tab.index,
    backgroundColor: AppColors.surface,
    indicatorColor: AppColors.softBlue,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    onDestinationSelected: (int index) =>
        viewModel.selectTab(MainTab.values[index]),
    destinations: <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.search_rounded, key: Key('tab_discover')),
        selectedIcon: Icon(Icons.travel_explore_rounded),
        label: 'Discover',
      ),
      const NavigationDestination(
        icon: Icon(Icons.map_outlined, key: Key('tab_map')),
        selectedIcon: Icon(Icons.map_rounded),
        label: 'Map',
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: viewModel.mystery.journeyActive,
          smallSize: 7,
          child: const Icon(Icons.explore_outlined, key: Key('tab_mystery')),
        ),
        selectedIcon: const Icon(Icons.explore_rounded),
        label: 'Mystery',
      ),
      const NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined, key: Key('tab_plan')),
        selectedIcon: Icon(Icons.calendar_month_rounded),
        label: 'Plan',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded, key: Key('tab_profile')),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ],
  );
}

class _Toast extends StatelessWidget {
  const _Toast({required this.data, required this.onDismiss});

  final AppToastData data;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Positioned(
    top: 10,
    left: 16,
    right: 16,
    child: SafeArea(
      bottom: false,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(5, 10, 8, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: data.color.withValues(alpha: .25)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x332A435C),
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 4,
                height: 30,
                decoration: BoxDecoration(
                  color: data.color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.info_rounded, color: data.color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, size: 17),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
