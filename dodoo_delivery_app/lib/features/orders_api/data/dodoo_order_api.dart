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
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Content-Type': 'application/json'},
              // The list endpoint returns 200 with a JSON array; treat <500 as
              // a real response so we can surface API-level messages.
              validateStatus: (s) => s != null && s < 500,
            ));

  final Dio _dio;

  /// POST GetAllTypeOrdersByCityStatusCombi → list of open orders for a city.
  Future<List<DodooOrder>> getAllOrders({
    String cityCode = DodooApiConfig.defaultCityCode,
    List<String> statusList = DodooApiConfig.openStatuses,
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

  /// Fetches detail by routing on the OrderID prefix (PDP… vs STOR…).
  Future<DodooOrder?> getOrderDetail(String orderId) {
    final id = orderId.toUpperCase();
    if (id.startsWith('STOR')) return getStoreOrderDetail(orderId);
    return getPickDropDetail(orderId);
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
