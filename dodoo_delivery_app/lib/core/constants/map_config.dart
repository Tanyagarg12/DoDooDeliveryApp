/// Central configuration for the Google Maps / tracking module.
///
/// ─────────────────────────────────────────────────────────────────────────
/// GOOGLE MAPS API KEY SETUP
/// 1. Native map tiles (the GoogleMap widget) read their key from the platform
///    config, NOT from here:
///      • Android → android/app/src/main/AndroidManifest.xml
///                  (com.google.android.geo.API_KEY)
///      • iOS     → ios/Runner/AppDelegate.swift (GMSServices.provideAPIKey)
/// 2. The [directionsApiKey] below is only used for the optional Directions API
///    HTTP call that draws the optimized route polyline. Leave it as the
///    placeholder to fall back to a straight pickup→drop line.
/// ─────────────────────────────────────────────────────────────────────────
class MapConfig {
  MapConfig._();

  /// Used only for the Directions API REST call (route optimization).
  /// Replace with a key that has "Directions API" enabled.
  static const String directionsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY_HERE';

  /// True when a real Directions key has been provided.
  static bool get hasDirectionsKey =>
      directionsApiKey.isNotEmpty &&
      directionsApiKey != 'YOUR_GOOGLE_MAPS_API_KEY_HERE';

  /// Fallback camera target when we have no location yet (central India).
  static const double defaultLat = 20.5937;
  static const double defaultLng = 78.9629;
  static const double defaultZoom = 15.0;

  /// How often the rider's GPS is pushed to the backend, expressed as the
  /// minimum distance (metres) the rider must move before a new fix is sent.
  /// Movement-based updates are far more battery-friendly than fixed timers.
  static const int trackingDistanceFilterMeters = 15;

  /// Hard ceiling between forced updates even while stationary (Android).
  static const Duration trackingMaxInterval = Duration(seconds: 8);
}
