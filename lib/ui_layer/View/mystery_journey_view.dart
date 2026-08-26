import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data_layer/Models/app_models.dart';
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
  bool _checkInComplete = false;
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
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
      MysteryStage.preferences => _preferences(),
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
              onPressed: () => widget.viewModel.setStage(MysteryStage.active),
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
                const Eyebrow('Mystery Journey', color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  'Follow a clue.\nFind a story.',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Discover a Malaysian place without revealing the destination too soon.',
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
            'Solo Explorer',
            'Follow the clues at your own pace',
            Icons.person_rounded,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _modeCard(
            JourneyMode.group,
            'Group Explorer',
            'Discover with nearby travellers',
            Icons.groups_rounded,
            AppColors.teal,
          ),
        ),
      ],
    ),
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
                      'Your travel mood',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Personalise the surprise',
                      style: TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _editPreferencesSheet,
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
                label: '${widget.viewModel.radius.round()} km',
                selected: true,
              ),
            ],
          ),
        ],
      ),
    ),
    Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () => widget.viewModel.setStage(MysteryStage.preferences),
        icon: const Icon(Icons.tune_rounded, size: 17),
        label: const Text('Detailed preferences'),
      ),
    ),
    const SizedBox(height: 16),
    FilledButton.icon(
      key: const Key('start_mystery'),
      onPressed: () => widget.viewModel.setStage(
        widget.viewModel.mode == JourneyMode.solo
            ? MysteryStage.shake
            : MysteryStage.groupSetup,
      ),
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
    const SizedBox(height: 9),
    OutlinedButton.icon(
      onPressed: () {
        widget.viewModel.setMode(JourneyMode.solo);
        widget.viewModel.setStage(MysteryStage.shake);
        widget.notify(
          'Surprise Me ignores preferences for this quest.',
          AppColors.primary,
        );
      },
      icon: const Icon(Icons.auto_awesome_rounded),
      label: const Text('Surprise me'),
    ),
  ], key: const PageStorageKey<String>('mystery-home'));

  Widget _modeCard(
    JourneyMode mode,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final selected = widget.viewModel.mode == mode;
    return AppCard(
      onTap: () => widget.viewModel.setMode(mode),
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
              max: 30,
              divisions: 5,
              onChanged: (double value) =>
                  setSheet(() => widget.viewModel.setRadius(value)),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                widget.notify('Travel mood saved.', AppColors.teal);
              },
              child: const Text('Save preferences'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupSetup() => _scroll(<Widget>[
    const SizedBox(height: 18),
    Center(
      child: AnimatedContainer(
        duration: AppTokens.normal,
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.viewModel.matched
              ? const Color(0xFFE9FAF4)
              : AppColors.softBlue,
          border: Border.all(
            color: widget.viewModel.matched
                ? AppColors.teal
                : AppColors.primary,
            width: 2,
          ),
        ),
        child: Icon(
          widget.viewModel.matched ? Icons.group_rounded : Icons.radar_rounded,
          size: 66,
          color: widget.viewModel.matched ? AppColors.teal : AppColors.primary,
        ),
      ),
    ),
    const SizedBox(height: 24),
    Text(
      widget.viewModel.matched
          ? 'Nearby team found!'
          : 'Find travellers nearby',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 7),
    Text(
      widget.viewModel.matched
          ? '3 explorers are ready within 1 km.'
          : 'We’ll scan a 1 km radius for people who want to discover Malaysia together.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    const SizedBox(height: 24),
    if (!widget.viewModel.matched)
      FilledButton.icon(
        onPressed: widget.viewModel.scanning
            ? null
            : widget.viewModel.scanNearby,
        icon: widget.viewModel.scanning
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.radar_rounded),
        label: Text(
          widget.viewModel.scanning ? 'Scanning nearby…' : 'Scan for teammates',
        ),
      ),
    if (widget.viewModel.matched) ...<Widget>[
      AppCard(
        child: Column(
          children: const <Widget>[
            _TravellerTile(
              initials: 'AM',
              name: 'Amberly',
              status: 'Host · Ready',
              color: AppColors.softBlue,
            ),
            Divider(),
            _TravellerTile(
              initials: 'LT',
              name: 'Lucas Tan',
              status: 'Ready · 420m away',
              color: Color(0xFFE9FAF4),
            ),
            Divider(),
            _TravellerTile(
              initials: 'AS',
              name: 'Amirah S.',
              status: 'Ready · 760m away',
              color: Color(0xFFFFF5DF),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: () => widget.viewModel.setStage(MysteryStage.groupWaiting),
        icon: const Icon(Icons.meeting_room_rounded),
        label: const Text('Enter Waiting Room'),
      ),
    ],
    const SizedBox(height: 9),
    OutlinedButton(
      onPressed: () {
        widget.viewModel.setMode(JourneyMode.solo);
        widget.viewModel.setStage(MysteryStage.home);
      },
      child: const Text('Continue Solo instead'),
    ),
  ]);

  Widget _groupWaiting() => _scroll(<Widget>[
    const Eyebrow('Group room · You are host', color: AppColors.teal),
    const SizedBox(height: 4),
    const SectionTitle(
      'Ready for a shared mystery?',
      subtitle: 'Everyone must be ready before the trip begins.',
    ),
    const SizedBox(height: 14),
    AppCard(
      color: const Color(0xFFE9FAF4),
      borderColor: const Color(0xFFBFECDD),
      child: Column(
        children: <Widget>[
          const _TravellerTile(
            initials: 'AM',
            name: 'Amberly',
            status: 'Host · Ready',
            color: Colors.white,
          ),
          const Divider(),
          const _TravellerTile(
            initials: 'LT',
            name: 'Lucas Tan',
            status: 'Ready · 420m',
            color: Colors.white,
          ),
          const Divider(),
          const _TravellerTile(
            initials: 'AS',
            name: 'Amirah S.',
            status: 'Ready · 760m',
            color: Colors.white,
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
              onPressed: () {
                widget.viewModel.setGroupPreferences(true);
                _editPreferencesSheet();
              },
              child: Text(
                widget.viewModel.groupPreferencesSet ? 'Edit' : 'Set',
              ),
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: widget.viewModel.groupPreferencesSet
                  ? const Color(0xFFE9FAF4)
                  : AppColors.elevated,
              child: Icon(
                widget.viewModel.groupPreferencesSet
                    ? Icons.chat_rounded
                    : Icons.lock_rounded,
                color: widget.viewModel.groupPreferencesSet
                    ? AppColors.teal
                    : AppColors.muted,
              ),
            ),
            title: Text(
              widget.viewModel.groupPreferencesSet
                  ? 'Group chat unlocked'
                  : 'Group chat locked',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text('Chat unlocks after preferences are set'),
            trailing: IconButton(
              onPressed: widget.viewModel.groupPreferencesSet
                  ? () => setState(() => _chatOpen = !_chatOpen)
                  : null,
              icon: Icon(_chatOpen ? Icons.expand_less : Icons.expand_more),
            ),
          ),
          if (_chatOpen) ...<Widget>[
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
              onSubmitted: widget.viewModel.addMessage,
              decoration: const InputDecoration(
                hintText: 'Share a clue guess…',
                suffixIcon: Icon(Icons.send_rounded),
              ),
            ),
          ],
        ],
      ),
    ),
    const SizedBox(height: 16),
    FilledButton.icon(
      onPressed: widget.viewModel.ready && widget.viewModel.groupPreferencesSet
          ? () => widget.viewModel.setStage(MysteryStage.shake)
          : null,
      icon: const Icon(Icons.rocket_launch_rounded),
      label: const Text('Start Group Journey'),
    ),
    const SizedBox(height: 8),
    OutlinedButton.icon(
      onPressed: () {
        widget.viewModel.setStage(MysteryStage.shake);
        widget.notify('Random group discovery activated.', AppColors.primary);
      },
      icon: const Icon(Icons.auto_awesome_rounded),
      label: const Text('Surprise the group'),
    ),
  ]);

  Widget _preferences() => _scroll(<Widget>[
    const SectionTitle(
      'Mystery preferences',
      subtitle: 'Choose interests and a comfortable discovery radius.',
    ),
    const SizedBox(height: 12),
    AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children:
                <String>['Culture', 'History', 'Local food', 'Art & streets']
                    .map(
                      (String c) => AppChip(
                        label: c,
                        selected: widget.viewModel.categories.contains(c),
                        onTap: () => widget.viewModel.toggleCategory(c),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 14),
          Text(
            'Radius · ${widget.viewModel.radius.round()} km',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Slider(
            value: widget.viewModel.radius,
            min: 5,
            max: 30,
            divisions: 5,
            onChanged: widget.viewModel.setRadius,
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    FilledButton(
      onPressed: () => widget.viewModel.setStage(MysteryStage.shake),
      child: const Text('Continue'),
    ),
    const SizedBox(height: 8),
    OutlinedButton(
      onPressed: () => widget.viewModel.setStage(MysteryStage.shake),
      child: const Text('Surprise me'),
    ),
  ]);

  Widget _shake() => _scroll(<Widget>[
    const SizedBox(height: 38),
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
      'Shake to discover',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineLarge,
    ),
    const SizedBox(height: 8),
    Text(
      widget.viewModel.mode == JourneyMode.group
          ? 'Shake together to reveal your shared mystery clue.'
          : 'Give your phone a confident shake. We’ll choose a destination from your travel mood.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    const SizedBox(height: 26),
    FilledButton.icon(
      key: const Key('tap_to_discover'),
      onPressed: () {
        widget.viewModel.startJourney();
        widget.notify('Mystery clue generated!', AppColors.teal);
      },
      icon: const Icon(Icons.touch_app_rounded),
      label: const Text('Discover now'),
    ),
    const SizedBox(height: 8),
    const Center(
      child: Text(
        'Prefer not to shake? Use the button to continue.',
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
    ),
  ]);

  Widget _active() => _scroll(<Widget>[
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF173D66),
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Eyebrow('Live mystery', color: Colors.white),
          SizedBox(height: 8),
          Text(
            'Follow the clock’s story',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'A 19th-century copper-domed keeper of time watches over the square where a nation found its voice.',
            style: TextStyle(
              color: Color(0xE6FFFFFF),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 13),
    AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.near_me_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                '1.5 km away',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              Spacer(),
              Text(
                'Central KL',
                style: TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
          if (widget.viewModel.hintCount > 0) ...<Widget>[
            const Divider(height: 24),
            const Text(
              'Hint: Look opposite the tall flagpole at Merdeka Square.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          if (widget.viewModel.hintCount > 1)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Extra hint: Its clock tower has three copper domes.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    ),
    if (widget.viewModel.mode == JourneyMode.group) ...<Widget>[
      const SizedBox(height: 12),
      AppCard(
        child: Column(
          children: const <Widget>[
            _TravellerTile(
              initials: 'LT',
              name: 'Lucas Tan',
              status: '420m from destination',
              color: Color(0xFFE9FAF4),
            ),
            Divider(),
            _TravellerTile(
              initials: 'AS',
              name: 'Amirah S.',
              status: '760m from destination',
              color: Color(0xFFFFF5DF),
            ),
          ],
        ),
      ),
    ],
    const SizedBox(height: 14),
    Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.viewModel.hintCount >= 2 ? null : _askHint,
            icon: const Icon(Icons.lightbulb_outline_rounded),
            label: const Text('Unlock hint'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: widget.viewModel.routeRevealed
                ? widget.onDirections
                : _confirmRoute,
            icon: const Icon(Icons.route_rounded),
            label: Text(
              widget.viewModel.routeRevealed ? 'Open Map' : 'Reveal route',
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    if (widget.viewModel.mode == JourneyMode.group)
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
              subtitle: const Text('3 online'),
              trailing: IconButton(
                onPressed: () => setState(() => _chatOpen = !_chatOpen),
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
                onSubmitted: widget.viewModel.addMessage,
                decoration: const InputDecoration(
                  hintText: 'Share a clue guess…',
                  suffixIcon: Icon(Icons.send_rounded),
                ),
              ),
            ],
          ],
        ),
      ),
    const SizedBox(height: 12),
    FilledButton.icon(
      onPressed: widget.viewModel.mode == JourneyMode.group
          ? _showGroupCheckIn
          : _showArrivalOptions,
      icon: Icon(
        widget.viewModel.mode == JourneyMode.group
            ? Icons.groups_rounded
            : Icons.gps_fixed_rounded,
      ),
      label: Text(
        widget.viewModel.mode == JourneyMode.group
            ? 'Group Verified Arrival'
            : 'Verified Arrival',
      ),
    ),
    const SizedBox(height: 8),
    TextButton.icon(
      onPressed: () => widget.viewModel.setStage(MysteryStage.interrupted),
      icon: const Icon(Icons.pause_circle_outline_rounded),
      label: const Text('Leave and continue later'),
    ),
  ]);

  void _askHint() {
    if (widget.viewModel.mode == JourneyMode.group) {
      _voteDialog('Unlock this group hint?', widget.viewModel.unlockHint);
    } else {
      widget.viewModel.unlockHint();
      widget.notify('New hint unlocked.', AppColors.primary);
    }
  }

  void _confirmRoute() {
    void revealAndNavigate() {
      widget.viewModel.revealRoute();
      widget.onDirections();
    }

    if (widget.viewModel.mode == JourneyMode.group) {
      _voteDialog('Reveal the exact route?', revealAndNavigate);
    } else {
      _voteDialog('Reveal exact route?', revealAndNavigate, group: false);
    }
  }

  Future<void> _voteDialog(
    String title,
    VoidCallback accepted, {
    bool group = true,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        icon: Icon(
          group ? Icons.how_to_vote_rounded : Icons.route_rounded,
          color: AppColors.primary,
          size: 34,
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(
          group
              ? 'A majority of 2 out of 3 travellers is required. Help may reduce the final achievement score.'
              : 'The precise destination and navigation route will be shown.',
          textAlign: TextAlign.center,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              if (group) {
                widget.notify('Vote passed · 3/3 approved.', AppColors.teal);
              }
              accepted();
            },
            child: Text(group ? 'Vote Yes' : 'Reveal Route'),
          ),
        ],
      ),
    );
  }

  Future<void> _showArrivalOptions() async {
    await showAppSheet<void>(
      context,
      SheetBody(
        children: <Widget>[
          const ModalTitle(
            title: 'Arrival verification',
            subtitle: 'Deterministic GPS demo controls',
            icon: Icons.gps_fixed_rounded,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.viewModel.finishJourney();
            },
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Verify arrival successfully'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.viewModel.setStage(MysteryStage.verificationFailed);
            },
            icon: const Icon(Icons.location_off_rounded),
            label: const Text('Simulate GPS error'),
          ),
        ],
      ),
    );
  }

  Future<void> _showGroupCheckIn() async {
    _checkInComplete = false;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          icon: Icon(
            _checkInComplete ? Icons.camera_alt_rounded : Icons.groups_rounded,
            color: AppColors.teal,
            size: 40,
          ),
          title: Text(
            _checkInComplete ? 'Team photo verified!' : 'Team is in range',
            textAlign: TextAlign.center,
          ),
          content: Text(
            _checkInComplete
                ? 'Everyone made it. This group memory has been saved.'
                : '3 of 3 travellers are within 500m. Minimum requirement: 2.',
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            if (!_checkInComplete)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Not yet'),
              ),
            FilledButton(
              onPressed: () {
                if (!_checkInComplete) {
                  setDialog(() => _checkInComplete = true);
                } else {
                  Navigator.pop(context);
                  widget.viewModel.finishJourney();
                }
              },
              child: Text(
                _checkInComplete ? 'Complete Group Quest' : 'Check in together',
              ),
            ),
          ],
        ),
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
                      '+400 XP',
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
          const Padding(
            padding: EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Sultan Abdul Samad Clock Tower',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'Dataran Merdeka, Kuala Lumpur',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 10),
                AppChip(
                  label: 'Independence Explorer badge',
                  selected: true,
                  selectedColor: AppColors.warning,
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
