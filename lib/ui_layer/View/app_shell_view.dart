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
    ]);
    return AnimatedBuilder(
      animation: merged,
      builder: (BuildContext context, _) => PopScope(
        canPop: !vm.hasNestedScreen,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (!didPop && vm.hasNestedScreen) vm.back();
        },
        child: Scaffold(
          body: SafeArea(
            child: Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    _Header(
                      viewModel: vm,
                      onProfileSettings: () => _profileSettings(context),
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
                            places: vm.discovery.places,
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
                            onDiscover: () => vm.selectTab(MainTab.discover),
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
                  _Toast(data: vm.toast!, onDismiss: vm.dismissToast),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _profileSettings(BuildContext context) => showAppSheet<void>(
    context,
    SheetBody(
      children: <Widget>[
        const ModalTitle(
          title: 'User Profile & Settings',
          subtitle: 'Amberly · explorer@gmail.com',
          icon: Icons.person_rounded,
        ),
        const SizedBox(height: 10),
        const Center(
          child: InitialsAvatar('AM', radius: 40, color: AppColors.softBlue),
        ),
        const SizedBox(height: 8),
        const Text(
          'Amberly',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const Text(
          'Role: Admin',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: AppColors.primary),
        ),
        const SizedBox(height: 15),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _resetConfirmation(context);
          },
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Reset Demo Data'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Future<void> _resetConfirmation(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        icon: const Icon(Icons.restart_alt_rounded, color: AppColors.warning),
        title: const Text('Reset demo data?'),
        content: const Text(
          'Bookmarks, itinerary changes and active Mystery progress will return to the prototype defaults.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (yes == true) widget.viewModel.resetDemo();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.viewModel, required this.onProfileSettings});
  final AppViewModel viewModel;
  final VoidCallback onProfileSettings;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: const BoxDecoration(
      color: Color(0xFAFFFFFF),
      border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
    ),
    child: Row(
      children: <Widget>[
        if (viewModel.hasNestedScreen)
          IconButton(
            tooltip: 'Back',
            onPressed: viewModel.back,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.elevated,
              side: const BorderSide(color: AppColors.border),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 19),
          )
        else if (viewModel.tab != MainTab.plan) ...<Widget>[
          InkWell(
            onTap: () => viewModel.selectTab(MainTab.mystery),
            borderRadius: BorderRadius.circular(14),
            child: const Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.primary,
                  child: Icon(
                    Icons.explore_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Explore My',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),
                    Text(
                      '● Malaysia · explore nearby',
                      style: TextStyle(
                        fontSize: 8,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (viewModel.tab == MainTab.plan) ...<Widget>[
          const SizedBox(width: 7),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: viewModel.plan.planName,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
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
          if (viewModel.plan.hasConflict)
            IconButton(
              tooltip: 'Time conflict',
              onPressed: () => viewModel.showToast(
                'Open the itinerary conflict control to auto-adjust.',
                AppColors.warning,
              ),
              icon: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 19,
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
        ] else
          const Spacer(),
        IconButton(
          tooltip: 'Profile settings',
          onPressed: onProfileSettings,
          style: IconButton.styleFrom(backgroundColor: AppColors.elevated),
          icon: const InitialsAvatar(
            'AM',
            radius: 14,
            color: AppColors.softBlue,
          ),
        ),
      ],
    ),
  );
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({required this.viewModel});
  final AppViewModel viewModel;
  @override
  Widget build(BuildContext context) {
    const tabs = <(MainTab, String, IconData)>[
      (MainTab.discover, 'Discover', Icons.search_rounded),
      (MainTab.map, 'Map', Icons.map_rounded),
      (MainTab.mystery, 'Mystery', Icons.explore_rounded),
      (MainTab.plan, 'Plan', Icons.calendar_month_rounded),
      (MainTab.profile, 'Profile', Icons.person_rounded),
    ];
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(5, 6, 5, 7),
      decoration: const BoxDecoration(
        color: Color(0xFCFFFFFF),
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x112A435C),
            blurRadius: 25,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: tabs.map(((MainTab, String, IconData) item) {
          final (tab, label, icon) = item;
          final active = viewModel.tab == tab;
          final mystery = tab == MainTab.mystery;
          if (mystery) {
            return Expanded(
              child: Transform.translate(
                offset: const Offset(0, -9),
                child: InkWell(
                  key: const Key('tab_mystery'),
                  onTap: () => viewModel.selectTab(tab),
                  borderRadius: BorderRadius.circular(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Badge(
                        isLabelVisible: viewModel.mystery.journeyActive,
                        label: const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 6,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        backgroundColor: const Color(0xFF70E0B5),
                        textColor: const Color(0xFF155842),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x482F80ED),
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.explore_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: active ? AppColors.primary : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return Expanded(
            child: InkWell(
              key: Key('tab_${label.toLowerCase()}'),
              onTap: () => viewModel.selectTab(tab),
              borderRadius: BorderRadius.circular(17),
              child: Container(
                height: 53,
                decoration: BoxDecoration(
                  color: active ? AppColors.softBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                  border: active
                      ? Border.all(color: const Color(0xFFD7E8FF))
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      icon,
                      size: 21,
                      color: active ? AppColors.primary : AppColors.muted,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                        color: active ? AppColors.primary : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
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
