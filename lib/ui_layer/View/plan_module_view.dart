import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import '../../core/localization/localized_text.dart';
import '../../core/localization/app_localization.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../data_layer/Models/app_models.dart';
import '../ViewModel/collaborative_planning_view_model.dart';
import 'shared/app_widgets.dart';
import '../../features/collaborative_planner/models/planner_messages.dart';

Future<T?> showPlannerDialog<T>(
  BuildContext context,
  Widget child,
) => showDialog<T>(
  context: context,
  barrierColor: const Color(0x990E1B2A),
  builder: (_) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.copyWith(
        titleLarge: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 38),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
    child: Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 365),
        child: child,
      ),
    ),
  ),
);

class PlanModuleView extends StatefulWidget {
  const PlanModuleView({
    super.key,
    required this.viewModel,
    required this.bookmarks,
    required this.recommendations,
    required this.onDiscover,
    required this.onViewRoute,
    required this.notify,
  });
  final CollaborativePlanningViewModel viewModel;
  final List<HeritagePlace> bookmarks;
  final List<HeritagePlace> recommendations;
  final VoidCallback onDiscover;
  final ValueChanged<List<ActivityItem>> onViewRoute;
  final void Function(String, Color) notify;
  @override
  State<PlanModuleView> createState() => _PlanModuleViewState();
}

class _PlanModuleViewState extends State<PlanModuleView> {
  final TextEditingController _joinCode = TextEditingController();
  bool _heritageExpanded = true;
  String _heritageQuery = '';

  @override
  void dispose() {
    _joinCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.viewModel,
    builder: (BuildContext context, _) => Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 9, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F3F6),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: <Widget>[
                _tab(
                  PlanSection.workspace,
                  'My trip',
                  Icons.calendar_month_rounded,
                ),
                _tab(
                  PlanSection.history,
                  'Trips (${widget.viewModel.history.length})',
                  Icons.history_rounded,
                ),
                _tab(
                  PlanSection.groups,
                  'Travelers (${widget.viewModel.travellers.length})',
                  Icons.groups_rounded,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: switch (widget.viewModel.section) {
            PlanSection.workspace => _workspace(),
            PlanSection.history => _history(),
            PlanSection.groups => _groups(),
          },
        ),
      ],
    ),
  );

  Widget _tab(PlanSection section, String label, IconData icon) {
    final selected = widget.viewModel.section == section;
    return Expanded(
      child: InkWell(
        onTap: () => widget.viewModel.setSection(section),
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected
                ? const <BoxShadow>[
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 14,
                color: selected ? AppColors.primary : AppColors.muted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _workspace() {
    final vm = widget.viewModel;
    final day = vm.activeDay;
    return ListView(
      key: const PageStorageKey<String>('plan-workspace'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: <Widget>[
        Container(
          height: 196,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.cardRadius),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x29304F70),
                blurRadius: 30,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset('assets/sultan_abdul_samad.png', fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[Colors.transparent, Color(0xE014202C)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'UPCOMING TRIP',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const Spacer(),
                        _heroButton(
                          Icons.groups_rounded,
                          () => vm.setSection(PlanSection.groups),
                          '${vm.travellers.length}',
                        ),
                        const SizedBox(width: 6),
                        _heroButton(Icons.download_rounded, _exportSheet, null),
                      ],
                    ),
                    const Spacer(),
                    const Text(
                      'Aug 20 – Aug 23, 2026',
                      style: TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      vm.planName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Penang & Kuala Lumpur · Malaysia',
                      style: TextStyle(
                        color: Color(0xDDFFFFFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      children: <Widget>[
                        InitialsAvatar('AM', radius: 15, color: Colors.white),
                        SizedBox(width: 3),
                        InitialsAvatar(
                          'LT',
                          radius: 15,
                          color: Color(0xFFE9FAF4),
                        ),
                        Spacer(),
                        Text(
                          '2 destinations',
                          style: TextStyle(
                            color: Color(0xDDFFFFFF),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: <Widget>[
            Expanded(
              child: SizedBox(
                height: 54,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: vm.days.indexed.map(((int, PlanDay) pair) {
                    final (i, d) = pair;
                    final selected = i == vm.dayIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: InkWell(
                        onTap: () => vm.setDay(i),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 73,
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Column(
                            children: <Widget>[
                              Text(
                                d.label,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '${_month(d.date.month)} ${d.date.day}',
                                style: TextStyle(
                                  color: selected
                                      ? const Color(0xDDFFFFFF)
                                      : AppColors.muted,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 7),
            IconButton(
              key: const Key('manage_dates'),
              tooltip: 'Manage date tabs',
              onPressed: _manageDates,
              style: IconButton.styleFrom(backgroundColor: AppColors.elevated),
              icon: const Icon(
                Icons.edit_calendar_rounded,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        InkWell(
          key: const Key('view_day_route'),
          onTap: day.activities.isEmpty
              ? null
              : () {
                  widget.notify(
                    PlannerMessages.redirectRoute(vm.dayIndex + 1),
                    AppColors.primary,
                  );
                  widget.onViewRoute(day.activities);
                },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.textPrimary),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.route_rounded, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'View ${day.label} Route',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Current location · ${day.activities.length} scheduled stops · auto-sorted by time',
                        style: const TextStyle(
                          fontSize: 8,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFFF5F4A),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: SectionTitle(
                '${day.label} itinerary',
                subtitle: '${day.activities.length} activity cards',
              ),
            ),
            IconButton(
              key: const Key('open_add_activity'),
              tooltip: 'Add Activity',
              onPressed: () => _activitySheet(),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (vm.hasConflict) ...<Widget>[
          InkWell(
            onTap: _conflictSheet,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E5),
                border: Border.all(color: const Color(0xFFF1C768)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          PlannerMessages.conflict(vm.conflictCount),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          PlannerMessages.conflictPrompt,
                          style: TextStyle(
                            fontSize: 8,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
        ],
        if (day.activities.isEmpty)
          EmptyState(
            icon: Icons.view_agenda_outlined,
            title: 'This day is wide open',
            message: 'Add an activity card or choose a saved heritage place.',
            action: FilledButton(
              onPressed: () => _activitySheet(),
              child: const Text('Add Activity'),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: day.activities.length,
            onReorderItem: vm.reorder,
            itemBuilder: (BuildContext context, int i) => Padding(
              key: ValueKey<String>(day.activities[i].id),
              padding: const EdgeInsets.only(bottom: 9),
              child: _ActivityCard(
                index: i,
                item: day.activities[i],
                onEdit: () => _activitySheet(day.activities[i]),
                onDelete: () => _deleteActivity(day.activities[i]),
              ),
            ),
          ),
        const SizedBox(height: 8),
        _heritageRecommendations(day),
      ],
    );
  }

  Widget _heritageRecommendations(PlanDay day) {
    final vm = widget.viewModel;
    final query = _heritageQuery.toLowerCase();
    final places =
        (widget.recommendations
                .where(
                  (p) =>
                      query.isEmpty ||
                      p.name.toLowerCase().contains(query) ||
                      p.state.toLowerCase().contains(query) ||
                      p.category.toLowerCase().contains(query),
                )
                .toList()
              ..sort(compareHeritagePlacesForListing))
            .take(4)
            .toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.explore_outlined, color: Color(0xFFFF5F4A)),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'HERITAGE RECOMMENDATIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Heritage places and saved bookmarks in one list',
                      style: TextStyle(fontSize: 8, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: widget.onDiscover,
                child: const Text('Discover'),
              ),
              IconButton(
                onPressed: () =>
                    setState(() => _heritageExpanded = !_heritageExpanded),
                icon: Icon(
                  _heritageExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
              ),
            ],
          ),
          if (_heritageExpanded) ...<Widget>[
            InkWell(
              onTap: widget.onDiscover,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E7),
                  border: Border.all(color: const Color(0xFFFFC84A)),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: <Widget>[
                    const CircleAvatar(
                      radius: 17,
                      backgroundColor: Color(0xFFFFA800),
                      child: Icon(
                        Icons.bookmark,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'My Bookmarked Heritage\nView all ${widget.bookmarks.length} saved location',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFD96B00),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              onChanged: (value) => setState(() => _heritageQuery = value),
              decoration: const InputDecoration(
                hintText: 'Search heritage by name, place or type...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 9),
            ...places.map(
              (p) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.bookmarked
                      ? const Color(0xFFFFFBED)
                      : AppColors.elevated,
                  border: Border.all(
                    color: p.bookmarked
                        ? const Color(0xFFFFC84A)
                        : AppColors.border,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: p.image.startsWith('http')
                          ? Image.network(
                              p.image,
                              width: 74,
                              height: 66,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox(
                                width: 74,
                                height: 66,
                                child: Icon(Icons.account_balance_rounded),
                              ),
                            )
                          : p.image.isNotEmpty
                          ? Image.asset(
                              p.image,
                              width: 74,
                              height: 66,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox(
                                width: 74,
                                height: 66,
                                child: Icon(Icons.account_balance_rounded),
                              ),
                            )
                          : const SizedBox(
                              width: 74,
                              height: 66,
                              child: Icon(Icons.account_balance_rounded),
                            ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            p.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 8,
                              color: AppColors.muted,
                            ),
                          ),
                          Text(
                            p.category,
                            style: const TextStyle(
                              fontSize: 8,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        final saved = await vm.addPlace(p);
                        widget.notify(
                          saved
                              ? PlannerMessages.locationAdded(p.name)
                              : (vm.supabaseError ??
                                    'The activity card could not be saved.'),
                          saved ? AppColors.primary : AppColors.danger,
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: Text(
                        'Add to ${day.label}',
                        style: const TextStyle(fontSize: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroButton(IconData icon, VoidCallback onTap, String? count) =>
      InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: count == null ? 10 : 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 16, color: AppColors.primary),
              if (count != null) ...<Widget>[
                const SizedBox(width: 3),
                Text(
                  count,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _history() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
    children: <Widget>[
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFFF9A8C)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.route_rounded, size: 14, color: Color(0xFFFF5F4A)),
              SizedBox(width: 5),
              Text(
                'Plan Selection',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFFFF5F4A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      SectionTitle(
        'Your Travel Plans History',
        subtitle: 'Select an existing travel plan or create a new one.',
        trailing: FilledButton.icon(
          key: const Key('open_create_plan'),
          onPressed: _createPlan,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create New Plan'),
        ),
      ),
      const SizedBox(height: 14),
      AppCard(
        color: AppColors.softBlue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Join a shared plan with code',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Enter the invite code given by the plan owner. No email invitation is needed.',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _joinCode,
                    decoration: const InputDecoration(
                      hintText: 'e.g. TRIP-9842',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _joinPlan,
                  child: const Text('Join Plan'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (widget.viewModel.history.isEmpty)
        EmptyState(
          icon: Icons.luggage_outlined,
          title: 'No travel plans yet',
          message: PlannerMessages.noPlans,
          action: FilledButton(
            onPressed: _createPlan,
            child: const Text('+ Create New Plan'),
          ),
        )
      else
        ...widget.viewModel.planChoices.map(
          (PlanChoice plan) => Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 184,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFFFA499)),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x182A435C),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Stack(
                    children: <Widget>[
                      Image.asset(
                        'assets/sultan_abdul_samad.png',
                        height: 134,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        left: 10,
                        top: 62,
                        child: AppChip(
                          label: 'PIN: ${plan.inviteCode}',
                          selected: true,
                          selectedColor: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          plan.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '📍 Penang & Kuala Lumpur',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          '📅 2026-08-20 to 2026-08-23 (3 Date Tabs)',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          '♙ 2 Members',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () =>
                              widget.viewModel.openHistoryPlanById(plan.id),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                          ),
                          label: const Text(
                            'Open Workspace',
                            style: TextStyle(fontSize: 9),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: 'Delete Plan',
                            onPressed: () => _deletePlan(plan),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.danger,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Widget _groups() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
    children: <Widget>[
      const SectionTitle(
        'Trip Group Management',
        subtitle: 'Malaysia UNESCO Heritage Tour',
      ),
      const SizedBox(height: 12),
      AppCard(
        color: AppColors.softBlue,
        child: Row(
          children: <Widget>[
            Icon(Icons.vpn_key_rounded, color: AppColors.primary),
            SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Trip Invite PIN Code',
                    style: TextStyle(fontSize: 9, color: AppColors.muted),
                  ),
                  Text(
                    widget.viewModel.inviteCode,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _shareInvite,
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share'),
            ),
            IconButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: widget.viewModel.inviteCode),
                );
                widget.notify(
                  '${widget.viewModel.inviteCode} copied',
                  AppColors.primary,
                );
              },
              icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ...widget.viewModel.travellers.map(
        (Traveller traveller) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: AppCard(
            child: Row(
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    InitialsAvatar(traveller.initials, radius: 23),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: traveller.online
                              ? AppColors.teal
                              : AppColors.muted,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        traveller.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        traveller.online ? 'Online now' : 'Offline',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.viewModel.currentUserIsAdmin &&
                    !widget.viewModel.isCurrentTraveller(traveller))
                  PopupMenuButton<String>(
                    tooltip: 'Member actions',
                    onSelected: (String action) async {
                      if (action == 'role') {
                        final updated = await widget.viewModel.updateRole(
                          traveller,
                        );
                        widget.notify(
                          updated
                              ? PlannerMessages.memberUpdated
                              : (widget.viewModel.supabaseError ??
                                    'Member role could not be updated.'),
                          updated ? AppColors.teal : AppColors.danger,
                        );
                      }
                      if (action == 'remove') {
                        _confirmRemove(traveller);
                      }
                    },
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'role',
                        child: Text(
                          traveller.role == 'Admin'
                              ? 'Change to Member'
                              : 'Make Admin',
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'remove',
                        child: Text('Remove member'),
                      ),
                    ],
                    child: AppChip(
                      label: traveller.role,
                      selected: traveller.role == 'Admin',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      OutlinedButton.icon(
        onPressed: _leaveGroup,
        icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
        label: const Text('Leave travel group'),
      ),
    ],
  );

  Future<void> _activitySheet([ActivityItem? item]) async {
    final time = TextEditingController(text: item?.time ?? '09:00 AM');
    final title = TextEditingController(text: item?.title);
    final location = TextEditingController(text: item?.location);
    final notes = TextEditingController(text: item?.notes);
    HeritagePlace? selected;
    String? selectedPlaceId;
    // Editing may select any verified catalogue location; creating highlights
    // bookmarks first while still making the complete catalogue searchable.
    final savedPlaces = <String, HeritagePlace>{
      for (final place in <HeritagePlace>[
        ...widget.bookmarks,
        ...widget.recommendations,
      ])
        place.id: place,
    }.values.toList()..sort(compareHeritagePlacesForListing);
    List<HeritagePlace> locationSuggestions = <HeritagePlace>[];
    var category = item?.category ?? 'Sightseeing';
    String? successMessage;
    await showPlannerDialog<void>(
      context,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter sheetSet) => SheetBody(
          children: <Widget>[
            ModalTitle(
              title: item == null
                  ? 'Create Itinerary Activity Card'
                  : 'Edit Itinerary Activity Card',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9EA),
                border: Border.all(color: const Color(0xFFFFC84A)),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.location_on_rounded,
                        size: 15,
                        color: Color(0xFF9A4400),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item == null
                            ? 'Choose a verified heritage location'
                            : 'Change to a verified heritage location',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF7A3500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPlaceId,
                    isExpanded: true,
                    hint: Text(
                      'Choose from ${savedPlaces.length} heritage places',
                    ),
                    items: savedPlaces.indexed
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: '${entry.$2.id}#${entry.$1}',
                            child: Text(
                              entry.$2.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (placeId) => sheetSet(() {
                      selectedPlaceId = placeId;
                      if (placeId != null) {
                        final index = int.parse(placeId.split('#').last);
                        final p = savedPlaces[index];
                        selected = p;
                        location.text = _placeLocation(p);
                        if (title.text.isEmpty) title.text = p.name;
                        category = _plannerCategoryForPlace(p);
                      }
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            TextField(
              controller: title,
              decoration: InputDecoration(
                labelText: context.tr('Activity Title *'),
                hintText: 'e.g. Visit Batu Caves Cathedral',
              ),
            ),
            const SizedBox(height: 9),
            TextField(
              controller: location,
              onTap: () => sheetSet(() {
                locationSuggestions = _curatedLocationSuggestions('');
              }),
              onChanged: (value) {
                selectedPlaceId = null;
                selected = null;
                sheetSet(() {
                  if (widget.recommendations.any(
                    (place) => place.category == category,
                  )) {
                    category = 'Sightseeing';
                  }
                  locationSuggestions = _curatedLocationSuggestions(value);
                });
              },
              decoration: InputDecoration(
                labelText: context.tr('Searchable / Selectable Location *'),
                hintText: context.tr('Search any location in Malaysia'),
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
            ),
            if (locationSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 9, 12, 3),
                      child: Text(
                        'HERITAGE & PINNED SUGGESTIONS',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    ...locationSuggestions.map(
                      (place) => ListTile(
                        dense: true,
                        leading: Icon(
                          place.bookmarked
                              ? Icons.bookmark_rounded
                              : Icons.account_balance_rounded,
                          size: 18,
                          color: place.bookmarked
                              ? AppColors.warning
                              : AppColors.primary,
                        ),
                        title: Text(
                          place.name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          place.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9),
                        ),
                        onTap: () => sheetSet(() {
                          selected = place;
                          location.text = _placeLocation(place);
                          if (title.text.isEmpty) title.text = place.name;
                          category = _plannerCategoryForPlace(place);
                          locationSuggestions = <HeritagePlace>[];
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 9),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: time,
                    decoration: InputDecoration(
                      labelText: context.tr('Start Time *'),
                      prefixIcon: const Icon(Icons.schedule_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: category,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      labelText: context.tr('Category'),
                      contentPadding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                    ),
                    selectedItemBuilder: (context) =>
                        <String>{
                              'Sightseeing',
                              'Culture',
                              'Food',
                              if (selected != null) selected!.category,
                              if (item != null) item.category,
                            }
                            .toList()
                            .map(
                              (value) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    items:
                        <String>{
                              'Sightseeing',
                              'Culture',
                              'Food',
                              if (selected != null) selected!.category,
                              if (item != null) item.category,
                            }
                            .toList()
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(
                                  value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (value) =>
                        sheetSet(() => category = value ?? category),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            TextField(
              controller: notes,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.tr('Optional Description / Notes'),
                hintText: 'e.g. Remember to buy ticket online in advance...',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      if (title.text.trim().isEmpty) {
                        widget.notify(
                          'Enter an activity title.',
                          AppColors.danger,
                        );
                        return;
                      }
                      if (location.text.trim().isEmpty) {
                        widget.notify(
                          'Select or search for a location in Malaysia.',
                          AppColors.danger,
                        );
                        return;
                      }
                      if (time.text.trim().isEmpty) {
                        widget.notify('Select a start time.', AppColors.danger);
                        return;
                      }
                      if (!_validPlannerTime(time.text)) {
                        widget.notify(
                          'Enter a valid time such as 09:00 AM or 01:30 PM.',
                          AppColors.danger,
                        );
                        return;
                      }
                      final verifiedHeritage =
                          selected != null ||
                          (item != null &&
                              location.text.trim() == item.location);
                      final heritageCategories = widget.recommendations
                          .map((place) => place.category)
                          .toSet();
                      if (heritageCategories.contains(category) &&
                          !verifiedHeritage) {
                        widget.notify(
                          'Select a verified heritage suggestion before using a heritage category.',
                          AppColors.danger,
                        );
                        return;
                      }
                      if (item == null) {
                        ActivityItem? created;
                        if (selected != null) {
                          if (!await _confirmDistantLocation(
                            selected!.latitude,
                            selected!.longitude,
                            selected!.name,
                          )) {
                            return;
                          }
                          created = ActivityItem(
                            id: 'a-${DateTime.now().millisecondsSinceEpoch}',
                            time: time.text.trim(),
                            title: title.text.trim(),
                            location: _placeLocation(selected!),
                            category: category,
                            latitude: selected!.latitude,
                            longitude: selected!.longitude,
                            notes: notes.text.trim(),
                          );
                          final saved = await widget.viewModel.addActivity(
                            created,
                          );
                          if (!saved) {
                            widget.notify(
                              widget.viewModel.supabaseError ??
                                  'The activity card could not be saved.',
                              AppColors.danger,
                            );
                            return;
                          }
                        } else {
                          try {
                            final matches = await widget.viewModel.repository
                                .searchLocations(location.text.trim());
                            if (matches.isEmpty) {
                              widget.notify(
                                PlannerMessages.noMatch,
                                AppColors.danger,
                              );
                              return;
                            }
                            final place = matches.first;
                            if (!await _confirmDistantLocation(
                              place.point.latitude,
                              place.point.longitude,
                              place.name,
                            )) {
                              return;
                            }
                            created = ActivityItem(
                              id: 'a-${DateTime.now().millisecondsSinceEpoch}',
                              time: time.text.trim(),
                              title: title.text.trim(),
                              location: place.displayName,
                              category: category,
                              latitude: place.point.latitude,
                              longitude: place.point.longitude,
                              notes: notes.text.trim(),
                            );
                            final saved = await widget.viewModel.addActivity(
                              created,
                            );
                            if (!saved) {
                              widget.notify(
                                widget.viewModel.supabaseError ??
                                    'The activity card could not be saved.',
                                AppColors.danger,
                              );
                              return;
                            }
                          } catch (_) {
                            widget.notify(
                              'OpenStreetMap location search is unavailable. Please try again.',
                              AppColors.danger,
                            );
                            return;
                          }
                        }
                        if (widget.viewModel.supabaseError != null) {
                          widget.notify(
                            widget.viewModel.supabaseError!,
                            AppColors.danger,
                          );
                          return;
                        }
                      } else {
                        var resolvedLocation = item.location;
                        var resolvedLatitude = item.latitude;
                        var resolvedLongitude = item.longitude;
                        if (selected != null) {
                          resolvedLocation = _placeLocation(selected!);
                          resolvedLatitude = selected!.latitude;
                          resolvedLongitude = selected!.longitude;
                        } else if (location.text.trim() != item.location) {
                          try {
                            final matches = await widget.viewModel.repository
                                .searchLocations(location.text.trim());
                            if (matches.isEmpty) {
                              widget.notify(
                                PlannerMessages.noMatch,
                                AppColors.danger,
                              );
                              return;
                            }
                            final place = matches.first;
                            if (!await _confirmDistantLocation(
                              place.point.latitude,
                              place.point.longitude,
                              place.name,
                            )) {
                              return;
                            }
                            resolvedLocation = place.displayName;
                            resolvedLatitude = place.point.latitude;
                            resolvedLongitude = place.point.longitude;
                          } catch (_) {
                            widget.notify(
                              'OpenStreetMap location search is unavailable. Please try again.',
                              AppColors.danger,
                            );
                            return;
                          }
                        }
                        final saved = await widget.viewModel.updateActivity(
                          item,
                          time: time.text.trim(),
                          title: title.text.trim(),
                          location: resolvedLocation,
                          category: category,
                          latitude: resolvedLatitude,
                          longitude: resolvedLongitude,
                          notes: notes.text.trim(),
                        );
                        if (!saved) {
                          widget.notify(
                            widget.viewModel.supabaseError ??
                                'The activity card could not be saved.',
                            AppColors.danger,
                          );
                          return;
                        }
                      }
                      if (!context.mounted) return;
                      successMessage = item == null
                          ? PlannerMessages.cardAdded
                          : 'Activity card updated.';
                      Navigator.pop(context);
                    },
                    child: Text(
                      item == null ? 'Add Activity Card' : 'Save Changes',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    // showDialog completes when pop is requested, before its reverse animation
    // has necessarily detached every inherited dependency. Let the route finish
    // leaving the tree before rebuilding Plan or disposing field controllers.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted && successMessage != null) {
      widget.notify(successMessage!, AppColors.teal);
    }
    time.dispose();
    title.dispose();
    location.dispose();
    notes.dispose();
  }

  bool _validPlannerTime(String value) {
    final match = RegExp(
      r'^(0?[1-9]|1[0-2]):([0-5]\d)\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    return match != null;
  }

  List<HeritagePlace> _curatedLocationSuggestions(String value) {
    final query = value.trim().toLowerCase();
    final unique = <String, HeritagePlace>{};
    for (final place in <HeritagePlace>[
      ...widget.bookmarks,
      ...widget.recommendations,
    ]) {
      unique[place.id] = place;
    }
    final matches =
        unique.values
            .where(
              (place) =>
                  !_containsCjk(place.name) && query.isEmpty ||
                  (!_containsCjk(place.name) &&
                      (place.name.toLowerCase().contains(query) ||
                          place.address.toLowerCase().contains(query) ||
                          place.category.toLowerCase().contains(query))),
            )
            .toList()
          ..sort(compareHeritagePlacesForListing);
    return matches.take(5).toList();
  }

  bool _containsCjk(String value) =>
      RegExp(r'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]').hasMatch(value);

  String _placeLocation(HeritagePlace place) {
    final address = place.address.trim();
    if (address.isNotEmpty) return address;
    return place.name.trim();
  }

  String _plannerCategoryForPlace(HeritagePlace place) {
    if (place.category == 'Food' || place.category == 'Local Food') {
      return 'Food';
    }
    if (place.category == 'Sightseeing') return 'Sightseeing';
    return place.category.isEmpty ? 'Culture' : place.category;
  }

  Future<bool> _confirmDistantLocation(
    double latitude,
    double longitude,
    String name,
  ) async {
    final activities = widget.viewModel.activeDay.activities;
    if (activities.isEmpty) return true;
    final nearestKm = activities
        .map(
          (activity) => _distanceKm(
            activity.latitude,
            activity.longitude,
            latitude,
            longitude,
          ),
        )
        .reduce((a, b) => a < b ? a : b);
    if (nearestKm < 120) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        title: const Text('Location is far from this day’s itinerary'),
        content: Text(
          '$name is approximately ${nearestKm.round()} km from the nearest activity and may be in a different state. Are you sure you want to add it?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes, add location'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  double _distanceKm(
    double latitudeA,
    double longitudeA,
    double latitudeB,
    double longitudeB,
  ) {
    const earthRadiusKm = 6371.0;
    final lat1 = latitudeA * math.pi / 180;
    final lat2 = latitudeB * math.pi / 180;
    final deltaLat = (latitudeB - latitudeA) * math.pi / 180;
    final deltaLon = (longitudeB - longitudeA) * math.pi / 180;
    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Future<void> _deleteActivity(ActivityItem item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete activity?'),
        content: Text(PlannerMessages.deleteCard(item.title)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes == true) {
      final removed = await widget.viewModel.deleteActivity(item);
      widget.notify(
        removed
            ? PlannerMessages.cardRemoved
            : (widget.viewModel.supabaseError ??
                  'The card could not be removed.'),
        removed ? AppColors.teal : AppColors.danger,
      );
    }
  }

  Future<void> _createPlan() async {
    final name = TextEditingController();
    final selectedAreas = <String>{};
    final areaOptions = <String>{
      'Johor',
      'Kedah',
      'Kelantan',
      'Kuala Lumpur',
      'Labuan',
      'Melaka',
      'Negeri Sembilan',
      'Pahang',
      'Penang',
      'Perak',
      'Perlis',
      'Putrajaya',
      'Sabah',
      'Sarawak',
      'Selangor',
      'Terengganu',
      ...widget.recommendations
          .map((place) => place.state.trim())
          .where((state) => state.isNotEmpty),
    }.toList()..sort();
    DateTime start = DateTime.now();
    DateTime end = DateTime.now().add(const Duration(days: 3));
    await showPlannerDialog<void>(
      context,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter sheetSet) => SheetBody(
          children: <Widget>[
            const ModalTitle(
              title: 'Create New Travel Plan',
              subtitle: 'Malaysia destinations only',
              icon: Icons.add_location_alt_rounded,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              onChanged: (_) => sheetSet(() {}),
              decoration: const InputDecoration(
                labelText: 'Plan Name *',
                hintText: 'e.g. Penang Heritage Getaway',
              ),
            ),
            const SizedBox(height: 9),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      Icon(Icons.place_rounded, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Trip Areas / Regions *',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose one or more Malaysian states or territories.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: areaOptions
                        .map(
                          (area) => AppChip(
                            label: area,
                            selected: selectedAreas.contains(area),
                            onTap: () => sheetSet(() {
                              selectedAreas.contains(area)
                                  ? selectedAreas.remove(area)
                                  : selectedAreas.add(area);
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: <Widget>[
                Expanded(
                  child: _dateField('Start Date', start, () async {
                    final value = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2035),
                      initialDate: start.isBefore(DateTime.now())
                          ? DateTime.now()
                          : start,
                    );
                    if (value != null) {
                      sheetSet(() {
                        start = value;
                        if (end.isBefore(start)) end = start;
                      });
                    }
                  }),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dateField('End Date', end, () async {
                    final value = await showDatePicker(
                      context: context,
                      firstDate: start,
                      lastDate: DateTime(2035),
                      initialDate: end.isBefore(start) ? start : end,
                    );
                    if (value != null) sheetSet(() => end = value);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AppCard(
              color: AppColors.softBlue,
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.check_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${end.difference(start).inDays + 1} days · ${selectedAreas.length} trip areas · ${end.difference(start).inDays + 1} Day tabs will be created',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('create_plan_confirm'),
                    onPressed: name.text.trim().isEmpty || selectedAreas.isEmpty
                        ? null
                        : () async {
                            final days = end.difference(start).inDays + 1;
                            final saved = await widget.viewModel.createPlan(
                              name.text,
                              start,
                              days,
                            );
                            if (!context.mounted) return;
                            if (!saved) {
                              widget.notify(
                                widget.viewModel.supabaseError ??
                                    'The travel plan could not be saved.',
                                AppColors.danger,
                              );
                              return;
                            }
                            Navigator.pop(context);
                            widget.notify(
                              PlannerMessages.planCreated,
                              AppColors.teal,
                            );
                          },
                    child: const Text('Create Travel Plan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    name.dispose();
  }

  Future<void> _deleteDay(PlanDay day) async {
    final dayNumber = widget.viewModel.days.indexOf(day) + 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Day $dayNumber?'),
        content: Text(PlannerMessages.deleteDay(dayNumber)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final removed = await widget.viewModel.deleteDay(day);
      widget.notify(
        removed
            ? PlannerMessages.dateRemoved
            : (widget.viewModel.supabaseError ??
                  'The date tab could not be removed.'),
        removed ? AppColors.teal : AppColors.danger,
      );
    }
  }

  Widget _dateField(String label, DateTime date, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today_rounded, size: 16),
      ),
      child: Text(
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
        style: const TextStyle(fontSize: 12),
      ),
    ),
  );

  Future<void> _manageDates() async {
    var newDate = widget.viewModel.days.last.date.add(const Duration(days: 1));
    if (newDate.isBefore(DateTime.now())) newDate = DateTime.now();
    await showPlannerDialog<void>(
      context,
      StatefulBuilder(
        builder: (context, sheetSet) => SheetBody(
          children: <Widget>[
            const ModalTitle(
              title: 'Manage Date Tabs',
              icon: Icons.calendar_month_outlined,
            ),
            const SizedBox(height: 10),
            ...widget.viewModel.days.map(
              (d) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${d.label}   (${_month(d.date.month)} ${d.date.day})   ${d.activities.length} Cards',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit date',
                      onPressed: () async {
                        final value = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2028),
                          initialDate: d.date.isBefore(DateTime.now())
                              ? DateTime.now()
                              : d.date,
                        );
                        if (value != null) {
                          final updated = await widget.viewModel.renameDay(
                            d,
                            value,
                          );
                          sheetSet(() {});
                          widget.notify(
                            updated
                                ? PlannerMessages.dateUpdated
                                : 'This date already exists in the travel plan.',
                            updated ? AppColors.teal : AppColors.warning,
                          );
                        }
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                    ),
                    IconButton(
                      tooltip: 'Delete date',
                      onPressed: () => _deleteDay(d),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            const Text(
              'Add New Date Tab Chronologically',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 7),
            _dateField('Date', newDate, () async {
              final value = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime(2028),
                initialDate: newDate,
              );
              if (value != null) sheetSet(() => newDate = value);
            }),
            const SizedBox(height: 7),
            Text(
              'Travel plan range: ${widget.viewModel.days.first.date.toIso8601String().substring(0, 10)} to ${widget.viewModel.days.last.date.toIso8601String().substring(0, 10)}. Dates are sorted automatically.',
              style: const TextStyle(fontSize: 8, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () async {
                final added = await widget.viewModel.addDay(newDate);
                if (!added) {
                  widget.notify(
                    'This date already exists in the travel plan.',
                    AppColors.warning,
                  );
                  return;
                }
                sheetSet(
                  () => newDate = widget.viewModel.days.last.date.add(
                    const Duration(days: 1),
                  ),
                );
                widget.notify(PlannerMessages.dateAdded, AppColors.teal);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Date Tab'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _conflictSheet() => showPlannerDialog<void>(
    context,
    SheetBody(
      children: <Widget>[
        const ModalTitle(
          title: 'Time Clash Resolution',
          subtitle: 'Overlapping itinerary cards detected',
          icon: Icons.warning_amber_rounded,
        ),
        const SizedBox(height: 12),
        AppCard(
          color: const Color(0xFFFFF7E5),
          borderColor: const Color(0xFFF1D38A),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'An activity starts before the OSRM journey from its previous stop can finish. Automatic adjustment moves affected cards to the earliest feasible 15-minute time slot.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (final detail in widget.viewModel.conflictDetails) ...[
                const SizedBox(height: 8),
                Text(
                  detail,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            final saved = await widget.viewModel.autoFixConflict();
            if (!mounted) return;
            Navigator.pop(context);
            widget.notify(
              saved
                  ? PlannerMessages.recalculated
                  : (widget.viewModel.supabaseError ??
                        PlannerMessages.routeUnavailable),
              saved ? AppColors.teal : AppColors.danger,
            );
          },
          child: const Text('Accept Automated Time Adjustment'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Manual Adjustment Later'),
        ),
      ],
    ),
  );

  Future<void> _exportSheet() async {
    final cards = widget.viewModel.days.fold<int>(
      0,
      (int total, PlanDay day) => total + day.activities.length,
    );
    if (cards == 0) {
      widget.notify(PlannerMessages.noCards, AppColors.danger);
      return;
    }
    await showPlannerDialog<void>(
      context,
      AnimatedBuilder(
        animation: widget.viewModel,
        builder: (BuildContext context, _) => SheetBody(
          children: <Widget>[
            const ModalTitle(title: 'Export Trip Plan to PDF'),
            const SizedBox(height: 12),
            AppCard(
              color: AppColors.softBlue,
              borderColor: const Color(0xFF9FC6FF),
              child: Row(
                children: <Widget>[
                  const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(
                      Icons.description_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.viewModel.planName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${widget.viewModel.days.length} days · $cards cards',
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Format:                         PDF Document',
                          style: TextStyle(
                            fontSize: 8,
                            color: AppColors.danger,
                          ),
                        ),
                        const Text(
                          'Includes:              OSRM Travel Durations & Itinerary Cards',
                          style: TextStyle(
                            fontSize: 8,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              PlannerMessages.exportConfirm,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.viewModel.exporting
                        ? null
                        : () async {
                            try {
                              final bytes = await widget.viewModel.exportPdf();
                              final safeName = widget.viewModel.planName
                                  .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
                              await SharePlus.instance.share(
                                ShareParams(
                                  files: <XFile>[
                                    XFile.fromData(
                                      bytes,
                                      mimeType: 'application/pdf',
                                      name: '${safeName}_itinerary.pdf',
                                    ),
                                  ],
                                  fileNameOverrides: <String>[
                                    '${safeName}_itinerary.pdf',
                                  ],
                                  text: widget.viewModel.planName,
                                ),
                              );
                            } catch (_) {
                              widget.notify(
                                PlannerMessages.exportError,
                                AppColors.danger,
                              );
                              return;
                            }
                            if (context.mounted) Navigator.pop(context);
                            widget.notify(
                              PlannerMessages.exportSuccess,
                              AppColors.teal,
                            );
                          },
                    icon: widget.viewModel.exporting
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(
                      widget.viewModel.exporting
                          ? 'Generating PDF…'
                          : 'Download PDF',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(Traveller t) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove traveller?'),
        content: const Text(PlannerMessages.removeMemberConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes == true) {
      final removed = await widget.viewModel.removeTraveller(t);
      widget.notify(
        removed
            ? PlannerMessages.memberUpdated
            : (widget.viewModel.supabaseError ??
                  'The member could not be removed.'),
        removed ? AppColors.teal : AppColors.danger,
      );
    }
  }

  Future<void> _leaveGroup() async {
    if (widget.viewModel.currentUserIsAdmin &&
        !widget.viewModel.hasAnotherAdmin) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Transfer admin rights first'),
          content: const Text(PlannerMessages.adminTransferWarning),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text(PlannerMessages.leaveConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Leave Group'),
          ),
        ],
      ),
    );
    if (yes == true) {
      final left = await widget.viewModel.leaveGroup();
      widget.notify(
        left
            ? 'You left the travel group.'
            : (widget.viewModel.supabaseError ??
                  'The group could not be left.'),
        left ? AppColors.warning : AppColors.danger,
      );
    }
  }

  Future<void> _shareInvite() async {
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Join my FindIt travel plan',
        text:
            'Join ${widget.viewModel.planName} with Trip Invite PIN Code ${widget.viewModel.inviteCode}. findit://plan/join/${widget.viewModel.inviteCode}',
      ),
    );
    widget.notify(PlannerMessages.invitationShared, AppColors.teal);
  }

  Future<void> _joinPlan() async {
    final joined = await widget.viewModel.joinPlan(_joinCode.text);
    widget.notify(
      joined ? PlannerMessages.planJoined : PlannerMessages.invalidCode,
      joined ? AppColors.teal : AppColors.danger,
    );
    if (joined) _joinCode.clear();
  }

  Future<void> _deletePlan(PlanChoice plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Travel Plan?'),
        content: Text(PlannerMessages.deletePlan(plan.name)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete Plan'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final deleted = await widget.viewModel.deletePlanById(plan.id);
      widget.notify(
        deleted
            ? PlannerMessages.planDeleted
            : (widget.viewModel.supabaseError ??
                  'The plan could not be deleted.'),
        deleted ? AppColors.teal : AppColors.danger,
      );
    }
  }

  String _month(int month) => const <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.index,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });
  final int index;
  final ActivityItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.only(top: 6, right: 7),
            child: Icon(Icons.drag_indicator_rounded, color: AppColors.muted),
          ),
        ),
        Container(
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.softBlue,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: <Widget>[
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(height: 4),
              Text(
                item.time.replaceAll(' ', '\n'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: item.category == 'Food'
                        ? const Color(0xFFFFF3CC)
                        : const Color(0xFFF3E7FF),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: item.category == 'Food'
                          ? AppColors.warning
                          : const Color(0xFFD8B7FF),
                    ),
                  ),
                  child: Text(
                    item.category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: item.category == 'Food'
                          ? const Color(0xFF9A6500)
                          : const Color(0xFF7A25B5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.location,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              if (item.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    item.notes,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              if (item.transit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.directions_car_outlined,
                        size: 13,
                        color: AppColors.teal,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'From previous stop · ${item.transit}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.tealDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Column(
          children: <Widget>[
            IconButton(
              tooltip: 'Edit activity',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
            IconButton(
              tooltip: 'Delete activity',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
                size: 18,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
