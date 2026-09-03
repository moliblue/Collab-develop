import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data_layer/Models/app_models.dart';
import '../../data_layer/Models/journey.dart'
    show GroupVoteType, JourneyMember, NearbyGroupRoom;
import '../ViewModel/shake_find_view_model.dart';
import 'shared/app_widgets.dart';

class MysteryJourneyView extends StatefulWidget {
  const MysteryJourneyView({
    super.key,
    required this.viewModel,
    required this.onViewPassport,
    required this.onDirections,
    required this.notify,
  });

  final MysteryJourneyViewModel viewModel;
  final VoidCallback onViewPassport;
  final VoidCallback onDirections;
  final void Function(String, Color) notify;

  @override
  State<MysteryJourneyView> createState() => _MysteryJourneyViewState();
}

class _MysteryJourneyViewState extends State<MysteryJourneyView>
    with SingleTickerProviderStateMixin {
  bool _chatOpen = false;
  final TextEditingController _chatController = TextEditingController();
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
        height: 286,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x18203548),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset('assets/sultan_abdul_samad.png', fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[Color(0x180B2234), Color(0xDF0B2234)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
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
                  const Eyebrow('Mystery trip', color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    'Less planning.\nMore exploring.',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Follow playful clues and discover Malaysia’s stories, food and hidden corners.',
                    style: TextStyle(
                      color: Color(0xE8FFFFFF),
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
              'Solo mode',
              'Solve the mystery on your own',
              Icons.person_rounded,
              AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _modeCard(
              JourneyMode.group,
              'Team mode',
              'Solve it with nearby teammates',
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
    return AppCard(
      onTap: widget.viewModel.journeyActive
          ? null
          : () => widget.viewModel.setMode(mode),
      radius: AppTokens.cardRadius,
      color: selected ? color.withValues(alpha: .09) : Colors.white,
      borderColor: selected ? color : AppColors.border,
      child: SizedBox(
        height: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .13),
              child: Icon(icon, color: color),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 12,
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

  Widget _memberCard() => AppCard(
    child: Column(
      children: widget.viewModel.members.indexed
          .expand(
            ((int, JourneyMember) item) => <Widget>[
              if (item.$1 > 0) const Divider(),
              _memberTile(item.$2),
            ],
          )
          .toList(growable: false),
    ),
  );

  Widget _memberTile(JourneyMember member, {Color color = AppColors.softBlue}) {
    final words = member.displayName.trim().split(RegExp(r'\s+'));
    final initials = words
        .take(2)
        .where((value) => value.isNotEmpty)
        .map((value) => value[0].toUpperCase())
        .join();
    return _TravellerTile(
      initials: initials.isEmpty ? '?' : initials,
      name: member.displayName,
      status:
          '${member.isHost ? 'Host · ' : ''}'
          '${member.participantStatus ?? member.status}',
      color: color,
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
    Eyebrow(
      widget.viewModel.isHost ? 'Waiting room · You are host' : 'Waiting room',
      color: AppColors.teal,
    ),
    const SizedBox(height: 4),
    SectionTitle(
      '${widget.viewModel.roomMemberCount} travellers in the room',
      subtitle: 'Room ID: ${widget.viewModel.journey?.groupRoomId ?? ''}',
    ),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('leave_waiting_room'),
        onPressed: widget.viewModel.loading ? null : _confirmLeaveWaitingRoom,
        style: TextButton.styleFrom(foregroundColor: AppColors.danger),
        icon: const Icon(Icons.exit_to_app_rounded),
        label: Text(
          widget.viewModel.isHost ? 'Close Waiting Room' : 'Leave Waiting Room',
        ),
      ),
    ),
    const SizedBox(height: 14),
    AppCard(
      color: const Color(0xFFE9FAF4),
      borderColor: const Color(0xFFBFECDD),
      child: Column(
        children: <Widget>[
          ...widget.viewModel.members.indexed.expand(
            ((int, JourneyMember) item) => <Widget>[
              if (item.$1 > 0) const Divider(),
              _memberTile(item.$2, color: Colors.white),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'I’m ready',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            value: widget.viewModel.ready,
            onChanged: widget.viewModel.setReady,
            activeThumbColor: AppColors.teal,
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    AppCard(
      child: Column(
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: AppColors.softBlue,
              child: Icon(Icons.tune_rounded, color: AppColors.primary),
            ),
            title: const Text(
              'Group preferences',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              widget.viewModel.groupPreferencesSet
                  ? '${widget.viewModel.categories.join(', ')} · ${widget.viewModel.radius.round()} km'
                  : 'Host selects the group mood',
            ),
            trailing: TextButton(
              onPressed:
                  widget.viewModel.isHost &&
                      widget.viewModel.roomMemberCount >= 2
                  ? _editPreferencesSheet
                  : null,
              child: Text(
                widget.viewModel.groupPreferencesSet ? 'Edit' : 'Set',
              ),
            ),
          ),
          if (widget.viewModel.groupChatUnlocked) ...<Widget>[
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: widget.viewModel.groupChatUnlocked
                    ? const Color(0xFFE9FAF4)
                    : AppColors.elevated,
                child: Icon(
                  widget.viewModel.groupChatUnlocked
                      ? Icons.chat_rounded
                      : Icons.lock_rounded,
                  color: widget.viewModel.groupChatUnlocked
                      ? AppColors.teal
                      : AppColors.muted,
                ),
              ),
              title: Text(
                widget.viewModel.groupChatUnlocked
                    ? 'Group chat unlocked'
                    : 'Group chat locked',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                widget.viewModel.groupChatUnlocked
                    ? '${widget.viewModel.roomMemberCount} people in this room'
                    : 'Chat unlocks when another traveller joins',
              ),
              trailing: IconButton(
                onPressed: () {
                  setState(() => _chatOpen = !_chatOpen);
                  if (_chatOpen) {
                    unawaited(widget.viewModel.loadGroupMessages());
                  }
                },
                icon: Icon(_chatOpen ? Icons.expand_less : Icons.expand_more),
              ),
            ),
          ],
          if (_chatOpen && widget.viewModel.groupChatUnlocked) ...<Widget>[
            ...widget.viewModel.messages.map(
              (String m) => Align(
                alignment: m.startsWith('You:')
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: m.startsWith('You:')
                        ? AppColors.primary
                        : AppColors.elevated,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    m,
                    style: TextStyle(
                      color: m.startsWith('You:')
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
            TextField(
              controller: _chatController,
              onSubmitted: _sendChat,
              decoration: InputDecoration(
                hintText: 'Share a clue guess…',
                suffixIcon: IconButton(
                  onPressed: () => _sendChat(_chatController.text),
                  icon: const Icon(Icons.send_rounded),
                  tooltip: 'Send message',
                ),
              ),
            ),
          ],
        ],
      ),
    ),
    const SizedBox(height: 16),
    FilledButton.icon(
      onPressed:
          widget.viewModel.ready &&
              widget.viewModel.isHost &&
              widget.viewModel.roomMemberCount >= 2 &&
              widget.viewModel.groupPreferencesSet
          ? () => widget.viewModel.setStage(MysteryStage.shake)
          : null,
      icon: const Icon(Icons.rocket_launch_rounded),
      label: const Text('Start Group Journey'),
    ),
    const SizedBox(height: 8),
    OutlinedButton.icon(
      onPressed:
          widget.viewModel.isHost && widget.viewModel.roomMemberCount >= 2
          ? widget.viewModel.useGroupSurpriseMe
          : null,
      icon: const Icon(Icons.auto_awesome_rounded),
      label: const Text('Surprise the group'),
    ),
    if (kDebugMode && widget.viewModel.isHost) ...<Widget>[
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const Key('add_test_group_member'),
        onPressed:
            widget.viewModel.loading || widget.viewModel.roomMemberCount >= 4
            ? null
            : widget.viewModel.addTestCompanion,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Test Explorer to Room'),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text(
          'Debug companion · Joins this room for the full Group Journey flow.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: AppColors.muted),
        ),
      ),
    ],
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
            color: AppColors.primaryDark,
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
          child: const Icon(
            Icons.explore_rounded,
            color: Colors.white,
            size: 72,
          ),
        ),
      ),
    ),
    const SizedBox(height: 34),
    Text(
      widget.viewModel.mode == JourneyMode.group
          ? 'Ready to sync?'
          : 'Shake your phone!',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineLarge,
    ),
    const SizedBox(height: 8),
    Text(
      widget.viewModel.mode == JourneyMode.group
          ? 'When everyone is ready, the host can trigger one shared reveal for the whole room.'
          : 'Shake your phone to generate your personalized mystery heritage clue.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    if (widget.viewModel.mode == JourneyMode.group) ...<Widget>[
      const SizedBox(height: 20),
      AppCard(
        color: const Color(0xFFE9FAF4),
        borderColor: const Color(0xFFBFECDD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Room ready check',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                AppChip(
                  label: widget.viewModel.ready ? 'All synced' : 'Waiting',
                  selected: widget.viewModel.ready,
                  selectedColor: AppColors.teal,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'You',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Tap to toggle your ready status'),
              value: widget.viewModel.ready,
              onChanged: widget.viewModel.setReady,
              activeThumbColor: AppColors.teal,
            ),
            ...widget.viewModel.members.indexed.expand(
              ((int, JourneyMember) item) => <Widget>[
                if (item.$1 > 0) const Divider(),
                _memberTile(item.$2, color: Colors.white),
              ],
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

  Widget _active() => _scroll(<Widget>[
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF173D66),
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Eyebrow('Live mystery', color: Colors.white),
          const SizedBox(height: 8),
          Text(
            'Your hidden destination',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.viewModel.clue,
            style: const TextStyle(
              color: Color(0xE6FFFFFF),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
    if (widget.viewModel.loading) ...<Widget>[
      const SizedBox(height: 10),
      const LinearProgressIndicator(),
    ],
    if (widget.viewModel.message != null) ...<Widget>[
      const SizedBox(height: 10),
      AppCard(
        color: const Color(0xFFFFF5DF),
        child: Text(widget.viewModel.message!),
      ),
    ],
    const SizedBox(height: 13),
    AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.near_me_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.viewModel.distanceMeters > 0
                      ? '${widget.viewModel.distanceMeters.toStringAsFixed(0)} m away'
                      : 'Distance updates with GPS',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.viewModel.routeRevealed
                    ? widget.viewModel.journey?.locationHint ?? 'Exact route'
                    : 'Destination hidden',
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
          ...widget.viewModel.hints.map(
            (String hint) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Hint: $hint',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    if (widget.viewModel.mode == JourneyMode.group) ...<Widget>[
      const SizedBox(height: 12),
      _memberCard(),
    ],
    const SizedBox(height: 14),
    Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed:
                widget.viewModel.hintCount >= 3 ||
                    (widget.viewModel.mode == JourneyMode.group &&
                        widget.viewModel.hasSubmittedVote(GroupVoteType.hint))
                ? null
                : _askHint,
            icon: const Icon(Icons.lightbulb_outline_rounded),
            label: Text(_voteButtonLabel(GroupVoteType.hint, 'Unlock hint')),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: widget.viewModel.routeRevealed
                ? widget.onDirections
                : widget.viewModel.mode == JourneyMode.group &&
                      widget.viewModel.hasSubmittedVote(GroupVoteType.route)
                ? null
                : _confirmRoute,
            icon: const Icon(Icons.route_rounded),
            label: Text(
              widget.viewModel.routeRevealed
                  ? 'Open Map'
                  : _voteButtonLabel(GroupVoteType.route, 'Reveal route'),
            ),
          ),
        ),
      ],
    ),
    if (widget.viewModel.mode == JourneyMode.group) ...<Widget>[
      const SizedBox(height: 12),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.monitor_heart_rounded, color: AppColors.teal),
                SizedBox(width: 8),
                Text(
                  'Team activity',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const Divider(height: 22),
            ...widget.viewModel.members.map(
              (JourneyMember member) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: CircleAvatar(
                        radius: 3,
                        backgroundColor: AppColors.teal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${member.displayName}: '
                        '${member.participantStatus ?? member.status}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
    const SizedBox(height: 12),
    if (widget.viewModel.mode == JourneyMode.group &&
        widget.viewModel.groupChatUnlocked)
      AppCard(
        child: Column(
          children: <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.forum_rounded, color: AppColors.teal),
              title: const Text(
                'Group Chat',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text('${widget.viewModel.roomMemberCount} members'),
              trailing: IconButton(
                onPressed: () {
                  setState(() => _chatOpen = !_chatOpen);
                  if (_chatOpen) {
                    unawaited(widget.viewModel.loadGroupMessages());
                  }
                },
                icon: Icon(_chatOpen ? Icons.expand_less : Icons.expand_more),
              ),
            ),
            if (_chatOpen) ...<Widget>[
              ...widget.viewModel.messages.map(
                (String message) => Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text(message, style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ),
              TextField(
                controller: _chatController,
                onSubmitted: _sendChat,
                decoration: InputDecoration(
                  hintText: 'Share a clue guess…',
                  suffixIcon: IconButton(
                    onPressed: () => _sendChat(_chatController.text),
                    icon: const Icon(Icons.send_rounded),
                    tooltip: 'Send message',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    if (kDebugMode) ...<Widget>[
      const SizedBox(height: 12),
      _developerTestingCard(),
    ],
    const SizedBox(height: 12),
    FilledButton.icon(
      key: const Key('test_real_arrival'),
      onPressed: widget.viewModel.loading
          ? null
          : widget.viewModel.testArrivalNow,
      icon: const Icon(Icons.gps_fixed_rounded),
      label: const Text('Check Arrival with Real GPS'),
    ),
    const SizedBox(height: 8),
    TextButton.icon(
      onPressed: () => widget.viewModel.setStage(MysteryStage.interrupted),
      icon: const Icon(Icons.pause_circle_outline_rounded),
      label: const Text('Leave and continue later'),
    ),
  ]);

  Widget _developerTestingCard() {
    final canSimulateTestExplorer =
        widget.viewModel.mode == JourneyMode.group &&
        widget.viewModel.isHost &&
        widget.viewModel.hasActiveTestExplorer;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.science_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Developer Testing',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (canSimulateTestExplorer) ...<Widget>[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('simulate_test_explorer_hint_vote'),
              onPressed:
                  widget.viewModel.loading ||
                      widget.viewModel.hasTestExplorerVote(GroupVoteType.hint)
                  ? null
                  : () => _simulateTestExplorerVote(GroupVoteType.hint),
              child: const Text('Simulate Test Explorer Hint Vote'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('simulate_test_explorer_route_vote'),
              onPressed:
                  widget.viewModel.loading ||
                      widget.viewModel.hasTestExplorerVote(GroupVoteType.route)
                  ? null
                  : () => _simulateTestExplorerVote(GroupVoteType.route),
              child: const Text('Simulate Test Explorer Reveal Vote'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('simulate_test_explorer_arrival'),
              onPressed: widget.viewModel.loading
                  ? null
                  : () => widget.viewModel.simulateArrival(testExplorer: true),
              icon: const Icon(Icons.person_pin_circle_rounded),
              label: const Text('Simulate Test Explorer Arrival'),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('simulate_my_arrival'),
            onPressed: widget.viewModel.loading
                ? null
                : widget.viewModel.simulateArrival,
            icon: const Icon(Icons.my_location_rounded),
            label: const Text('Simulate My Arrival'),
          ),
        ],
      ),
    );
  }

  void _sendChat(String value) {
    final message = value.trim();
    if (message.isEmpty) return;
    widget.viewModel.addMessage(message);
    _chatController.clear();
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

  Future<void> _simulateTestExplorerVote(GroupVoteType type) async {
    final outcome = await widget.viewModel.simulateTestExplorerVote(type);
    if (!mounted || outcome == null) return;
    widget.notify(
      'Test Explorer · ${outcome.message}',
      outcome.passed ? AppColors.teal : AppColors.primary,
    );
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

  Widget _interrupted() => _centredState(
    icon: Icons.warning_amber_rounded,
    color: AppColors.warning,
    title: 'Cancel Active Journey?',
    body: 'Progress, unlocked hints and the active timer will be cleared.',
    primary: 'Keep Journey & Continue',
    onPrimary: () => widget.viewModel.setStage(MysteryStage.active),
    secondary: 'Confirm & Cancel Journey',
    onSecondary: widget.viewModel.cancelJourney,
  );

  Widget _complete() => _scroll(<Widget>[
    const SizedBox(height: 30),
    const CircleAvatar(
      radius: 48,
      backgroundColor: Color(0xFFE9FAF4),
      child: Icon(Icons.verified_rounded, size: 55, color: AppColors.teal),
    ),
    const SizedBox(height: 18),
    const Eyebrow('Verified arrival', color: AppColors.teal),
    const SizedBox(height: 8),
    Text(
      'Quest Completed!',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineLarge,
    ),
    const SizedBox(height: 5),
    const Text(
      'You found the mystery destination and earned a new travel memory.',
      textAlign: TextAlign.center,
      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
    ),
    const SizedBox(height: 18),
    AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Stack(
              children: <Widget>[
                if (widget.viewModel.revealedDestination?.imageUrl
                    case final url?)
                  Image.network(
                    url,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Image.asset(
                      'assets/sultan_abdul_samad.png',
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Image.asset(
                    'assets/sultan_abdul_samad.png',
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '+100 XP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.viewModel.revealedDestination?.name ??
                      'Mystery destination',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.viewModel.revealedDestination?.address ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.viewModel.revealedDestination?.description ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.onViewPassport,
            icon: const Icon(Icons.workspace_premium_rounded),
            label: const Text('View Passport'),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: FilledButton.icon(
            onPressed: widget.viewModel.resetForNewQuest,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('New Quest'),
          ),
        ),
      ],
    ),
  ]);

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

class _TravellerTile extends StatelessWidget {
  const _TravellerTile({
    required this.initials,
    required this.name,
    required this.status,
    required this.color,
  });
  final String initials;
  final String name;
  final String status;
  final Color color;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: InitialsAvatar(initials, color: color),
    title: Text(
      name,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
    ),
    subtitle: Text(status, style: const TextStyle(fontSize: 10)),
    trailing: const Icon(
      Icons.check_circle_rounded,
      color: AppColors.teal,
      size: 18,
    ),
  );
}
