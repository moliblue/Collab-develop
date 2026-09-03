enum JourneyStatus {
  idle,
  active,
  routeRevealed,
  verifying,
  completed,
  cancelled,
}

enum JourneyMode { solo, group }

enum GroupVoteType { hint, route }

class GroupVoteOutcome {
  const GroupVoteOutcome({
    required this.type,
    required this.yesVotes,
    required this.requiredVotes,
    required this.memberCount,
    required this.passed,
    this.voteRound = 1,
    this.currentUserVoted = false,
    this.testExplorerVoted = false,
    this.alreadyVoted = false,
  });

  final GroupVoteType type;
  final int yesVotes;
  final int requiredVotes;
  final int memberCount;
  final bool passed;
  final int voteRound;
  final bool currentUserVoted;
  final bool testExplorerVoted;
  final bool alreadyVoted;

  String get message => alreadyVoted
      ? 'Vote already submitted: $yesVotes/$requiredVotes Yes votes.'
      : passed
      ? '${type == GroupVoteType.hint ? 'Hint' : 'Route'} vote passed: '
            '$yesVotes/$requiredVotes Yes votes.'
      : 'Vote recorded: $yesVotes/$requiredVotes Yes votes required.';
}

class ArrivalCheckResult {
  const ArrivalCheckResult({
    required this.distanceMeters,
    required this.accuracyMeters,
  });

  final double distanceMeters;
  final double accuracyMeters;

  bool get hasReliableAccuracy => accuracyMeters <= 30;
  bool get isInsideArrivalRadius => hasReliableAccuracy && distanceMeters <= 50;
}

class TravelPreferences {
  const TravelPreferences({
    this.categories = const <String>{},
    this.transport = 'Walking',
    this.duration = '1-2 hours',
    this.radiusKm = 5,
    this.useSavedPreferences = false,
  });

  final Set<String> categories;
  final String transport;
  final String duration;
  final double radiusKm;
  final bool useSavedPreferences;

  bool get isSurpriseMe => categories.isEmpty;
  String get selectionMode => isSurpriseMe
      ? 'surprise_me'
      : useSavedPreferences
      ? 'saved_preferences'
      : 'edited_preferences';

  String get summary {
    final interests = categories.isEmpty
        ? 'Surprise me'
        : categories.join(', ');
    return '$interests • $transport • $duration • ${radiusKm.toStringAsFixed(0)} km';
  }

  TravelPreferences copyWith({
    Set<String>? categories,
    String? transport,
    String? duration,
    double? radiusKm,
    bool? useSavedPreferences,
  }) => TravelPreferences(
    categories: categories ?? this.categories,
    transport: transport ?? this.transport,
    duration: duration ?? this.duration,
    radiusKm: radiusKm ?? this.radiusKm,
    useSavedPreferences: useSavedPreferences ?? this.useSavedPreferences,
  );
}

class JourneyDestination {
  const JourneyDestination({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.description,
    this.imageUrl,
  });

  factory JourneyDestination.fromJson(Map<String, dynamic> json) =>
      JourneyDestination(
        id: json['id'].toString(),
        name: json['name'] as String? ?? 'Mystery destination',
        category: json['category'] as String? ?? '',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        address: json['address'] as String? ?? '',
        description: json['description'] as String? ?? '',
        imageUrl: json['image_url'] as String?,
      );

  final String id;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final String address;
  final String description;
  final String? imageUrl;
}

class JourneyMember {
  const JourneyMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.status,
    this.participantStatus,
  });
  final String userId;
  final String displayName;
  final String role;
  final String status;
  final String? participantStatus;
  bool get isHost => role == 'host';
}

class NearbyGroupRoom {
  const NearbyGroupRoom({
    required this.id,
    required this.memberCount,
    required this.distanceMeters,
    required this.preferenceLabels,
    this.capacity = 4,
  });

  final String id;
  final int memberCount;
  final int capacity;
  final double distanceMeters;
  final List<String> preferenceLabels;

  bool get hasPreferences => preferenceLabels.isNotEmpty;
  bool get isFull => memberCount >= capacity;
}

class JourneyProfile {
  const JourneyProfile({
    required this.userId,
    required this.explorerLevel,
    required this.xp,
    required this.streakDays,
  });
  final String userId;
  final int explorerLevel;
  final int xp;
  final int streakDays;
}

class Journey {
  const Journey({
    required this.id,
    required this.status,
    required this.clue,
    required this.locationHint,
    required this.distanceMeters,
    this.mode = JourneyMode.solo,
    this.participantId,
    this.destination,
    this.preferences = const TravelPreferences(),
    this.additionalHints = const <String>[],
    this.exactRouteRevealed = false,
    this.groupRoomId,
    this.groupDeadline,
    this.members = const <JourneyMember>[],
    this.isHost = false,
    this.groupPreferencesSet = false,
    this.completedAt,
  });

  final String id;
  final JourneyStatus status;
  final JourneyMode mode;
  final String? participantId;
  final String clue;
  final String locationHint;
  final double distanceMeters;
  final JourneyDestination? destination;
  final TravelPreferences preferences;
  final List<String> additionalHints;
  final bool exactRouteRevealed;
  final String? groupRoomId;
  final DateTime? groupDeadline;
  final List<JourneyMember> members;
  final bool isHost;
  final bool groupPreferencesSet;
  final DateTime? completedAt;

  bool get destinationMayBeRevealed =>
      status == JourneyStatus.completed || exactRouteRevealed;

  Journey copyWith({
    JourneyStatus? status,
    String? clue,
    String? locationHint,
    double? distanceMeters,
    TravelPreferences? preferences,
    List<String>? additionalHints,
    bool? exactRouteRevealed,
    List<JourneyMember>? members,
    bool? isHost,
    bool? groupPreferencesSet,
    DateTime? completedAt,
  }) => Journey(
    id: id,
    status: status ?? this.status,
    mode: mode,
    participantId: participantId,
    clue: clue ?? this.clue,
    locationHint: locationHint ?? this.locationHint,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    destination: destination,
    preferences: preferences ?? this.preferences,
    additionalHints: additionalHints ?? this.additionalHints,
    exactRouteRevealed: exactRouteRevealed ?? this.exactRouteRevealed,
    groupRoomId: groupRoomId,
    groupDeadline: groupDeadline,
    members: members ?? this.members,
    isHost: isHost ?? this.isHost,
    groupPreferencesSet: groupPreferencesSet ?? this.groupPreferencesSet,
    completedAt: completedAt ?? this.completedAt,
  );
}
