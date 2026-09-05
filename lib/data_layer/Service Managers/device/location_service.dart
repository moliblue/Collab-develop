import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationFailureReason {
  servicesDisabled,
  denied,
  deniedForever,
  unavailable,
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.reason, this.message);
  final LocationFailureReason reason;
  final String message;
  @override
  String toString() => message;
}

class LocationReading {
  const LocationReading({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });
  factory LocationReading.fromPosition(Position value) => LocationReading(
    latitude: value.latitude,
    longitude: value.longitude,
    accuracy: value.accuracy,
    timestamp: value.timestamp,
  );
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
}

enum ArrivalProgress { poorAccuracy, outsideRadius, dwelling, verified }

class ArrivalDecision {
  const ArrivalDecision(this.progress, {this.remaining = Duration.zero});
  final ArrivalProgress progress;
  final Duration remaining;
}

class ArrivalDwellTracker {
  ArrivalDwellTracker({
    this.maximumAccuracyMeters = 30,
    this.arrivalRadiusMeters = 50,
    this.requiredDwell = const Duration(seconds: 10),
  });

  final double maximumAccuracyMeters;
  final double arrivalRadiusMeters;
  final Duration requiredDwell;
  DateTime? _enteredAt;

  ArrivalDecision evaluate({
    required double accuracyMeters,
    required double distanceMeters,
    required DateTime at,
  }) {
    if (accuracyMeters > maximumAccuracyMeters) {
      _enteredAt = null;
      return const ArrivalDecision(ArrivalProgress.poorAccuracy);
    }
    if (distanceMeters > arrivalRadiusMeters) {
      _enteredAt = null;
      return const ArrivalDecision(ArrivalProgress.outsideRadius);
    }
    _enteredAt ??= at;
    final elapsed = at.difference(_enteredAt!);
    if (elapsed >= requiredDwell) {
      return const ArrivalDecision(ArrivalProgress.verified);
    }
    return ArrivalDecision(
      ArrivalProgress.dwelling,
      remaining: requiredDwell - elapsed,
    );
  }

  void reset() => _enteredAt = null;
}

class LocationService {
  const LocationService();

  Future<void> ensurePermission() async {
    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (kDebugMode) {
      debugPrint('Location services enabled: $servicesEnabled');
    }
    if (!servicesEnabled) {
      throw const LocationServiceException(
        LocationFailureReason.servicesDisabled,
        'Location services are disabled. Turn on GPS and try again.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (kDebugMode) {
      debugPrint('Location permission before request: $permission');
    }
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (kDebugMode) {
        debugPrint('Location permission after request: $permission');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        LocationFailureReason.deniedForever,
        'Location permission is permanently denied. Enable it in Settings.',
      );
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      throw const LocationServiceException(
        LocationFailureReason.denied,
        'Location permission is required for a Mystery Journey.',
      );
    }
  }

  Future<LocationReading> getFreshLocation() async {
    await ensurePermission();
    try {
      final value = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationReading.fromPosition(value);
    } on TimeoutException {
      throw const LocationServiceException(
        LocationFailureReason.unavailable,
        'Unable to detect your current location. Move to an open area and try again.',
      );
    }
  }

  Stream<LocationReading> watchLocation() async* {
    await ensurePermission();
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).map(LocationReading.fromPosition);
  }

  double distanceBetween(
    LocationReading value,
    double latitude,
    double longitude,
  ) => Geolocator.distanceBetween(
    value.latitude,
    value.longitude,
    latitude,
    longitude,
  );
}
