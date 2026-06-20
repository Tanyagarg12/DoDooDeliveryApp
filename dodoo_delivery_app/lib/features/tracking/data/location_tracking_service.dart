import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/map_config.dart';
import '../../../core/firebase/firestore_service.dart';

/// Result of a permission/availability check.
enum LocationReadiness {
  ready,
  serviceDisabled,
  denied,
  deniedForever,
}

/// Singleton that owns the device GPS stream and pushes the rider's live
/// position to Firestore (`rider_tracking` collection).
///
/// Design goals:
///  • **Live** — emits a broadcast [stream] of [Position] the UI can follow.
///  • **Background-capable** — uses geolocator's Android foreground service +
///    iOS background location so tracking survives the app being minimized.
///  • **Battery-friendly** — movement-based updates ([distanceFilter]) instead
///    of a tight timer; DB writes are throttled.
class LocationTrackingService {
  LocationTrackingService._();
  static final LocationTrackingService instance = LocationTrackingService._();

  final _db = FirestoreService.instance;

  StreamSubscription<Position>? _geoSub;
  final _controller = StreamController<Position>.broadcast();

  /// Broadcast stream of live device positions while tracking is active.
  Stream<Position> get stream => _controller.stream;

  Position? _last;
  Position? get lastPosition => _last;

  String? _orderId;
  bool _running = false;
  bool get isTracking => _running;

  DateTime? _lastDbWrite;

  // ── Permissions ────────────────────────────────────────────────────────

  /// Ensures location services are on and foreground permission is granted.
  /// Requests permission if needed. Returns the resulting readiness.
  Future<LocationReadiness> ensurePermission() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) return LocationReadiness.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
        return LocationReadiness.denied;
      case LocationPermission.deniedForever:
        return LocationReadiness.deniedForever;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
      case LocationPermission.unableToDetermine:
        return LocationReadiness.ready;
    }
  }

  /// Opens the OS settings page so the user can re-enable a "denied forever"
  /// permission or turn location services back on.
  Future<void> openSettings({bool locationService = false}) {
    return locationService
        ? Geolocator.openLocationSettings()
        : Geolocator.openAppSettings();
  }

  /// One-shot current location (used to centre the map before the stream warms
  /// up). Returns null if it cannot be obtained.
  Future<Position?> currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Start / stop ─────────────────────────────────────────────────────────

  /// Begins streaming GPS and publishing to Supabase. Safe to call again with a
  /// new [orderId] — it simply rebinds. Returns the readiness; only [ready]
  /// actually starts the stream.
  Future<LocationReadiness> start({String? orderId}) async {
    _orderId = orderId;
    final readiness = await ensurePermission();
    if (readiness != LocationReadiness.ready) return readiness;

    if (_running) return readiness; // already streaming

    _running = true;
    _geoSub = Geolocator.getPositionStream(
      locationSettings: _platformSettings(),
    ).listen(
      _onPosition,
      onError: (_) {/* transient GPS errors — keep the stream alive */},
      cancelOnError: false,
    );
    return readiness;
  }

  /// Stops streaming and flags the backend row as no longer tracking.
  Future<void> stop() async {
    _running = false;
    await _geoSub?.cancel();
    _geoSub = null;
    try {
      await _db.stopTracking();
    } catch (_) {}
  }

  /// Re-point the active stream at a different order without restarting GPS.
  void bindOrder(String? orderId) => _orderId = orderId;

  // ── Internals ──────────────────────────────────────────────────────────

  void _onPosition(Position pos) {
    _last = pos;
    if (!_controller.isClosed) _controller.add(pos);
    _maybeWriteToDb(pos);
  }

  /// Throttle DB writes so a fast-moving GPS doesn't hammer Supabase.
  Future<void> _maybeWriteToDb(Position pos) async {
    final now = DateTime.now();
    if (_lastDbWrite != null &&
        now.difference(_lastDbWrite!) < const Duration(seconds: 3)) {
      return;
    }
    _lastDbWrite = now;
    try {
      await _db.updateTracking(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
        speed: pos.speed,
        bearing: pos.heading,
        orderId: _orderId,
      );
    } catch (_) {
      // Allow the next fix to retry; never crash the stream on a network blip.
    }
  }

  LocationSettings _platformSettings() {
    const distanceFilter = MapConfig.trackingDistanceFilterMeters;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        intervalDuration: MapConfig.trackingMaxInterval,
        // Foreground service keeps tracking alive when the app is backgrounded.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'DoDoo Rider — Live Tracking',
          notificationText: 'Sharing your location for the active delivery.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
        activityType: ActivityType.automotiveNavigation,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );
  }
}
