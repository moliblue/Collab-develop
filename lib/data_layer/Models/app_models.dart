enum JourneyMode { solo, group }

enum MysteryStage {
  home,
  groupSetup,
  groupWaiting,
  shake,
  active,
  verificationFailed,
  interrupted,
  complete,
}

enum ProfileStage {
  dashboard,
  badges,
  passport,
  login,
  register,
  verifyEmail,
  recover,
  resetPassword,
}

class Review {
  Review({
    required this.name,
    required this.date,
    required this.rating,
    required this.comment,
  });
  final String name;
  final String date;
  final int rating;
  final String comment;
}

class DestinationImage {
  const DestinationImage({
    required this.id,
    required this.imageUrl,
    required this.isCover,
    required this.displayOrder,
    this.source = 'pexels',
    this.sourceImageId,
    this.photographerName,
    this.photographerUrl,
    this.matchStatus = 'fallback',
    this.licenseName,
    this.licenseUrl,
    this.sourcePageUrl,
    this.refreshAfter,
  });

  final String id;
  final String imageUrl;
  final bool isCover;
  final int displayOrder;
  final String source;
  final String? sourceImageId;
  final String? photographerName;
  final String? photographerUrl;
  final String matchStatus;
  final String? licenseName;
  final String? licenseUrl;
  final String? sourcePageUrl;
  final DateTime? refreshAfter;

  bool get isTemporaryGooglePhoto =>
      source == 'google_places' && refreshAfter != null;
}

class HeritagePlace {
  HeritagePlace({
    required this.id,
    required this.name,
    required this.category,
    required this.state,
    required this.shortDescription,
    required this.description,
    required this.image,
    required this.distanceKm,
    required this.rating,
    required this.reviewsCount,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.hours,
    this.bookmarked = false,
    this.osmId,
    this.osmType,
    this.osmNumericId,
    this.osmTags = const <String, String>{},
    this.googlePlaceId,
    this.googlePlaceName,
    this.googleMatchStatus,
    this.formattedAddress,
    this.openingHoursWeekdayText = const <String>[],
    this.openingHoursPeriods,
    this.openingHoursUpdatedAt,
    this.googleMapsUri,
    List<DestinationImage>? images,
    List<Review>? reviews,
  }) : images = images ?? <DestinationImage>[],
       reviews = reviews ?? <Review>[];
  final String id;
  final String name;
  final String category;
  final String state;
  final String shortDescription;
  final String description;
  final String image;
  final double distanceKm;
  double rating;
  int reviewsCount;
  final double latitude;
  final double longitude;
  final String address;
  final String hours;
  bool bookmarked;
  final String? osmId;
  final String? osmType;
  final int? osmNumericId;
  final Map<String, String> osmTags;
  final String? googlePlaceId;
  final String? googlePlaceName;
  final String? googleMatchStatus;
  final String? formattedAddress;
  final List<String> openingHoursWeekdayText;
  final Map<String, dynamic>? openingHoursPeriods;
  final DateTime? openingHoursUpdatedAt;
  final String? googleMapsUri;
  final List<DestinationImage> images;
  final List<Review> reviews;

  String get coverImageUrl {
    if (images.isEmpty) return image;
    final ordered = [...images]
      ..sort((a, b) {
        if (a.isCover != b.isCover) return a.isCover ? -1 : 1;
        final byOrder = a.displayOrder.compareTo(b.displayOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    return ordered.first.imageUrl.trim().isNotEmpty
        ? ordered.first.imageUrl
        : image;
  }

  List<String> get detailImageUrls {
    final urls = detailImages
        .map((entry) => entry.imageUrl.trim())
        .toList(growable: false);
    if (urls.isNotEmpty) return urls;
    final legacy = image.trim();
    return legacy.isEmpty ? const <String>[] : <String>[legacy];
  }

  List<DestinationImage> get detailImages {
    final ordered = [...images]
      ..sort((a, b) {
        final byOrder = a.displayOrder.compareTo(b.displayOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    final seen = <String>{};
    return ordered
        .where(
          (entry) =>
              entry.imageUrl.trim().isNotEmpty &&
              seen.add(entry.imageUrl.trim()),
        )
        .take(3)
        .toList(growable: false);
  }

  int get coverImageIndex {
    final urls = detailImageUrls;
    if (urls.length < 2 || images.isEmpty) return 0;
    final coverUrl = coverImageUrl;
    final index = urls.indexOf(coverUrl);
    return index < 0 ? 0 : index;
  }

  String get displayAddress {
    final googleAddress = _cleanAddress(formattedAddress);
    if (googleAddress.isNotEmpty) return googleAddress;
    final catalogueAddress = _cleanAddress(address);
    if (catalogueAddress.isNotEmpty) return catalogueAddress;
    final cleanState = state.trim();
    if (cleanState.isEmpty || cleanState.toLowerCase() == 'malaysia') {
      return 'Malaysia';
    }
    return '$cleanState, Malaysia';
  }

  String get directionsUri {
    final googleUri = googleMapsUri?.trim() ?? '';
    if (googleUri.isNotEmpty) return googleUri;
    return Uri.https('www.google.com', '/maps/search/', <String, String>{
      'api': '1',
      'query': '$latitude,$longitude',
    }).toString();
  }

  String get discoveryShareText {
    final location = state.trim().isEmpty ? 'Malaysia' : state.trim();
    return <String>[
      name,
      '',
      'Discover $name in $location.',
      displayAddress,
      '',
      'View on Google Maps:',
      directionsUri,
    ].join('\n');
  }

  String? openingHoursForDay(int weekday) {
    const days = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    if (weekday < DateTime.monday || weekday > DateTime.sunday) return null;
    final day = days[weekday - DateTime.monday].toLowerCase();
    for (final entry in openingHoursWeekdayText) {
      final trimmed = entry.trim();
      final separator = trimmed.indexOf(':');
      if (separator < 0) continue;
      if (trimmed.substring(0, separator).trim().toLowerCase() == day) {
        final value = trimmed.substring(separator + 1).trim();
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  static String _cleanAddress(String? value) {
    final parts = (value ?? '')
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && part.toLowerCase() != 'null');
    final result = <String>[];
    for (final part in parts) {
      if (result.isEmpty || result.last.toLowerCase() != part.toLowerCase()) {
        result.add(part);
      }
    }
    while (result.length > 1 &&
        result[result.length - 1].toLowerCase() == 'malaysia' &&
        result[result.length - 2].toLowerCase() == 'malaysia') {
      result.removeAt(result.length - 1);
    }
    return result.join(', ');
  }
}

class MysteryMapCompletion {
  const MysteryMapCompletion({
    required this.place,
    required this.completedAt,
    required this.completionCount,
    required this.passportStampCollected,
  });

  final HeritagePlace place;
  final DateTime completedAt;
  final int completionCount;
  final bool passportStampCollected;
}

class ActivityItem {
  ActivityItem({
    required this.id,
    required this.time,
    required this.title,
    required this.location,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.notes = '',
    this.transit = '',
    this.routeDistanceMeters,
    this.routeDurationSeconds,
    this.routeGeometry = const <List<double>>[],
  });
  final String id;
  String time;
  String title;
  String location;
  String category;
  String notes;
  String transit;
  double latitude;
  double longitude;
  double? routeDistanceMeters;
  double? routeDurationSeconds;
  List<List<double>> routeGeometry;
}

class PlanDay {
  PlanDay({
    required this.id,
    required this.label,
    required this.date,
    required this.activities,
  });
  final String id;
  String label;
  DateTime date;
  final List<ActivityItem> activities;
}

class Traveller {
  Traveller({
    required this.name,
    required this.initials,
    required this.role,
    this.userId,
    this.online = true,
  });
  final String? userId;
  final String name;
  final String initials;
  String role;
  bool online;
}

class BadgeData {
  const BadgeData({
    this.id = '',
    required this.title,
    required this.description,
    required this.rarity,
    required this.xp,
    required this.unlocked,
    required this.icon,
    this.progress = 0,
    this.requirementValue = 1,
    this.unlockedAt,
  });
  final String id;
  final String title;
  final String description;
  final String rarity;
  final int xp;
  final bool unlocked;
  final int icon;
  final int progress;
  final int requirementValue;
  final DateTime? unlockedAt;
}

class PassportStampData {
  const PassportStampData({
    required this.id,
    required this.destinationName,
    required this.earnedAt,
  });

  final String id;
  final String destinationName;
  final DateTime earnedAt;
}
