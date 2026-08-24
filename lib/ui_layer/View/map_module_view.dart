import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../data_layer/Models/app_models.dart';
import '../ViewModel/map_quest_view_model.dart';
import 'shared/app_widgets.dart';

class MapModuleView extends StatefulWidget {
  const MapModuleView({
    super.key,
    required this.viewModel,
    required this.places,
    required this.onBack,
    required this.onXpReward,
    required this.notify,
  });
  final MapQuestViewModel viewModel;
  final List<HeritagePlace> places;
  final VoidCallback onBack;
  final ValueChanged<int> onXpReward;
  final void Function(String, Color) notify;
  @override
  State<MapModuleView> createState() => _MapModuleViewState();
}

class _MapModuleViewState extends State<MapModuleView> {
  final MapController controller = MapController();
  bool filtersOpen = false;

  List<HeritagePlace> get filtered {
    final q = widget.viewModel.query.toLowerCase();
    return widget.places
        .where(
          (HeritagePlace p) =>
              (q.isEmpty ||
                  p.name.toLowerCase().contains(q) ||
                  p.address.toLowerCase().contains(q)) &&
              (widget.viewModel.category == 'All' ||
                  _mapCategory(p) == widget.viewModel.category),
        )
        .toList();
  }

  String _mapCategory(HeritagePlace p) => switch (p.category) {
    'Traditional Heritage Site' => 'Historical Monument',
    'Local Craft' => 'Cultural Heritage',
    'Local Food' => 'Cultural Heritage',
    _ => 'Architecture',
  };

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.viewModel,
    builder: (BuildContext context, _) {
      final vm = widget.viewModel;
      final points = vm.routeStops.isNotEmpty
          ? <LatLng>[
              const LatLng(5.4182, 100.3411),
              ...vm.routeStops.map(
                (ActivityItem a) => LatLng(a.latitude, a.longitude),
              ),
            ]
          : vm.directionTarget == null
          ? <LatLng>[]
          : <LatLng>[
              const LatLng(5.4182, 100.3411),
              LatLng(
                vm.directionTarget!.latitude,
                vm.directionTarget!.longitude,
              ),
            ];
      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: FlutterMap(
              mapController: controller,
              options: const MapOptions(
                initialCenter: LatLng(5.4182, 100.3411),
                initialZoom: 12.2,
                backgroundColor: Color(0xFFE7F0EA),
              ),
              children: <Widget>[
                const _OfflineMapBackground(),
                CircleLayer(
                  circles: <CircleMarker>[
                    CircleMarker(
                      point: const LatLng(5.4182, 100.3411),
                      radius: vm.radius * 650,
                      useRadiusInMeter: true,
                      color: AppColors.teal.withValues(alpha: .06),
                      borderColor: AppColors.teal.withValues(alpha: .45),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                if (points.length > 1)
                  PolylineLayer(
                    polylines: <Polyline>[
                      Polyline(
                        points: points,
                        color: AppColors.tealDark,
                        strokeWidth: 5,
                        pattern: const StrokePattern.dotted(),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: <Marker>[
                    const Marker(
                      point: LatLng(5.4182, 100.3411),
                      width: 50,
                      height: 50,
                      child: _UserMarker(),
                    ),
                    if (vm.routeStops.isEmpty && vm.directionTarget == null)
                      ...filtered.map(
                        (HeritagePlace p) => Marker(
                          point: LatLng(p.latitude, p.longitude),
                          width: 130,
                          height: 52,
                          child: _PlaceMarker(
                            place: p,
                            bookmarked: p.bookmarked,
                            onTap: () => vm.select(p),
                          ),
                        ),
                      ),
                    if (vm.directionTarget != null)
                      Marker(
                        point: LatLng(
                          vm.directionTarget!.latitude,
                          vm.directionTarget!.longitude,
                        ),
                        width: 52,
                        height: 52,
                        child: const Icon(
                          Icons.location_on_rounded,
                          size: 47,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ...vm.routeStops.indexed.map(((int, ActivityItem) pair) {
                      final (i, a) = pair;
                      return Marker(
                        point: LatLng(a.latitude, a.longitude),
                        width: 54,
                        height: 54,
                        child: _NumberMarker(number: i + 1),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Back',
                        onPressed: widget.onBack,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.textPrimary,
                          shadowColor: Colors.black26,
                          elevation: 3,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: TextField(
                          onChanged: vm.setQuery,
                          decoration: const InputDecoration(
                            fillColor: Colors.white,
                            prefixIcon: Icon(Icons.search_rounded),
                            hintText: 'Search heritage map…',
                            contentPadding: EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      IconButton(
                        tooltip: 'Map filters',
                        onPressed: () =>
                            setState(() => filtersOpen = !filtersOpen),
                        style: IconButton.styleFrom(
                          backgroundColor: filtersOpen
                              ? AppColors.primary
                              : Colors.white,
                          foregroundColor: filtersOpen
                              ? Colors.white
                              : AppColors.textSecondary,
                          shadowColor: Colors.black26,
                          elevation: 3,
                        ),
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                  if (filtersOpen)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: AppCard(
                        radius: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Search radius · ${vm.radius.round()} km',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Slider(
                              value: vm.radius,
                              min: 1,
                              max: 25,
                              divisions: 24,
                              onChanged: vm.setRadius,
                            ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children:
                                    <String>[
                                          'All',
                                          'Architecture',
                                          'Historical Monument',
                                          'Cultural Heritage',
                                          'Temple & Sacred',
                                          'Museum',
                                        ]
                                        .map(
                                          (String c) => Padding(
                                            padding: const EdgeInsets.only(
                                              right: 5,
                                            ),
                                            child: AppChip(
                                              label: c,
                                              selected: vm.category == c,
                                              onTap: () => vm.setCategory(c),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: vm.directionTarget != null || vm.routeStops.isNotEmpty
                ? 178
                : 22,
            child: Column(
              children: <Widget>[
                FloatingActionButton.small(
                  heroTag: 'locate',
                  tooltip: 'Centre on me',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  onPressed: () {
                    controller.move(const LatLng(5.4182, 100.3411), 14);
                    widget.notify(
                      'Centered on Penang UNESCO Heritage Hub.',
                      AppColors.teal,
                    );
                  },
                  child: const Icon(Icons.my_location_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom',
                  tooltip: 'Zoom in',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  onPressed: () {
                    final camera = controller.camera;
                    controller.move(camera.center, camera.zoom + 1);
                  },
                  child: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          if (vm.directionTarget != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 14,
              child: _RoutePanel(
                title: 'Directions in Map',
                subtitle: vm.directionTarget!.name,
                detail: '18.4 km · 27 min · Offline direct preview',
                onClose: vm.clearDirections,
              ),
            ),
          if (vm.routeStops.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 14,
              child: _DayRoutePanel(
                stops: vm.routeStops,
                onClose: vm.clearDayRoute,
                onFocus: (ActivityItem a) =>
                    controller.move(LatLng(a.latitude, a.longitude), 14.5),
              ),
            ),
          if (vm.selected != null)
            _LocationSheet(
              place: vm.selected!,
              vm: vm,
              onReward: widget.onXpReward,
              notify: widget.notify,
            ),
        ],
      );
    },
  );
}

class _OfflineMapBackground extends StatelessWidget {
  const _OfflineMapBackground();
  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(child: CustomPaint(painter: _MapPainter()));
}

class _MapPainter extends CustomPainter {
  const _MapPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE8F1EA),
    );
    final water = Paint()..color = const Color(0xFFCDE9F1);
    canvas.drawPath(
      ui.Path()
        ..moveTo(0, size.height * .72)
        ..quadraticBezierTo(
          size.width * .38,
          size.height * .55,
          size.width,
          size.height * .68,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      water,
    );
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;
    for (var i = -1; i < 7; i++) {
      final y = i * 90.0;
      canvas.drawPath(
        ui.Path()
          ..moveTo(-20, y)
          ..quadraticBezierTo(
            size.width * .45,
            y + 100,
            size.width + 30,
            y + 30,
          ),
        road,
      );
    }
    road
      ..color = const Color(0xFFF7E3B5)
      ..strokeWidth = 4;
    for (var i = 0; i < 6; i++) {
      final x = i * 80.0;
      canvas.drawPath(
        ui.Path()
          ..moveTo(x, -20)
          ..quadraticBezierTo(
            x + 80,
            size.height * .48,
            x + 15,
            size.height + 20,
          ),
        road,
      );
    }
    final park = Paint()..color = const Color(0xFFCDE5C8);
    canvas.drawOval(
      Rect.fromLTWH(size.width * .57, size.height * .22, 120, 80),
      park,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UserMarker extends StatelessWidget {
  const _UserMarker();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.tealDark,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black26, blurRadius: 8),
        ],
      ),
    ),
  );
}

class _PlaceMarker extends StatelessWidget {
  const _PlaceMarker({
    required this.place,
    required this.bookmarked,
    required this.onTap,
  });
  final HeritagePlace place;
  final bool bookmarked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: bookmarked ? AppColors.warning : AppColors.border,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Colors.black12, blurRadius: 9),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (bookmarked)
                const Icon(
                  Icons.star_rounded,
                  size: 12,
                  color: AppColors.warning,
                ),
              const Icon(
                Icons.museum_rounded,
                size: 15,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
      ],
    ),
  );
}

class _NumberMarker extends StatelessWidget {
  const _NumberMarker({required this.number});
  final int number;
  @override
  Widget build(BuildContext context) => Center(
    child: CircleAvatar(
      radius: 19,
      backgroundColor: Colors.white,
      child: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.tealDark,
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ),
  );
}

class _RoutePanel extends StatelessWidget {
  const _RoutePanel({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.onClose,
  });
  final String title;
  final String subtitle;
  final String detail;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 20,
    child: Row(
      children: <Widget>[
        const CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Icon(Icons.navigation_rounded, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Eyebrow('Directions in Map'),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                detail,
                style: const TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Clear route',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

class _DayRoutePanel extends StatelessWidget {
  const _DayRoutePanel({
    required this.stops,
    required this.onClose,
    required this.onFocus,
  });
  final List<ActivityItem> stops;
  final VoidCallback onClose;
  final ValueChanged<ActivityItem> onFocus;
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 20,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.route_rounded, color: AppColors.teal),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'Day route · time order',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              tooltip: 'Clear day route',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        SizedBox(
          height: 105,
          child: ListView(
            children: stops.indexed.map(((int, ActivityItem) pair) {
              final (i, a) = pair;
              return ListTile(
                dense: true,
                onTap: () => onFocus(a),
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.tealDark,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                title: Text(
                  a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                trailing: Text(
                  a.time,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.tealDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ),
  );
}

class _LocationSheet extends StatelessWidget {
  const _LocationSheet({
    required this.place,
    required this.vm,
    required this.onReward,
    required this.notify,
  });
  final HeritagePlace place;
  final MapQuestViewModel vm;
  final ValueChanged<int> onReward;
  final void Function(String, Color) notify;
  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Material(
      color: const Color(0x55152231),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .76,
            maxWidth: 520,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: 190,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                        child: Image.asset(place.image, fit: BoxFit.cover),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(30),
                          ),
                          gradient: LinearGradient(
                            colors: <Color>[
                              Colors.transparent,
                              Color(0xB0152231),
                            ],
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton(
                          tooltip: 'Close',
                          onPressed: () => vm.select(null),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                      Positioned(
                        left: 15,
                        right: 15,
                        bottom: 13,
                        child: Text(
                          place.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          Text(
                            ' ${place.rating.toStringAsFixed(1)}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.place_rounded,
                            size: 15,
                            color: AppColors.primary,
                          ),
                          Text(
                            ' ${place.distanceKm.toStringAsFixed(1)} km away',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        place.shortDescription,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        color: const Color(0xFFF3EEFF),
                        borderColor: const Color(0xFFE0D3FF),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.camera_alt_rounded,
                                  color: Color(0xFF7C3AED),
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'PICTURE QUEST',
                                  style: TextStyle(
                                    color: Color(0xFF6D28D9),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Spacer(),
                                AppChip(label: '+250 XP', selected: true),
                              ],
                            ),
                            SizedBox(height: 7),
                            Text(
                              'Capture a heritage detail',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'Reach the location, capture an original photo and share your reflection.',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => vm.showDirections(place),
                        icon: const Icon(Icons.navigation_rounded),
                        label: const Text('Get Directions'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const Key('open_map_location_details'),
                        onPressed: () => _memo(context),
                        icon: const Icon(Icons.menu_book_rounded),
                        label: const Text('Heritage Memo'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: vm.isCompleted(place.id)
                            ? null
                            : () {
                                if (!vm.gpsNearby) {
                                  _rangeDialog(context);
                                } else {
                                  _quest(context);
                                }
                              },
                        icon: const Icon(Icons.workspace_premium_rounded),
                        label: Text(
                          vm.isCompleted(place.id)
                              ? 'Picture Quest Completed'
                              : 'Join Picture Quest',
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
    ),
  );

  Future<void> _memo(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      icon: const Icon(
        Icons.auto_stories_rounded,
        color: AppColors.primary,
        size: 36,
      ),
      title: Text('Heritage Memo · ${place.name}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AppChip(label: '19th Century', selected: true),
            const SizedBox(height: 10),
            Text(place.description),
            const SizedBox(height: 12),
            const AppCard(
              color: Color(0xFFFFF7E5),
              borderColor: Color(0xFFF3D998),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'DID YOU KNOW?',
                    style: TextStyle(
                      color: Color(0xFF9A6700),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Local oral histories connect this landmark to Malaysia’s trade routes, artisan communities and independence story.',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Wrap(
              spacing: 5,
              children: <Widget>[
                AppChip(label: 'Heritage'),
                AppChip(label: 'Malaysia'),
                AppChip(label: 'Local story'),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close Memo'),
        ),
      ],
    ),
  );

  Future<void> _rangeDialog(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      icon: const Icon(
        Icons.location_searching_rounded,
        color: AppColors.warning,
        size: 38,
      ),
      title: const Text('Join within 500m'),
      content: const Text(
        'This picture quest uses local demo GPS. Move the demo position near this spot to continue.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () {
            vm.simulateNear();
            Navigator.pop(context);
            notify(
              'GPS moved to this heritage spot for testing.',
              AppColors.teal,
            );
          },
          child: const Text('Move GPS (Demo)'),
        ),
      ],
    ),
  );

  Future<void> _quest(BuildContext context) => showAppSheet<void>(
    context,
    _QuestForm(
      place: place,
      onComplete: () {
        vm.completeQuest(place);
        onReward(250);
        notify('Picture quest completed · +250 XP!', AppColors.teal);
      },
    ),
  );
}

class _QuestForm extends StatefulWidget {
  const _QuestForm({required this.place, required this.onComplete});
  final HeritagePlace place;
  final VoidCallback onComplete;
  @override
  State<_QuestForm> createState() => _QuestFormState();
}

class _QuestFormState extends State<_QuestForm> {
  bool photo = false;
  final caption = TextEditingController();
  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SheetBody(
    children: <Widget>[
      const ModalTitle(
        title: 'Capture local heritage',
        subtitle: 'Picture Quest · +250 XP',
        icon: Icons.camera_alt_rounded,
      ),
      const SizedBox(height: 12),
      InkWell(
        onTap: () => setState(() => photo = true),
        child: Container(
          height: 210,
          decoration: BoxDecoration(
            color: const Color(0xFFF3EEFF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFC4B5FD), width: 2),
          ),
          child: photo
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(widget.place.image, fit: BoxFit.cover),
                )
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.add_a_photo_rounded,
                      color: Color(0xFF7C3AED),
                      size: 42,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Take or upload a photo',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Tap for deterministic demo capture',
                      style: TextStyle(fontSize: 9, color: AppColors.muted),
                    ),
                  ],
                ),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: caption,
        maxLength: 180,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Optional photo caption'),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: photo
            ? () {
                Navigator.pop(context);
                widget.onComplete();
              }
            : null,
        icon: const Icon(Icons.camera_alt_rounded),
        label: const Text('Submit Picture & Claim XP'),
      ),
    ],
  );
}
