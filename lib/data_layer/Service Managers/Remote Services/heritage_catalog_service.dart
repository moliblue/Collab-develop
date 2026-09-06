import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../Models/app_models.dart';
import 'heritage_location_normalizer.dart';

/// Reads the curated, Google-matched catalogue used by Map and Plan.
class HeritageCatalogService {
  HeritageCatalogService({this.client});

  final SupabaseClient? client;

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
    return _fetchCatalogue(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
  }

  /// Returns every active verified Supabase catalogue record. Discover and
  /// Plan merge these with their existing built-in places, so catalogue growth
  /// never removes the locations already available in the app.
  Future<List<HeritagePlace>> fetchCatalogue() async {
    final client = _availableClient;
    if (client == null) return <HeritagePlace>[];
    final rows = await client
        .from('displayable_heritage_locations')
        .select()
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
        .from('displayable_heritage_locations')
        .select()
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
    return HeritageLocationNormalizer.deduplicate(values);
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
    final osmId = HeritageLocationNormalizer.clean(row['osm_id']);
    final tags = Map<String, String>.from(row['osm_tags'] as Map? ?? const {});
    final name = HeritageLocationNormalizer.clean(row['name']);
    final state = HeritageLocationNormalizer.stateFor(row, tags);
    final address = HeritageLocationNormalizer.addressFor(
      row,
      tags,
      name: name,
      state: state,
    );
    return HeritagePlace(
      id: osmId,
      osmId: osmId,
      name: name,
      category: '${row['category']}',
      state: state,
      shortDescription: '${row['category']}',
      description: '${row['description'] ?? ''}',
      image: '${row['cover_image_url'] ?? row['image_url'] ?? ''}',
      distanceKm: distance,
      rating: 0,
      reviewsCount: 0,
      latitude: placeLatitude,
      longitude: placeLongitude,
      address: address,
      hours: '${row['opening_hours'] ?? ''}',
      osmTags: tags,
      googleRating: (row['google_rating'] as num?)?.toDouble(),
      googleUserRatingCount: (row['google_user_rating_count'] as num?)?.toInt(),
    );
  }
}
