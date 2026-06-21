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

  /// Endpoint path (relative to [baseUrl]) DoDoo uses to UPDATE an order's
  /// status — i.e. push the rider's progress back to the DoDoo platform.
  ///
  /// LEFT EMPTY until DoDoo provides the operation (the service hides its
  /// metadata, so it can't be auto-discovered). When you have it, set it here,
  /// e.g. '/UpdateOrderStatus', and status push-back activates automatically.
  static const String statusUpdatePath = '';

  /// HTTP method for [statusUpdatePath] ('POST' or 'GET').
  static const String statusUpdateMethod = 'POST';
}
