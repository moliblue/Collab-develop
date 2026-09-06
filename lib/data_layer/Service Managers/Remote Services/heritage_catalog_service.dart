import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../Models/app_models.dart';
import 'osm_heritage_service.dart';

/// Reads the curated catalogue first and falls back to live OSM/Overpass data.
class HeritageCatalogService {
  HeritageCatalogService({this.client, OsmHeritageService? osm})
    : _osm = osm ?? OsmHeritageService();

  final SupabaseClient? client;
  final OsmHeritageService _osm;

  SupabaseClient? get _availableClient {
    if (client != null) return client;
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
    List<HeritagePlace> catalogue = <HeritagePlace>[];
    List<HeritagePlace> osmPlaces = <HeritagePlace>[];
    Object? catalogueError;
    Object? osmError;
    try {
      catalogue = await _fetchCatalogue(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );
    } catch (error) {
      catalogueError = error;
    }
    try {
      osmPlaces = await _osm.fetchNearbyHeritage(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );
    } catch (error) {
      osmError = error;
    }
    final merged = _mergePlaces(<HeritagePlace>[...catalogue, ...osmPlaces]);
    if (merged.isNotEmpty) return merged;
    if (catalogueError != null && osmError != null) throw osmError;
    return merged;
  }

  /// Returns every active verified Supabase catalogue record. Discover and
  /// Plan merge these with their existing built-in places, so catalogue growth
  /// never removes the locations already available in the app.
  Future<List<HeritagePlace>> fetchCatalogue() async {
    final client = _availableClient;
    if (client == null) return <HeritagePlace>[];
    final rows = await client
        .from('heritage_locations')
        .select()
        .eq('is_active', true)
        .order('name')
        .limit(1000);
    return _mergePlaces(
      rows
          .map(
            (row) => _fromRow(Map<String, dynamic>.from(row), 3.1390, 101.6869),
          )
          .toList(growable: false),
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
    final longitudeDelta =
        radiusKm /
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
    final candidates = rows
        .map(
          (row) =>
              _fromRow(Map<String, dynamic>.from(row), latitude, longitude),
        )
        .where((place) => place.distanceKm <= radiusKm)
        .toList();
    final places = _mergePlaces(candidates);
    places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return places;
  }

  List<HeritagePlace> _mergePlaces(Iterable<HeritagePlace> values) {
    final unique = <String, HeritagePlace>{};
    for (final place in values) {
      final nameKey = place.name.trim().toLowerCase();
      final coordinateKey =
          '${place.latitude.toStringAsFixed(4)}|'
          '${place.longitude.toStringAsFixed(4)}';
      final key = nameKey.isEmpty ? coordinateKey : nameKey;
      final current = unique[key];
      if (current == null ||
          place.description.length > current.description.length) {
        unique[key] = place;
      }
    }
    return unique.values.toList();
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
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(latitude * math.pi / 180) *
            math.cos(placeLatitude * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final distance =
        earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
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
