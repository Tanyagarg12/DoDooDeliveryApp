/// The delivery cities DoDoo operates in.
///
/// [code] is the `CityCode` sent to the external DoDoo order API
/// (GetAllTypeOrdersByCityStatusCombi) and stored on each imported order so
/// the admin portal and rider app can filter by location. [name] is the
/// human-readable label shown in the city dropdowns.
class DodooCity {
  const DodooCity({required this.code, required this.name});

  final String code;
  final String name;
}

/// Master list of serviceable cities. Add a row here and it shows up in both
/// the admin and rider city pickers automatically.
class DodooCities {
  DodooCities._();

  static const List<DodooCity> all = [
    DodooCity(code: 'ATP', name: 'Anantapur'),
    DodooCity(code: 'KNL', name: 'Kurnool'),
    DodooCity(code: 'TDP', name: 'Tadipatri'),
  ];

  /// The city selected by default (also where legacy orders with no city land).
  static const DodooCity defaultCity = DodooCity(code: 'ATP', name: 'Anantapur');

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
