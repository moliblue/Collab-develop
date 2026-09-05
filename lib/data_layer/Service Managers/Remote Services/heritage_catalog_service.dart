import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../Models/app_models.dart';
import 'osm_heritage_service.dart';

/// Reads the curated catalogue first and falls back to live OSM/Overpass data.
class HeritageCatalogService {
  HeritageCatalogService({
    SupabaseClient? client,
    OsmHeritageService? osm,
  }) : _client = client,
       _osm = osm ?? OsmHeritageService();

  final SupabaseClient? _client;
  final OsmHeritageService _osm;

  SupabaseClient? get _availableClient {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<HeritagePlace>> fetchNearbyHeritage({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    try {
      final cached = await _fetchCatalogue(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );
      if (cached.isNotEmpty) return cached;
    } catch (_) {
      // The public OSM fallback keeps discovery usable during DB outages or
      // before the catalogue migration has been applied.
    }
    return _osm.fetchNearbyHeritage(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
  }

  Future<List<HeritagePlace>> _fetchCatalogue({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    final client = _availableClient;
    if (client == null) return <HeritagePlace>[];
    final radiusKm = radiusMeters / 1000;
    final latitudeDelta = radiusKm / 111.0;
    final longitudeDelta = radiusKm /
        (111.0 * math.max(0.1, math.cos(latitude * math.pi / 180)).abs());
    final rows = await client
        .from('heritage_locations')
        .select()
        .eq('is_active', true)
        .gte('latitude', latitude - latitudeDelta)
        .lte('latitude', latitude + latitudeDelta)
        .gte('longitude', longitude - longitudeDelta)
        .lte('longitude', longitude + longitudeDelta)
        .limit(250);
    final places = rows
        .map((row) => _fromRow(Map<String, dynamic>.from(row), latitude, longitude))
        .where((place) => place.distanceKm <= radiusKm)
        .toList();
    places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return places;
  }

  HeritagePlace _fromRow(
    Map<String, dynamic> row,
    double latitude,
    double longitude,
  ) {
    final placeLatitude = (row['latitude'] as num).toDouble();
    final placeLongitude = (row['longitude'] as num).toDouble();
    const earthRadiusKm = 6371.0;
    final dLat = (placeLatitude - latitude) * math.pi / 180;
    final dLon = (placeLongitude - longitude) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(latitude * math.pi / 180) *
            math.cos(placeLatitude * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final distance = earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final osmId = '${row['osm_id']}';
    return HeritagePlace(
      id: osmId,
      osmId: osmId,
      name: '${row['name']}',
      category: '${row['category']}',
      state: '${row['state'] ?? ''}',
      shortDescription: '${row['category']}',
      description: '${row['description'] ?? ''}',
      image: '${row['image_url'] ?? ''}',
      distanceKm: distance,
      rating: 0,
      reviewsCount: 0,
      latitude: placeLatitude,
      longitude: placeLongitude,
      address: '${row['address'] ?? ''}',
      hours: '${row['opening_hours'] ?? ''}',
      osmTags: Map<String, String>.from(row['osm_tags'] as Map? ?? const {}),
    );
  }
}
