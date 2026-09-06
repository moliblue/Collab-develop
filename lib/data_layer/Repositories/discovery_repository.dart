import 'package:supabase_flutter/supabase_flutter.dart';

import '../Models/app_models.dart';
import '../Models/mock_data.dart';
import '../Service Managers/Remote Services/heritage_location_normalizer.dart';

abstract class DiscoveryRepository {
  Future<List<HeritagePlace>> getDestinations();
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
        .from('heritage_locations')
        .select()
        .eq('is_active', true)
        .eq('is_verified', true)
        .order('name');
    final candidates = <HeritagePlace>[];
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
      final isWorkshop = <String>[sourceCategory, ...tags.keys, ...tags.values]
          .any((value) {
            final v = value.toLowerCase();
            return v.contains('workshop') ||
                v.contains('craft') ||
                v.contains('artisan');
          });
      final state = HeritageLocationNormalizer.stateFor(row, tags);
      final address = HeritageLocationNormalizer.addressFor(
        row,
        tags,
        name: name,
        state: state,
      );
      candidates.add(
        HeritagePlace(
          id: id,
          osmId: id,
          name: name,
          category: isWorkshop
              ? 'Heritage Workshops'
              : 'Traditional Heritage Site',
          state: state,
          shortDescription: address,
          description: '${row['description'] ?? ''}'.trim(),
          image: '${row['image_url'] ?? ''}'.trim(),
          distanceKm: 0,
          rating: 0,
          reviewsCount: 0,
          latitude: lat,
          longitude: lng,
          address: address,
          hours: '${row['opening_hours'] ?? ''}'.trim(),
          osmTags: tags,
        ),
      );
    }
    // Keep the original curated cards and their local images. Supabase records
    // remain authoritative when they describe the same nearby place.
    candidates.addAll(createPlaces());
    return HeritageLocationNormalizer.deduplicate(candidates)
      ..sort((a, b) => a.name.compareTo(b.name));
  }

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
      'destination_photo_url': place.image,
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
