import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/planner_models.dart';

class OsrmService {
  OsrmService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  Future<RouteLeg> route(List<GeoPoint> points) async {
    if (points.length < 2) {
      throw ArgumentError('At least two coordinates are required');
    }
    for (final point in points) {
      if (point.latitude < -90 ||
          point.latitude > 90 ||
          point.longitude < -180 ||
          point.longitude > 180) {
        throw ArgumentError('Invalid route coordinate');
      }
    }
    final coordinates = points
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');
    final uri =
        Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/$coordinates',
        ).replace(
          queryParameters: <String, String>{
            'overview': 'full',
            'geometries': 'geojson',
            'steps': 'true',
          },
        );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('OSRM ${response.statusCode}: ${response.body}');
    }
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final routes = json['routes'] as List<dynamic>?;
    if (json['code'] != 'Ok' || routes == null || routes.isEmpty) {
      throw StateError('OSRM route unavailable');
    }
    final route = routes.first as Map<String, dynamic>;
    final coordinatesJson =
        (route['geometry'] as Map<String, dynamic>)['coordinates']
            as List<dynamic>;
    return RouteLeg(
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
      geometry: coordinatesJson.map((dynamic c) {
        final pair = c as List<dynamic>;
        return GeoPoint(
          (pair[1] as num).toDouble(),
          (pair[0] as num).toDouble(),
        );
      }).toList(),
    );
  }

  void dispose() => _client.close();
}
