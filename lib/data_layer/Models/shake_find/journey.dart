enum JourneyStatus {
  idle,
  active,
  routeRevealed,
  verifying,
  completed,
  cancelled,
}

enum JourneyMode { solo, group }

class TravelPreferences {
  const TravelPreferences({
    this.categories = const <String>{},
    this.transport = 'Walking',
    this.duration = '1-2 hours',
    this.radiusKm = 5,
  });

  final Set<String> categories;
  final String transport;
  final String duration;
  final double radiusKm;

  String get summary {
    final interests = categories.isEmpty
        ? 'Surprise me'
        : categories.join(', ');
    return '$interests • $transport • $duration • ${radiusKm.toStringAsFixed(0)} km';
  }
}

class Journey {
  const Journey({
    required this.id,
    required this.status,
    required this.clue,
    required this.locationHint,
    required this.distanceMeters,
  });

  final String id;
  final JourneyStatus status;
  final String clue;
  final String locationHint;
  final double distanceMeters;

  Journey copyWith({
    String? id,
    JourneyStatus? status,
    String? clue,
    String? locationHint,
    double? distanceMeters,
  }) => Journey(
    id: id ?? this.id,
    status: status ?? this.status,
    clue: clue ?? this.clue,
    locationHint: locationHint ?? this.locationHint,
    distanceMeters: distanceMeters ?? this.distanceMeters,
  );
}
