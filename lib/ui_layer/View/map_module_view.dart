import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../data_layer/Models/app_models.dart';
import '../../data_layer/Service Managers/device/map_navigation_service.dart';
import '../ViewModel/map_quest_view_model.dart';
import 'shared/app_widgets.dart';

enum _RouteMode { driving, walking }

class MapModuleView extends StatefulWidget {
  const MapModuleView({
    super.key,
    required this.viewModel,
    required this.active,
    required this.onBack,
    required this.onXpReward,
    required this.onAddToPlan,
    required this.notify,
  });
  final MapQuestViewModel viewModel;
  final bool active;
  final VoidCallback onBack;
  final ValueChanged<int> onXpReward;
  final ValueChanged<HeritagePlace> onAddToPlan;
  final void Function(String, Color) notify;
  @override
  State<MapModuleView> createState() => _MapModuleViewState();
}

class _MapModuleViewState extends State<MapModuleView> {
  final MapController controller = MapController();
  final MapNavigationService navigation = MapNavigationService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ValueNotifier<double> _headingNotifier = ValueNotifier<double>(0);
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<double?>? _headingSubscription;
  Timer? _locationTimeoutTimer;
  bool filtersOpen = false;
  bool _navigationActive = false;
  bool _locating = false;
  bool _routeLoading = false;
  _RouteMode _routeMode = _RouteMode.driving;
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
  static const double _questRadiusMeters = 1000;

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
    _locationTimeoutTimer?.cancel();
    _positionSubscription?.cancel();
    _headingSubscription?.cancel();
    _headingNotifier.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
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
        final currentPosition = _effectiveUserPosition;
        if (_guidanceMode && currentPosition != null) {
          controller.moveAndRotate(currentPosition, 17.5, (360 - value) % 360);
        }
      });
      final lastKnown = await navigation.getLastKnownPosition();
      if (lastKnown != null && mounted && _navigationActive) {
        _updatePosition(lastKnown);
      } else {
        _locationTimeoutTimer?.cancel();
        _locationTimeoutTimer = Timer(const Duration(seconds: 15), () {
          if (!mounted || !_navigationActive || _userPosition != null) return;
          _navigationActive = false;
          _positionSubscription?.cancel();
          _positionSubscription = null;
          setState(() {
            _locating = false;
            _locationIssue =
                'GPS did not return a position. Allow Location for this site, '
                'enable device Location, then tap the location button again.';
          });
        });
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
    _locationTimeoutTimer?.cancel();
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
    _locationTimeoutTimer?.cancel();
    final next = LatLng(position.latitude, position.longitude);
    final previous = _userPosition;
    if (previous != null) {
      final movement = const Distance().as(LengthUnit.Meter, previous, next);
      final noiseFloor = math.max(10.0, position.accuracy * 1.5);
      if (movement < noiseFloor) {
        if (_locating) setState(() => _locating = false);
        return;
      }
    }
    final effectiveNext = next;
    final moved = _routedFrom == null
        ? double.infinity
        : const Distance().as(LengthUnit.Meter, _routedFrom!, effectiveNext);
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
      controller.moveAndRotate(effectiveNext, 17.5, (360 - _heading) % 360);
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

  // Navigation and quest eligibility must always use the physical device GPS.
  LatLng? get _effectiveUserPosition => _userPosition;

  List<LatLng> _routeWaypoints() {
    final origin = _userPosition;
    if (origin == null) return <LatLng>[];
    if (widget.viewModel.routeStops.isNotEmpty) {
      return <LatLng>[
        origin,
        ...widget.viewModel.routeStops.map(
          (ActivityItem item) => LatLng(item.latitude, item.longitude),
        ),
      ];
    }
    final target = widget.viewModel.directionTarget;
    return target == null
        ? <LatLng>[]
        : <LatLng>[origin, LatLng(target.latitude, target.longitude)];
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
    _routeDistanceMeters = 0;
    _routeDurationSeconds = 0;
    _routeIssue = null;
    _routedFrom = null;
    _guidanceMode = false;
    _routeMode = _RouteMode.driving;
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
      final result = _routeMode == _RouteMode.driving
          ? await navigation.fetchDrivingRoute(waypoints)
          : await navigation.fetchWalkingRoute(waypoints);
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
      if (_routeMode == _RouteMode.driving) {
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
      } else {
        setState(() {
          _roadRoute = <LatLng>[];
          _routeDistanceMeters = 0;
          _routeDurationSeconds = 0;
          _routedFrom = null;
          _routeIssue = 'Route is currently unavailable. Please try again.';
        });
      }
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
    final currentPosition = _effectiveUserPosition;
    if (currentPosition == null) {
      _startNavigation();
      widget.notify(
        _locationIssue ?? 'Waiting for your GPS position…',
        AppColors.primary,
      );
      return;
    }
    controller.move(currentPosition, 16.5);
  }

  void _toggleGuidance() {
    final currentPosition = _effectiveUserPosition;
    if (currentPosition == null) {
      _centerOnUser();
      return;
    }
    setState(() => _guidanceMode = !_guidanceMode);
    if (_guidanceMode) {
      controller.moveAndRotate(currentPosition, 17.5, (360 - _heading) % 360);
    } else {
      controller.rotate(0);
      if (_roadRoute.isNotEmpty) _fitRoute(_roadRoute);
    }
  }

  String get _routeDetail {
    final mode = _routeMode == _RouteMode.driving ? 'Driving' : 'Walking';
    if (_routeLoading) return '$mode · Calculating route…';
    if (_routeIssue != null) return '$mode · $_routeIssue';
    if (_routeDistanceMeters <= 0) return '$mode · Waiting for live location…';
    final distance = _routeDistanceMeters >= 1000
        ? '${(_routeDistanceMeters / 1000).toStringAsFixed(1)} km'
        : '${_routeDistanceMeters.round()} m';
    if (_routeDurationSeconds <= 0) return '$mode · $distance';
    final minutes = (_routeDurationSeconds / 60).ceil();
    return '$mode · $distance · about $minutes min';
  }

  void _setRouteMode(_RouteMode mode) {
    if (_routeLoading || mode == _routeMode || !_hasRouteTarget) return;
    setState(() {
      _routeMode = mode;
      _guidanceMode = false;
      _roadRoute = <LatLng>[];
      _routeDistanceMeters = 0;
      _routeDurationSeconds = 0;
      _routeIssue = null;
      _routedFrom = null;
      _routeReloadPending = false;
    });
    controller.rotate(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoadRoute());
  }

  Future<void> _joinRouteQuest(BuildContext context) async {
    final target = widget.viewModel.directionTarget;
    if (target == null) return;
    await _joinHeritageQuest(
      context: context,
      place: target,
      vm: widget.viewModel,
      currentPosition: _effectiveUserPosition,
      notify: widget.notify,
      onXpReward: widget.onXpReward,
    );
  }

  double? _routeOriginDistance(HeritagePlace target) {
    final current = _userPosition;
    if (current == null) return null;
    return const Distance().as(
      LengthUnit.Meter,
      current,
      LatLng(target.latitude, target.longitude),
    );
  }

  String _liveRouteStatus(HeritagePlace target) {
    final distance = _routeOriginDistance(target);
    if (distance == null) return 'Waiting for live GPS position…';
    if (distance <= _questRadiusMeters) {
      return 'Live GPS · within 1 km · Quest available';
    }
    final label = distance >= 1000
        ? '${(distance / 1000).toStringAsFixed(1)} km'
        : '${distance.round()} m';
    return 'Live GPS · $label from destination';
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
      final points = _roadRoute.isNotEmpty
          ? _roadRoute
          : _routeMode == _RouteMode.driving
          ? _routeWaypoints()
          : <LatLng>[];
      final completedMysteryIds = vm.completedMysteries
          .map((completion) => completion.place.id)
          .toSet();
      final revealedMystery = vm.revealedActiveMysteryDestination;
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
                if (_effectiveUserPosition != null && !_hasRouteTarget)
                  CircleLayer(
                    circles: <CircleMarker>[
                      CircleMarker(
                        point: _effectiveUserPosition!,
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
                    if (_effectiveUserPosition != null)
                      Marker(
                        point: _effectiveUserPosition!,
                        width: 64,
                        height: 64,
                        child: ValueListenableBuilder<double>(
                          valueListenable: _headingNotifier,
                          builder: (BuildContext context, double heading, _) =>
                              _UserMarker(heading: _guidanceMode ? 0 : heading),
                        ),
                      ),
                    if (vm.routeStops.isEmpty && vm.directionTarget == null)
                      ...filtered
                          .where(
                            (place) =>
                                !completedMysteryIds.contains(place.id) &&
                                !vm.shouldHideForActiveMystery(place),
                          )
                          .map(
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
                    if (vm.routeStops.isEmpty && vm.directionTarget == null)
                      ...vm.completedMysteries
                          .where(
                            (completion) => !vm.shouldHideForActiveMystery(
                              completion.place,
                            ),
                          )
                          .map(
                            (MysteryMapCompletion completion) => Marker(
                              point: LatLng(
                                completion.place.latitude,
                                completion.place.longitude,
                              ),
                              alignment: Alignment.topCenter,
                              width: 58,
                              height: 58,
                              child: _CompletedMysteryMarker(
                                place: completion.place,
                                onTap: () =>
                                    vm.selectCompletedMystery(completion),
                              ),
                            ),
                          ),
                    if (vm.routeStops.isEmpty &&
                        vm.directionTarget == null &&
                        revealedMystery != null)
                      Marker(
                        point: LatLng(
                          revealedMystery.latitude,
                          revealedMystery.longitude,
                        ),
                        alignment: Alignment.topCenter,
                        width: 64,
                        height: 64,
                        child: _ActiveMysteryMarker(
                          place: revealedMystery,
                          onTap: () => vm.showDirections(revealedMystery),
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
                        child:
                            vm.revealedActiveMysteryDestination != null &&
                                vm.isCurrentMysteryPlace(vm.directionTarget!)
                            ? _ActiveMysteryMarker(
                                place: vm.directionTarget!,
                                onTap: () {},
                              )
                            : const Icon(
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
                          controller: _searchController,
                          focusNode: _searchFocus,
                          onTap: () => setState(() {}),
                          onChanged: (value) {
                            vm.setQuery(value);
                            setState(() {});
                          },
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
                  if (_searchFocus.hasFocus && filtered.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: AppCard(
                        radius: 14,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: filtered
                              .take(5)
                              .map((place) {
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    place.bookmarked
                                        ? Icons.bookmark_rounded
                                        : Icons.account_balance_rounded,
                                    color: place.bookmarked
                                        ? AppColors.warning
                                        : AppColors.primary,
                                  ),
                                  title: Text(
                                    place.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    place.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    _searchController.text = place.name;
                                    vm.setQuery(place.name);
                                    vm.select(place);
                                    _searchFocus.unfocus();
                                    controller.move(
                                      LatLng(place.latitude, place.longitude),
                                      16,
                                    );
                                  },
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
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
                                    <String>{
                                          'All',
                                          ...vm.nearbyPlaces.map(_mapCategory),
                                        }
                                        .toList()
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
                  heroTag: 'zoom-out',
                  tooltip: 'Zoom out',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  onPressed: () {
                    final camera = controller.camera;
                    controller.move(camera.center, camera.zoom - 1);
                  },
                  child: const Icon(Icons.remove_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom-in',
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
                mode: _routeMode,
                onModeChanged: _setRouteMode,
                liveStatus: _liveRouteStatus(vm.directionTarget!),
                canJoinQuest:
                    (_routeOriginDistance(vm.directionTarget!) ??
                        double.infinity) <=
                    _questRadiusMeters,
                questLoading: vm.questLoading,
                onJoinQuest: () => _joinRouteQuest(context),
                onGuide: _toggleGuidance,
                onClose: () {
                  setState(() {
                    _guidanceMode = false;
                    _roadRoute = <LatLng>[];
                    _routeDistanceMeters = 0;
                    _routeDurationSeconds = 0;
                    _routeIssue = null;
                    _routedFrom = null;
                    _routeMode = _RouteMode.driving;
                    _routeReloadPending = false;
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
                loading: _routeLoading,
                guidanceActive: _guidanceMode,
                onGuide: _toggleGuidance,
                onClose: vm.clearDayRoute,
                onFocus: (ActivityItem a) =>
                    controller.move(LatLng(a.latitude, a.longitude), 14.5),
              ),
            ),
          if (vm.selected != null)
            _LocationSheet(
              place: vm.selected!,
              mysteryCompletion: vm.selectedMysteryCompletion,
              vm: vm,
              currentPosition: () => _effectiveUserPosition,
              notify: widget.notify,
              onAddToPlan: widget.onAddToPlan,
              onXpReward: widget.onXpReward,
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

class _CompletedMysteryMarker extends StatelessWidget {
  const _CompletedMysteryMarker({required this.place, required this.onTap});

  final HeritagePlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${place.name}, completed Mystery Journey',
    child: InkResponse(
      onTap: onTap,
      radius: 28,
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          const Icon(
            Icons.location_on_rounded,
            size: 52,
            color: AppColors.tealDark,
          ),
          const Positioned(
            top: 10,
            child: Icon(Icons.check_rounded, size: 18, color: Colors.white),
          ),
          Positioned(
            right: 1,
            top: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.teal, width: 2),
              ),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.explore_rounded,
                  size: 11,
                  color: AppColors.tealDark,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActiveMysteryMarker extends StatelessWidget {
  const _ActiveMysteryMarker({required this.place, required this.onTap});

  final HeritagePlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${place.name}, active Mystery destination',
    child: InkResponse(
      onTap: onTap,
      radius: 28,
      child: const Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          Icon(
            Icons.location_on_rounded,
            size: 54,
            color: AppColors.primaryDark,
          ),
          Positioned(
            top: 10,
            child: Icon(Icons.explore_rounded, size: 19, color: Colors.white),
          ),
        ],
      ),
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
    required this.loading,
    required this.guidanceActive,
    required this.mode,
    required this.onModeChanged,
    required this.liveStatus,
    required this.canJoinQuest,
    required this.questLoading,
    required this.onJoinQuest,
    required this.onGuide,
    required this.onClose,
  });
  final String title;
  final String subtitle;
  final String detail;
  final bool loading;
  final bool guidanceActive;
  final _RouteMode mode;
  final ValueChanged<_RouteMode> onModeChanged;
  final String? liveStatus;
  final bool canJoinQuest;
  final bool questLoading;
  final VoidCallback onJoinQuest;
  final VoidCallback onGuide;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 20,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
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
                  : Icon(
                      mode == _RouteMode.driving
                          ? Icons.directions_car_rounded
                          : Icons.directions_walk_rounded,
                      color: Colors.white,
                    ),
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
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _RouteModeSelector(
                    mode: mode,
                    enabled: !loading,
                    onChanged: onModeChanged,
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
        const SizedBox(height: 6),
        if (liveStatus != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              liveStatus!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        Row(
          children: <Widget>[
            Expanded(
              child: TextButton.icon(
                onPressed: loading ? null : onGuide,
                icon: Icon(
                  guidanceActive
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline_rounded,
                  size: 18,
                ),
                label: Text(guidanceActive ? 'Stop Route' : 'Start Route'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canJoinQuest && !questLoading ? onJoinQuest : null,
                icon: const Icon(Icons.workspace_premium_rounded, size: 17),
                label: Text(
                  questLoading ? 'Checking…' : 'Join Heritage Quest',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _RouteModeSelector extends StatelessWidget {
  const _RouteModeSelector({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final _RouteMode mode;
  final bool enabled;
  final ValueChanged<_RouteMode> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 30,
    child: Row(
      children: _RouteMode.values
          .map(
            (_RouteMode value) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Material(
                  color: mode == value
                      ? AppColors.primary.withValues(alpha: .13)
                      : AppColors.elevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                    side: BorderSide(
                      color: mode == value
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: InkWell(
                    onTap: enabled && mode != value
                        ? () => onChanged(value)
                        : null,
                    borderRadius: BorderRadius.circular(9),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          value == _RouteMode.driving
                              ? Icons.directions_car_rounded
                              : Icons.directions_walk_rounded,
                          size: 13,
                          color: enabled ? AppColors.primary : AppColors.muted,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            value == _RouteMode.driving ? 'Driving' : 'Walking',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    ),
  );
}

class _DayRoutePanel extends StatelessWidget {
  const _DayRoutePanel({
    required this.stops,
    required this.loading,
    required this.guidanceActive,
    required this.onGuide,
    required this.onClose,
    required this.onFocus,
  });
  final List<ActivityItem> stops;
  final bool loading;
  final bool guidanceActive;
  final VoidCallback onGuide;
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
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: loading ? null : onGuide,
            icon: Icon(
              guidanceActive
                  ? Icons.pause_circle_filled_rounded
                  : Icons.navigation_rounded,
            ),
            label: Text(
              guidanceActive ? 'Stop Route Guidance' : 'Start Route Guidance',
            ),
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
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: AppColors.softBlue,
      child: Center(
        child: Icon(Icons.museum_rounded, size: 54, color: AppColors.primary),
      ),
    );
    if (place.image.isEmpty) return fallback;
    if (place.image.startsWith('http://') ||
        place.image.startsWith('https://')) {
      return Image.network(
        place.image,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.asset(place.image, fit: BoxFit.cover);
  }
}

class _LocationSheet extends StatelessWidget {
  const _LocationSheet({
    required this.place,
    required this.mysteryCompletion,
    required this.vm,
    required this.currentPosition,
    required this.notify,
    required this.onAddToPlan,
    required this.onXpReward,
  });
  final HeritagePlace place;
  final MysteryMapCompletion? mysteryCompletion;
  final MapQuestViewModel vm;
  final LatLng? Function() currentPosition;
  final void Function(String, Color) notify;
  final ValueChanged<HeritagePlace> onAddToPlan;
  final ValueChanged<int> onXpReward;
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
                            if (mysteryCompletion == null)
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
                        if (mysteryCompletion
                            case final completion?) ...<Widget>[
                          const SizedBox(height: 12),
                          AppCard(
                            key: const Key('completed_mystery_details'),
                            color: const Color(0xFFE9FAF4),
                            borderColor: AppColors.teal.withValues(alpha: .3),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 19,
                                      color: AppColors.tealDark,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Mystery Journey Completed ✓',
                                        style: TextStyle(
                                          color: AppColors.tealDark,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Last explored: ${_shortDate(completion.completedAt)}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                if (completion.passportStampCollected)
                                  const Text(
                                    'Passport Stamp: Collected',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                Text(
                                  completion.completionCount == 1
                                      ? 'Explored once'
                                      : 'Explored ${completion.completionCount} times',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const AppCard(
                          color: AppColors.softBlue,
                          borderColor: Color(0xFFD4E2FF),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.camera_alt_rounded,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      'PICTURE QUEST',
                                      maxLines: 2,
                                      style: TextStyle(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  AppChip(label: '+100 XP', selected: true),
                                ],
                              ),
                              SizedBox(height: 7),
                              Text(
                                'Heritage location quest',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Upload a photo of this heritage location.',
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
                          onPressed: () => onAddToPlan(place),
                          icon: const Icon(Icons.add_task_rounded),
                          label: const Text('Add to Plan'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: vm.questLoading
                              ? null
                              : () => _joinQuest(context),
                          icon: const Icon(Icons.workspace_premium_rounded),
                          label: Text(
                            vm.questLoading
                                ? 'Checking Quest…'
                                : 'Join Heritage Quest',
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

  Future<void> _joinQuest(BuildContext context) => _joinHeritageQuest(
    context: context,
    place: place,
    vm: vm,
    currentPosition: currentPosition(),
    notify: notify,
    onXpReward: onXpReward,
  );

  static String _shortDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

Future<void> _showQuestMessage(BuildContext context, String message) =>
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        icon: const Icon(
          Icons.location_searching_rounded,
          color: AppColors.warning,
          size: 38,
        ),
        title: const Text('Heritage Quest'),
        content: Text(message),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

Future<void> _joinHeritageQuest({
  required BuildContext context,
  required HeritagePlace place,
  required MapQuestViewModel vm,
  required LatLng? currentPosition,
  required void Function(String, Color) notify,
  required ValueChanged<int> onXpReward,
}) async {
  if (currentPosition == null) {
    await _showQuestMessage(
      context,
      'Current location is unavailable. Please enable location services and try again.',
    );
    return;
  }

  final distanceMeters = const Distance().as(
    LengthUnit.Meter,
    currentPosition,
    LatLng(place.latitude, place.longitude),
  );
  if (distanceMeters > _MapModuleViewState._questRadiusMeters) {
    await _showQuestMessage(
      context,
      'You must be within 1 kilometre of this heritage location to join the quest.',
    );
    return;
  }

  final result = await vm.prepareQuest(place);
  if (!context.mounted) return;
  switch (result.status) {
    case QuestJoinStatus.ready:
      await showAppSheet<void>(
        context,
        _QuestForm(
          place: place,
          vm: vm,
          notify: notify,
          onXpReward: onXpReward,
        ),
      );
      return;
    case QuestJoinStatus.unavailable:
      await _showQuestMessage(
        context,
        'Heritage quest is unavailable for this location.',
      );
      return;
    case QuestJoinStatus.alreadyCompleted:
      await _showQuestMessage(
        context,
        'You have already completed this heritage quest.',
      );
      return;
    case QuestJoinStatus.authenticationRequired:
      await _showQuestMessage(
        context,
        'Please sign in to join a heritage quest.',
      );
      return;
    case QuestJoinStatus.failed:
      await _showQuestMessage(
        context,
        'Heritage quest data is currently unavailable. Please try again later.',
      );
      return;
    case QuestJoinStatus.busy:
      return;
  }
}

class _QuestForm extends StatefulWidget {
  const _QuestForm({
    required this.place,
    required this.vm,
    required this.notify,
    required this.onXpReward,
  });

  final HeritagePlace place;
  final MapQuestViewModel vm;
  final void Function(String, Color) notify;
  final ValueChanged<int> onXpReward;
  @override
  State<_QuestForm> createState() => _QuestFormState();
}

class _QuestFormState extends State<_QuestForm> {
  final caption = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _photoBytes;
  String? _photoExtension;
  bool _selectingPhoto = false;
  bool _submitting = false;

  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SheetBody(
    children: <Widget>[
      ModalTitle(
        title: 'Capture local heritage',
        subtitle:
            '${widget.place.name} · +${MapQuestViewModel.pictureQuestXp} XP',
        icon: Icons.camera_alt_rounded,
      ),
      const SizedBox(height: 12),
      AppCard(
        color: AppColors.softBlue,
        borderColor: const Color(0xFFD4E2FF),
        child: const Text(
          MapQuestViewModel.pictureQuestInstructions,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 12),
      InkWell(
        onTap: _selectingPhoto || _submitting ? null : _pickPhoto,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 210,
          decoration: BoxDecoration(
            color: const Color(0xFFF3EEFF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFC4B5FD), width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: _photoBytes == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (_selectingPhoto)
                      const CircularProgressIndicator()
                    else
                      const Icon(
                        Icons.add_a_photo_rounded,
                        color: Color(0xFF7C3AED),
                        size: 42,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      _selectingPhoto
                          ? 'Opening gallery…'
                          : 'Choose a photo from Gallery',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Text(
                      'JPG, JPEG, PNG or WEBP',
                      style: TextStyle(fontSize: 9, color: AppColors.muted),
                    ),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.memory(_photoBytes!, fit: BoxFit.cover),
                    const Positioned(
                      right: 10,
                      bottom: 10,
                      child: AppChip(label: 'Tap to change', selected: true),
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
        onPressed: _submitting ? null : _submit,
        icon: const Icon(Icons.camera_alt_rounded),
        label: Text(
          _submitting
              ? 'Submitting…'
              : 'Submit Picture · +${MapQuestViewModel.pictureQuestXp} XP',
        ),
      ),
    ],
  );

  Future<void> _pickPhoto() async {
    setState(() => _selectingPhoto = true);
    try {
      final photo = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (photo == null || !mounted) return;
      final extension = _supportedExtension(photo.name);
      if (extension == null) {
        _showMessage('Please select a JPG, JPEG, PNG or WEBP image.');
        return;
      }
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        _showMessage('Unable to read the selected photo. Please try again.');
        return;
      }
      setState(() {
        _photoBytes = bytes;
        _photoExtension = extension;
      });
    } catch (_) {
      if (mounted) {
        _showMessage('Unable to select a photo. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _selectingPhoto = false);
    }
  }

  String? _supportedExtension(String filename) {
    final match = RegExp(r'[.]([^.]+)$').firstMatch(filename.toLowerCase());
    final extension = match?.group(1);
    return switch (extension) {
      'jpg' || 'jpeg' || 'png' || 'webp' => extension,
      _ => null,
    };
  }

  Future<void> _submit() async {
    final photoBytes = _photoBytes;
    final extension = _photoExtension;
    if (photoBytes == null || extension == null) {
      _showMessage('Please upload a photo before submitting the quest.');
      return;
    }

    setState(() => _submitting = true);
    final trimmedCaption = caption.text.trim();
    final result = await widget.vm.submitPictureQuest(
      place: widget.place,
      photoBytes: photoBytes,
      extension: extension,
      caption: trimmedCaption.isEmpty ? null : trimmedCaption,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result.status) {
      case QuestSubmissionStatus.completed:
        widget.onXpReward(result.xpAwarded);
        Navigator.pop(context);
        widget.notify(
          'Quest completed successfully. Experience Points (XP) have been awarded.',
          AppColors.teal,
        );
        return;
      case QuestSubmissionStatus.alreadyCompleted:
        Navigator.pop(context);
        widget.notify(
          'You have already completed this heritage quest.',
          AppColors.primary,
        );
        return;
      case QuestSubmissionStatus.uploadFailed:
        _showMessage('Photo upload failed. Please try again.');
        return;
      case QuestSubmissionStatus.authenticationRequired:
        _showMessage('Please sign in to join a heritage quest.');
        return;
      case QuestSubmissionStatus.failed:
        _showMessage('Quest submission failed. Please try again.');
        return;
      case QuestSubmissionStatus.busy:
        return;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
