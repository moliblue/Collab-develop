import 'package:flutter_test/flutter_test.dart';
import 'package:findit_my/data_layer/Models/app_models.dart';
import 'package:findit_my/data_layer/Repositories/discovery_repository.dart';
import 'package:findit_my/ui_layer/ViewModel/discovery_view_model.dart';

void main() {
  group('DiscoveryViewModel', () {
    test(
      'loads once, sorts A-Z, and combines name search with category',
      () async {
        final repository = _FakeDiscoveryRepository();
        final vm = DiscoveryViewModel(repository: repository);
        await vm.load();
        expect(vm.filteredPlaces.map((p) => p.name), <String>[
          'Alpha House',
          'Zulu Craft',
        ]);
        expect(repository.loadCalls, 1);

        vm.toggleCategory('Heritage Workshops');
        vm.setQuery('zULu');
        expect(vm.filteredPlaces.single.name, 'Zulu Craft');
        vm.setQuery('missing');
        expect(vm.filteredPlaces, isEmpty);
        vm.clearFilters();
        expect(vm.query, 'missing');
      },
    );

    test('bookmark persists and duplicate UI toggles remove it', () async {
      final repository = _FakeDiscoveryRepository();
      final vm = DiscoveryViewModel(repository: repository);
      await vm.load();
      final place = vm.places.first;
      expect(await vm.toggleBookmark(place), isTrue);
      expect(repository.bookmarks, contains(place.id));
      expect(await vm.toggleBookmark(place), isFalse);
      expect(repository.bookmarks, isNot(contains(place.id)));
    });

    test(
      'review requires a valid rating and refreshes persisted aggregate',
      () async {
        final repository = _FakeDiscoveryRepository();
        final vm = DiscoveryViewModel(repository: repository);
        await vm.load();
        final place = vm.places.first;
        expect(
          await vm.addReview(place, 0, ''),
          'Error: Please provide a valid rating before submitting your review.',
        );
        expect(repository.reviewWrites, 0);
        expect(await vm.addReview(place, 5, ''), isNull);
        expect(place.rating, 5);
        expect(place.reviewsCount, 1);
      },
    );
  });
}

class _FakeDiscoveryRepository implements DiscoveryRepository {
  int loadCalls = 0;
  int reviewWrites = 0;
  final Set<String> bookmarks = <String>{};
  final Map<String, List<Review>> reviews = <String, List<Review>>{};

  @override
  Future<List<HeritagePlace>> getDestinations() async {
    loadCalls++;
    return <HeritagePlace>[
      _place('z', 'Zulu Craft', 'Heritage Workshops'),
      _place('a', 'Alpha House', 'Traditional Heritage Site'),
    ];
  }

  @override
  Future<Set<String>> getBookmarkIds() async => Set<String>.from(bookmarks);
  @override
  Future<void> addBookmark(HeritagePlace place) async =>
      bookmarks.add(place.id);
  @override
  Future<void> removeBookmark(String destinationId) async =>
      bookmarks.remove(destinationId);
  @override
  Future<List<Review>> getReviews(String destinationId) async =>
      List<Review>.from(reviews[destinationId] ?? const <Review>[]);
  @override
  Future<void> addReview(String destinationId, int rating, String? text) async {
    reviewWrites++;
    reviews
        .putIfAbsent(destinationId, () => <Review>[])
        .add(
          Review(
            name: 'Test',
            date: '2026-09-06',
            rating: rating,
            comment: text ?? '',
          ),
        );
  }

  HeritagePlace _place(String id, String name, String category) =>
      HeritagePlace(
        id: id,
        name: name,
        category: category,
        state: 'Penang',
        shortDescription: 'Address',
        description: 'Description',
        image: '',
        distanceKm: 0,
        rating: 0,
        reviewsCount: 0,
        latitude: 5.4,
        longitude: 100.3,
        address: 'Address',
        hours: '',
      );
}
