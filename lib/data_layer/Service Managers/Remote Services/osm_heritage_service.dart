import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../Models/app_models.dart';

class OsmHeritageService {
  static const List<({String host, String path})> endpoints =
      <({String host, String path})>[
        (host: 'overpass-api.de', path: '/api/interpreter'),
        (host: 'overpass.private.coffee', path: '/api/interpreter'),
        (host: 'maps.mail.ru', path: '/osm/tools/overpass/api/interpreter'),
      ];
  static const Duration requestTimeout = Duration(seconds: 20);
  static const Set<int> fallbackStatusCodes = <int>{429, 502, 503, 504};

  Future<List<HeritagePlace>> fetchNearbyHeritage({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    debugPrint('OSM heritage request started');
    debugPrint('OSM search center: $latitude, $longitude');
    debugPrint('OSM search radius: $radiusMeters metres');

    final query = _buildQuery(latitude, longitude, radiusMeters);
    for (var index = 0; index < endpoints.length; index++) {
      final attempt = index + 1;
      final endpoint = endpoints[index];
      debugPrint('Overpass attempt $attempt: ${endpoint.host}');
      try {
        final decoded = await _request(endpoint, query);
        final places = _parseResponse(
          decoded,
          latitude: latitude,
          longitude: longitude,
        );
        debugPrint(
          'OSM heritage request successful: ${places.length} locations',
        );
        return places;
      } on _OverpassStatusException catch (error) {
        debugPrint(
          'Overpass attempt $attempt failed: HTTP ${error.statusCode}',
        );
        if (!fallbackStatusCodes.contains(error.statusCode)) rethrow;
      } on TimeoutException {
        debugPrint('Overpass attempt $attempt failed: request timed out');
      } on SocketException {
        debugPrint('Overpass attempt $attempt failed: connection error');
      } on HandshakeException {
        debugPrint('Overpass attempt $attempt failed: connection error');
      } on HttpException catch (error) {
        debugPrint('Overpass attempt $attempt failed: ${error.message}');
      } on FormatException catch (error) {
        debugPrint('OSM heritage request failed: ${error.message}');
        rethrow;
      }
    }

    debugPrint(
      'OSM heritage request failed: all Overpass endpoints unavailable',
    );
    throw const HttpException('All Overpass endpoints unavailable.');
  }

  Future<dynamic> _request(
    ({String host, String path}) endpoint,
    String query,
  ) async {
    final client = HttpClient()..userAgent = 'FindItMy/1.0';
    try {
      return await _performRequest(
        client,
        endpoint,
        query,
      ).timeout(requestTimeout);
    } finally {
      client.close(force: true);
    }
  }

  Future<dynamic> _performRequest(
    HttpClient client,
    ({String host, String path}) endpoint,
    String query,
  ) async {
    final request = await client.postUrl(
      Uri.https(endpoint.host, endpoint.path),
    );
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    request.write('data=${Uri.encodeQueryComponent(query)}');
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw _OverpassStatusException(response.statusCode);
    }
    return jsonDecode(body);
  }

  String _buildQuery(double latitude, double longitude, int radiusMeters) =>
      '''
[out:json][timeout:18];
(
  nwr(around:$radiusMeters,$latitude,$longitude)["historic"];
  nwr(around:$radiusMeters,$latitude,$longitude)["heritage"];
  nwr(around:$radiusMeters,$latitude,$longitude)["tourism"~"^(museum|gallery|attraction|artwork)\$"];
);
out tags center qt;
''';

  List<HeritagePlace> _parseResponse(
    dynamic decoded, {
    required double latitude,
    required double longitude,
  }) {
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid Overpass response.');
    }
    final elements = decoded['elements'];
    if (elements is! List<dynamic>) {
      throw const FormatException('Overpass response has no elements list.');
    }

    final origin = LatLng(latitude, longitude);
    final seen = <String>{};
    final places = <HeritagePlace>[];
    for (final value in elements) {
      if (value is! Map<String, dynamic>) continue;
      final type = value['type'];
      final numericId = value['id'];
      final rawTags = value['tags'];
      if (type is! String || numericId is! num || rawTags is! Map) continue;

      final tags = <String, String>{};
      for (final entry in rawTags.entries) {
        if (entry.key is String && entry.value is String) {
          tags[entry.key as String] = entry.value as String;
        }
      }
      final name = tags['name']?.trim();
      if (name == null || name.isEmpty) continue;

      final coordinates = _coordinates(value, type);
      if (coordinates == null ||
          !coordinates.latitude.isFinite ||
          !coordinates.longitude.isFinite ||
          coordinates.latitude < -90 ||
          coordinates.latitude > 90 ||
          coordinates.longitude < -180 ||
          coordinates.longitude > 180) {
        continue;
      }

      final osmNumericId = numericId.toInt();
      final osmId = '$type/$osmNumericId';
      if (!seen.add(osmId)) continue;
      final category = _category(tags);
      places.add(
        HeritagePlace(
          id: osmId,
          osmId: osmId,
          osmType: type,
          osmNumericId: osmNumericId,
          osmTags: Map<String, String>.unmodifiable(tags),
          name: name,
          category: category,
          state: tags['addr:state'] ?? '',
          shortDescription: category,
          description: '',
          image: '',
          distanceKm: const Distance().as(
            LengthUnit.Kilometer,
            origin,
            coordinates,
          ),
          rating: 0,
          reviewsCount: 0,
          latitude: coordinates.latitude,
          longitude: coordinates.longitude,
          address: _address(tags),
          hours: tags['opening_hours'] ?? '',
        ),
      );
    }
    places.sort(
      (HeritagePlace a, HeritagePlace b) =>
          a.distanceKm.compareTo(b.distanceKm),
    );
    return places;
  }

  LatLng? _coordinates(Map<String, dynamic> element, String type) {
    final source = type == 'node' ? element : element['center'];
    if (source is! Map) return null;
    final lat = source['lat'];
    final lon = source['lon'];
    if (lat is! num || lon is! num) return null;
    return LatLng(lat.toDouble(), lon.toDouble());
  }

  String _category(Map<String, String> tags) {
    final tourism = tags['tourism'];
    if (tourism == 'museum') return 'Museum';
    if (tourism == 'gallery' || tourism == 'artwork') {
      return 'Cultural Heritage';
    }
    if (tags['amenity'] == 'place_of_worship') return 'Temple & Sacred';
    if (tags.containsKey('historic')) return 'Historical Monument';
    if (tourism == 'attraction' || tags.containsKey('heritage')) {
      return 'Cultural Heritage';
    }
    return 'Architecture';
  }

  String _address(Map<String, String> tags) {
    final parts = <String>[
      if ((tags['addr:housenumber'] ?? '').isNotEmpty)
        tags['addr:housenumber']!,
      if ((tags['addr:street'] ?? '').isNotEmpty) tags['addr:street']!,
      if ((tags['addr:city'] ?? '').isNotEmpty) tags['addr:city']!,
      if ((tags['addr:state'] ?? '').isNotEmpty) tags['addr:state']!,
      if ((tags['addr:postcode'] ?? '').isNotEmpty) tags['addr:postcode']!,
    ];
    return parts.join(', ');
  }
}

class _OverpassStatusException implements Exception {
  const _OverpassStatusException(this.statusCode);

  final int statusCode;
}
