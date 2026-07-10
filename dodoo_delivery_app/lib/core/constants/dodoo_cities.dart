/// The delivery cities DoDoo operates in.
///
/// [code] is the `CityCode` sent to the external DoDoo order API
/// (GetAllTypeOrdersByCityStatusCombi) and stored on each imported order so
/// the admin portal and rider app can filter by location. [name] is the
/// human-readable label shown in the city dropdowns.
import 'dart:math' as math;

class DodooCity {
  const DodooCity({
    required this.code,
    required this.name,
    required this.lat,
    required this.lng,
  });

  final String code;
  final String name;

  /// Approx. city-centre coordinates, used to pick the rider's nearest city.
  final double lat;
  final double lng;
}

/// Master list of serviceable cities. Add a row here and it shows up in both
/// the admin and rider city pickers automatically.
class DodooCities {
  DodooCities._();

  // NOTE: `code` must match DoDoo's LocationCode/CityCode exactly (used for
  // order fetching + store City). Confirmed against GetOperatingLocations:
  // Anantapur=ATP, Tadipatri=TDP, Kurnool=KRNT (NOT "KNL").
  static const List<DodooCity> all = [
    DodooCity(code: 'ATP', name: 'Anantapur', lat: 14.6819, lng: 77.6006),
    DodooCity(code: 'KRNT', name: 'Kurnool', lat: 15.8281, lng: 78.0373),
    DodooCity(code: 'TDP', name: 'Tadipatri', lat: 14.9091, lng: 78.0092),
  ];

  /// The city selected by default (also where legacy orders with no city land).
  static const DodooCity defaultCity =
      DodooCity(code: 'ATP', name: 'Anantapur', lat: 14.6819, lng: 77.6006);

  /// The serviceable city closest to the given coordinates (great-circle).
  /// Returns null if [lat]/[lng] are null.
  static DodooCity? nearest(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    DodooCity? best;
    double bestKm = double.infinity;
    for (final c in all) {
      final km = _haversineKm(lat, lng, c.lat, c.lng);
      if (km < bestKm) {
        bestKm = km;
        best = c;
      }
    }
    return best;
  }

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.asin(math.sqrt(a));
  }

  /// Resolves a stored city code back to its display name (falls back to the
  /// code itself, then to the default city's name when blank).
  static String nameFor(String? code) {
    if (code == null || code.isEmpty) return defaultCity.name;
    for (final c in all) {
      if (c.code == code) return c.name;
    }
    return code;
  }

  static DodooCity byCode(String? code) {
    for (final c in all) {
      if (c.code == code) return c;
    }
    return defaultCity;
  }

  /// Best-effort match of a free-text address to a city (riders have an
  /// address, not a city code). [cityCode] == null means "All cities".
  static bool addressInCity(String? address, String? cityCode) {
    if (cityCode == null) return true;
    final city = byCode(cityCode).name.toLowerCase();
    return (address ?? '').toLowerCase().contains(city);
  }
}
