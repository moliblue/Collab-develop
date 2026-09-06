import 'dart:math' as math;

import '../../Models/app_models.dart';

/// Cleans catalogue/OSM records before they reach Discover, Map, or Plan.
class HeritageLocationNormalizer {
  static const _countryOnlyValues = <String>{
    'malaysia',
    'my',
    'malaysia, malaysia',
  };

  static String clean(Object? value) => '${value ?? ''}'
      .replaceAll('\u0000', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String stateFor(Map<String, dynamic> row, Map<String, String> tags) {
    final candidates = <String>[
      clean(row['state']),
      clean(tags['addr:state']),
      clean(tags['is_in:state']),
      clean(tags['addr:province']),
    ];
    final address = clean(row['address']).toLowerCase();
    for (final state in malaysiaStates) {
      if (address.contains(state.toLowerCase())) candidates.add(state);
    }
    for (final candidate in candidates) {
      if (candidate.isNotEmpty &&
          !_countryOnlyValues.contains(candidate.toLowerCase())) {
        return candidate;
      }
    }
    return '';
  }

  static String addressFor(
    Map<String, dynamic> row,
    Map<String, String> tags, {
    required String name,
    required String state,
  }) {
    final stored = clean(row['address']);
    if (stored.isNotEmpty &&
        !_countryOnlyValues.contains(stored.toLowerCase())) {
      return stored;
    }
    final parts = <String>[
      clean(tags['addr:housenumber']),
      clean(tags['addr:street']),
      clean(tags['addr:place']),
      clean(tags['addr:suburb']),
      clean(tags['addr:city'] ?? tags['addr:town']),
      state,
      clean(tags['addr:postcode']),
      'Malaysia',
    ].where((part) => part.isNotEmpty).toList();
    final unique = <String>[];
    for (final part in parts) {
      if (!unique.any((value) => value.toLowerCase() == part.toLowerCase())) {
        unique.add(part);
      }
    }
    // A searchable fallback is preferable to an empty address for map-photo
    // providers. The coordinates remain the routing source of truth.
    if (unique.length == 1) return '$name, Malaysia';
    return unique.join(', ');
  }

  static List<HeritagePlace> deduplicate(Iterable<HeritagePlace> places) {
    final result = <HeritagePlace>[];
    for (final candidate in places) {
      final index = result.indexWhere(
        (current) =>
            _nameKey(current.name) == _nameKey(candidate.name) &&
            _distanceMetres(current, candidate) <= 150,
      );
      if (index < 0) {
        result.add(candidate);
      } else {
        result[index] = _merge(result[index], candidate);
      }
    }
    return result;
  }

  static String _nameKey(String value) => value
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');

  static int _quality(HeritagePlace place) =>
      (place.address.isNotEmpty ? 4 : 0) +
      (place.state.isNotEmpty ? 3 : 0) +
      (place.image.isNotEmpty ? 3 : 0) +
      (place.description.isNotEmpty ? 2 : 0) +
      place.osmTags.length.clamp(0, 4);

  static HeritagePlace _merge(HeritagePlace current, HeritagePlace candidate) {
    final primary = _quality(candidate) > _quality(current)
        ? candidate
        : current;
    final secondary = identical(primary, current) ? candidate : current;
    // Preserve a Supabase/OSM identity so bookmarks and reviews continue to
    // reference a real catalogue row, while filling its missing presentation
    // fields from the existing curated card.
    final currentIsCatalogue = current.osmId?.isNotEmpty == true;
    final candidateIsCatalogue = candidate.osmId?.isNotEmpty == true;
    final identity = currentIsCatalogue && candidateIsCatalogue
        ? primary
        : currentIsCatalogue
        ? current
        : candidateIsCatalogue
        ? candidate
        : primary;
    String best(String a, String b) => a.trim().isNotEmpty ? a : b;
    return HeritagePlace(
      id: identity.id,
      osmId: identity.osmId,
      osmType: identity.osmType,
      osmNumericId: identity.osmNumericId,
      osmTags: current.osmTags.isNotEmpty ? current.osmTags : candidate.osmTags,
      name: primary.name,
      category: primary.category,
      state: best(primary.state, secondary.state),
      shortDescription: best(
        primary.shortDescription,
        secondary.shortDescription,
      ),
      description: best(primary.description, secondary.description),
      image: best(primary.image, secondary.image),
      distanceKm: identity.distanceKm,
      rating: math.max(current.rating, candidate.rating),
      reviewsCount: math.max(current.reviewsCount, candidate.reviewsCount),
      latitude: identity.latitude,
      longitude: identity.longitude,
      address: best(primary.address, secondary.address),
      hours: best(primary.hours, secondary.hours),
      bookmarked: current.bookmarked || candidate.bookmarked,
      reviews: current.reviews.isNotEmpty ? current.reviews : candidate.reviews,
    );
  }

  static double _distanceMetres(HeritagePlace a, HeritagePlace b) {
    const radius = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final value =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radius * 2 * math.atan2(math.sqrt(value), math.sqrt(1 - value));
  }

  static const malaysiaStates = <String>[
    'Johor',
    'Kedah',
    'Kelantan',
    'Melaka',
    'Negeri Sembilan',
    'Pahang',
    'Penang',
    'Perak',
    'Perlis',
    'Sabah',
    'Sarawak',
    'Selangor',
    'Terengganu',
    'Kuala Lumpur',
    'Labuan',
    'Putrajaya',
  ];
}
