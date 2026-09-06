import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:findit_my/data_layer/Models/app_models.dart';
import 'package:findit_my/data_layer/Repositories/discovery_repository.dart';
import 'package:findit_my/ui_layer/View/discover_module_view.dart';
import 'package:findit_my/ui_layer/ViewModel/discovery_view_model.dart';

void main() {
  test('destination image selection respects cover and legacy fallback', () {
    final place = HeritagePlace(
      id: 'a',
      name: 'Alpha House',
      category: 'Traditional Heritage Site',
      state: 'Penang',
      shortDescription: 'Address',
      description: 'Description',
      image: 'legacy.jpg',
      distanceKm: 0,
      rating: 0,
      reviewsCount: 0,
      latitude: 5.4,
      longitude: 100.3,
      address: 'Address',
      hours: '',
      images: const <DestinationImage>[
        DestinationImage(
          id: 'two',
          imageUrl: 'two.jpg',
          isCover: true,
          displayOrder: 2,
        ),
        DestinationImage(
          id: 'one',
          imageUrl: 'one.jpg',
          isCover: false,
          displayOrder: 1,
        ),
        DestinationImage(
          id: 'three',
          imageUrl: 'three.jpg',
          isCover: false,
          displayOrder: 3,
        ),
      ],
    );

    expect(place.coverImageUrl, 'two.jpg');
    expect(place.detailImageUrls, <String>['one.jpg', 'two.jpg', 'three.jpg']);
    expect(place.coverImageIndex, 1);

    final legacyOnly = _FakeDiscoveryRepository()._place(
      'legacy',
      'Legacy',
      'Traditional Heritage Site',
      image: 'legacy.jpg',
    );
    expect(legacyOnly.coverImageUrl, 'legacy.jpg');
    expect(legacyOnly.detailImageUrls, <String>['legacy.jpg']);

    final noImage = _FakeDiscoveryRepository()._place(
      'placeholder',
      'Placeholder Place',
      'Museum',
      image: '',
    );
    expect(noImage.coverImageUrl, isEmpty);
    expect(noImage.detailImageUrls, isEmpty);

    final singleImage = HeritagePlace(
      id: 'single',
      name: 'Single Image Place',
      category: 'Museum',
      state: 'Kuala Lumpur',
      shortDescription: '',
      description: '',
      image: 'legacy.jpg',
      distanceKm: 0,
      rating: 0,
      reviewsCount: 0,
      latitude: 3.1,
      longitude: 101.7,
      address: '',
      hours: '',
      images: const <DestinationImage>[
        DestinationImage(
          id: 'cover',
          imageUrl: 'cover.jpg',
          isCover: true,
          displayOrder: 1,
        ),
      ],
    );
    expect(singleImage.coverImageUrl, 'cover.jpg');
    expect(singleImage.detailImageUrls, <String>['cover.jpg']);
  });

  test('Discovery place formats cached details and native share text', () {
    final place = HeritagePlace(
      id: 'petrosains',
      name: 'Petrosains',
      category: 'Museum',
      state: 'Kuala Lumpur',
      shortDescription: '',
      description: 'Science discovery centre.',
      image: '',
      distanceKm: 0,
      rating: 0,
      reviewsCount: 0,
      latitude: 3.1579,
      longitude: 101.7116,
      address: 'Jalan Ampang',
      hours: '',
      formattedAddress: 'Jalan Ampang, Kuala Lumpur, Malaysia, Malaysia',
      googleMapsUri: 'https://maps.google.com/?cid=petrosains',
      openingHoursWeekdayText: const <String>[
        'Monday: 9:00 AM – 5:30 PM',
        'Tuesday: Closed',
      ],
    );

    expect(place.displayAddress, 'Jalan Ampang, Kuala Lumpur, Malaysia');
    expect(place.openingHoursForDay(DateTime.monday), '9:00 AM – 5:30 PM');
    expect(place.openingHoursForDay(DateTime.tuesday), 'Closed');
    expect(
      place.discoveryShareText,
      contains('Discover Petrosains in Kuala Lumpur.'),
    );
    expect(place.discoveryShareText, contains(place.displayAddress));
    expect(place.discoveryShareText, endsWith(place.googleMapsUri!));
  });

  group('DiscoveryViewModel', () {
    testWidgets('detail hero pages through three destination images', (
      tester,
    ) async {
      final repository = _FakeDiscoveryRepository()
        ..destinationImages = <DestinationImage>[
          DestinationImage(
            id: 'one',
            imageUrl: 'assets/petaling_street.png',
            isCover: true,
            displayOrder: 1,
            source: 'google_places',
            photographerName: 'Test Photographer',
            sourcePageUrl: 'https://maps.google.com/',
            refreshAfter: DateTime(2026, 9, 6, 12),
          ),
          DestinationImage(
            id: 'two',
            imageUrl: 'assets/batu_caves.png',
            isCover: false,
            displayOrder: 2,
          ),
          DestinationImage(
            id: 'three',
            imageUrl: 'assets/blue_mansion.png',
            isCover: false,
            displayOrder: 3,
          ),
        ];
      final vm = DiscoveryViewModel(repository: repository);
      await vm.load();
      await vm.select(vm.places.first);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscoverModuleView(
              viewModel: vm,
              onDirections: (_) {},
              onAddToPlan: (_) {},
              notify: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('destination_image_carousel')), findsOne);
      expect(
        find.text('Google Maps · Photo by Test Photographer'),
        findsOneWidget,
      );
      expect(find.text('View on Google Maps'), findsOneWidget);
      expect(find.byKey(const Key('destination_image_indicator_0')), findsOne);
      expect(find.byKey(const Key('destination_image_indicator_2')), findsOne);
      expect(
        tester
            .getSize(find.byKey(const Key('destination_image_indicator_0')))
            .width,
        24,
      );
      await tester.fling(
        find.byKey(const Key('destination_image_carousel')),
        const Offset(-600, 0),
        1200,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const Key('destination_image_indicator_1')))
            .width,
        24,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('single destination image renders without pagination dots', (
      tester,
    ) async {
      final repository = _FakeDiscoveryRepository()
        ..destinationImages = const <DestinationImage>[
          DestinationImage(
            id: 'only',
            imageUrl: 'assets/petaling_street.png',
            isCover: true,
            displayOrder: 1,
          ),
        ];
      final vm = DiscoveryViewModel(repository: repository);
      await vm.load();
      await vm.select(vm.places.first);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscoverModuleView(
              viewModel: vm,
              onDirections: (_) {},
              onAddToPlan: (_) {},
              notify: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('destination_image_carousel')), findsOne);
      expect(
        find.byKey(const Key('destination_image_indicator_0')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing destination image uses a category placeholder', (
      tester,
    ) async {
      final repository = _FakeDiscoveryRepository()
        ..customPlaces = <HeritagePlace>[
          _FakeDiscoveryRepository()._place(
            'museum-without-photo',
            'Museum Without Photo',
            'Museum',
          ),
        ];
      final vm = DiscoveryViewModel(repository: repository);
      await vm.load();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscoverModuleView(
              viewModel: vm,
              onDirections: (_) {},
              onAddToPlan: (_) {},
              notify: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('discovery_category_placeholder_museum')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('detail renders cached hours and expands the weekly schedule', (
      tester,
    ) async {
      final repository = _FakeDiscoveryRepository()
        ..customPlaces = <HeritagePlace>[
          HeritagePlace(
            id: 'hours',
            name: 'Hours Museum',
            category: 'Museum',
            state: 'Kuala Lumpur',
            shortDescription: '',
            description: 'Description',
            image: '',
            distanceKm: 0,
            rating: 0,
            reviewsCount: 0,
            latitude: 3.1,
            longitude: 101.7,
            address: '',
            hours: '',
            formattedAddress: 'Jalan Museum, Kuala Lumpur, Malaysia',
            openingHoursWeekdayText: const <String>[
              'Monday: 9:00 AM – 5:30 PM',
              'Tuesday: 9:00 AM – 5:30 PM',
              'Wednesday: 9:00 AM – 5:30 PM',
              'Thursday: 9:00 AM – 5:30 PM',
              'Friday: 9:00 AM – 5:30 PM',
              'Saturday: 9:00 AM – 5:30 PM',
              'Sunday: 9:00 AM – 5:30 PM',
            ],
          ),
        ];
      final vm = DiscoveryViewModel(repository: repository);
      await vm.load();
      await vm.select(vm.places.single);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscoverModuleView(
              viewModel: vm,
              onDirections: (_) {},
              onAddToPlan: (_) {},
              notify: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Open today'), findsOneWidget);
      expect(find.text('Jalan Museum, Kuala Lumpur, Malaysia'), findsOneWidget);
      expect(find.text('View full hours'), findsOneWidget);
      await tester.tap(find.text('View full hours'));
      await tester.pump();
      expect(find.text('Monday: 9:00 AM – 5:30 PM'), findsOneWidget);
      expect(find.text('Hide full hours'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('main Discovery list shows scroll-to-top after 600 pixels', (
      tester,
    ) async {
      final repository = _FakeDiscoveryRepository()..generatedPlaceCount = 12;
      final vm = DiscoveryViewModel(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscoverModuleView(
              viewModel: vm,
              onDirections: (_) {},
              onAddToPlan: (_) {},
              notify: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('discover_scroll_to_top')), findsNothing);
      await tester.drag(
        find.byKey(const PageStorageKey<String>('discover-list')),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('discover_scroll_to_top')), findsOneWidget);

      await tester.tap(find.byKey(const Key('discover_scroll_to_top')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('discover_scroll_to_top')), findsNothing);
      expect(tester.takeException(), isNull);
    });

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

        vm.toggleCategory('Cultural Heritage');
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
  int generatedPlaceCount = 0;
  final Set<String> bookmarks = <String>{};
  final Map<String, List<Review>> reviews = <String, List<Review>>{};
  List<DestinationImage> destinationImages = const <DestinationImage>[];
  List<HeritagePlace>? customPlaces;

  @override
  Future<List<DestinationImage>> getDestinationImages(
    String destinationId,
  ) async => destinationImages;

  @override
  Future<List<HeritagePlace>> getDestinations() async {
    loadCalls++;
    if (customPlaces != null) return List<HeritagePlace>.from(customPlaces!);
    if (generatedPlaceCount > 0) {
      return List<HeritagePlace>.generate(
        generatedPlaceCount,
        (index) => _place(
          'place-$index',
          'Place ${index.toString().padLeft(2, '0')}',
          'Traditional Heritage Site',
        ),
      );
    }
    return <HeritagePlace>[
      _place('z', 'Zulu Craft', 'Cultural Heritage'),
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

  HeritagePlace _place(
    String id,
    String name,
    String category, {
    String image = '',
  }) => HeritagePlace(
    id: id,
    name: name,
    category: category,
    state: 'Penang',
    shortDescription: 'Address',
    description: 'Description',
    image: image,
    distanceKm: 0,
    rating: 0,
    reviewsCount: 0,
    latitude: 5.4,
    longitude: 100.3,
    address: 'Address',
    hours: '',
  );
}
