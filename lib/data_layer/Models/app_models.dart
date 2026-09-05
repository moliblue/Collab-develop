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
    List<Review>? reviews,
  }) : reviews = reviews ?? <Review>[];
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
  final List<Review> reviews;
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
