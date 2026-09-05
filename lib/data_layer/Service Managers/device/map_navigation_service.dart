import 'dart:convert';

import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

enum LocationAccessStatus { ready, servicesDisabled, denied, deniedForever }

class RoadRoute {
  const RoadRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
}

class MapNavigationService {
  Future<LocationAccessStatus> requestLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccessStatus.servicesDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.denied => LocationAccessStatus.denied,
      LocationPermission.deniedForever => LocationAccessStatus.deniedForever,
      LocationPermission.whileInUse ||
      LocationPermission.always => LocationAccessStatus.ready,
      LocationPermission.unableToDetermine => LocationAccessStatus.denied,
    };
  }

  Stream<Position> get positionStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 4,
    ),
  );

  Future<Position?> getLastKnownPosition() => Geolocator.getLastKnownPosition();

  Stream<double?>? get headingStream =>
      FlutterCompass.events?.map((CompassEvent event) => event.heading);

  Future<RoadRoute> fetchDrivingRoute(List<LatLng> waypoints) async {
    return _fetchOsrmRoute(
      waypoints,
      host: 'router.project-osrm.org',
      routePathPrefix: '/route/v1/driving',
    );
  }

  Future<RoadRoute> fetchWalkingRoute(List<LatLng> waypoints) async {
    return _fetchOsrmRoute(
      waypoints,
      host: 'routing.openstreetmap.de',
      routePathPrefix: '/routed-foot/route/v1/driving',
    );
  }

  Future<RoadRoute> _fetchOsrmRoute(
    List<LatLng> waypoints, {
    required String host,
    required String routePathPrefix,
  }) async {
    if (waypoints.length < 2) {
      throw ArgumentError('At least two route points are required.');
    }
    final coordinates = waypoints
        .map((LatLng point) => '${point.longitude},${point.latitude}')
        .join(';');
    final uri = Uri.https(
      host,
      '$routePathPrefix/$coordinates',
      <String, String>{
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
      },
    );
    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('Routing service returned ${response.statusCode}.');
    }
    final payload = jsonDecode(utf8.decode(response.bodyBytes))
        as Map<String, dynamic>;
    final routes = payload['routes'] as List<dynamic>?;
    if (payload['code'] != 'Ok' || routes == null || routes.isEmpty) {
      throw const FormatException('No road route was returned.');
    }
    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;
    return RoadRoute(
      points: coordinates
          .map((dynamic value) {
            final pair = value as List<dynamic>;
            return LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            );
          })
          .toList(growable: false),
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
    );
  }
}
