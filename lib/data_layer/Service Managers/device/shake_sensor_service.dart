import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ShakeSensorService {
  ShakeSensorService({
    this.shakeThreshold = 5.5,
    this.jerkThreshold = 9,
    this.cooldown = const Duration(milliseconds: 1400),
  });

  /// Linear acceleration above normal gravity, in m/s².
  final double shakeThreshold;

  /// Change between consecutive raw acceleration samples, in m/s².
  final double jerkThreshold;
  final Duration cooldown;
  StreamSubscription<AccelerometerEvent>? _subscription;
  DateTime? _lastShake;
  AccelerometerEvent? _previousEvent;
  bool _disposed = false;

  bool get isListening => _subscription != null;

  void startListening({
    required VoidCallback onShake,
    required void Function(Object error) onError,
  }) {
    if (_disposed) throw StateError('ShakeSensorService is disposed.');
    unawaited(stopListening());
    _lastShake = null;
    _previousEvent = null;
    _subscription =
        accelerometerEventStream(
          samplingPeriod: SensorInterval.gameInterval,
        ).listen(
          (event) {
            final magnitude = math.sqrt(
              event.x * event.x + event.y * event.y + event.z * event.z,
            );
            // Raw accelerometer data is supported more consistently by Android
            // emulators. Remove gravity from its magnitude, and also measure the
            // sudden change between samples so a virtual shake/quick rotation is
            // recognised without making stationary gravity a false positive.
            final linearAcceleration = (magnitude - 9.80665).abs();
            final previous = _previousEvent;
            _previousEvent = event;
            final jerk = previous == null
                ? 0.0
                : math.sqrt(
                    math.pow(event.x - previous.x, 2) +
                        math.pow(event.y - previous.y, 2) +
                        math.pow(event.z - previous.z, 2),
                  );
            if (linearAcceleration < shakeThreshold && jerk < jerkThreshold) {
              return;
            }
            final now = DateTime.now();
            if (_lastShake != null && now.difference(_lastShake!) < cooldown) {
              return;
            }
            _lastShake = now;
            debugPrint(
              'Shake detected: linear=${linearAcceleration.toStringAsFixed(2)}, '
              'jerk=${jerk.toStringAsFixed(2)}',
            );
            unawaited(stopListening());
            onShake();
          },
          onError: (Object error, StackTrace stackTrace) {
            unawaited(stopListening());
            onError(error);
          },
          cancelOnError: true,
        );
  }

  Future<void> stopListening() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  Future<void> dispose() async {
    _disposed = true;
    await stopListening();
  }
}
