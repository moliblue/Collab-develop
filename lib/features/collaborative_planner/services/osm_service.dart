import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/planner_models.dart';

class OsmPlace {
  const OsmPlace({
    required this.name,
    required this.displayName,
    required this.point,
    required this.type,
  });
  final String name;
  final String displayName;
  final GeoPoint point;
  final String type;
}

class OsmService {
  OsmService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const _endpoint = 'https://nominatim.openstreetmap.org';
  Future<List<OsmPlace>> search(
    String query, {
    bool heritageOnly = false,
  }) async {
    if (query.trim().length < 3) return <OsmPlace>[];
    final uri = Uri.parse('$_endpoint/search').replace(
      queryParameters: <String, String>{
        'q': heritageOnly ? '$query heritage Malaysia' : query,
        'format': 'jsonv2',
        'addressdetails': '1',
        'dedupe': '1',
        'limit': '8',
        'countrycodes': 'my',
      },
    );
    final response = await _client
        .get(uri, headers: const <String, String>{'Accept-Language': 'en'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Nominatim ${response.statusCode}: ${response.body}');
    }
    return (jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>)
        .map((dynamic value) {
          final j = value as Map<String, dynamic>;
          final display = '${j['display_name'] ?? ''}'.trim();
          if (display.isEmpty) return null;
          final latitude = double.tryParse('${j['lat']}');
          final longitude = double.tryParse('${j['lon']}');
          if (latitude == null || longitude == null) return null;
          return OsmPlace(
            name: '${j['name'] ?? display.split(',').first}',
            displayName: display,
            point: GeoPoint(latitude, longitude),
            type: '${j['type'] ?? 'place'}',
          );
        })
        .whereType<OsmPlace>()
        .toList();
  }

  void dispose() => _client.close();
}
