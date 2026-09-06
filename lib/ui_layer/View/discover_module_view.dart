import 'package:flutter/material.dart' hide Text;
import '../../core/localization/localized_text.dart';

import '../../core/theme/app_theme.dart';
import '../../data_layer/Models/app_models.dart';
import '../ViewModel/discovery_view_model.dart';
import 'shared/app_widgets.dart';

class DiscoverModuleView extends StatefulWidget {
  const DiscoverModuleView({
    super.key,
    required this.viewModel,
    required this.onDirections,
    required this.onAddToPlan,
    required this.notify,
  });
  final DiscoveryViewModel viewModel;
  final ValueChanged<HeritagePlace> onDirections;
  final ValueChanged<HeritagePlace> onAddToPlan;
  final void Function(String, Color) notify;

  @override
  State<DiscoverModuleView> createState() => _DiscoverModuleViewState();
}

class _DiscoverModuleViewState extends State<DiscoverModuleView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.viewModel.load();
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.viewModel,
    builder: (BuildContext context, _) {
      if (widget.viewModel.selected != null) {
        return _LocationDetail(
          place: widget.viewModel.selected!,
          viewModel: widget.viewModel,
          onDirections: widget.onDirections,
          onAddToPlan: widget.onAddToPlan,
          notify: widget.notify,
        );
      }
      return switch (widget.viewModel.section) {
        DiscoverSection.bookmarks => _bookmarks(),
        DiscoverSection.discover => _discover(),
      };
    },
  );

  Widget _discover() {
    final vm = widget.viewModel;
    final results = vm.filteredPlaces;
    if (vm.loading && vm.places.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.loadError != null && vm.places.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: vm.loadError!,
          message: 'Check your connection and try again.',
          action: FilledButton(
            onPressed: () => vm.load(force: true),
            child: const Text('Retry'),
          ),
        ),
      );
    }
    return ListView(
      key: const PageStorageKey<String>('discover-list'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        Container(
          height: 190,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset('assets/petaling_street.png', fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[Color(0x220C2130), Color(0xD90C2130)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Badge(
                  label: Text('${vm.bookmarks.length}'),
                  child: IconButton(
                    key: const Key('open_bookmarks'),
                    tooltip: 'View saved places',
                    onPressed: () => vm.setSection(DiscoverSection.bookmarks),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: .94),
                      foregroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.bookmark_rounded),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Eyebrow('Discover Malaysia', color: Colors.white),
                    const SizedBox(height: 6),
                    Text(
                      'Find your next local story',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Heritage, food and places worth slowing down for.',
                      style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                onChanged: vm.setQuery,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search heritage locations…',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Badge(
              isLabelVisible: vm.states.isNotEmpty || vm.categories.isNotEmpty,
              label: Text('${vm.states.length + vm.categories.length}'),
              child: IconButton(
                tooltip: 'Filter',
                onPressed: vm.toggleFilters,
                style: IconButton.styleFrom(
                  backgroundColor: vm.filtersOpen
                      ? AppColors.primary
                      : Colors.white,
                  foregroundColor: vm.filtersOpen
                      ? Colors.white
                      : AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size.square(48),
                ),
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: vm.availableCategories.map((String category) {
              final selected = vm.categories.contains(category);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AppChip(
                  label: category,
                  selected: selected,
                  onTap: () => vm.toggleCategory(category),
                ),
              );
            }).toList(),
          ),
        ),
        if (vm.filtersOpen) ...<Widget>[
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Pick your travel mood',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    TextButton(
                      onPressed: vm.clearFilters,
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
                const Eyebrow('Destination', color: AppColors.muted),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  children: vm.availableStates
                      .map(
                        (String s) => AppChip(
                          label: s,
                          selected: vm.states.contains(s),
                          onTap: () => vm.toggleState(s),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                const Eyebrow('Experience', color: AppColors.muted),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  children: vm.availableCategories
                      .map(
                        (String c) => AppChip(
                          label: c,
                          selected: vm.categories.contains(c),
                          selectedColor: AppColors.teal,
                          onTap: () => vm.toggleCategory(c),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: vm.closeFilters,
                  child: Text('Show ${results.length} places'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 13),
        Row(
          children: <Widget>[
            Text(
              '${results.length}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Text(
              ' places to explore',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const Spacer(),
            const Text(
              'Sorted A–Z',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 9),
        if (results.isEmpty)
          EmptyState(
            icon: Icons.travel_explore_rounded,
            title: vm.categories.isNotEmpty
                ? 'No locations match the selected category.'
                : 'No locations found.',
            message: 'Try another category or search term.',
            action: TextButton(
              onPressed: vm.clearFilters,
              child: const Text('Reset filters'),
            ),
          )
        else
          ...results.map(
            (HeritagePlace p) => Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: _DestinationCard(
                place: p,
                onTap: () => vm.select(p),
                onBookmark: () async {
                  final saved = await vm.toggleBookmark(p);
                  if (saved == null) {
                    widget.notify(
                      vm.takeActionError() ?? 'Unable to update bookmark.',
                      AppColors.danger,
                    );
                    return;
                  }
                  widget.notify(
                    saved
                        ? 'Destination added to your bookmarks.'
                        : 'Removed from bookmarks.',
                    AppColors.primary,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _bookmarks() {
    final items = widget.viewModel.bookmarks;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Back to Discover',
              onPressed: () =>
                  widget.viewModel.setSection(DiscoverSection.discover),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: SectionTitle(
                'Saved places',
                subtitle: '${items.length} heritage favourites',
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        if (items.isEmpty)
          EmptyState(
            icon: Icons.bookmark_border_rounded,
            title: 'No saved places yet',
            message:
                'Bookmark heritage gems from Discover and they’ll wait here.',
            action: FilledButton(
              onPressed: () =>
                  widget.viewModel.setSection(DiscoverSection.discover),
              child: const Text('Explore Discover'),
            ),
          )
        else
          ...items.map(
            (HeritagePlace p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DestinationCard(
                place: p,
                onTap: () => widget.viewModel.select(p),
                onBookmark: () async {
                  final saved = await widget.viewModel.toggleBookmark(p);
                  if (saved == null) {
                    widget.notify(
                      widget.viewModel.takeActionError() ??
                          'Unable to update bookmark.',
                      AppColors.danger,
                    );
                  }
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.place,
    required this.onTap,
    required this.onBookmark,
  });
  final HeritagePlace place;
  final VoidCallback onTap;
  final VoidCallback onBookmark;

  Color get accent => switch (place.category) {
    'Local Craft' => AppColors.teal,
    'Local Food' => AppColors.warning,
    'Local Micro Business' => AppColors.pink,
    _ => AppColors.primary,
  };

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    padding: EdgeInsets.zero,
    radius: AppTokens.cardRadius,
    child: Column(
      children: <Widget>[
        SizedBox(
          height: 184,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(19),
                ),
                child: Hero(tag: place.id, child: _PlaceImage(place.image)),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
                  gradient: LinearGradient(
                    colors: <Color>[Colors.transparent, Color(0x70152231)],
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                left: 11,
                top: 11,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .93),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    place.category,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 11,
                top: 11,
                child: IconButton(
                  key: Key('bookmark_${place.id}'),
                  tooltip: place.bookmarked ? 'Remove bookmark' : 'Bookmark',
                  onPressed: onBookmark,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: .93),
                    foregroundColor: place.bookmarked
                        ? AppColors.warning
                        : AppColors.textSecondary,
                    minimumSize: const Size.square(36),
                    padding: EdgeInsets.zero,
                  ),
                  icon: Icon(
                    place.bookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 18,
                  ),
                ),
              ),
              Positioned(
                left: 11,
                bottom: 11,
                child: _ImagePill(
                  icon: Icons.place_rounded,
                  text: place.state,
                  color: accent,
                ),
              ),
              Positioned(
                right: 11,
                bottom: 11,
                child: _ImagePill(
                  icon: Icons.star_rounded,
                  text:
                      '${place.rating.toStringAsFixed(1)} (${place.reviewsCount})',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      place.shortDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 17,
                backgroundColor: accent.withValues(alpha: .1),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: accent,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ImagePill extends StatelessWidget {
  const _ImagePill({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .93),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _PlaceImage extends StatelessWidget {
  const _PlaceImage(this.source);
  final String source;

  @override
  Widget build(BuildContext context) {
    final trimmed = source.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(trimmed, fit: BoxFit.cover, errorBuilder: _fallback);
    }
    if (trimmed.isNotEmpty) {
      return Image.asset(trimmed, fit: BoxFit.cover, errorBuilder: _fallback);
    }
    return _fallback(context, Object(), null);
  }

  Widget _fallback(BuildContext context, Object _, StackTrace? stackTrace) =>
      const ColoredBox(
        color: Color(0xFFEAF0F4),
        child: Center(
          child: Icon(
            Icons.account_balance_rounded,
            size: 58,
            color: AppColors.muted,
          ),
        ),
      );
}

class _LocationDetail extends StatefulWidget {
  const _LocationDetail({
    required this.place,
    required this.viewModel,
    required this.onDirections,
    required this.onAddToPlan,
    required this.notify,
  });
  final HeritagePlace place;
  final DiscoveryViewModel viewModel;
  final ValueChanged<HeritagePlace> onDirections;
  final ValueChanged<HeritagePlace> onAddToPlan;
  final void Function(String, Color) notify;
  @override
  State<_LocationDetail> createState() => _LocationDetailState();
}

class _LocationDetailState extends State<_LocationDetail> {
  bool expanded = false;
  int rating = 0;
  final review = TextEditingController();
  @override
  void dispose() {
    review.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        SizedBox(
          height: 255,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Hero(tag: p.id, child: _PlaceImage(p.image)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[Color(0x10152231), Color(0xC0152231)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: () => widget.viewModel.select(null),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.textPrimary,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Share',
                      onPressed: () => widget.notify(
                        'Place link copied for sharing.',
                        AppColors.primary,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.textPrimary,
                      ),
                      icon: const Icon(Icons.share_rounded),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Bookmark',
                      onPressed: () async {
                        final saved = await widget.viewModel.toggleBookmark(p);
                        widget.notify(
                          saved == true
                              ? 'Destination added to your bookmarks.'
                              : saved == false
                              ? 'Removed from bookmarks.'
                              : widget.viewModel.takeActionError() ??
                                    'Unable to update bookmark.',
                          saved == null ? AppColors.danger : AppColors.primary,
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: p.bookmarked
                            ? AppColors.warning
                            : AppColors.textPrimary,
                      ),
                      icon: Icon(
                        p.bookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        p.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      p.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.warning,
                          size: 16,
                        ),
                        Text(
                          ' ${p.rating.toStringAsFixed(1)} (${p.reviewsCount})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.place_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        Text(
                          ' ${p.distanceKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'About this place',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      p.description,
                      maxLines: expanded ? null : 3,
                      overflow: expanded ? null : TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => setState(() => expanded = !expanded),
                      child: Text(expanded ? 'Show less' : 'Read full story'),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.schedule_rounded,
                        color: AppColors.teal,
                      ),
                      title: const Text(
                        'Opening hours',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(p.hours),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.place_outlined,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Plan your visit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(p.address),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => widget.onDirections(p),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Get Directions'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        widget.onAddToPlan(p);
                        widget.notify(
                          'Added to active travel day.',
                          AppColors.teal,
                        );
                      },
                      icon: const Icon(Icons.add_task_rounded),
                      label: const Text('Add to Plan'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionTitle('Traveller reviews'),
              const SizedBox(height: 9),
              if (widget.viewModel.detailsLoading)
                const Center(child: CircularProgressIndicator()),
              ...p.reviews.map(
                (Review r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            InitialsAvatar(r.name.substring(0, 1), radius: 15),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                r.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              r.date,
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '★' * r.rating,
                          style: const TextStyle(color: AppColors.warning),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          r.comment,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('write_review'),
                onPressed: _reviewSheet,
                icon: const Icon(Icons.rate_review_rounded),
                label: const Text('Write Review'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _reviewSheet() async => showAppSheet<void>(
    context,
    StatefulBuilder(
      builder: (BuildContext context, StateSetter sheetSet) => SheetBody(
        children: <Widget>[
          const ModalTitle(
            title: 'Write a Review',
            subtitle: 'Share your local experience',
            icon: Icons.rate_review_rounded,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(
              5,
              (int i) => IconButton(
                onPressed: () => sheetSet(() => rating = i + 1),
                icon: Icon(
                  i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: AppColors.warning,
                  size: 30,
                ),
              ),
            ),
          ),
          TextField(
            controller: review,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'What made this place memorable?',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: widget.viewModel.reviewSubmitting
                ? null
                : () async {
                    final error = await widget.viewModel.addReview(
                      widget.place,
                      rating,
                      review.text,
                    );
                    if (error != null) {
                      widget.notify(error, AppColors.danger);
                      return;
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    rating = 0;
                    review.clear();
                    widget.notify(
                      'Review submitted successfully.',
                      AppColors.teal,
                    );
                  },
            child: const Text('Submit Review'),
          ),
        ],
      ),
    ),
  );
}
