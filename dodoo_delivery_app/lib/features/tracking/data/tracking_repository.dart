import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/map_config.dart';
import '../../../core/utils/map_utils.dart';

/// A driving route plus its summary, returned by [TrackingRepository.fetchRoute].
class RouteResult {
  const RouteResult({
    required this.points,
    this.distanceText,
    this.durationText,
    this.isOptimized = false,
  });

  /// Ordered polyline points from origin to destination.
  final List<LatLng> points;

  /// Human-readable distance/duration from the Directions API (null on fallback).
  final String? distanceText;
  final String? durationText;

  /// True when the polyline came from the Directions API (optimized road route)
  /// rather than the straight-line fallback.
  final bool isOptimized;
}

/// Builds driving routes via the Google Directions API for the live-tracking
/// map. (Realtime rider-location streams now live in Firestore directly.)
class TrackingRepository {
  TrackingRepository({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  // ── Route / optimization ─────────────────────────────────────────────────

  /// Fetches the optimized driving route between [origin] and [destination].
  ///
  /// Uses the Google Directions API when [MapConfig.hasDirectionsKey] is true;
  /// otherwise (or on any error) returns a straight two-point line so the map
  /// still shows a connection. Optional [waypoints] are passed with
  /// `optimize:true` so Google reorders multi-stop trips for the shortest path.
  Future<RouteResult> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
  }) async {
    if (!MapConfig.hasDirectionsKey) {
      return RouteResult(points: [origin, destination]);
    }
    try {
      final params = <String, dynamic>{
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'key': MapConfig.directionsApiKey,
      };
      if (waypoints.isNotEmpty) {
        final wp = waypoints
            .map((w) => '${w.latitude},${w.longitude}')
            .join('|');
        params['waypoints'] = 'optimize:true|$wp';
      }

      final res = await _dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: params,
      );
      final data = res.data ?? const {};
      final routes = (data['routes'] as List?) ?? const [];
      if (data['status'] != 'OK' || routes.isEmpty) {
        return RouteResult(points: [origin, destination]);
      }

      final route = routes.first as Map<String, dynamic>;
      final encoded =
          (route['overview_polyline']?['points'] as String?) ?? '';
      final pts = encoded.isNotEmpty
          ? MapUtils.decodePolyline(encoded)
          : [origin, destination];

      final legs = (route['legs'] as List?) ?? const [];
      String? distanceText;
      String? durationText;
      if (legs.isNotEmpty) {
        // Sum legs so multi-waypoint trips report the full distance/time.
        int meters = 0;
        int seconds = 0;
        for (final l in legs) {
          meters += ((l['distance']?['value'] as num?) ?? 0).toInt();
          seconds += ((l['duration']?['value'] as num?) ?? 0).toInt();
        }
        distanceText = '${(meters / 1000).toStringAsFixed(1)} km';
        durationText = '${(seconds / 60).round()} min';
      }

      return RouteResult(
        points: pts,
        distanceText: distanceText,
        durationText: durationText,
        isOptimized: true,
      );
    } catch (_) {
      return RouteResult(points: [origin, destination]);
    }
  }

}
