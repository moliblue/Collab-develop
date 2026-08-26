import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data_layer/Models/app_models.dart';
import '../ViewModel/collaborative_planning_view_model.dart';
import 'shared/app_widgets.dart';

class PlanModuleView extends StatefulWidget {
  const PlanModuleView({
    super.key,
    required this.viewModel,
    required this.bookmarks,
    required this.onDiscover,
    required this.onViewRoute,
    required this.notify,
  });
  final CollaborativePlanningViewModel viewModel;
  final List<HeritagePlace> bookmarks;
  final VoidCallback onDiscover;
  final ValueChanged<List<ActivityItem>> onViewRoute;
  final void Function(String, Color) notify;
  @override
  State<PlanModuleView> createState() => _PlanModuleViewState();
}

class _PlanModuleViewState extends State<PlanModuleView> {
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
        Row(
          children: <Widget>[
            Expanded(
              child: SectionTitle(
                '${day.label} itinerary',
                subtitle: '${day.activities.length} activity cards',
              ),
            ),
            if (vm.hasConflict)
              IconButton(
                tooltip: 'Time conflicts',
                onPressed: _conflictSheet,
                color: AppColors.warning,
                icon: const Icon(Icons.warning_amber_rounded),
              ),
            IconButton(
              key: const Key('view_day_route'),
              tooltip: 'View Day Route',
              onPressed: day.activities.isEmpty
                  ? null
                  : () => widget.onViewRoute(day.activities),
              color: AppColors.tealDark,
              icon: const Icon(Icons.route_rounded),
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
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionTitle(
                'Saved heritage',
                subtitle: 'Bookmarks from Discover',
              ),
              const SizedBox(height: 10),
              if (widget.bookmarks.isEmpty)
                EmptyState(
                  icon: Icons.bookmark_border_rounded,
                  title: 'No saved heritage yet',
                  message: 'Bookmark places in Discover to add them here.',
                  action: TextButton(
                    onPressed: widget.onDiscover,
                    child: const Text('Explore Discover'),
                  ),
                )
              else
                SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: widget.bookmarks
                        .map(
                          (HeritagePlace p) => Container(
                            width: 215,
                            margin: const EdgeInsets.only(right: 9),
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppColors.elevated,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: <Widget>[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: Image.asset(
                                    p.image,
                                    width: 70,
                                    height: 88,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        p.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const Spacer(),
                                      FilledButton(
                                        onPressed: () {
                                          vm.addPlace(p);
                                          widget.notify(
                                            'Added ${p.name} to ${day.label}.',
                                            AppColors.teal,
                                          );
                                        },
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size.fromHeight(
                                            31,
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: const Text(
                                          'Add to day',
                                          style: TextStyle(fontSize: 9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
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
      SectionTitle(
        'Plan History',
        subtitle: '${widget.viewModel.history.length} saved travel plans',
        trailing: FilledButton.icon(
          key: const Key('open_create_plan'),
          onPressed: _createPlan,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create Plan'),
        ),
      ),
      const SizedBox(height: 14),
      if (widget.viewModel.history.isEmpty)
        EmptyState(
          icon: Icons.luggage_outlined,
          title: 'No travel plans yet',
          message: 'Create your first collaborative itinerary.',
          action: FilledButton(
            onPressed: _createPlan,
            child: const Text('Create Plan'),
          ),
        )
      else
        ...widget.viewModel.history.map(
          (String name) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: Image.asset(
                      'assets/sultan_abdul_samad.png',
                      height: 125,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const Text(
                          'Penang & Kuala Lumpur · Aug 20–23',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: <Widget>[
                            const Expanded(
                              child: AppChip(
                                label: 'Invite: HERITAGE-2026',
                                icon: Icons.key_rounded,
                              ),
                            ),
                            const SizedBox(width: 7),
                            FilledButton(
                              onPressed: () =>
                                  widget.viewModel.openHistoryPlan(name),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(110, 40),
                              ),
                              child: const Text('Open Workspace'),
                            ),
                          ],
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
        'Group Management',
        subtitle: 'Roles, status and invite access',
      ),
      const SizedBox(height: 12),
      const AppCard(
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
                    'Invite code',
                    style: TextStyle(fontSize: 9, color: AppColors.muted),
                  ),
                  Text(
                    'HERITAGE-2026',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.copy_rounded, color: AppColors.primary),
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
                PopupMenuButton<String>(
                  tooltip: 'Member actions',
                  onSelected: (String action) {
                    if (action == 'role') {
                      widget.viewModel.updateRole(traveller);
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
                    if (traveller.name != 'Amberly')
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
    final notes = TextEditingController(text: item?.notes);
    HeritagePlace? selected;
    await showAppSheet<void>(
      context,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter sheetSet) => SheetBody(
          children: <Widget>[
            ModalTitle(
              title: item == null ? 'Add Activity Card' : 'Edit Activity Card',
              subtitle: 'Search and select a mapped location',
              icon: Icons.add_card_rounded,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: time,
              decoration: const InputDecoration(
                labelText: 'Time *',
                hintText: '09:00 AM',
              ),
            ),
            const SizedBox(height: 9),
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Activity title *'),
            ),
            const SizedBox(height: 9),
            DropdownButtonFormField<HeritagePlace>(
              initialValue: selected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Searchable location',
              ),
              items: widget.bookmarks
                  .map(
                    (HeritagePlace p) => DropdownMenuItem<HeritagePlace>(
                      value: p,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (HeritagePlace? p) => sheetSet(() {
                selected = p;
                if (p != null && title.text.isEmpty) title.text = p.name;
              }),
            ),
            const SizedBox(height: 9),
            TextField(
              controller: notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes / transit details',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                if (time.text.trim().isEmpty || title.text.trim().isEmpty) {
                  widget.notify(
                    'Time and activity title are required.',
                    AppColors.danger,
                  );
                  return;
                }
                if (item == null) {
                  widget.viewModel.addActivity(
                    ActivityItem(
                      id: 'a-${DateTime.now().millisecondsSinceEpoch}',
                      time: time.text.trim(),
                      title: title.text.trim(),
                      location: selected?.address ?? 'Selected travel area',
                      category: selected?.category ?? 'Sightseeing',
                      latitude: selected?.latitude ?? 5.4182,
                      longitude: selected?.longitude ?? 100.3411,
                      notes: notes.text.trim(),
                    ),
                  );
                } else {
                  widget.viewModel.updateActivity(
                    item,
                    time: time.text.trim(),
                    title: title.text.trim(),
                    notes: notes.text.trim(),
                  );
                }
                Navigator.pop(context);
                widget.notify(
                  item == null
                      ? 'Activity card added.'
                      : 'Activity card updated.',
                  AppColors.teal,
                );
              },
              child: Text(item == null ? 'Add Activity' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
    time.dispose();
    title.dispose();
    notes.dispose();
  }

  Future<void> _deleteActivity(ActivityItem item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete activity?'),
        content: Text('Remove “${item.title}” from this day?'),
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
    if (yes == true) widget.viewModel.deleteActivity(item);
  }

  Future<void> _createPlan() async {
    final name = TextEditingController();
    DateTime start = DateTime(2026, 9, 1);
    int days = 3;
    await showAppSheet<void>(
      context,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter sheetSet) => SheetBody(
          children: <Widget>[
            const ModalTitle(
              title: 'Create Travel Plan',
              subtitle: 'Malaysia destinations and date tabs',
              icon: Icons.add_location_alt_rounded,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Plan name *',
                hintText: 'e.g. Penang Food & Heritage',
              ),
            ),
            const SizedBox(height: 9),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Destinations',
                hintText: 'Penang, Kuala Lumpur',
                prefixIcon: Icon(Icons.place_rounded),
              ),
            ),
            const SizedBox(height: 9),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start date'),
              subtitle: Text(
                '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
              ),
              trailing: IconButton(
                onPressed: () async {
                  final value = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2026),
                    lastDate: DateTime(2028),
                    initialDate: start,
                  );
                  if (value != null) sheetSet(() => start = value);
                },
                icon: const Icon(Icons.calendar_month_rounded),
              ),
            ),
            Row(
              children: <Widget>[
                const Text(
                  'Trip days',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                Expanded(
                  child: Slider(
                    value: days.toDouble(),
                    min: 1,
                    max: 7,
                    divisions: 6,
                    label: '$days',
                    onChanged: (double v) => sheetSet(() => days = v.round()),
                  ),
                ),
                Text('$days'),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('create_plan_confirm'),
              onPressed: () {
                if (name.text.trim().isEmpty) {
                  widget.notify('Plan name is required.', AppColors.danger);
                  return;
                }
                widget.viewModel.createPlan(name.text, start, days);
                Navigator.pop(context);
                widget.notify(
                  'Travel plan created with $days day tabs.',
                  AppColors.teal,
                );
              },
              child: const Text('Create Travel Plan'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
  }

  Future<void> _manageDates() => showAppSheet<void>(
    context,
    SheetBody(
      children: <Widget>[
        const ModalTitle(
          title: 'Manage Date Tabs',
          subtitle: 'Dates stay in chronological order',
          icon: Icons.edit_calendar_rounded,
        ),
        const SizedBox(height: 10),
        ...widget.viewModel.days.map(
          (PlanDay d) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.primary,
            ),
            title: Text(
              d.label,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              '${_month(d.date.month)} ${d.date.day} · ${d.activities.length} cards',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: 'Rename date',
                  onPressed: () async {
                    final value = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2026),
                      lastDate: DateTime(2028),
                      initialDate: d.date,
                    );
                    if (value != null) widget.viewModel.renameDay(d, value);
                  },
                  icon: const Icon(Icons.edit_rounded, size: 18),
                ),
                IconButton(
                  tooltip: 'Delete date',
                  onPressed: () => widget.viewModel.deleteDay(d),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        FilledButton.icon(
          onPressed: () async {
            final value = await showDatePicker(
              context: context,
              firstDate: DateTime(2026),
              lastDate: DateTime(2028),
              initialDate: widget.viewModel.days.last.date.add(
                const Duration(days: 1),
              ),
            );
            if (value != null) widget.viewModel.addDay(value);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Date Tab'),
        ),
      ],
    ),
  );

  Future<void> _conflictSheet() => showAppSheet<void>(
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
          child: Text(
            'Two activities share the same start time. The automatic adjustment moves the second card after the first with a 15-minute buffer.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            widget.viewModel.autoFixConflict();
            Navigator.pop(context);
            widget.notify(
              'Schedule automatically recalculated.',
              AppColors.teal,
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
    await showAppSheet<void>(
      context,
      AnimatedBuilder(
        animation: widget.viewModel,
        builder: (BuildContext context, _) => SheetBody(
          children: <Widget>[
            const ModalTitle(
              title: 'Export Trip Plan to PDF',
              subtitle: 'UI-only local simulation',
              icon: Icons.picture_as_pdf_rounded,
            ),
            const SizedBox(height: 12),
            AppCard(
              color: AppColors.softBlue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.viewModel.planName,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${widget.viewModel.days.length} days · ${widget.viewModel.days.fold<int>(0, (int total, PlanDay day) => total + day.activities.length)} cards · PDF document',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: widget.viewModel.exporting
                  ? null
                  : () async {
                      await widget.viewModel.exportPdfDemo();
                      if (context.mounted) Navigator.pop(context);
                      widget.notify(
                        'Trip plan export completed (demo).',
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
                widget.viewModel.exporting ? 'Generating PDF…' : 'Download PDF',
              ),
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
        content: Text('Remove ${t.name} from this plan?'),
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
    if (yes == true) widget.viewModel.removeTraveller(t);
  }

  Future<void> _leaveGroup() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text(
          'You will lose access to collaborative edits for this plan.',
        ),
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
      widget.viewModel.leaveGroup();
      widget.notify('You left the travel group.', AppColors.warning);
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
              AppChip(
                label: item.category,
                selected: true,
                selectedColor: item.category == 'Food'
                    ? AppColors.warning
                    : AppColors.teal,
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
                        Icons.directions_walk_rounded,
                        size: 13,
                        color: AppColors.teal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.transit,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tealDark,
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
