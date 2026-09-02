import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data_layer/Models/journey.dart';
import '../ViewModel/shake_find_view_model.dart';
import 'shared/premium_animated_button.dart';

class ShakeFindView extends StatefulWidget {
  const ShakeFindView({super.key, required this.viewModel});

  final ShakeFindViewModel viewModel;

  @override
  State<ShakeFindView> createState() => _ShakeFindViewState();
}

class _ShakeFindViewState extends State<ShakeFindView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heroController;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.viewModel.initialize();
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shake & Find'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Chip(label: Text('Mystery mode')),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          top: false,
          child: AnimatedBuilder(
            animation: widget.viewModel,
            builder: (context, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _content(widget.viewModel),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(ShakeFindViewModel vm) {
    final journey = vm.journey;
    if (journey == null) return _setup(vm);
    if (journey.status == JourneyStatus.completed) {
      return _completed(vm, journey);
    }
    return _journey(vm, journey);
  }

  Widget _setup(ShakeFindViewModel vm) {
    return ListView(
      key: const ValueKey('setup'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _hero(),
        const SizedBox(height: 24),
        const Text(
          'Where will curiosity take you?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose how you explore, then shake to unlock a destination.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 22),
        SegmentedButton<JourneyMode>(
          segments: const [
            ButtonSegment(
              value: JourneyMode.solo,
              icon: Icon(Icons.person),
              label: Text('Solo'),
            ),
            ButtonSegment(
              value: JourneyMode.group,
              icon: Icon(Icons.groups),
              label: Text('Group'),
            ),
          ],
          selected: {vm.selectedMode},
          onSelectionChanged: vm.isLoading
              ? null
              : (selection) => vm.selectMode(selection.first),
        ),
        const SizedBox(height: 18),
        _InfoCard(
          icon: Icons.tune_rounded,
          title: 'Travel preferences',
          body: vm.preferences.summary,
          trailing: TextButton(
            onPressed: vm.isLoading ? null : () => _editPreferences(vm),
            child: const Text('Edit'),
          ),
        ),
        if (vm.message != null) ...[
          const SizedBox(height: 14),
          _StatusBanner(message: vm.message!, warning: vm.sensorUnavailable),
        ],
        const SizedBox(height: 20),
        PremiumAnimatedButton(
          label: vm.isListeningForShake
              ? 'Listening for a shake...'
              : 'Enable Shake to Start',
          icon: Icons.screen_rotation_alt_rounded,
          isLoading: vm.isLoading,
          onPressed: vm.isListeningForShake || vm.isLoading
              ? null
              : vm.startShakeDetection,
        ),
        if (vm.isListeningForShake) ...[
          const SizedBox(height: 10),
          PremiumAnimatedButton(
            label: 'Stop listening',
            icon: Icons.stop_circle_outlined,
            isOutlined: true,
            onPressed: vm.stopShakeDetection,
          ),
        ],
        const SizedBox(height: 10),
        PremiumAnimatedButton(
          label: 'Tap instead',
          icon: Icons.touch_app_rounded,
          isOutlined: true,
          isLoading: vm.isLoading,
          onPressed: vm.isLoading ? null : vm.startJourney,
        ),
      ],
    );
  }

  Widget _hero() {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: const Color(0xFF173D66),
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .22),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _heroController,
        child: const Icon(Icons.explore_rounded, size: 92, color: Colors.white),
        builder: (context, child) => Transform.translate(
          offset: Offset(0, math.sin(_heroController.value * math.pi) * -8),
          child: Transform.rotate(
            angle: math.sin(_heroController.value * math.pi * 2) * .035,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _journey(ShakeFindViewModel vm, Journey journey) {
    final routeVisible =
        journey.status == JourneyStatus.routeRevealed ||
        journey.status == JourneyStatus.verifying;
    return ListView(
      key: ValueKey(journey.status),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        const Icon(Icons.auto_awesome, size: 62, color: AppColors.primary),
        const SizedBox(height: 12),
        Text(
          routeVisible ? 'Route revealed' : 'Your mystery clue',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        _InfoCard(
          icon: routeVisible ? Icons.route_rounded : Icons.lightbulb_outline,
          title: routeVisible ? journey.locationHint : 'Clue',
          body: journey.clue,
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.near_me_outlined,
          title: '${journey.distanceMeters.toStringAsFixed(0)} metres away',
          body: routeVisible
              ? 'Follow the revealed route.'
              : journey.locationHint,
        ),
        if (vm.message != null) ...[
          const SizedBox(height: 12),
          _StatusBanner(message: vm.message!, warning: vm.gpsUnavailable),
        ],
        const SizedBox(height: 20),
        if (!routeVisible) ...[
          PremiumAnimatedButton(
            label: 'Request another hint',
            icon: Icons.tips_and_updates_outlined,
            isOutlined: true,
            onPressed: vm.isLoading ? null : vm.requestHint,
          ),
          const SizedBox(height: 10),
          PremiumAnimatedButton(
            label: 'Reveal route',
            icon: Icons.route_rounded,
            isLoading: vm.isLoading,
            onPressed: vm.isLoading ? null : vm.revealRoute,
          ),
        ] else
          PremiumAnimatedButton(
            label: journey.status == JourneyStatus.verifying
                ? 'Checking your location...'
                : 'Verify destination arrival',
            icon: Icons.gps_fixed_rounded,
            isLoading: vm.isLoading,
            onPressed: vm.isLoading ? null : vm.verifyArrival,
          ),
        const SizedBox(height: 10),
        PremiumAnimatedButton(
          label: 'Cancel journey',
          icon: Icons.close_rounded,
          isOutlined: true,
          onPressed: vm.isLoading ? null : vm.cancelJourney,
        ),
      ],
    );
  }

  Widget _completed(ShakeFindViewModel vm, Journey journey) {
    return ListView(
      key: const ValueKey('completed'),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const CircleAvatar(
          radius: 58,
          backgroundColor: AppColors.success,
          child: Icon(Icons.check_rounded, size: 70, color: Colors.white),
        ),
        const SizedBox(height: 24),
        const Text(
          'Journey completed!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 29, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          'You found ${journey.locationHint}. Ready for another mystery?',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 28),
        PremiumAnimatedButton(
          label: 'Start another journey',
          icon: Icons.refresh_rounded,
          onPressed: vm.resetJourney,
        ),
      ],
    );
  }

  Future<void> _editPreferences(ShakeFindViewModel vm) async {
    final result = await showModalBottomSheet<TravelPreferences>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PreferencesSheet(initial: vm.preferences),
    );
    if (result != null && mounted) vm.updatePreferences(result);
  }
}

class _PreferencesSheet extends StatefulWidget {
  const _PreferencesSheet({required this.initial});
  final TravelPreferences initial;

  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  late Set<String> categories = {...widget.initial.categories};
  late double radius = widget.initial.radiusKm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Travel preferences',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: ['Culture', 'History', 'Local food', 'Art & streets']
                  .map(
                    (item) => FilterChip(
                      label: Text(item),
                      selected: categories.contains(item),
                      onSelected: (selected) => setState(
                        () => selected
                            ? categories.add(item)
                            : categories.remove(item),
                      ),
                    ),
                  )
                  .toList(),
            ),
            Text('Radius: ${radius.toStringAsFixed(0)} km'),
            Slider(
              value: radius,
              min: 5,
              max: 30,
              divisions: 5,
              onChanged: (value) => setState(() => radius = value),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                TravelPreferences(categories: categories, radiusKm: radius),
              ),
              child: const Text('Save preferences'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: CircleAvatar(
        backgroundColor: AppColors.softBlue,
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(body),
      ),
      trailing: trailing,
    ),
  );
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, this.warning = false});
  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: warning ? const Color(0xFFFFF7ED) : AppColors.softBlue,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(message, textAlign: TextAlign.center),
  );
}
