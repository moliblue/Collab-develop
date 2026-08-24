import 'package:flutter/material.dart';

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
        DiscoverSection.recommend => _RecommendSpot(
          viewModel: widget.viewModel,
          notify: widget.notify,
        ),
        DiscoverSection.discover => _discover(),
      };
    },
  );

  Widget _discover() {
    final vm = widget.viewModel;
    final results = vm.filteredPlaces;
    return ListView(
      key: const PageStorageKey<String>('discover-list'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AppColors.softBlue,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Eyebrow('✈ Discover Malaysia'),
                    const SizedBox(height: 4),
                    Text(
                      'Where to next?',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Local favourites, heritage gems and good stories.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Badge(
                label: Text('${vm.bookmarks.length}'),
                child: IconButton(
                  key: const Key('open_bookmarks'),
                  tooltip: 'View saved places',
                  onPressed: () => vm.setSection(DiscoverSection.bookmarks),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.warning,
                    minimumSize: const Size.square(48),
                  ),
                  icon: const Icon(Icons.bookmark_rounded),
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
                  hintText: 'Search places, food or stories…',
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
                  children:
                      <String>[
                            'Kuala Lumpur',
                            'Selangor',
                            'Penang',
                            'Melaka',
                            'Johor',
                            'Sabah',
                            'Sarawak',
                          ]
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
                  children:
                      <String>[
                            'Traditional Heritage Site',
                            'Local Craft',
                            'Local Food',
                            'Local Micro Business',
                          ]
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
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            const Spacer(),
            const Text(
              'Sorted A–Z',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 9),
        if (results.isEmpty)
          EmptyState(
            icon: Icons.travel_explore_rounded,
            title: 'No adventures found',
            message: 'Try another place, type or search term.',
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
                onBookmark: () {
                  final saved = vm.toggleBookmark(p);
                  widget.notify(
                    saved
                        ? 'Added to your bookmarks.'
                        : 'Removed from bookmarks.',
                    AppColors.primary,
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 3),
        OutlinedButton.icon(
          key: const Key('recommend_spot'),
          onPressed: () => vm.setSection(DiscoverSection.recommend),
          icon: const Icon(Icons.add_location_alt_rounded),
          label: const Text('Recommend New Spot'),
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
                onBookmark: () => widget.viewModel.toggleBookmark(p),
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
    radius: 28,
    child: Column(
      children: <Widget>[
        SizedBox(
          height: 178,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(27),
                ),
                child: Hero(
                  tag: place.id,
                  child: Image.asset(place.image, fit: BoxFit.cover),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
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
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
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
                  text: '${place.distanceKm.toStringAsFixed(1)} km',
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
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      place.shortDescription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
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
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
        ),
      ],
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
              Hero(
                tag: p.id,
                child: Image.asset(p.image, fit: BoxFit.cover),
              ),
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
                      onPressed: () => widget.viewModel.toggleBookmark(p),
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
            onPressed: () {
              final error = widget.viewModel.addReview(
                widget.place,
                rating,
                review.text,
              );
              if (error != null) {
                widget.notify(error, AppColors.danger);
                return;
              }
              Navigator.pop(context);
              widget.notify('Review submitted successfully!', AppColors.teal);
            },
            child: const Text('Submit Review'),
          ),
        ],
      ),
    ),
  );
}

class _RecommendSpot extends StatefulWidget {
  const _RecommendSpot({required this.viewModel, required this.notify});
  final DiscoveryViewModel viewModel;
  final void Function(String, Color) notify;
  @override
  State<_RecommendSpot> createState() => _RecommendSpotState();
}

class _RecommendSpotState extends State<_RecommendSpot> {
  final name = TextEditingController();
  final description = TextEditingController();
  String category = '';
  bool photoReady = false;
  bool locating = false;
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('recommend_form'),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
    children: <Widget>[
      Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Back',
            onPressed: () =>
                widget.viewModel.setSection(DiscoverSection.discover),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const Expanded(
            child: SectionTitle(
              'Recommend New Spot',
              subtitle: 'Help travellers find local heritage',
            ),
          ),
        ],
      ),
      const SizedBox(height: 13),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Spot name *',
                hintText: 'e.g. Heritage Hainan Kopitiam',
              ),
            ),
            const SizedBox(height: 11),
            DropdownButtonFormField<String>(
              initialValue: category.isEmpty ? null : category,
              decoration: const InputDecoration(labelText: 'Category *'),
              items:
                  <String>[
                        'Traditional Heritage Site',
                        'Local Craft',
                        'Local Food',
                        'Local Micro Business',
                      ]
                      .map(
                        (String c) => DropdownMenuItem<String>(
                          value: c,
                          child: Text(c, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
              onChanged: (String? v) => setState(() => category = v ?? ''),
            ),
            const SizedBox(height: 12),
            Container(
              height: 175,
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Stack(
                children: <Widget>[
                  const Positioned.fill(
                    child: CustomPaint(painter: _PinMapPainter()),
                  ),
                  const Center(
                    child: Icon(
                      Icons.location_pin,
                      color: AppColors.primary,
                      size: 42,
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 9,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .94),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '5.4182° N, 100.3411° E · George Town, Penang',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: locating
                  ? null
                  : () async {
                      setState(() => locating = true);
                      await Future<void>.delayed(
                        const Duration(milliseconds: 350),
                      );
                      if (mounted) {
                        setState(() => locating = false);
                        widget.notify(
                          'Mock GPS location refreshed.',
                          AppColors.teal,
                        );
                      }
                    },
              icon: const Icon(Icons.my_location_rounded),
              label: Text(locating ? 'Locating…' : 'Auto-locate GPS'),
            ),
            const SizedBox(height: 11),
            TextField(
              controller: description,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'What makes this place special?',
              ),
            ),
            const SizedBox(height: 11),
            InkWell(
              onTap: () => setState(() => photoReady = true),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 145,
                decoration: BoxDecoration(
                  color: photoReady ? AppColors.softBlue : AppColors.elevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: photoReady
                        ? AppColors.primary
                        : AppColors.borderStrong,
                    width: photoReady ? 1.5 : 1,
                  ),
                ),
                child: photoReady
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            Image.asset(
                              'assets/batik_artisan.png',
                              fit: BoxFit.cover,
                            ),
                            const Positioned(
                              right: 9,
                              bottom: 9,
                              child: _ImagePill(
                                icon: Icons.check_rounded,
                                text: 'Photo ready',
                                color: AppColors.teal,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.add_a_photo_rounded,
                            color: AppColors.muted,
                            size: 30,
                          ),
                          SizedBox(height: 7),
                          Text(
                            'Tap to add a JPG/PNG photo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Demo uses a bundled local image',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.upload_rounded),
        label: const Text('Submit Recommended Spot'),
      ),
    ],
  );

  Future<void> _submit() async {
    if (name.text.trim().isEmpty ||
        category.isEmpty ||
        description.text.trim().isEmpty ||
        !photoReady) {
      widget.notify(
        'Complete all required spot details and add a photo.',
        AppColors.danger,
      );
      return;
    }
    final duplicate = widget.viewModel.findDuplicate(name.text);
    if (duplicate != null) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 38,
          ),
          title: const Text('Existing Location Found'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  duplicate.image,
                  height: 110,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                duplicate.name,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const Text(
                'Would you like to merge your rating and review?',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                duplicate.reviewsCount++;
                Navigator.pop(context);
                widget.viewModel.setSection(DiscoverSection.discover);
                widget.notify(
                  'Your contribution was merged into the existing spot.',
                  AppColors.teal,
                );
              },
              child: const Text('Yes, Merge'),
            ),
          ],
        ),
      );
    } else {
      widget.viewModel.addRecommended(
        name: name.text,
        category: category,
        description: description.text,
      );
      widget.notify('Recommended spot added successfully!', AppColors.teal);
    }
  }
}

class _PinMapPainter extends CustomPainter {
  const _PinMapPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFD8E7EF)
      ..strokeWidth = 2;
    for (double y = 20; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 8), p);
    }
    for (double x = 12; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x - 20, size.height), p);
    }
    final water = Paint()..color = const Color(0xFFCAE8F4);
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * .68)
        ..quadraticBezierTo(
          size.width * .45,
          size.height * .5,
          size.width,
          size.height * .72,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      water,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
