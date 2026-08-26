import 'package:flutter/foundation.dart';

import '../../data_layer/Models/app_models.dart';
import '../../data_layer/Models/mock_data.dart';

enum DiscoverSection { discover, bookmarks }

class DiscoveryViewModel extends ChangeNotifier {
  final List<HeritagePlace> _places = createPlaces();
  DiscoverSection _section = DiscoverSection.discover;
  HeritagePlace? _selected;
  String _query = '';
  final Set<String> _states = <String>{};
  final Set<String> _categories = <String>{};
  bool _filtersOpen = false;

  List<HeritagePlace> get places => List<HeritagePlace>.unmodifiable(_places);
  DiscoverSection get section => _section;
  HeritagePlace? get selected => _selected;
  String get query => _query;
  Set<String> get states => Set<String>.unmodifiable(_states);
  Set<String> get categories => Set<String>.unmodifiable(_categories);
  bool get filtersOpen => _filtersOpen;
  List<HeritagePlace> get bookmarks =>
      _places.where((HeritagePlace p) => p.bookmarked).toList();
  List<HeritagePlace> get filteredPlaces {
    final q = _query.trim().toLowerCase();
    return _places.where((HeritagePlace p) {
        final textMatches =
            q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            p.state.toLowerCase().contains(q);
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

  void select(HeritagePlace? value) {
    _selected = value;
    notifyListeners();
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

  bool toggleBookmark(HeritagePlace place) {
    place.bookmarked = !place.bookmarked;
    notifyListeners();
    return place.bookmarked;
  }

  String? addReview(HeritagePlace place, int rating, String comment) {
    if (rating < 1 || rating > 5) {
      return 'Please select a rating before submitting.';
    }
    place.reviews.insert(
      0,
      Review(
        name: 'Amberly',
        date: 'August 24, 2026',
        rating: rating,
        comment: comment.trim().isEmpty
            ? 'A memorable Malaysian heritage stop.'
            : comment.trim(),
      ),
    );
    place.reviewsCount = place.reviews.length;
    place.rating =
        place.reviews.fold<int>(0, (int sum, Review r) => sum + r.rating) /
        place.reviews.length;
    notifyListeners();
    return null;
  }

  void reset() {
    _places
      ..clear()
      ..addAll(createPlaces());
    _section = DiscoverSection.discover;
    _selected = null;
    _query = '';
    _states.clear();
    _categories.clear();
    notifyListeners();
  }
}
