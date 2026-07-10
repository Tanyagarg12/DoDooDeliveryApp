import 'package:dio/dio.dart';

import '../../../core/constants/dodoo_store_api_config.dart';

/// Result of a save call: whether it succeeded, the (new/updated) id if the
/// server returns one, and the raw response for debugging.
class DodooSaveResult {
  const DodooSaveResult({
    required this.ok,
    this.id,
    this.raw,
    this.message,
    this.unreachable = false,
  });
  final bool ok;
  final String? id;
  final dynamic raw;
  final String? message;

  /// True when the call failed because the DoDoo store server couldn't be
  /// reached (timeout / connection error) — i.e. worth auto-retrying later,
  /// as opposed to a real error (bad data, server rejection).
  final bool unreachable;
}

/// Client for the DoDoo **store-management** API (admin side):
/// SaveStore, SaveStoreItem, UpdateWallet, UpdateStoreCurrentStatus.
///
/// SaveStore / SaveStoreItem field names match DoDoo's confirmed contracts.
/// Testing uses Kurnool ("Kurnool" as the `City` name). Two contracts remain
/// unconfirmed and use best-guess shapes (flagged inline): the GET format for
/// UpdateStoreCurrentStatus, and the UpdateWallet UserID/OfferWallet semantics.
class DodooStoreApi {
  DodooStoreApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: DodooStoreApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'Content-Type': 'application/json'},
              validateStatus: (s) => s != null && s < 500,
            ));

  final Dio _dio;

  /// POST /SaveStore — add ([id] == '0') or update a store. Returns the store
  /// id when the server echoes it.
  ///
  /// Field names match DoDoo's SaveStore contract exactly. [city] is the city
  /// NAME (e.g. "Kurnool"), not the code. [categoryId] is DoDoo's category
  /// ObjectId. Coordinates are strings.
  Future<DodooSaveResult> saveStore({
    String id = '0',
    required String storeName,
    required String address,
    required String city,
    required String categoryId,
    required String mobile,
    String? location,
    String email = '',
    String deliveryTime = '40 mins',
    String minOrder = '0',
    String imagePath = '',
    bool isActive = true,
    String showOrder = '1',
    String openTime = '08:00',
    String closeTime = '21:00',
    String longitude = '',
    String lattitude = '',
  }) async {
    final body = <String, dynamic>{
      'id': id, // '0' = insert, else update
      'StoreName': storeName,
      'Address': address,
      'City': city,
      'Category': categoryId,
      'Location': location ?? city,
      'Mobile': mobile,
      'Email': email,
      'DeliveryTime': deliveryTime,
      'MinOrder': minOrder,
      'ImagePath': imagePath,
      'IsActive': isActive,
      'ShowOrder': showOrder,
      'OpenTime': openTime,
      'CloseTime': closeTime,
      'Longitude': longitude,
      'Lattitude': lattitude, // DoDoo spells it "Lattitude"
    };
    return _post('/SaveStore', body);
  }

  /// POST /SaveStoreItem — add ([id] == '0') or update a store item.
  ///
  /// Field names match DoDoo's SaveStoreItem contract exactly. [dishType] is
  /// "Veg" / "Non-veg"; [category] is a category NAME (e.g. "Sweets");
  /// [discountType] is "Percentage" or "Amount"; prices/amounts are strings.
  Future<DodooSaveResult> saveStoreItem({
    String id = '0',
    required String storeId,
    required String dishType,
    required String category,
    required String itemName,
    required String unitPrice,
    String unitType = '1',
    String imagePath = '',
    bool isActive = true,
    String description = '',
    String discountAmount = '0',
    String discountType = 'Percentage', // "Percentage" | "Amount"
  }) async {
    final body = <String, dynamic>{
      'id': id,
      'StoreID': storeId,
      'DishType': dishType,
      'Category': category,
      'ItemName': itemName,
      'UnitPrice': unitPrice,
      'UnitType': unitType,
      'ImagePath': imagePath,
      'isActive': isActive, // lowercase 'i' per the contract
      'Description': description,
      'DiscountAmount': discountAmount,
      'DiscountType': discountType,
    };
    return _post('/SaveStoreItem', body);
  }

  /// POST /UpdateWallet — add balance to a user/store wallet.
  /// Sample contract: {"UserID":"…","OfferWallet":"2"}.
  Future<DodooSaveResult> updateWallet({
    required String userId,
    required num amount,
  }) async {
    return _post('/UpdateWallet', {
      'UserID': userId,
      'OfferWallet': amount.toString(),
    });
  }

  /// POST /UpdateStoreCurrentStatus — set a store open (true) / off (false).
  /// Body: {"id": storeId, "IsStoreOpen": bool} (per the API doc).
  Future<DodooSaveResult> updateStoreCurrentStatus({
    required String storeId,
    required bool on,
  }) async {
    return _post('/UpdateStoreCurrentStatus', {'id': storeId, 'IsStoreOpen': on});
  }

  /// POST /StoreAdminAuthentication — authenticate a store by mobile and return
  /// its DoDoo profile (incl. `id` = DoDoo store id, and `IsStoreOpen`). Default
  /// store password is "dodoo". Used to fetch a store's DoDoo id after SaveStore
  /// (SaveStore's response doesn't include the new id).
  Future<Map<String, dynamic>?> storeAdminAuthentication({
    required String mobile,
    String password = 'dodoo',
  }) async {
    try {
      final res = await _dio.post<dynamic>('/StoreAdminAuthentication', data: {
        'userid': mobile,
        'Pasword': password,
        'reg_id': '',
      });
      final data = res.data;
      if (data is Map && data['status']?.toString() == '1') {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<DodooSaveResult> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await _dio.post<dynamic>(path, data: body);
      final data = res.data;
      // SaveStore/SaveStoreItem/UpdateStoreCurrentStatus reply
      // {"Result":"Insert Success"/"Update Success","Status":"1"} — Result is
      // a status MESSAGE, not an id, so don't treat it as one.
      String? message;
      if (data is Map) {
        message =
            (data['Result'] ?? data['message'] ?? data['Message'])?.toString();
      }
      final statusOk = data is! Map ||
          data['Status']?.toString() == '1' ||
          data['status']?.toString() == '1' ||
          (message?.toLowerCase().contains('success') ?? false);
      final ok = (res.statusCode ?? 500) < 300 && statusOk;
      return DodooSaveResult(ok: ok, raw: data, message: message);
    } on DioException catch (e) {
      final unreachable = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError;
      return DodooSaveResult(
          ok: false, unreachable: unreachable, message: _msg(e));
    }
  }

  String _msg(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'The DoDoo server took too long to respond.';
      case DioExceptionType.connectionError:
        return 'Cannot reach the DoDoo store server.';
      case DioExceptionType.badResponse:
        return 'DoDoo server error (${e.response?.statusCode}).';
      default:
        return 'DoDoo request failed. ${e.message ?? ''}'.trim();
    }
  }
}
