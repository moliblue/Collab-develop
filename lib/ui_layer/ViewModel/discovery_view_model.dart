import 'package:flutter/foundation.dart';

import '../../data_layer/Models/app_models.dart';
import '../../data_layer/Repositories/discovery_repository.dart';

enum DiscoverSection { discover, bookmarks }

class DiscoveryViewModel extends ChangeNotifier {
  DiscoveryViewModel({DiscoveryRepository? repository})
    : _repository = repository ?? SupabaseDiscoveryRepository();
  final DiscoveryRepository _repository;
  final List<HeritagePlace> _places = <HeritagePlace>[];
  DiscoverSection _section = DiscoverSection.discover;
  HeritagePlace? _selected;
  String _query = '';
  final Set<String> _states = <String>{};
  final Set<String> _categories = <String>{};
  bool _filtersOpen = false;
  bool _loading = false;
  bool _loaded = false;
  bool _detailsLoading = false;
  bool _reviewSubmitting = false;
  String? _loadError;
  String? _actionError;

  List<HeritagePlace> get places => List<HeritagePlace>.unmodifiable(_places);
  DiscoverSection get section => _section;
  HeritagePlace? get selected => _selected;
  String get query => _query;
  Set<String> get states => Set<String>.unmodifiable(_states);
  Set<String> get categories => Set<String>.unmodifiable(_categories);
  bool get filtersOpen => _filtersOpen;
  bool get loading => _loading;
  bool get detailsLoading => _detailsLoading;
  bool get reviewSubmitting => _reviewSubmitting;
  String? get loadError => _loadError;
  // Compatibility surface used by the latest shared AppViewModel/Discover UI.
  // It delegates to the single repository-backed loading state below.
  bool get catalogueLoading => _loading;
  String? get catalogueIssue => _loadError;
  List<String> get availableStates =>
      (_places
          .map((place) => place.state)
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort());
  List<String> get availableCategories =>
      (_places
          .map((place) => place.category)
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort());
  String? takeActionError() {
    final value = _actionError;
    _actionError = null;
    return value;
  }

  List<HeritagePlace> get bookmarks =>
      _places.where((HeritagePlace p) => p.bookmarked).toList();
  List<HeritagePlace> get filteredPlaces {
    final q = _query.trim().toLowerCase();
    return _places.where((HeritagePlace p) {
        final textMatches = q.isEmpty || p.name.toLowerCase().contains(q);
        return textMatches &&
            (_states.isEmpty || _states.contains(p.state)) &&
            (_categories.isEmpty || _categories.contains(p.category));
      }).toList()
      ..sort((HeritagePlace a, HeritagePlace b) => a.name.compareTo(b.name));
  }

  void setSection(DiscoverSection value) {
    _section = value;
    _selected = null;
    notifyListeners();
  }

  Future<void> load({bool force = false}) async {
    if (_loading || (_loaded && !force)) return;
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      final places = await _repository.getDestinations();
      _places
        ..clear()
        ..addAll(places);
      try {
        final bookmarked = await _repository.getBookmarkIds();
        for (final place in _places) {
          place.bookmarked = bookmarked.contains(place.id);
        }
      } catch (_) {
        // The catalogue remains readable while the pending UC201 persistence
        // migration has not yet been approved/deployed.
      }
      _loaded = true;
    } catch (_) {
      _loadError = 'Unable to load locations. Please try again.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadHeritageCatalogue() => load();

  Future<void> select(HeritagePlace? value) async {
    _selected = value;
    notifyListeners();
    if (value == null) return;
    _detailsLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait<dynamic>([
        _repository.getDestinationImages(value.id),
        _repository.getReviews(value.id),
      ]);
      final images = results[0] as List<DestinationImage>;
      final reviews = results[1] as List<Review>;
      value.images
        ..clear()
        ..addAll(images);
      value.reviews
        ..clear()
        ..addAll(reviews);
      value.reviewsCount = reviews.length;
      value.rating = reviews.isEmpty
          ? 0
          : reviews.fold<int>(0, (sum, r) => sum + r.rating) / reviews.length;
    } catch (_) {
      _actionError = 'Unable to load reviews. Please try again.';
    } finally {
      _detailsLoading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void toggleFilters() {
    _filtersOpen = !_filtersOpen;
    notifyListeners();
  }

  void closeFilters() {
    _filtersOpen = false;
    notifyListeners();
  }

  void clearFilters() {
    _states.clear();
    _categories.clear();
    notifyListeners();
  }

  void toggleState(String value) {
    _states.contains(value) ? _states.remove(value) : _states.add(value);
    notifyListeners();
  }

  void toggleCategory(String value) {
    _categories.contains(value)
        ? _categories.remove(value)
        : _categories.add(value);
    notifyListeners();
  }

  Future<bool?> toggleBookmark(HeritagePlace place) async {
    final target = !place.bookmarked;
    try {
      if (target) {
        await _repository.addBookmark(place);
      } else {
        await _repository.removeBookmark(place.id);
      }
      place.bookmarked = target;
      notifyListeners();
      return target;
    } catch (_) {
      _actionError = 'Unable to update bookmark. Please try again.';
      notifyListeners();
      return null;
    }
  }

  Future<String?> addReview(
    HeritagePlace place,
    int rating,
    String comment,
  ) async {
    if (rating < 1 || rating > 5) {
      return 'Error: Please provide a valid rating before submitting your review.';
    }
    _reviewSubmitting = true;
    notifyListeners();
    try {
      await _repository.addReview(place.id, rating, comment);
      final reviews = await _repository.getReviews(place.id);
      place.reviews
        ..clear()
        ..addAll(reviews);
      place.reviewsCount = reviews.length;
      place.rating =
          reviews.fold<int>(0, (sum, r) => sum + r.rating) / reviews.length;
      return null;
    } catch (_) {
      return 'Unable to submit review. Please try again.';
    } finally {
      _reviewSubmitting = false;
      notifyListeners();
    }
  }

  void reset() {
    _places.clear();
    _loaded = false;
    _section = DiscoverSection.discover;
    _selected = null;
    _query = '';
    _states.clear();
    _categories.clear();
    notifyListeners();
  }
}
