import 'dart:convert';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'latitude': latitude,
    'longitude': longitude,
  };
}

class RouteLeg {
  const RouteLeg({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.geometry,
  });
  final double distanceMeters;
  final double durationSeconds;
  final List<GeoPoint> geometry;
  String get summary =>
      '${(durationSeconds / 60).round()} min drive (${(distanceMeters / 1000).toStringAsFixed(1)} km)';
}

class PlannerActivity {
  PlannerActivity({
    required this.id,
    required this.dayId,
    required this.title,
    required this.location,
    required this.startTime,
    required this.category,
    required this.point,
    this.description = '',
    this.position = 0,
    this.routeDistanceMeters,
    this.routeDurationSeconds,
    this.routeGeometry = const <GeoPoint>[],
  });
  final String id;
  final String dayId;
  String title;
  String location;
  String startTime;
  String category;
  String description;
  GeoPoint point;
  int position;
  final double? routeDistanceMeters;
  final double? routeDurationSeconds;
  final List<GeoPoint> routeGeometry;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'day_id': dayId,
    'title': title,
    'location': location,
    'start_time': _postgresTime(startTime),
    'category': category,
    'description': description,
    'latitude': point.latitude,
    'longitude': point.longitude,
    'position': position,
    'route_distance_m': routeDistanceMeters,
    'route_duration_s': routeDurationSeconds,
    'route_geometry': routeGeometry
        .map((point) => <double>[point.latitude, point.longitude])
        .toList(),
  };
  static String _postgresTime(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return value;
    var hour = int.parse(match.group(1)!);
    final period = match.group(3)!.toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return '${hour.toString().padLeft(2, '0')}:${match.group(2)}:00';
  }

  factory PlannerActivity.fromJson(Map<String, dynamic> json) =>
      PlannerActivity(
        id: '${json['id']}',
        dayId: '${json['day_id']}',
        title: '${json['title']}',
        location: '${json['location']}',
        startTime: '${json['start_time']}',
        category: '${json['category'] ?? 'Sightseeing'}',
        description: '${json['description'] ?? ''}',
        point: GeoPoint(
          (json['latitude'] as num).toDouble(),
          (json['longitude'] as num).toDouble(),
        ),
        position: (json['position'] as num?)?.toInt() ?? 0,
        routeDistanceMeters: (json['route_distance_m'] as num?)?.toDouble(),
        routeDurationSeconds: (json['route_duration_s'] as num?)?.toDouble(),
        routeGeometry: (json['route_geometry'] as List<dynamic>? ?? <dynamic>[])
            .whereType<List<dynamic>>()
            .where((pair) => pair.length >= 2)
            .map(
              (pair) => GeoPoint(
                (pair[0] as num).toDouble(),
                (pair[1] as num).toDouble(),
              ),
            )
            .toList(),
      );
}

class PlannerDay {
  PlannerDay({
    required this.id,
    required this.date,
    List<PlannerActivity>? activities,
  }) : activities = activities ?? <PlannerActivity>[];
  final String id;
  DateTime date;
  final List<PlannerActivity> activities;
  String get label => 'Day';
}

class PlannerMember {
  PlannerMember({
    required this.userId,
    required this.name,
    required this.role,
    this.initials = '',
  });
  final String userId;
  final String name;
  String role;
  final String initials;
  bool get isAdmin => role.toLowerCase() == 'admin';

  factory PlannerMember.fromJson(Map<String, dynamic> json) {
    final id = '${json['user_id']}';
    final name = '${json['display_name'] ?? ''}'.trim();
    final label = name.isEmpty ? 'Member ${id.substring(0, 6)}' : name;
    return PlannerMember(
      userId: id,
      name: label,
      role: '${json['role'] ?? 'member'}',
      initials: label
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .take(2)
          .map((part) => part[0].toUpperCase())
          .join(),
    );
  }
}

class TravelPlan {
  TravelPlan({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.inviteCode,
    this.regions = const <String>[],
    String? primaryRegion,
    this.revision = 0,
    List<PlannerDay>? days,
    List<PlannerMember>? members,
  }) : primaryRegion = primaryRegion?.trim().isNotEmpty == true
           ? primaryRegion!.trim()
           : (regions.isEmpty ? '' : regions.first),
       days = days ?? <PlannerDay>[],
       members = members ?? <PlannerMember>[];
  final String id;
  final String ownerId;
  String name;
  DateTime startDate;
  DateTime endDate;
  final String inviteCode;
  final List<String> regions;
  final String primaryRegion;
  int revision;
  final List<PlannerDay> days;
  final List<PlannerMember> members;
  int get activityCount =>
      days.fold(0, (sum, day) => sum + day.activities.length);
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'owner_id': ownerId,
    'name': name,
    'start_date': startDate.toIso8601String().substring(0, 10),
    'end_date': endDate.toIso8601String().substring(0, 10),
    'invite_code': inviteCode,
    'regions': regions,
    'revision': revision,
  };
  String encodeSharePayload() => base64Url.encode(
    utf8.encode(jsonEncode(<String, String>{'plan': id, 'code': inviteCode})),
  );

  factory TravelPlan.fromJson(Map<String, dynamic> json) => TravelPlan(
    id: '${json['id']}',
    ownerId: '${json['owner_id']}',
    name: '${json['name']}',
    startDate: DateTime.parse('${json['start_date']}'),
    endDate: DateTime.parse('${json['end_date']}'),
    inviteCode: '${json['invite_code']}',
    regions: (json['regions'] as List<dynamic>? ?? const <dynamic>[])
        .map((value) => '$value'.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false),
    revision: (json['revision'] as num?)?.toInt() ?? 0,
  );

  static const supportedRegions = <String>[
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
    'Putrajaya',
    'Labuan',
  ];

  static String coverAssetForRegion(String region) => switch (region) {
    'Penang' => 'assets/blue_mansion.png',
    'Kuala Lumpur' => 'assets/sultan_abdul_samad.png',
    'Selangor' => 'assets/batu_caves.png',
    _ => 'assets/discovery_placeholder.png',
  };

  String get coverAsset => coverAssetForRegion(primaryRegion);
}
