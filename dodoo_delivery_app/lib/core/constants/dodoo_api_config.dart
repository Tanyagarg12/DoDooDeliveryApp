/// Configuration for the external DoDoo order platform API
/// (a .NET WCF service at MyService.svc).
///
/// NOTE: these endpoints are currently unauthenticated (no API key). If the
/// platform later adds auth, put the key/header here and attach it in
/// [DodooOrderApi]. Do not hardcode secrets that get committed to git.
class DodooApiConfig {
  DodooApiConfig._();

  static const String baseUrl = 'https://www.dodoo.in:5678/MyService.svc';

  /// Default city for the admin "import orders" screen (editable in the UI).
  static const String defaultCityCode = 'ATP';

  /// Order statuses considered "available to dispatch".
  static const List<String> openStatuses = [
    'Open',
    'Accept',
    'InProgress',
    'OnGoing',
  ];

  /// DoDoo status-update endpoint. Called as:
  ///   GET {baseUrl}/UpdateOrderStatus/{Type}/{Status}/{ShortOrderID}
  /// e.g. /UpdateOrderStatus/Store/InProgress/STOR20260616193554136
  /// (Type = Store | PickDrop; ShortOrderID = the OrderID without the city
  /// prefix, e.g. ATP_STOR… → STOR…).
  static const String statusUpdatePath = '/UpdateOrderStatus';
}
