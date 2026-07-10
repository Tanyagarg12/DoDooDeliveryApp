/// Config for the DoDoo **store-management** API — used by admin to add/update
/// stores, store items, wallet balance, and the store on/off status.
///
/// NOTE: this is a DIFFERENT host/port from the order API in [DodooApiConfig]
/// (`www.dodoo.in:5678`). Use the DOMAIN, not a raw IP — the store server's
/// public IP drifts (it was `18.217.195.26`, now `3.142.218.179`), but
/// `dodoo.in` tracks it. Must be `dodoo.in` WITHOUT `www` (the `www.` variant
/// 400s on :1234). Cleartext HTTP is allowed via network_security_config.xml.
class DodooStoreApiConfig {
  DodooStoreApiConfig._();

  static const String baseUrl = 'http://dodoo.in:1234/MyService.svc';

  /// All store-management calls are city-scoped. Kurnool ('KNL') is the city we
  /// test against first (see DodooCities).
  static const String testCityCode = 'KNL';
}
