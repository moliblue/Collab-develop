import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import '../../core/localization/localized_text.dart';

import '../../core/theme/app_theme.dart';
import '../../data_layer/Models/app_models.dart';
import '../../data_layer/Models/journey.dart'
    show
        ArrivalVerificationState,
        GroupChatMessage,
        GroupVoteType,
        JourneyMember,
        NearbyGroupRoom;
import '../ViewModel/shake_find_view_model.dart';
import 'shared/app_widgets.dart';

class MysteryJourneyView extends StatefulWidget {
  const MysteryJourneyView({
    super.key,
    required this.viewModel,
    required this.onViewPassport,
    required this.onDirections,
    required this.onAddToPlan,
    required this.notify,
  });

  final MysteryJourneyViewModel viewModel;
  final VoidCallback onViewPassport;
  final VoidCallback onDirections;
  final VoidCallback onAddToPlan;
  final void Function(String, Color) notify;

  @override
  State<MysteryJourneyView> createState() => _MysteryJourneyViewState();
}

class _MysteryJourneyViewState extends State<MysteryJourneyView>
    with SingleTickerProviderStateMixin {
  bool _chatOpen = false;
  int _visibleChatMessageCount = 0;
  final TextEditingController _chatController = TextEditingController();
  final GlobalKey _chatBottomKey = GlobalKey();
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.viewModel.initialize());
    });
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _chatController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.viewModel,
    builder: (BuildContext context, _) => switch (widget.viewModel.stage) {
      MysteryStage.home => _home(),
      MysteryStage.groupSetup => _groupSetup(),
      MysteryStage.groupWaiting => _groupWaiting(),
      MysteryStage.shake => _shake(),
      MysteryStage.active => _active(),
      MysteryStage.verificationFailed => _failed(),
      MysteryStage.interrupted => _interrupted(),
      MysteryStage.complete => _complete(),
    },
  );

  Widget _scroll(List<Widget> children, {Key? key}) => ListView(
    key: key,
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
    children: children,
  );

  Widget _home() => _scroll(<Widget>[
    if (widget.viewModel.loading)
      const LinearProgressIndicator()
    else if (widget.viewModel.message != null)
      AppCard(
        color: const Color(0xFFFFF5DF),
        child: Row(
          children: <Widget>[
            const Icon(Icons.info_outline_rounded, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.viewModel.message!)),
            IconButton(
              onPressed: () => widget.viewModel.initialize(force: true),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Retry',
            ),
          ],
        ),
      ),
    if (widget.viewModel.journeyActive) ...<Widget>[
      AppCard(
        color: AppColors.softBlue,
        borderColor: const Color(0xFFD2E7FF),
        child: Row(
          children: <Widget>[
            const CircleAvatar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: Icon(Icons.explore_rounded),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Mystery journey in progress',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Your clue and team progress are safely waiting.',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: widget.viewModel.resumeJourney,
              style: FilledButton.styleFrom(
                minimumSize: const Size(86, 38),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Resume'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ],
    if (widget.viewModel.profile != null) ...<Widget>[
      Container(
        height: 198,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[
              Color(0xFFFFE3A6),
              Color(0xFFFFB078),
              Color(0xFF7ED6C4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          border: Border.all(color: const Color(0xFFDCE4D8)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned(
              right: -28,
              top: -34,
              child: Icon(
                Icons.explore_rounded,
                size: 190,
                color: Colors.white.withValues(alpha: .18),
              ),
            ),
            Positioned(
              right: 22,
              top: 20,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.luggage_rounded,
                  color: AppColors.primaryDark,
                  size: 24,
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Eyebrow(
                    'Your surprise trip',
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Follow the clue.\nFind the story.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A hidden local experience, shaped around the way you like to explore.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Eyebrow('Mystery Journey mode'),
      const SizedBox(height: 3),
      const SectionTitle('Choose how to begin'),
      const SizedBox(height: 12),
      Row(
        children: <Widget>[
          Expanded(
            child: _modeCard(
              JourneyMode.solo,
              'Solo Journey',
              'A personal mystery at your own pace',
              Icons.person_rounded,
              AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _modeCard(
              JourneyMode.group,
              'Group Journey',
              'One shared mystery with nearby travellers',
              Icons.groups_rounded,
              AppColors.teal,
            ),
          ),
        ],
      ),
      if (widget.viewModel.mode == JourneyMode.solo) ...<Widget>[
        const SizedBox(height: 18),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const CircleAvatar(
                    backgroundColor: AppColors.softBlue,
                    child: Icon(Icons.tune_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'My travel mood',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Make the surprise feel more you',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: widget.viewModel.journeyActive
                        ? null
                        : _editPreferencesSheet,
                    child: const Text('Edit'),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              if (widget.viewModel.categories.isEmpty) ...<Widget>[
                const Text(
                  'No exploration preferences saved yet. Set preferences or choose Surprise Me.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 9),
              ],
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  ...widget.viewModel.categories.map(
                    (String c) => AppChip(
                      label: c,
                      selected: true,
                      selectedColor: AppColors.teal,
                    ),
                  ),
                  AppChip(
                    label: 'Within ${widget.viewModel.radius.round()} km',
                    selected: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('start_mystery'),
        onPressed: () {
          if (widget.viewModel.journeyActive) {
            _warnAboutUnfinishedJourney();
            return;
          }
          widget.viewModel.setStage(
            widget.viewModel.mode == JourneyMode.solo
                ? MysteryStage.shake
                : MysteryStage.groupSetup,
          );
        },
        style: widget.viewModel.journeyActive
            ? FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE0E4E7),
                foregroundColor: AppColors.muted,
                elevation: 0,
              )
            : null,
        icon: Icon(
          widget.viewModel.mode == JourneyMode.solo
              ? Icons.explore_rounded
              : Icons.group_add_rounded,
        ),
        label: Text(
          widget.viewModel.mode == JourneyMode.solo
              ? 'Start Solo Mystery'
              : 'Find Nearby Teammates',
        ),
      ),
      if (widget.viewModel.mode == JourneyMode.solo) ...<Widget>[
        const SizedBox(height: 9),
        OutlinedButton.icon(
          onPressed: () {
            if (widget.viewModel.journeyActive) {
              _warnAboutUnfinishedJourney();
              return;
            }
            widget.viewModel.setMode(JourneyMode.solo);
            widget.viewModel.useSurpriseMe();
            widget.notify(
              'Surprise Me ignores preferences for this quest.',
              AppColors.primary,
            );
          },
          style: widget.viewModel.journeyActive
              ? OutlinedButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  side: const BorderSide(color: Color(0xFFD7DCDF)),
                )
              : null,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Surprise me - anywhere fun!'),
        ),
      ],
    ],
  ], key: const PageStorageKey<String>('mystery-home'));

  void _warnAboutUnfinishedJourney() {
    widget.viewModel.remindUnfinishedJourney();
    widget.notify(
      MysteryJourneyViewModel.unfinishedJourneyMessage,
      AppColors.warning,
    );
  }

  Widget _modeCard(
    JourneyMode mode,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final selected = widget.viewModel.mode == mode;
    return AnimatedScale(
      scale: selected ? 1 : .985,
      duration: AppTokens.fast,
      curve: Curves.easeOut,
      child: AppCard(
        onTap: widget.viewModel.journeyActive
            ? null
            : () => widget.viewModel.setMode(mode),
        radius: AppTokens.cardRadius,
        color: selected ? color.withValues(alpha: .09) : Colors.white,
        borderColor: selected ? color : AppColors.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .13),
                  child: Icon(icon, color: color),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: AppTokens.fast,
                  child: selected
                      ? Icon(
                          Icons.check_circle_rounded,
                          key: ValueKey<JourneyMode>(mode),
                          color: color,
                          size: 21,
                        )
                      : const SizedBox.square(
                          key: ValueKey<String>('unselected'),
                          dimension: 21,
                        ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space24),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPreferencesSheet() async {
    await showAppSheet<void>(
      context,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheet) => SheetBody(
          children: <Widget>[
            const ModalTitle(
              title: 'Travel preferences',
              subtitle: 'Tell Mystery what sounds fun',
              icon: Icons.tune_rounded,
            ),
            const SizedBox(height: 14),
            const Text(
              'Categories',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children:
                  <String>['Culture', 'History', 'Local food', 'Art & streets']
                      .map(
                        (String c) => AppChip(
                          label: c,
                          selected: widget.viewModel.categories.contains(c),
                          onTap: () => setSheet(
                            () => widget.viewModel.toggleCategory(c),
                          ),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Discovery radius · ${widget.viewModel.radius.round()} km',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Slider(
              value: widget.viewModel.radius,
              min: 5,
              max: 50,
              divisions: 9,
              onChanged: (double value) =>
                  setSheet(() => widget.viewModel.setRadius(value)),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                if (widget.viewModel.mode == JourneyMode.group &&
                    widget.viewModel.journey?.groupRoomId != null) {
                  await widget.viewModel.saveGroupPreferences();
                }
                widget.notify('Travel mood saved.', AppColors.teal);
              },
              child: const Text('Save preferences'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberTile(
    JourneyMember member, {
    Color color = AppColors.softBlue,
    bool showReadiness = false,
    bool isCurrentUser = false,
  }) {
    final words = member.displayName.trim().split(RegExp(r'\s+'));
    final initials = words
        .take(2)
        .where((value) => value.isNotEmpty)
        .map((value) => value[0].toUpperCase())
        .join();
    return _TravellerTile(
      initials: initials.isEmpty ? '?' : initials,
      name: member.displayName,
      status: showReadiness
          ? member.isReady
                ? 'Ready'
                : 'Not ready'
          : member.participantStatus ?? member.status,
      color: color,
      avatarUrl: member.avatarUrl,
      isHost: member.isHost,
      isReady: showReadiness ? member.isReady : null,
      isCurrentUser: isCurrentUser,
    );
  }

  Widget _groupSetup() => _scroll(<Widget>[
    const SizedBox(height: 10),
    Center(
      child: Container(
        width: 118,
        height: 118,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.softBlue,
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: const Icon(
          Icons.radar_rounded,
          size: 54,
          color: AppColors.primary,
        ),
      ),
    ),
    const SizedBox(height: 18),
    Text(
      'Nearby open rooms',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 7),
    Text(
      'Join an available waiting room within 1 km, or create a new room.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    const SizedBox(height: 20),
    FilledButton.icon(
      onPressed: widget.viewModel.loading
          ? null
          : widget.viewModel.createGroupRoom,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Create New Waiting Room'),
    ),
    const SizedBox(height: 18),
    Row(
      children: <Widget>[
        const Expanded(
          child: Text(
            'ROOMS NEAR YOU',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
        ),
        IconButton(
          onPressed: widget.viewModel.scanning
              ? null
              : widget.viewModel.scanNearby,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh nearby rooms',
        ),
      ],
    ),
    if (widget.viewModel.scanning)
      const LinearProgressIndicator()
    else if (widget.viewModel.nearbyRooms.isEmpty)
      const AppCard(
        child: Column(
          children: <Widget>[
            Icon(Icons.group_off_outlined, color: AppColors.muted, size: 34),
            SizedBox(height: 8),
            Text(
              'No open rooms within 1 km',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 4),
            Text(
              'Create a waiting room and nearby travellers can discover it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      )
    else
      ...widget.viewModel.nearbyRooms.map(_nearbyRoomCard),
  ], key: const PageStorageKey<String>('mystery-group-setup'));

  Widget _nearbyRoomCard(NearbyGroupRoom room) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const CircleAvatar(
                backgroundColor: Color(0xFFE9FAF4),
                child: Icon(Icons.groups_rounded, color: AppColors.teal),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Waiting Room ${room.id.substring(0, math.min(6, room.id.length)).toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${room.distanceMeters.round()} m away',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${room.memberCount}/${room.capacity}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Room preferences',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          if (room.hasPreferences)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: room.preferenceLabels
                  .map((label) => AppChip(label: label, selected: true))
                  .toList(growable: false),
            )
          else
            const Text(
              'Not set yet',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: room.isFull
                  ? null
                  : () => widget.viewModel.joinGroupRoom(room.id),
              child: Text(room.isFull ? 'Room Full' : 'Join Room'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _groupWaiting() => _scroll(<Widget>[
    Container(
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF173D66), Color(0xFF205A91)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0x26FFFFFF),
                child: Icon(
                  Icons.groups_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Eyebrow('Nearby travellers', color: Colors.white),
                    const SizedBox(height: 3),
                    Text(
                      widget.viewModel.isHost
                          ? 'Your waiting room'
                          : 'Group waiting room',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.viewModel.roomMemberCount} / 4',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space12),
          Text(
            'Room ID: ${widget.viewModel.journey?.groupRoomId ?? ''}',
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
          ),
          const SizedBox(height: AppTokens.space8),
          TextButton.icon(
            key: const Key('leave_waiting_room'),
            onPressed: widget.viewModel.loading
                ? null
                : _confirmLeaveWaitingRoom,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.exit_to_app_rounded, size: 18),
            label: Text(
              widget.viewModel.isHost
                  ? 'Close Room & Switch to Solo'
                  : 'Leave Room & Switch to Solo',
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: AppTokens.space12),
    if (widget.viewModel.message != null) ...<Widget>[
      const SizedBox(height: 8),
      AppCard(
        color: const Color(0xFFFFF5DF),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.info_outline_rounded, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.viewModel.message!)),
          ],
        ),
      ),
    ],
    const SizedBox(height: 10),
    AppCard(
      color: widget.viewModel.allRoomMembersReady
          ? const Color(0xFFE9FAF4)
          : AppColors.surface,
      borderColor: widget.viewModel.allRoomMembersReady
          ? const Color(0xFFBFECDD)
          : AppColors.border,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Travellers',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${widget.viewModel.members.where((member) => member.isReady).length} ready',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          ...widget.viewModel.members.indexed.expand(
            ((int, JourneyMember) item) => <Widget>[
              if (item.$1 > 0) const Divider(),
              _memberTile(
                item.$2,
                color: Colors.white,
                showReadiness: true,
                isCurrentUser: item.$2.userId == widget.viewModel.currentUserId,
              ),
            ],
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'I’m Ready',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            subtitle: const Text('Let the host know you are ready to begin'),
            value: widget.viewModel.ready,
            onChanged: widget.viewModel.loading
                ? null
                : (value) => unawaited(widget.viewModel.setReady(value)),
            activeThumbColor: AppColors.teal,
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: AppColors.softBlue,
                child: Icon(Icons.tune_rounded, color: AppColors.primary),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Journey Preferences',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!widget.viewModel.groupPreferencesSet)
            const Text(
              'The host has not selected preferences yet.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                if (widget.viewModel.categories.isEmpty)
                  const AppChip(label: 'Surprise Me', selected: true)
                else
                  ...widget.viewModel.categories.map(
                    (category) => AppChip(label: category, selected: true),
                  ),
                AppChip(
                  label: 'Within ${widget.viewModel.radius.round()} km',
                  selected: true,
                ),
              ],
            ),
          if (widget.viewModel.isHost) ...<Widget>[
            const SizedBox(height: 14),
            const Text(
              'Host selection mode',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: <Widget>[
                AppChip(
                  label: 'Use Saved',
                  selected:
                      widget.viewModel.groupPreferenceMode ==
                      'saved_preferences',
                  onTap: widget.viewModel.loading
                      ? null
                      : widget.viewModel.useSavedGroupPreferences,
                ),
                AppChip(
                  label: 'Edit Now',
                  selected:
                      widget.viewModel.groupPreferenceMode ==
                      'edited_preferences',
                  onTap: widget.viewModel.loading
                      ? null
                      : _editPreferencesSheet,
                ),
                AppChip(
                  label: 'Surprise Me',
                  selected:
                      widget.viewModel.groupPreferenceMode == 'surprise_me',
                  onTap: widget.viewModel.loading
                      ? null
                      : widget.viewModel.useGroupSurpriseMe,
                ),
              ],
            ),
          ],
        ],
      ),
    ),
    if (widget.viewModel.groupChatUnlocked) ...<Widget>[
      const SizedBox(height: 14),
      _groupChatCard(),
    ] else ...<Widget>[
      const SizedBox(height: 14),
      const AppCard(
        child: Row(
          children: <Widget>[
            Icon(Icons.lock_outline_rounded, color: AppColors.muted),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Group Chat unlocks when at least 2 travellers join.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    ],
    const SizedBox(height: 16),
    AppCard(
      color: _canStartWaitingRoom
          ? const Color(0xFFE9FAF4)
          : const Color(0xFFFFF5DF),
      child: Row(
        children: <Widget>[
          Icon(
            _canStartWaitingRoom
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            color: _canStartWaitingRoom ? AppColors.teal : AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(_waitingStartStatus())),
        ],
      ),
    ),
    const SizedBox(height: 10),
    if (widget.viewModel.isHost)
      FilledButton.icon(
        key: const Key('start_group_journey'),
        onPressed: widget.viewModel.loading
            ? null
            : widget.viewModel.beginGroupJourney,
        style: !_canStartWaitingRoom
            ? FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE0E4E7),
                foregroundColor: AppColors.textSecondary,
              )
            : null,
        icon: const Icon(Icons.rocket_launch_rounded),
        label: Text(
          widget.viewModel.groupPreferenceMode == 'surprise_me'
              ? 'Start Surprise Group Journey'
              : 'Start Group Journey',
        ),
      )
    else
      const AppCard(
        color: AppColors.softBlue,
        child: Text(
          'Waiting for the host to select preferences and start the journey.',
          textAlign: TextAlign.center,
        ),
      ),
  ], key: const PageStorageKey<String>('mystery-group-waiting'));

  Widget _shake() => _scroll(<Widget>[
    const SizedBox(height: 24),
    AnimatedBuilder(
      animation: _shakeController,
      builder: (BuildContext context, Widget? child) => Transform.rotate(
        angle: math.sin(_shakeController.value * math.pi * 2) * .055,
        child: Transform.translate(
          offset: Offset(math.sin(_shakeController.value * math.pi * 4) * 4, 0),
          child: child,
        ),
      ),
      child: Center(
        child: Container(
          width: 138,
          height: 196,
          decoration: BoxDecoration(
            gradient: AppColors.travelSunsetGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 5),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x2D173D66),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned(
                top: 24,
                left: 20,
                child: Icon(Icons.location_on_rounded, color: Colors.white54),
              ),
              Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 72),
              Positioned(
                bottom: 24,
                right: 20,
                child: Icon(Icons.flag_rounded, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    ),
    const SizedBox(height: 34),
    Text(
      widget.viewModel.mode == JourneyMode.group
          ? 'Shake for your group mystery!'
          : 'Shake your phone!',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineLarge,
    ),
    const SizedBox(height: 8),
    Text(
      widget.viewModel.mode == JourneyMode.group
          ? 'Shake your phone to reveal one shared mystery clue for the whole room.'
          : 'Shake your phone to generate your personalized mystery heritage clue.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    if (widget.viewModel.mode == JourneyMode.group) ...<Widget>[
      const SizedBox(height: 20),
      AppCard(
        key: const Key('group_shake_progress'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Group Shake — ${widget.viewModel.groupShakenCount}/'
              '${widget.viewModel.members.length} shaken',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...widget.viewModel.members.map(
              (JourneyMember member) => Padding(
                key: Key('group_shake_member_${member.userId}'),
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: <Widget>[
                    Icon(
                      member.hasShaken
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: member.hasShaken
                          ? AppColors.teal
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: Text(member.displayName)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
    const SizedBox(height: 26),
    AppCard(
      key: const Key('shake_sensor_status'),
      color: !widget.viewModel.sensorUnavailable
          ? AppColors.softBlue
          : const Color(0xFFFFF5DF),
      borderColor: !widget.viewModel.sensorUnavailable
          ? const Color(0xFFD2E7FF)
          : const Color(0xFFFFD78A),
      child: Row(
        children: <Widget>[
          if (widget.viewModel.loading)
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            Icon(
              widget.viewModel.isListeningForShake
                  ? Icons.sensors_rounded
                  : widget.viewModel.sensorUnavailable
                  ? Icons.sensors_off_rounded
                  : Icons.hourglass_top_rounded,
              color: !widget.viewModel.sensorUnavailable
                  ? AppColors.primary
                  : AppColors.warning,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.viewModel.loading
                      ? 'Shake detected'
                      : widget.viewModel.isListeningForShake
                      ? 'Motion sensor active'
                      : widget.viewModel.sensorUnavailable
                      ? 'Motion sensor unavailable'
                      : 'Preparing motion sensor',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.viewModel.loading
                      ? 'Creating your mystery journey...'
                      : widget.viewModel.isListeningForShake
                      ? 'Hold your phone securely and shake it firmly.'
                      : widget.viewModel.sensorUnavailable
                      ? 'Retry to start listening for phone movement.'
                      : 'Starting phone movement detection...',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!widget.viewModel.loading && widget.viewModel.sensorUnavailable)
            IconButton(
              onPressed: () =>
                  unawaited(widget.viewModel.retryShakeDetection()),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Retry motion sensor',
            ),
        ],
      ),
    ),
    if (widget.viewModel.message != null &&
        !widget.viewModel.loading &&
        !widget.viewModel.sensorUnavailable) ...<Widget>[
      const SizedBox(height: 10),
      AppCard(
        color: const Color(0xFFFFF5DF),
        borderColor: const Color(0xFFFFD78A),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.info_outline_rounded, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.viewModel.message!)),
          ],
        ),
      ),
    ],
  ], key: const PageStorageKey<String>('mystery-shake'));

  Widget _active() {
    if (widget.viewModel.awaitingSoloRevisitDecision) {
      return _scroll(<Widget>[
        _activeHero(),
        const SizedBox(height: AppTokens.space16),
        if (widget.viewModel.loading) const LinearProgressIndicator(),
        if (widget.viewModel.message != null) ...<Widget>[
          const SizedBox(height: AppTokens.space12),
          AppCard(
            color: const Color(0xFFFFF5DF),
            borderColor: const Color(0xFFFFD78A),
            child: Text(widget.viewModel.message!),
          ),
        ],
        const SizedBox(height: AppTokens.space16),
        FilledButton.icon(
          onPressed: widget.viewModel.loading
              ? null
              : widget.viewModel.playThisRevisit,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Play This Revisit'),
        ),
        const SizedBox(height: AppTokens.space8),
        OutlinedButton.icon(
          onPressed: widget.viewModel.loading
              ? null
              : widget.viewModel.shakeAgainForNewDestination,
          icon: const Icon(Icons.vibration_rounded),
          label: const Text('Shake Again for a New Place'),
        ),
        const SizedBox(height: AppTokens.space8),
        TextButton(
          onPressed: widget.viewModel.loading
              ? null
              : widget.viewModel.adjustRevisitPreferences,
          child: const Text('Adjust Preferences'),
        ),
      ], key: const PageStorageKey<String>('mystery-revisit-decision'));
    }
    return _scroll(<Widget>[
      _activeHero(),
      const SizedBox(height: AppTokens.space16),
      _journeyProgressCard(),
      if (widget.viewModel.loading) ...<Widget>[
        const SizedBox(height: AppTokens.space12),
        const LinearProgressIndicator(),
      ],
      if (widget.viewModel.message != null) ...<Widget>[
        const SizedBox(height: AppTokens.space12),
        AppCard(
          color: const Color(0xFFFFF5DF),
          borderColor: const Color(0xFFFFD78A),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.info_outline_rounded, color: AppColors.warning),
              const SizedBox(width: AppTokens.space8),
              Expanded(child: Text(widget.viewModel.message!)),
            ],
          ),
        ),
      ],
      const SizedBox(height: AppTokens.space16),
      _clueCard(),
      const SizedBox(height: AppTokens.space12),
      _secondaryJourneyActions(),
      if (widget.viewModel.mode == JourneyMode.group)
        ..._groupVoteStatusCards(),
      if (widget.viewModel.mode == JourneyMode.group) ...<Widget>[
        const SizedBox(height: AppTokens.space16),
        _groupProgressCard(),
        if (widget.viewModel.groupChatUnlocked) ...<Widget>[
          const SizedBox(height: AppTokens.space16),
          _groupChatCard(),
        ],
      ],
      const SizedBox(height: AppTokens.space24),
      const SectionTitle(
        "Think you've found it?",
        subtitle: 'Check in with real GPS when you reach the place.',
      ),
      const SizedBox(height: AppTokens.space8),
      _arrivalStatusCard(),
      const SizedBox(height: AppTokens.space12),
      FilledButton.icon(
        key: const Key('test_real_arrival'),
        onPressed:
            widget.viewModel.loading || widget.viewModel.currentUserArrived
            ? null
            : widget.viewModel.testArrivalNow,
        icon: const Icon(Icons.gps_fixed_rounded),
        label: Text(
          widget.viewModel.currentUserArrived
              ? 'Your arrival is verified'
              : 'Check Arrival',
        ),
      ),
      const SizedBox(height: AppTokens.space8),
      Center(
        child: TextButton.icon(
          onPressed: () => widget.viewModel.setStage(MysteryStage.interrupted),
          icon: const Icon(Icons.pause_circle_outline_rounded),
          label: const Text('Leave and continue later'),
        ),
      ),
    ], key: const PageStorageKey<String>('mystery-active'));
  }

  Widget _activeHero() => Container(
    padding: const EdgeInsets.all(AppTokens.space16),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F3EA),
      borderRadius: BorderRadius.circular(AppTokens.cardRadius),
      border: Border.all(color: const Color(0xFFDCE4D8)),
    ),
    child: Stack(
      children: <Widget>[
        Positioned(
          right: -20,
          top: -22,
          child: Icon(
            Icons.explore_rounded,
            color: AppColors.teal.withValues(alpha: .08),
            size: 118,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.circle, color: AppColors.teal, size: 9),
                SizedBox(width: 7),
                Eyebrow('Live mystery', color: AppColors.tealDark),
              ],
            ),
            const SizedBox(height: AppTokens.space12),
            const Text(
              'Your hidden destination',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppTokens.space8),
            Text(
              widget.viewModel.clue,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            if (widget.viewModel.journey?.isRevisit == true) ...<Widget>[
              const SizedBox(height: AppTokens.space12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .82),
                  borderRadius: BorderRadius.circular(AppTokens.controlRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.replay_rounded,
                        size: 18,
                        color: AppColors.teal,
                      ),
                      SizedBox(width: AppTokens.space8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Revisit Challenge',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "You've explored this place before.",
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );

  Widget _journeyProgressCard() {
    final arrived =
        widget.viewModel.currentUserArrived ||
        widget.viewModel.arrivalVerification.state ==
            ArrivalVerificationState.verified;
    final steps = <({String label, IconData icon, bool completed})>[
      (label: 'Started', icon: Icons.flag_rounded, completed: true),
      (
        label: 'Clues',
        icon: Icons.auto_stories_rounded,
        completed: widget.viewModel.clue.trim().isNotEmpty || arrived,
      ),
      if (widget.viewModel.routeRevealed)
        (label: 'Route', icon: Icons.route_rounded, completed: true),
      (label: 'Arrived', icon: Icons.verified_rounded, completed: arrived),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Journey progress',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppTokens.space12),
          AnimatedSwitcher(
            duration: AppTokens.fast,
            child: Row(
              key: ValueKey<bool>(widget.viewModel.routeRevealed),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (var index = 0; index < steps.length; index++) ...<Widget>[
                  Expanded(
                    child: _JourneyProgressStep(
                      label: steps[index].label,
                      icon: steps[index].icon,
                      completed: steps[index].completed,
                    ),
                  ),
                  if (index < steps.length - 1)
                    Expanded(
                      child: AnimatedContainer(
                        duration: AppTokens.fast,
                        margin: const EdgeInsets.only(top: 13),
                        height: 2,
                        color: steps[index + 1].completed
                            ? AppColors.teal
                            : AppColors.border,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _clueCard() {
    final location = widget.viewModel.journey?.locationHint.trim();
    final locationText = location == null || location.isEmpty
        ? 'The exact destination remains hidden.'
        : location;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.softBlue,
                child: Icon(
                  Icons.travel_explore_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Clues & discoveries',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Your unlocked journey details',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space16),
          _MysteryDetailTile(
            icon: widget.viewModel.routeRevealed
                ? Icons.location_on_rounded
                : Icons.near_me_rounded,
            title: widget.viewModel.routeRevealed
                ? 'Exact location'
                : 'Location clue',
            text: locationText,
            trailing: widget.viewModel.distanceMeters > 0
                ? '${widget.viewModel.distanceMeters.toStringAsFixed(0)} m away'
                : null,
          ),
          AnimatedSwitcher(
            duration: AppTokens.normal,
            switchInCurve: Curves.easeOut,
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.topLeft,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Column(
              key: ValueKey<int>(widget.viewModel.hints.length),
              children: <Widget>[
                for (
                  var index = 0;
                  index < widget.viewModel.hints.length;
                  index++
                ) ...<Widget>[
                  const Divider(height: 22),
                  _MysteryDetailTile(
                    icon: Icons.lightbulb_outline_rounded,
                    title: 'Hint ${index + 1}',
                    text: widget.viewModel.hints[index],
                  ),
                ],
              ],
            ),
          ),
          if (widget.viewModel.hints.isEmpty) ...<Widget>[
            const Divider(height: 22),
            const _MysteryDetailTile(
              icon: Icons.lock_outline_rounded,
              title: 'Hints locked',
              text: 'Unlock a hint when you need another nudge.',
              muted: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _secondaryJourneyActions() {
    final actions = <Widget>[];
    if (widget.viewModel.hasHintsRemaining) {
      actions.add(
        OutlinedButton.icon(
          onPressed:
              widget.viewModel.mode == JourneyMode.group &&
                  widget.viewModel.hasSubmittedVote(GroupVoteType.hint)
              ? null
              : _askHint,
          icon: const Icon(Icons.lightbulb_outline_rounded),
          label: Text(
            _voteButtonLabel(GroupVoteType.hint, 'Unlock hint'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    actions.add(
      OutlinedButton.icon(
        onPressed: widget.viewModel.routeRevealed
            ? widget.onDirections
            : widget.viewModel.mode == JourneyMode.group &&
                  widget.viewModel.hasSubmittedVote(GroupVoteType.route)
            ? null
            : _confirmRoute,
        icon: Icon(
          widget.viewModel.routeRevealed
              ? Icons.map_outlined
              : Icons.route_rounded,
        ),
        label: Text(
          widget.viewModel.routeRevealed
              ? 'Open Map'
              : _voteButtonLabel(GroupVoteType.route, 'Reveal route'),
          textAlign: TextAlign.center,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!widget.viewModel.hasHintsRemaining) ...<Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE9FAF4),
              borderRadius: BorderRadius.circular(AppTokens.controlRadius),
              border: Border.all(color: const Color(0xFFBFECDD)),
            ),
            child: const Row(
              children: <Widget>[
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.teal,
                  size: 19,
                ),
                SizedBox(width: AppTokens.space8),
                Expanded(
                  child: Text(
                    'All clues discovered ✓',
                    style: TextStyle(
                      color: AppColors.tealDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space8),
        ],
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final width = actions.length == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - AppTokens.space8) / 2;
            return Wrap(
              spacing: AppTokens.space8,
              runSpacing: AppTokens.space8,
              children: actions
                  .map((action) => SizedBox(width: width, child: action))
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }

  Widget _groupProgressCard() => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const CircleAvatar(
              radius: 19,
              backgroundColor: Color(0xFFE9FAF4),
              child: Icon(
                Icons.groups_rounded,
                color: AppColors.teal,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Group progress',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Arrival is verified individually',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            AppChip(
              label:
                  '${widget.viewModel.members.where((member) => member.participantStatus == 'completed').length}/${widget.viewModel.members.length}',
              selected: true,
              selectedColor: AppColors.teal,
            ),
          ],
        ),
        const Divider(height: 24),
        ...widget.viewModel.members.map(
          (JourneyMember member) => Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.space8),
            child: _memberTile(
              member,
              color: const Color(0xFFE9FAF4),
              isCurrentUser: member.userId == widget.viewModel.currentUserId,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _groupChatCard() => AppCard(
    child: Column(
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            radius: 19,
            backgroundColor: Color(0xFFE9FAF4),
            child: Icon(Icons.forum_rounded, color: AppColors.teal, size: 20),
          ),
          title: const Text(
            'Group Chat',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text('${widget.viewModel.roomMemberCount} travellers'),
          trailing: IconButton(
            onPressed: _toggleChat,
            icon: AnimatedRotation(
              turns: _chatOpen ? .5 : 0,
              duration: AppTokens.fast,
              child: const Icon(Icons.expand_more),
            ),
          ),
        ),
        AnimatedSize(
          duration: AppTokens.normal,
          curve: Curves.easeOutCubic,
          child: _chatOpen
              ? Column(
                  children: <Widget>[
                    const Divider(height: 10),
                    ..._chatMessageWidgets(),
                    const SizedBox(height: AppTokens.space8),
                    TextField(
                      controller: _chatController,
                      enabled: !widget.viewModel.chatSending,
                      onSubmitted: _sendChat,
                      decoration: InputDecoration(
                        hintText: 'Share a clue guess…',
                        prefixIcon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                        ),
                        suffixIcon: IconButton(
                          onPressed: widget.viewModel.chatSending
                              ? null
                              : () => _sendChat(_chatController.text),
                          icon: widget.viewModel.chatSending
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          tooltip: 'Send message',
                        ),
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    ),
  );

  List<Widget> _chatMessageWidgets() {
    final messages = widget.viewModel.messages;
    if (_chatOpen && messages.length != _visibleChatMessageCount) {
      _visibleChatMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollChatToLatest(),
      );
    }
    return <Widget>[
      for (var index = 0; index < messages.length; index++)
        _chatMessage(
          messages[index],
          showSender:
              index == 0 ||
              messages[index - 1].userId != messages[index].userId,
        ),
      SizedBox(key: _chatBottomKey, height: 1),
    ];
  }

  Widget _chatMessage(
    GroupChatMessage message, {
    required bool showSender,
  }) => Align(
    key: ValueKey<String>('group-chat-message-${message.id}'),
    alignment: message.isCurrentUser
        ? Alignment.centerRight
        : Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(
        crossAxisAlignment: message.isCurrentUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          if (showSender) ...<Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .68,
              ),
              child: Text(
                message.senderName,
                key: ValueKey<String>('group-chat-sender-${message.id}'),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 3),
          ],
          FractionallySizedBox(
            widthFactor: .78,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: message.isCurrentUser
                    ? AppColors.primary
                    : const Color(0xFFF0F3F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      message.message,
                      style: TextStyle(
                        color: message.isCurrentUser
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${message.createdAt.hour.toString().padLeft(2, '0')}:'
                      '${message.createdAt.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: message.isCurrentUser
                            ? const Color(0xCFFFFFFF)
                            : AppColors.muted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _sendChat(String value) async {
    final message = value.trim();
    if (message.isEmpty) return;
    await widget.viewModel.addMessage(message);
    _chatController.clear();
    _scrollChatToLatest();
  }

  Future<void> _toggleChat() async {
    if (_chatOpen) {
      setState(() => _chatOpen = false);
      return;
    }
    setState(() => _chatOpen = true);
    await widget.viewModel.loadGroupMessages();
    _scrollChatToLatest();
  }

  void _scrollChatToLatest() {
    if (!mounted || !_chatOpen) return;
    final chatBottomContext = _chatBottomKey.currentContext;
    if (chatBottomContext != null) {
      unawaited(
        Scrollable.ensureVisible(
          chatBottomContext,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: 1,
        ),
      );
    }
  }

  Future<void> _confirmLeaveWaitingRoom() async {
    final isHost = widget.viewModel.isHost;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(isHost ? 'Close waiting room?' : 'Leave waiting room?'),
        content: Text(
          isHost
              ? 'The room has not started. Closing it will remove every waiting member.'
              : 'You will leave this waiting room and return to Mystery Journey.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep room'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(isHost ? 'Close room' : 'Leave room'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.viewModel.leaveWaitingRoom();
  }

  void _askHint() {
    if (widget.viewModel.mode == JourneyMode.group) {
      unawaited(_castGroupVote(GroupVoteType.hint));
      return;
    }
    unawaited(widget.viewModel.unlockHint());
  }

  void _confirmRoute() {
    if (widget.viewModel.mode == JourneyMode.group) {
      _voteDialog(
        'Vote to reveal exact route?',
        () => unawaited(_castGroupVote(GroupVoteType.route)),
      );
      return;
    }
    Future<void> revealAndNavigate() async {
      await widget.viewModel.revealRoute();
      if (widget.viewModel.routeRevealed) widget.onDirections();
    }

    _voteDialog(
      'Reveal exact route?',
      () => unawaited(revealAndNavigate()),
      group: false,
    );
  }

  Future<void> _castGroupVote(GroupVoteType type) async {
    final outcome = await widget.viewModel.castGroupVote(type);
    if (!mounted || outcome == null) return;
    widget.notify(
      outcome.message,
      outcome.passed ? AppColors.teal : AppColors.primary,
    );
    if (type == GroupVoteType.route && outcome.passed) {
      widget.onDirections();
    }
  }

  String _voteButtonLabel(GroupVoteType type, String soloLabel) {
    if (widget.viewModel.mode != JourneyMode.group) return soloLabel;
    final status = widget.viewModel.voteStatus(type);
    final action = type == GroupVoteType.hint
        ? 'Request Group Hint'
        : 'Vote to Reveal';
    if (status == null || status.requiredVotes == 0) return action;
    if (status.currentUserVoted && !status.passed) {
      return 'Vote submitted ${status.yesVotes}/${status.requiredVotes}';
    }
    return '$action ${status.yesVotes}/${status.requiredVotes}';
  }

  Future<void> _voteDialog(
    String title,
    VoidCallback accepted, {
    bool group = true,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        icon: Icon(
          group ? Icons.how_to_vote_rounded : Icons.route_rounded,
          color: AppColors.primary,
          size: 34,
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              group
                  ? 'Your vote will be saved. The exact destination stays hidden until a majority of active travellers approve.'
                  : 'The precise destination and navigation route will be shown.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              accepted();
            },
            child: Text(group ? 'Submit Vote' : 'Reveal Route'),
          ),
        ],
      ),
    );
  }

  bool get _canStartWaitingRoom =>
      widget.viewModel.roomMemberCount >= 2 &&
      widget.viewModel.groupPreferencesSet &&
      widget.viewModel.allRoomMembersReady;

  String _waitingStartStatus() {
    if (widget.viewModel.roomMemberCount < 2) {
      return 'At least 2 travellers are required to start.';
    }
    if (!widget.viewModel.groupPreferencesSet) {
      return 'The Host must choose the Group Journey preferences.';
    }
    final notReady = widget.viewModel.members
        .where((member) => !member.isReady)
        .length;
    if (notReady > 0) {
      return notReady == 1
          ? '1 traveller is not ready yet.'
          : '$notReady travellers are not ready yet.';
    }
    return 'Everyone is ready. The Host can start the Group Journey.';
  }

  List<Widget> _groupVoteStatusCards() {
    final cards = <Widget>[];
    for (final type in GroupVoteType.values) {
      final status = widget.viewModel.voteStatus(type);
      if (status == null || status.yesVotes == 0 || status.passed) continue;
      cards.addAll(<Widget>[
        const SizedBox(height: 10),
        AppCard(
          key: Key('active_group_vote_${type.name}'),
          color: AppColors.softBlue,
          borderColor: const Color(0xFFD2E7FF),
          child: Row(
            children: <Widget>[
              const Icon(Icons.how_to_vote_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${type == GroupVoteType.hint ? 'Group Hint' : 'Route Reveal'} vote active',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    AnimatedSwitcher(
                      duration: AppTokens.fast,
                      child: Text(
                        '${status.yesVotes}/${status.requiredVotes} Yes votes',
                        key: ValueKey<String>(
                          '${type.name}-${status.yesVotes}-${status.requiredVotes}',
                        ),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ]);
    }
    final feedback = widget.viewModel.groupVoteFeedback;
    if (feedback != null) {
      final lowerFeedback = feedback.toLowerCase();
      final approved = lowerFeedback.contains('approved');
      final failed = lowerFeedback.contains('failed');
      final feedbackColor = approved
          ? AppColors.teal
          : failed
          ? AppColors.danger
          : AppColors.primary;
      final feedbackBackground = approved
          ? const Color(0xFFE9FAF4)
          : failed
          ? const Color(0xFFFFECEC)
          : AppColors.softBlue;
      cards.addAll(<Widget>[
        const SizedBox(height: 10),
        AppCard(
          key: const Key('group_vote_result'),
          color: feedbackBackground,
          borderColor: feedbackColor.withValues(alpha: .28),
          child: Row(
            children: <Widget>[
              Icon(
                approved
                    ? Icons.check_circle_rounded
                    : failed
                    ? Icons.cancel_rounded
                    : Icons.how_to_vote_rounded,
                color: feedbackColor,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(feedback)),
            ],
          ),
        ),
      ]);
    }
    return cards;
  }

  Widget _failed() => _centredState(
    icon: Icons.location_off_rounded,
    color: AppColors.danger,
    title: 'Outside Verification Radius',
    body:
        'Your current GPS position is outside the required 50m radius. Move closer and try again.',
    primary: 'Retry Location Verification',
    onPrimary: () => widget.viewModel.setStage(MysteryStage.active),
    secondary: 'View Exact Location on Map',
    onSecondary: widget.onDirections,
  );

  Widget _arrivalStatusCard() {
    final update = widget.viewModel.arrivalVerification;
    final distance = update.distanceMeters == null
        ? null
        : '${update.distanceMeters!.toStringAsFixed(0)}m from destination';
    final accuracy = update.accuracyMeters == null
        ? null
        : 'GPS accuracy: ${update.accuracyMeters!.toStringAsFixed(0)}m';
    final measuredDistance = update.distanceMeters == null
        ? null
        : 'Distance: ${update.distanceMeters!.toStringAsFixed(0)}m';
    final (title, body, color, background, icon) = switch (update.state) {
      ArrivalVerificationState.outsideRange => (
        'Outside arrival range',
        <String>[
          ?distance,
          'Move within 50m to begin verification.',
        ].join('\n'),
        AppColors.danger,
        const Color(0xFFFFECEC),
        Icons.location_off_rounded,
      ),
      ArrivalVerificationState.waitingForAccuracy => (
        'Waiting for better GPS accuracy',
        <String>[
          ?accuracy,
          ?measuredDistance,
          'Move to an open area. Accuracy must be 30m or better.',
        ].join('\n'),
        AppColors.warning,
        const Color(0xFFFFF5DF),
        Icons.gps_not_fixed_rounded,
      ),
      ArrivalVerificationState.verifying => (
        'Verifying arrival',
        <String>[
          ?measuredDistance,
          ?accuracy,
          '${update.secondsRemaining}s remaining',
        ].join('\n'),
        AppColors.primary,
        AppColors.softBlue,
        Icons.timer_outlined,
      ),
      ArrivalVerificationState.interrupted => (
        'Verification interrupted.',
        <String>[
          ?distance,
          'You left the arrival zone.',
          'Please move back within 50m and try again.',
        ].join('\n'),
        AppColors.danger,
        const Color(0xFFFFECEC),
        Icons.timer_off_outlined,
      ),
      ArrivalVerificationState.verified => (
        'Arrival verified',
        'Mystery Destination revealed.',
        AppColors.teal,
        const Color(0xFFE9FAF4),
        Icons.verified_rounded,
      ),
      ArrivalVerificationState.idle => (
        'Arrival not checked yet',
        'Tap Check Arrival with Real GPS when you reach the destination.',
        AppColors.textSecondary,
        Colors.white,
        Icons.gps_fixed_rounded,
      ),
    };
    final progress = update.state == ArrivalVerificationState.verifying
        ? ((10 - update.secondsRemaining) / 10).clamp(0.0, 1.0)
        : null;
    return AppCard(
      key: const Key('arrival_verification_status'),
      color: background,
      borderColor: color.withValues(alpha: .3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (progress != null) ...<Widget>[
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: progress),
              duration: AppTokens.fast,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _interrupted() {
    final isGroup = widget.viewModel.mode == JourneyMode.group;
    return _centredState(
      icon: Icons.warning_amber_rounded,
      color: AppColors.warning,
      title: isGroup ? 'Leave Group Journey?' : 'Cancel Solo Mystery Journey?',
      body: isGroup
          ? 'Your participation will end. Other travellers can continue their Journey.'
          : 'Your current progress, unlocked hints and active timer will be cleared.',
      primary: 'Keep Journey & Continue',
      onPrimary: () => widget.viewModel.setStage(MysteryStage.active),
      secondary: isGroup
          ? 'Confirm & Leave Journey'
          : 'Confirm & Cancel Journey',
      onSecondary: widget.viewModel.cancelJourney,
    );
  }

  Widget _genericCompletionVisual() => Container(
    key: const Key('generic_mystery_completion_visual'),
    height: 164,
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: <Color>[
          Color(0xFF173D66),
          Color(0xFF246BFD),
          Color(0xFF169C8A),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Stack(
      children: <Widget>[
        Positioned(
          right: -24,
          top: -30,
          child: Icon(
            Icons.public_rounded,
            color: Colors.white.withValues(alpha: .09),
            size: 160,
          ),
        ),
        const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.explore_rounded, color: Colors.white, size: 54),
              SizedBox(height: 8),
              Text(
                'A Malaysian story discovered',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _completionVisual() {
    final imageUrl = widget.viewModel.revealedDestination?.imageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return _genericCompletionVisual();
    }
    return Image.network(
      imageUrl,
      height: 150,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _genericCompletionVisual(),
    );
  }

  Widget _complete() => _scroll(<Widget>[
    const SizedBox(height: AppTokens.space16),
    TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: .82, end: 1),
      duration: AppTokens.normal,
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: Opacity(opacity: value.clamp(0, 1), child: child),
      ),
      child: const CircleAvatar(
        radius: 46,
        backgroundColor: Color(0xFFE9FAF4),
        child: Icon(Icons.verified_rounded, size: 52, color: AppColors.teal),
      ),
    ),
    const SizedBox(height: AppTokens.space16),
    const Center(child: Eyebrow('Verified arrival', color: AppColors.teal)),
    const SizedBox(height: AppTokens.space8),
    Text(
      'Journey Complete',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineLarge,
    ),
    const SizedBox(height: AppTokens.space8),
    const Text(
      'You found another piece of Malaysia.',
      textAlign: TextAlign.center,
      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
    ),
    const SizedBox(height: AppTokens.space16),
    AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: _completionVisual(),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 21,
                    ),
                    const SizedBox(width: AppTokens.space8),
                    Expanded(
                      child: Text(
                        widget.viewModel.revealedDestination?.name ??
                            'Mystery destination',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space8),
                Text(
                  widget.viewModel.revealedDestination?.address ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const Divider(height: 22),
                Text(
                  widget.viewModel.revealedDestination?.description ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: AppTokens.space16),
    FilledButton.icon(
      onPressed: widget.viewModel.resetForNewQuest,
      icon: const Icon(Icons.explore_rounded),
      label: const Text('Explore Another Mystery'),
    ),
    const SizedBox(height: AppTokens.space8),
    Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('add_mystery_destination_to_plan'),
            onPressed: widget.onAddToPlan,
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Add to Plan', textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(width: AppTokens.space8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.onViewPassport,
            icon: const Icon(Icons.workspace_premium_rounded),
            label: const Text('View Passport', textAlign: TextAlign.center),
          ),
        ),
      ],
    ),
    if (widget.viewModel.revealedDestination != null) ...<Widget>[
      const SizedBox(height: AppTokens.space8),
      Center(
        child: TextButton.icon(
          onPressed: widget.onDirections,
          icon: const Icon(Icons.map_outlined),
          label: const Text('View on Map'),
        ),
      ),
    ],
  ], key: const PageStorageKey<String>('mystery-complete'));

  Widget _centredState({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    required String primary,
    required VoidCallback onPrimary,
    required String secondary,
    required VoidCallback onSecondary,
  }) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: <Widget>[
          CircleAvatar(
            radius: 50,
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(icon, color: color, size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed: onPrimary,
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(primary),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onSecondary, child: Text(secondary)),
        ],
      ),
    ),
  );
}

class _JourneyProgressStep extends StatelessWidget {
  const _JourneyProgressStep({
    required this.label,
    required this.icon,
    required this.completed,
  });

  final String label;
  final IconData icon;
  final bool completed;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      AnimatedContainer(
        duration: AppTokens.fast,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: completed ? AppColors.teal : AppColors.elevated,
          border: Border.all(
            color: completed ? AppColors.teal : AppColors.borderStrong,
          ),
        ),
        child: Icon(
          completed ? Icons.check_rounded : icon,
          color: completed ? Colors.white : AppColors.muted,
          size: 15,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: completed ? AppColors.tealDark : AppColors.muted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _MysteryDetailTile extends StatelessWidget {
  const _MysteryDetailTile({
    required this.icon,
    required this.title,
    required this.text,
    this.trailing,
    this.muted = false,
  });

  final IconData icon;
  final String title;
  final String text;
  final String? trailing;
  final bool muted;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: muted ? AppColors.elevated : AppColors.softBlue,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          icon,
          color: muted ? AppColors.muted : AppColors.primary,
          size: 18,
        ),
      ),
      const SizedBox(width: AppTokens.space12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: muted
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: AppTokens.space8),
                  Flexible(
                    child: Text(
                      trailing!,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(
              text,
              softWrap: true,
              style: TextStyle(
                color: muted ? AppColors.muted : AppColors.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _TravellerTile extends StatelessWidget {
  const _TravellerTile({
    required this.initials,
    required this.name,
    required this.status,
    required this.color,
    this.avatarUrl,
    this.isHost = false,
    this.isReady,
    this.isCurrentUser = false,
  });
  final String initials;
  final String name;
  final String status;
  final Color color;
  final String? avatarUrl;
  final bool isHost;
  final bool? isReady;
  final bool isCurrentUser;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: avatarUrl?.trim().isNotEmpty == true
        ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl!))
        : InitialsAvatar(initials, color: color),
    title: Row(
      children: <Widget>[
        Flexible(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ),
        if (isHost) ...<Widget>[
          const SizedBox(width: 6),
          const AppChip(label: 'Host', selected: true),
        ],
        if (isCurrentUser) ...<Widget>[
          const SizedBox(width: 6),
          const AppChip(label: 'You'),
        ],
      ],
    ),
    subtitle: Text(status, style: const TextStyle(fontSize: 10)),
    trailing: isReady == null
        ? null
        : AnimatedSwitcher(
            duration: AppTokens.fast,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              isReady! ? Icons.check_circle_rounded : Icons.schedule_rounded,
              key: ValueKey<bool>(isReady!),
              color: isReady! ? AppColors.teal : AppColors.muted,
              size: 18,
            ),
          ),
  );
}
