import 'package:supabase_flutter/supabase_flutter.dart';

import '../Models/app_models.dart';
import '../Service Managers/Remote Services/heritage_location_normalizer.dart';

abstract class DiscoveryRepository {
  Future<List<HeritagePlace>> getDestinations();
  Future<List<DestinationImage>> getDestinationImages(String destinationId);
  Future<Set<String>> getBookmarkIds();
  Future<void> addBookmark(HeritagePlace place);
  Future<void> removeBookmark(String destinationId);
  Future<List<Review>> getReviews(String destinationId);
  Future<void> addReview(String destinationId, int rating, String? text);
}

class SupabaseDiscoveryRepository implements DiscoveryRepository {
  SupabaseDiscoveryRepository({this.clientOverride});
  final SupabaseClient? clientOverride;

  SupabaseClient get client => clientOverride ?? Supabase.instance.client;
  String get userId {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Authentication is required.');
    return id;
  }

  @override
  Future<List<HeritagePlace>> getDestinations() async {
    final rows = await client
        .from('displayable_heritage_locations')
        .select()
        .eq('is_active', true)
        .eq('is_verified', true)
        .order('name');
    final reviewRows = await client
        .from('destination_reviews')
        .select('destination_id,rating');
    final ratingTotals = <String, int>{};
    final ratingCounts = <String, int>{};
    for (final raw in reviewRows) {
      final row = Map<String, dynamic>.from(raw);
      final destinationId = '${row['destination_id']}'.trim();
      final rating = (row['rating'] as num?)?.toInt();
      if (destinationId.isEmpty || rating == null) continue;
      ratingTotals.update(
        destinationId,
        (value) => value + rating,
        ifAbsent: () => rating,
      );
      ratingCounts.update(
        destinationId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    List<dynamic> coverRows = const <dynamic>[];
    try {
      coverRows = await client
          .from('destination_image_covers')
          .select(
            'id,destination_id,image_url,source,source_image_id,'
            'photographer_name,photographer_url,is_cover,display_order,'
            'match_status,license_name,license_url,source_page_url,'
            'refresh_after',
          );
    } on PostgrestException catch (error) {
      if (_isMissingImageMetadata(error)) {
        coverRows = await client
            .from('destination_image_covers')
            .select(
              'id,destination_id,image_url,source,source_image_id,'
              'photographer_name,photographer_url,is_cover,display_order',
            );
      } else {
        rethrow;
      }
    }
    final covers = <String, DestinationImage>{};
    for (final raw in coverRows) {
      final row = Map<String, dynamic>.from(raw as Map);
      covers['${row['destination_id']}'] = _destinationImage(row);
    }
    final unique = <String, HeritagePlace>{};
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      final id = '${row['osm_id']}'.trim();
      final name = '${row['name']}'.trim();
      final lat = (row['latitude'] as num?)?.toDouble();
      final lng = (row['longitude'] as num?)?.toDouble();
      if (id.isEmpty || name.isEmpty || lat == null || lng == null) continue;
      final sourceCategory = HeritageLocationNormalizer.clean(row['category']);
      final tags = Map<String, String>.from(
        row['osm_tags'] as Map? ?? const {},
      );
      final state = HeritageLocationNormalizer.stateFor(row, tags);
      final rawFormattedAddress = HeritageLocationNormalizer.clean(
        row['formatted_address'],
      );
      final address = rawFormattedAddress.isNotEmpty
          ? rawFormattedAddress
          : HeritageLocationNormalizer.addressFor(
              row,
              tags,
              name: name,
              state: state,
            );
      unique[id] = HeritagePlace(
        id: id,
        osmId: id,
        name: name,
        category: sourceCategory,
        state: state,
        shortDescription: address,
        description: '${row['description'] ?? ''}'.trim(),
        image: '${row['cover_image_url'] ?? row['image_url'] ?? ''}'.trim(),
        distanceKm: 0,
        rating: ratingCounts[id] == null
            ? 0
            : ratingTotals[id]! / ratingCounts[id]!,
        reviewsCount: ratingCounts[id] ?? 0,
        latitude: lat,
        longitude: lng,
        address: address,
        hours: '${row['opening_hours'] ?? ''}'.trim(),
        osmTags: tags,
        googlePlaceId: row['google_place_id']?.toString(),
        googlePlaceName: row['google_place_name']?.toString(),
        googleMatchStatus: row['google_match_status']?.toString(),
        formattedAddress: rawFormattedAddress.isEmpty
            ? null
            : rawFormattedAddress,
        openingHoursWeekdayText:
            (row['opening_hours_weekday_text'] as List? ?? const <dynamic>[])
                .map((value) => '$value'.trim())
                .where((value) => value.isNotEmpty)
                .toList(growable: false),
        openingHoursPeriods: row['opening_hours_periods'] is Map
            ? Map<String, dynamic>.from(row['opening_hours_periods'] as Map)
            : null,
        openingHoursUpdatedAt: DateTime.tryParse(
          '${row['opening_hours_updated_at'] ?? ''}',
        ),
        googleMapsUri: row['google_maps_uri']?.toString(),
        images: covers[id] == null
            ? const <DestinationImage>[]
            : <DestinationImage>[covers[id]!],
      );
    }
    return unique.values.toList()..sort(compareHeritagePlacesForListing);
  }

  @override
  Future<List<DestinationImage>> getDestinationImages(
    String destinationId,
  ) async {
    try {
      final rows = await client
          .from('destination_images')
          .select(
            'id,image_url,source,source_image_id,photographer_name,'
            'photographer_url,is_cover,display_order,match_status,'
            'license_name,license_url,source_page_url,refresh_after',
          )
          .eq('destination_id', destinationId)
          .order('display_order')
          .limit(3);
      return rows
          .map((raw) => _destinationImage(Map<String, dynamic>.from(raw)))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      if (error.code == '42703') {
        final rows = await client
            .from('destination_images')
            .select(
              'id,image_url,source,source_image_id,photographer_name,'
              'photographer_url,is_cover,display_order,match_status',
            )
            .eq('destination_id', destinationId)
            .order('display_order')
            .limit(3);
        return rows
            .map((raw) => _destinationImage(Map<String, dynamic>.from(raw)))
            .toList(growable: false);
      }
      if (error.code == '42P01' || error.code == 'PGRST205') {
        return const <DestinationImage>[];
      }
      rethrow;
    }
  }

  DestinationImage _destinationImage(Map<String, dynamic> row) =>
      DestinationImage(
        id: '${row['id']}',
        imageUrl: '${row['image_url'] ?? ''}'.trim(),
        source: '${row['source'] ?? 'pexels'}',
        sourceImageId: row['source_image_id']?.toString(),
        photographerName: row['photographer_name']?.toString(),
        photographerUrl: row['photographer_url']?.toString(),
        matchStatus: '${row['match_status'] ?? 'fallback'}',
        licenseName: row['license_name']?.toString(),
        licenseUrl: row['license_url']?.toString(),
        sourcePageUrl: row['source_page_url']?.toString(),
        refreshAfter: DateTime.tryParse('${row['refresh_after'] ?? ''}'),
        isCover: row['is_cover'] == true,
        displayOrder: (row['display_order'] as num?)?.toInt() ?? 1,
      );

  bool _isMissingImageMetadata(PostgrestException error) =>
      error.code == '42703' ||
      error.code == '42P01' ||
      error.code == 'PGRST205';

  @override
  Future<Set<String>> getBookmarkIds() async {
    final rows = await client
        .from('bookmarks')
        .select('destination_id')
        .eq('user_id', userId);
    return rows.map((row) => '${row['destination_id']}').toSet();
  }

  @override
  Future<void> addBookmark(HeritagePlace place) async {
    await client.from('bookmarks').upsert({
      'user_id': userId,
      'destination_id': place.id,
      'destination_name': place.name,
      'destination_category': place.category,
      'destination_latitude': place.latitude,
      'destination_longitude': place.longitude,
      'destination_photo_url': place.coverImageUrl,
    }, onConflict: 'user_id,destination_id');
  }

  @override
  Future<void> removeBookmark(String destinationId) => client
      .from('bookmarks')
      .delete()
      .eq('user_id', userId)
      .eq('destination_id', destinationId);

  @override
  Future<List<Review>> getReviews(String destinationId) async {
    final rows = await client
        .from('destination_reviews')
        .select('user_id,rating,review_text,created_at')
        .eq('destination_id', destinationId)
        .order('created_at', ascending: false);
    final userIds = rows.map((r) => '${r['user_id']}').toSet().toList();
    final names = <String, String>{};
    if (userIds.isNotEmpty) {
      final profiles = await client
          .from('profiles')
          .select('id,username')
          .inFilter('id', userIds);
      for (final p in profiles) {
        names['${p['id']}'] = '${p['username']}';
      }
    }
    return rows.map((row) {
      final created = DateTime.tryParse('${row['created_at']}')?.toLocal();
      final date = created == null
          ? ''
          : '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';
      return Review(
        name: names['${row['user_id']}'] ?? 'Traveller',
        date: date,
        rating: (row['rating'] as num).toInt(),
        comment: '${row['review_text'] ?? ''}',
      );
    }).toList();
  }

  @override
  Future<void> addReview(String destinationId, int rating, String? text) =>
      client.from('destination_reviews').insert({
        'user_id': userId,
        'destination_id': destinationId,
        'rating': rating,
        'review_text': text?.trim().isEmpty ?? true ? null : text!.trim(),
      });
}
