import 'package:dio/dio.dart';

import '../../../core/constants/dodoo_api_config.dart';
import 'models/dodoo_order.dart';

/// Thrown for any DoDoo API failure, with a user-friendly [message].
class DodooApiException implements Exception {
  DodooApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Client for the external DoDoo order platform (MyService.svc).
class DodooOrderApi {
  DodooOrderApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: DodooApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 20),
              // The city list can be large (thousands of orders) — allow time.
              receiveTimeout: const Duration(seconds: 60),
              headers: {'Content-Type': 'application/json'},
              // The list endpoint returns 200 with a JSON array; treat <500 as
              // a real response so we can surface API-level messages.
              validateStatus: (s) => s != null && s < 500,
            ));

  final Dio _dio;

  /// POST GetAllTypeOrdersByCityStatusCombi → recent orders for a city filtered
  /// to the given statuses. This is MUCH faster than the full /All list (~4s &
  /// ~40KB vs ~28s & ~2MB) because the server caps + filters server-side, and
  /// it still includes recent finished orders for the admin history sections.
  Future<List<DodooOrder>> getAllOrders({
    String cityCode = DodooApiConfig.defaultCityCode,
    List<String> statusList = const [
      'Open',
      'Accept',
      'InProgress',
      'Deliver',
      'Cancel',
    ],
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        '/GetAllTypeOrdersByCityStatusCombi',
        data: {'CityCode': cityCode, 'Statuslist': statusList},
      );
      return _parseList(res.data);
    } on DioException catch (e) {
      throw DodooApiException(_dioMessage(e));
    }
  }

  /// GET GetPickDropByOrderID/{id}
  Future<DodooOrder?> getPickDropDetail(String orderId) =>
      _detail('/GetPickDropByOrderID/$orderId');

  /// GET GetStoreOrdersByOrderID/{id}
  Future<DodooOrder?> getStoreOrderDetail(String orderId) =>
      _detail('/GetStoreOrdersByOrderID/$orderId');

  /// Fetches detail by routing on the order type. IDs are city-prefixed
  /// (e.g. "ATP_STOR…" / "ATP_PDP…"), so we match on a substring, and prefer
  /// an explicit [orderType] ("Store" / "PickDrop") from the list when present.
  Future<DodooOrder?> getOrderDetail(String orderId, {String? orderType}) {
    final id = orderId.toUpperCase();
    final isStore =
        (orderType?.toLowerCase() == 'store') || id.contains('STOR');
    if (isStore) return getStoreOrderDetail(orderId);
    return getPickDropDetail(orderId);
  }

  /// GET GetStoreOrdersByStoreID/{storeId}
  /// Fetches all orders for a specific store by phone/store ID.
  Future<List<DodooOrder>> getStoreOrders(String storeId) async {
    try {
      final res = await _dio.get<dynamic>('/GetStoreOrdersByStoreID/$storeId');
      return _parseList(res.data);
    } on DioException catch (e) {
      throw DodooApiException(_dioMessage(e));
    }
  }

  /// Maps our internal order status to DoDoo's status word.
  /// Returns null for statuses there's nothing to push (e.g. 'pending').
  /// Maps our internal order status to DoDoo's status word for UpdateOrderStatus.
  /// DoDoo's real vocabulary (seen in the order data) is:
  /// Open / Accept / InProgress / OnGoing / Deliver / Cancel — a delivered
  /// order is recorded as "Deliver" (not "Completed").
  static String? dodooStatusFor(String internalStatus) {
    switch (internalStatus) {
      // DoDoo's CUSTOMER notifications are keyed to these words, and DoDoo has
      // them wired so:  "InProgress" => "…accepted, serving you soon"  and
      // "Accept" => "…picked your order".  So we push the word that triggers
      // the correct customer message:
      //   rider ACCEPTED  -> push "InProgress"
      //   rider PICKED UP -> push "Accept"
      // (dodoo_order.dart#internalStatus mirrors this for re-import.)
      case 'accepted':
        return 'InProgress';
      case 'picked_up':
      case 'in_transit':
      case 'reached':
        return 'Accept';
      case 'completed':
        return 'Deliver';
      case 'cancelled':
        return 'Cancel';
      default:
        return null;
    }
  }

  /// "Store" or "PickDrop" for the update path, from the order id / type.
  static String _typeSegment(String orderNumber, String? orderType) {
    final isStore = (orderType?.toLowerCase() == 'store') ||
        orderNumber.toUpperCase().contains('STOR');
    return isStore ? 'Store' : 'PickDrop';
  }

  /// Pushes an order's status to DoDoo:
  ///   GET /UpdateOrderStatus/{Type}/{Status}/{OrderID}
  /// IMPORTANT: DoDoo expects the FULL, city-prefixed OrderID here (e.g.
  /// ATP_STOR…). The short form (STOR…) returns "Update Success" but is a
  /// silent no-op — it does NOT change the order. Best-effort: never throws.
  /// Returns true only if DoDoo confirms the update (Status==1 / "success").
  /// Never throws — callers may `.ignore()` the result for fire-and-forget.
  Future<bool> pushStatus({
    required String orderNumber,
    required String internalStatus,
    String? orderType,
    String? riderId,
  }) async {
    final path = DodooApiConfig.statusUpdatePath;
    if (path.isEmpty || orderNumber.isEmpty) return false;
    final dodooStatus = dodooStatusFor(internalStatus);
    if (dodooStatus == null) return false;
    final type = _typeSegment(orderNumber, orderType);
    try {
      // Full OrderID (with the city prefix) — this is what actually updates.
      final res = await _dio.get<dynamic>('$path/$type/$dodooStatus/$orderNumber');
      final data = res.data;
      if (data is Map) {
        final status = data['Status']?.toString();
        final result = (data['Result'] ?? '').toString().toLowerCase();
        return status == '1' || result.contains('success');
      }
      // 2xx with a non-map body — treat as success.
      return true;
    } catch (_) {
      // Best-effort — DoDoo sync failures must not break the app flow.
      return false;
    }
  }

  /// GET ValidateSignup/{phone} → returns the OTP code (Result) or null.
  Future<String?> validateSignup(String phone) async {
    try {
      final res = await _dio.get<dynamic>('/ValidateSignup/$phone');
      final data = res.data;
      if (data is Map && data['Status']?.toString() == '1') {
        return data['Result']?.toString();
      }
      return null;
    } on DioException catch (e) {
      throw DodooApiException(_dioMessage(e));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Future<DodooOrder?> _detail(String path) async {
    try {
      final res = await _dio.get<dynamic>(path);
      final list = _parseList(res.data);
      if (list.isEmpty) return null;
      final order = list.first;
      return order.isNoData ? null : order;
    } on DioException catch (e) {
      throw DodooApiException(_dioMessage(e));
    }
  }

  List<DodooOrder> _parseList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => DodooOrder.fromJson(Map<String, dynamic>.from(e)))
          .where((o) => !o.isNoData)
          .toList();
    }
    return [];
  }

  String _dioMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'The DoDoo server took too long to respond. Try again.';
      case DioExceptionType.connectionError:
        return 'Cannot reach the DoDoo server. Check your connection.';
      case DioExceptionType.badResponse:
        return 'DoDoo server error (${e.response?.statusCode}).';
      default:
        return 'Could not load orders from DoDoo. ${e.message ?? ''}'.trim();
    }
  }
}
