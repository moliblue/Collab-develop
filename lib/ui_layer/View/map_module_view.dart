import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../data_layer/Models/app_models.dart';
import '../../data_layer/Service Managers/device/map_navigation_service.dart';
import '../ViewModel/map_quest_view_model.dart';
import 'shared/app_widgets.dart';

class MapModuleView extends StatefulWidget {
  const MapModuleView({
    super.key,
    required this.viewModel,
    required this.active,
    required this.onBack,
    required this.onXpReward,
    required this.notify,
  });
  final MapQuestViewModel viewModel;
  final bool active;
  final VoidCallback onBack;
  final ValueChanged<int> onXpReward;
  final void Function(String, Color) notify;
  @override
  State<MapModuleView> createState() => _MapModuleViewState();
}

class _MapModuleViewState extends State<MapModuleView> {
  final MapController controller = MapController();
  final MapNavigationService navigation = MapNavigationService();
  final ValueNotifier<double> _headingNotifier = ValueNotifier<double>(0);
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<double?>? _headingSubscription;
  bool filtersOpen = false;
  bool _navigationActive = false;
  bool _locating = false;
  bool _routeLoading = false;
  bool _guidanceMode = false;
  LatLng? _userPosition;
  LatLng? _routedFrom;
  double _heading = 0;
  double _routeDistanceMeters = 0;
  double _routeDurationSeconds = 0;
  List<LatLng> _roadRoute = <LatLng>[];
  String? _routeIssue;
  String? _locationIssue;
  String? _lastRouteSignature;
  bool _routeReloadPending = false;
  int _routeRequest = 0;
  bool _heritageLoadStarted = false;
  bool _showHeritageLabels = false;
  DateTime? _lastHeadingUpdate;

  static const Duration _headingUpdateInterval = Duration(milliseconds: 200);
  static const double _heritageLabelZoomThreshold = 15;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startNavigation());
    }
  }

  @override
  void didUpdateWidget(covariant MapModuleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _startNavigation();
    } else if (!widget.active && oldWidget.active) {
      _stopNavigation();
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _headingSubscription?.cancel();
    _headingNotifier.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> _startNavigation() async {
    if (_navigationActive || !mounted) return;
    _navigationActive = true;
    setState(() {
      _locating = true;
      _locationIssue = null;
    });
    try {
      final access = await navigation.requestLocationAccess();
      if (!mounted || !_navigationActive) return;
      if (access != LocationAccessStatus.ready) {
        setState(() {
          _navigationActive = false;
          _locating = false;
          _locationIssue = switch (access) {
            LocationAccessStatus.servicesDisabled ||
            LocationAccessStatus.denied ||
            LocationAccessStatus.deniedForever =>
              'Current location is unavailable. Please enable location services and try again.',
            LocationAccessStatus.ready => null,
          };
        });
        return;
      }
      _positionSubscription = navigation.positionStream.listen(
        _updatePosition,
        onError: (Object _) {
          if (mounted) {
            setState(() {
              _navigationActive = false;
              _locating = false;
              _locationIssue =
                  'Current location is unavailable. Please enable location services and try again.';
            });
          }
        },
      );
      _headingSubscription = navigation.headingStream?.listen((double? value) {
        if (!mounted || value == null) return;
        final now = DateTime.now();
        final lastUpdate = _lastHeadingUpdate;
        if (lastUpdate != null &&
            now.difference(lastUpdate) < _headingUpdateInterval) {
          return;
        }
        _lastHeadingUpdate = now;
        _heading = value;
        _headingNotifier.value = value;
        if (_guidanceMode && _userPosition != null) {
          controller.moveAndRotate(_userPosition!, 17.5, (360 - value) % 360);
        }
      });
      final lastKnown = await navigation.getLastKnownPosition();
      if (lastKnown != null && mounted && _navigationActive) {
        _updatePosition(lastKnown);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _navigationActive = false;
          _locating = false;
          _locationIssue =
              'Current location is unavailable. Please enable location services and try again.';
        });
      }
    }
  }

  void _stopNavigation() {
    _navigationActive = false;
    _positionSubscription?.cancel();
    _headingSubscription?.cancel();
    _positionSubscription = null;
    _headingSubscription = null;
  }

  void _updateHeritageLabelVisibility(MapCamera camera, bool hasGesture) {
    final showLabels = camera.zoom >= _heritageLabelZoomThreshold;
    if (showLabels == _showHeritageLabels || !mounted) return;
    setState(() => _showHeritageLabels = showLabels);
  }

  void _updatePosition(Position position) {
    if (!mounted) return;
    final next = LatLng(position.latitude, position.longitude);
    final moved = _routedFrom == null
        ? double.infinity
        : const Distance().as(LengthUnit.Meter, _routedFrom!, next);
    setState(() {
      _userPosition = next;
      _locating = false;
      _locationIssue = null;
      if (position.heading >= 0 && position.headingAccuracy > 0) {
        _heading = position.heading;
      }
    });
    if (position.heading >= 0 && position.headingAccuracy > 0) {
      _headingNotifier.value = position.heading;
    }
    if (_guidanceMode) {
      controller.moveAndRotate(next, 17.5, (360 - _heading) % 360);
    }
    if (!_heritageLoadStarted) {
      _heritageLoadStarted = true;
      if (!_hasRouteTarget) controller.move(next, 14);
      unawaited(
        widget.viewModel.loadNearbyHeritage(
          latitude: next.latitude,
          longitude: next.longitude,
        ),
      );
    }
    if (moved > 40 && _hasRouteTarget) {
      if (_routeLoading) {
        _routeReloadPending = true;
      } else {
        _loadRoadRoute();
      }
    }
  }

  bool get _hasRouteTarget =>
      widget.viewModel.directionTarget != null ||
      widget.viewModel.routeStops.isNotEmpty;

  List<LatLng> _routeWaypoints() {
    if (_userPosition == null) return <LatLng>[];
    if (widget.viewModel.routeStops.isNotEmpty) {
      return <LatLng>[
        _userPosition!,
        ...widget.viewModel.routeStops.map(
          (ActivityItem item) => LatLng(item.latitude, item.longitude),
        ),
      ];
    }
    final target = widget.viewModel.directionTarget;
    return target == null
        ? <LatLng>[]
        : <LatLng>[_userPosition!, LatLng(target.latitude, target.longitude)];
  }

  void _syncRoute() {
    final vm = widget.viewModel;
    final signature = vm.directionTarget != null
        ? 'place:${vm.directionTarget!.id}'
        : vm.routeStops.isNotEmpty
        ? 'day:${vm.routeStops.map((ActivityItem item) => item.id).join(',')}'
        : 'none';
    if (signature == _lastRouteSignature) return;
    _lastRouteSignature = signature;
    _roadRoute = <LatLng>[];
    _routeIssue = null;
    _routedFrom = null;
    _guidanceMode = false;
    if (signature != 'none') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoadRoute());
    } else {
      _routeReloadPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasRouteTarget) controller.rotate(0);
      });
    }
  }

  Future<void> _loadRoadRoute() async {
    if (_routeLoading) {
      _routeReloadPending = true;
      return;
    }
    final waypoints = _routeWaypoints();
    if (!mounted || !widget.active || waypoints.length < 2) {
      if (mounted && _hasRouteTarget && _userPosition == null) {
        setState(() {
          _routeIssue = 'Waiting for your GPS position…';
        });
      }
      return;
    }
    _routeReloadPending = false;
    final signature = _lastRouteSignature;
    final routeOrigin = waypoints.first;
    final request = ++_routeRequest;
    setState(() {
      _routeLoading = true;
      _routeIssue = null;
    });
    try {
      final result = await navigation.fetchDrivingRoute(waypoints);
      if (!mounted ||
          request != _routeRequest ||
          signature != _lastRouteSignature) {
        return;
      }
      setState(() {
        _roadRoute = result.points;
        _routeDistanceMeters = result.distanceMeters;
        _routeDurationSeconds = result.durationSeconds;
        _routedFrom = routeOrigin;
      });
      _fitRoute(result.points);
    } catch (_) {
      if (!mounted ||
          request != _routeRequest ||
          signature != _lastRouteSignature) {
        return;
      }
      setState(() {
        _roadRoute = waypoints;
        _routeDistanceMeters = const Distance().as(
          LengthUnit.Meter,
          waypoints.first,
          waypoints.last,
        );
        _routeDurationSeconds = 0;
        _routedFrom = routeOrigin;
        _routeIssue = 'Road routing unavailable · showing direct connection';
      });
      _fitRoute(waypoints);
    } finally {
      if (mounted && request == _routeRequest) {
        setState(() => _routeLoading = false);

        final currentPosition = _userPosition;
        final movedWhileLoading =
            currentPosition != null &&
            const Distance().as(
                  LengthUnit.Meter,
                  routeOrigin,
                  currentPosition,
                ) >
                40;
        final shouldReload =
            _hasRouteTarget &&
            (signature != _lastRouteSignature ||
                (_routeReloadPending && movedWhileLoading));
        _routeReloadPending = false;
        if (shouldReload) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoadRoute());
        }
      }
    }
  }

  void _fitRoute(List<LatLng> points) {
    if (!mounted || points.length < 2) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(54, 120, 54, 210),
          maxZoom: 17,
        ),
      );
    });
  }

  void _centerOnUser() {
    if (_userPosition == null) {
      _startNavigation();
      widget.notify(
        _locationIssue ?? 'Waiting for your GPS position…',
        AppColors.primary,
      );
      return;
    }
    controller.move(_userPosition!, 16.5);
  }

  void _toggleGuidance() {
    if (_userPosition == null) {
      _centerOnUser();
      return;
    }
    setState(() => _guidanceMode = !_guidanceMode);
    if (_guidanceMode) {
      controller.moveAndRotate(_userPosition!, 17.5, (360 - _heading) % 360);
    } else {
      controller.rotate(0);
      if (_roadRoute.isNotEmpty) _fitRoute(_roadRoute);
    }
  }

  String get _routeDetail {
    if (_routeLoading) return 'Calculating the best road route…';
    if (_routeIssue != null) return _routeIssue!;
    if (_routeDistanceMeters <= 0) return 'Waiting for live location…';
    final distance = _routeDistanceMeters >= 1000
        ? '${(_routeDistanceMeters / 1000).toStringAsFixed(1)} km'
        : '${_routeDistanceMeters.round()} m';
    if (_routeDurationSeconds <= 0) return distance;
    final minutes = (_routeDurationSeconds / 60).ceil();
    return '$distance · about $minutes min';
  }

  List<HeritagePlace> get filtered {
    final q = widget.viewModel.query.toLowerCase();
    return widget.viewModel.nearbyPlaces
        .where(
          (HeritagePlace p) =>
              p.distanceKm <= widget.viewModel.radius &&
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
    'Architecture' ||
    'Historical Monument' ||
    'Cultural Heritage' ||
    'Temple & Sacred' ||
    'Museum' => p.category,
    _ => 'Architecture',
  };

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.viewModel,
    builder: (BuildContext context, _) {
      final vm = widget.viewModel;
      _syncRoute();
      final points = _roadRoute.isNotEmpty ? _roadRoute : _routeWaypoints();
      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: FlutterMap(
              mapController: controller,
              options: MapOptions(
                initialCenter: const LatLng(5.4182, 100.3411),
                initialZoom: 12.2,
                backgroundColor: const Color(0xFFE7F0EA),
                onPositionChanged: _updateHeritageLabelVisibility,
              ),
              children: <Widget>[
                const _OfflineMapBackground(),
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.finditmy.findit_my',
                  maxNativeZoom: 19,
                ),
                if (_userPosition != null && !_hasRouteTarget)
                  CircleLayer(
                    circles: <CircleMarker>[
                      CircleMarker(
                        point: _userPosition!,
                        radius: vm.radius * 1000,
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
                        color: Colors.white,
                        strokeWidth: 9,
                      ),
                      Polyline(
                        points: points,
                        color: AppColors.primary,
                        strokeWidth: 5.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  rotate: true,
                  markers: <Marker>[
                    if (_userPosition != null)
                      Marker(
                        point: _userPosition!,
                        width: 64,
                        height: 64,
                        child: ValueListenableBuilder<double>(
                          valueListenable: _headingNotifier,
                          builder: (BuildContext context, double heading, _) =>
                              _UserMarker(heading: _guidanceMode ? 0 : heading),
                        ),
                      ),
                    if (vm.routeStops.isEmpty && vm.directionTarget == null)
                      ...filtered.map(
                        (HeritagePlace p) => Marker(
                          point: LatLng(p.latitude, p.longitude),
                          alignment: Alignment.topCenter,
                          width: 150,
                          height: 84,
                          child: _PlaceMarker(
                            place: p,
                            bookmarked: p.bookmarked,
                            showLabel: _showHeritageLabels,
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
                const RichAttributionWidget(
                  attributions: <SourceAttribution>[
                    TextSourceAttribution('OpenStreetMap contributors'),
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
                            hintText: 'Search the map',
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
                  if (vm.heritageLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                  if (vm.heritageIssue != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: AppCard(
                        radius: 14,
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                vm.heritageIssue!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed:
                                  vm.heritageLoading || _userPosition == null
                                  ? null
                                  : () => vm.retryNearbyHeritage(
                                      latitude: _userPosition!.latitude,
                                      longitude: _userPosition!.longitude,
                                    ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (vm.heritageLoadAttempted &&
                      !vm.heritageLoading &&
                      vm.heritageIssue == null &&
                      vm.nearbyPlaces.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: AppCard(
                        radius: 14,
                        child: Text(
                          'No named heritage locations were found in this area.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
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
                              'Search radius · ${_radiusLabel(vm.radius)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Slider(
                              value: vm.radiusOptionIndex.toDouble(),
                              min: 0,
                              max:
                                  (MapQuestViewModel.radiusOptionsKm.length - 1)
                                      .toDouble(),
                              divisions:
                                  MapQuestViewModel.radiusOptionsKm.length - 1,
                              onChanged: vm.setRadiusOption,
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
                  onPressed: _centerOnUser,
                  child: _locating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                ),
                if (_hasRouteTarget) ...<Widget>[
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'guidance',
                    tooltip: _guidanceMode
                        ? 'Stop heading-up guidance'
                        : 'Start heading-up guidance',
                    backgroundColor: _guidanceMode
                        ? AppColors.primary
                        : Colors.white,
                    foregroundColor: _guidanceMode
                        ? Colors.white
                        : AppColors.primary,
                    onPressed: _toggleGuidance,
                    child: const Icon(Icons.navigation_rounded),
                  ),
                ],
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
                title: _guidanceMode ? 'Guiding you' : 'Route ready',
                subtitle: vm.directionTarget!.name,
                detail: _routeDetail,
                loading: _routeLoading,
                guidanceActive: _guidanceMode,
                onGuide: _toggleGuidance,
                onClose: () {
                  setState(() {
                    _guidanceMode = false;
                    _roadRoute = <LatLng>[];
                  });
                  controller.rotate(0);
                  vm.clearDirections();
                },
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

  String _radiusLabel(double radiusKm) => radiusKm < 1
      ? '${(radiusKm * 1000).round()} m'
      : '${radiusKm.round()} km';
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
  const _UserMarker({required this.heading});
  final double heading;
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0x33246BFD),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black26, blurRadius: 8),
          ],
        ),
        child: Transform.rotate(
          angle: heading * math.pi / 180,
          child: const Icon(
            Icons.navigation_rounded,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}

class _PlaceMarker extends StatelessWidget {
  const _PlaceMarker({
    required this.place,
    required this.bookmarked,
    required this.showLabel,
    required this.onTap,
  });
  final HeritagePlace place;
  final bool bookmarked;
  final bool showLabel;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: place.name,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        children: <Widget>[
          if (showLabel)
            Positioned(
              left: 4,
              right: 4,
              bottom: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    place.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 51,
            bottom: 0,
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                const Icon(
                  Icons.location_on_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
                Positioned(
                  top: 10,
                  child: Icon(
                    _categoryIcon(place.category),
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                if (bookmarked)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.star_rounded,
                          size: 11,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  IconData _categoryIcon(String category) => switch (category) {
    'Temple & Sacred' => Icons.temple_buddhist_rounded,
    'Architecture' => Icons.account_balance_rounded,
    'Cultural Heritage' => Icons.palette_rounded,
    _ => Icons.museum_rounded,
  };
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
    required this.loading,
    required this.guidanceActive,
    required this.onGuide,
    required this.onClose,
  });
  final String title;
  final String subtitle;
  final String detail;
  final bool loading;
  final bool guidanceActive;
  final VoidCallback onGuide;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 20,
    child: Row(
      children: <Widget>[
        CircleAvatar(
          backgroundColor: guidanceActive
              ? AppColors.tealDark
              : AppColors.primary,
          child: loading
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.navigation_rounded, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Eyebrow(title),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: guidanceActive ? 'Stop guidance' : 'Start guidance',
          onPressed: loading ? null : onGuide,
          icon: Icon(
            guidanceActive
                ? Icons.pause_circle_filled_rounded
                : Icons.navigation_rounded,
            color: AppColors.primary,
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

class _PlaceImage extends StatelessWidget {
  const _PlaceImage({required this.place});

  final HeritagePlace place;

  @override
  Widget build(BuildContext context) => place.image.isEmpty
      ? const ColoredBox(
          color: AppColors.softBlue,
          child: Center(
            child: Icon(
              Icons.museum_rounded,
              size: 54,
              color: AppColors.primary,
            ),
          ),
        )
      : Image.asset(place.image, fit: BoxFit.cover);
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
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .62,
              maxWidth: 520,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTokens.cardRadius),
              border: Border.all(color: AppColors.border),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x24203548),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    height: 155,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        _PlaceImage(place: place),
                        const DecoratedBox(
                          decoration: BoxDecoration(
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
                              fontWeight: FontWeight.w700,
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
                            if (place.rating > 0) ...<Widget>[
                              const Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: AppColors.warning,
                              ),
                              Text(
                                ' ${place.rating.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
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
                          color: AppColors.softBlue,
                          borderColor: const Color(0xFFD4E2FF),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.camera_alt_rounded,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 7),
                                  Text(
                                    'PICTURE QUEST',
                                    style: TextStyle(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Spacer(),
                                  AppChip(label: '+250 XP', selected: true),
                                ],
                              ),
                              SizedBox(height: 7),
                              Text(
                                'Capture a heritage detail',
                                style: TextStyle(fontWeight: FontWeight.w700),
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
                  child: _PlaceImage(place: widget.place),
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
