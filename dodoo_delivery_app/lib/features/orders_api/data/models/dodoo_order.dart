import 'dart:math' as math;

/// The kind of DoDoo order.
enum DodooOrderType { pickDrop, store, unknown }

/// A single order from the external DoDoo platform API. Tolerant of missing
/// fields (the list endpoint is sparse; the two detail endpoints are full).
class DodooOrder {
  const DodooOrder({
    required this.raw,
    required this.orderId,
    this.status,
    this.name,
    this.contactNo,
    this.pickAddress,
    this.dropAddress,
    this.landmarkDropAddress,
    this.pickLat,
    this.pickLng,
    this.dropLat,
    this.dropLng,
    this.price,
    this.totPrice,
    this.deliveryCharge,
    this.tax,
    this.walletAmount,
    this.itemsCategory,
    this.desc,
    this.notes,
    this.paymentMode,
    this.cityCode,
    this.orderDate,
    this.orderType,
    this.storeId,
    this.storeName,
    this.validationCode,
    this.cartItems = const [],
    this.title,
  });

  final Map<String, dynamic> raw;
  final String orderId;
  final String? status;
  final String? name;
  final String? contactNo;
  final String? pickAddress;
  final String? dropAddress;
  final String? landmarkDropAddress;
  final double? pickLat;
  final double? pickLng;
  final double? dropLat;
  final double? dropLng;
  final double? price;
  final double? totPrice;
  final double? deliveryCharge;
  final double? tax;
  final double? walletAmount;
  final String? itemsCategory;
  final String? desc;
  final String? notes;
  final String? paymentMode;
  final String? cityCode;
  final String? orderDate;
  final String? orderType;
  final String? storeId;
  final String? storeName;
  final String? validationCode;
  final List<Map<String, dynamic>> cartItems;
  final String? title;

  DodooOrderType get type {
    final t = orderType?.toLowerCase();
    if (t == 'store') return DodooOrderType.store;
    if (t == 'pickdrop' || t == 'pick/drop') return DodooOrderType.pickDrop;
    final id = orderId.toUpperCase();
    if (id.contains('STOR')) return DodooOrderType.store;
    if (id.contains('PDP')) return DodooOrderType.pickDrop;
    return DodooOrderType.unknown;
  }

  /// The API returns a placeholder row with Title "No Data Found" / id "0"
  /// when an order isn't found.
  bool get isNoData =>
      (title?.toLowerCase().contains('no data') ?? false) ||
      raw['id']?.toString() == '0' ||
      orderId.isEmpty;

  /// The rider's earning. Store orders pay the delivery charge; pick/drop
  /// orders carry the fare in price/totPrice.
  double? get earning {
    if (type == DodooOrderType.store && (deliveryCharge ?? 0) > 0) {
      return deliveryCharge;
    }
    return totPrice ?? price ?? deliveryCharge;
  }

  /// Promotion/discount applied = (items + delivery + tax) − wallet − total.
  /// Returns 0 when there's no discount (so the row still shows "₹0").
  double? get promotion {
    if (price == null || totPrice == null) return null;
    final gross = price! + (deliveryCharge ?? 0) + (tax ?? 0);
    final p = gross - (walletAmount ?? 0) - totPrice!;
    return p > 0.5 ? double.parse(p.toStringAsFixed(2)) : 0;
  }

  /// Maps DoDoo's status word to our internal order status, so an imported
  /// order shows its real state (not always "pending").
  String get internalStatus {
    switch ((status ?? '').toLowerCase()) {
      // Mirror of DodooOrderApi.dodooStatusFor (kept in sync for round-trips):
      //   DoDoo "InProgress" == our "accepted"   (rider accepted)
      //   DoDoo "Accept"     == our "picked_up"  (rider picked up)
      case 'inprogress':
        return 'accepted';
      case 'accept':
      case 'accepted':
      case 'assigned':
      case 'pickedup':
        return 'picked_up';
      case 'ongoing':
        return 'in_transit';
      case 'deliver': // GetAllTypeOrdersByStore status word
      case 'delivered':
      case 'completed':
        return 'completed';
      case 'cancel': // GetAllTypeOrdersByStore status word
      case 'cancelled':
      case 'canceled':
        return 'cancelled';
      default: // Open / New / Pending / unknown
        return 'pending';
    }
  }

  /// Where the rider picks up. Store orders have no PickpAddress — the pickup
  /// is the store (whose readable name is in StoreID in the DoDoo data).
  String get pickupDisplay {
    if ((pickAddress ?? '').isNotEmpty) return pickAddress!;
    if ((storeId ?? '').isNotEmpty) return storeId!;
    return storeName ?? '';
  }

  factory DodooOrder.fromJson(Map<String, dynamic> j) {
    final cart = j['cartItems'];
    final items = cart is List
        ? cart
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    return DodooOrder(
      raw: j,
      orderId: (j['OrderID'] ?? '').toString(),
      status: j['Status']?.toString(),
      name: j['Name']?.toString(),
      contactNo: j['ContactNo']?.toString(),
      pickAddress: j['PickpAddress']?.toString(),
      dropAddress: j['DropAddress']?.toString(),
      landmarkDropAddress: j['LandMarkDropAddress']?.toString(),
      pickLat: _d(j['PickLattitude'] ?? j['Lattitude']),
      pickLng: _d(j['PickLongitude'] ?? j['Longitude']),
      dropLat: _d(j['DropLattitude']),
      dropLng: _d(j['DropLongitude']),
      price: _d(j['Price']),
      totPrice: _d(j['TotPrice']),
      deliveryCharge: _d(j['DeliveryCharge']),
      tax: _d(j['Tax']),
      walletAmount: _d(j['WalletAmount']),
      itemsCategory: j['ItemsCategory']?.toString(),
      desc: j['Desc']?.toString(),
      notes: j['Notes']?.toString(),
      paymentMode: j['PaymentMode']?.toString(),
      cityCode: j['CityCode']?.toString(),
      orderDate: (j['OrderDate'] ?? j['Date'])?.toString(),
      orderType: j['OrderType']?.toString(),
      storeId: j['StoreID']?.toString(),
      storeName: j['StoreName']?.toString(),
      validationCode: j['ValidationCode']?.toString(),
      cartItems: items,
      title: j['Title']?.toString(),
    );
  }

  /// A human-readable items summary, e.g. "Meals ×1 • Chapathi 2 ×2 • Dhal Fry ×1".
  String get itemsSummary {
    if (cartItems.isNotEmpty) {
      return cartItems.map((i) {
        final t = (i['Title'] ?? 'Item').toString();
        final q = (i['Qty'] ?? '1').toString();
        return '$t ×$q';
      }).join(' • ');
    }
    final parts = <String>[];
    if ((itemsCategory ?? '').isNotEmpty) parts.add(itemsCategory!);
    if ((desc ?? '').isNotEmpty) parts.add(desc!);
    if (parts.isEmpty && (notes ?? '').isNotEmpty) parts.add(notes!);
    return parts.join(' • ');
  }

  /// Default order distance (km) used until DoDoo provides pickup/drop
  /// coordinates. Rider earning is distance × per-km rate, so this drives it.
  static const double _defaultDistanceKm = 2.0;

  /// Maps this external order onto our `orders` columns so it can be imported
  /// and run through the rider-offer workflow.
  ///
  /// The rider's earning = [baseFare] + (order distance (km) × [pricePerKm]),
  /// both set by the admin (per-km is per city, base is flat). Distance comes
  /// from the pickup/drop coordinates when DoDoo sends them; until then it
  /// defaults to [_defaultDistanceKm] (2 km). So once the API returns
  /// coordinates, the km and earning update automatically — no code change.
  /// [cityCodeOverride] stamps the city the order was fetched for.
  Map<String, dynamic> toSupabaseOrder({
    double? pricePerKm,
    double? baseFare,
    double? minDeliveryCharge,
    double? pickDropCharge,
    String? cityCodeOverride,
  }) {
    final dist = _distanceKm() ?? _defaultDistanceKm;
    final rate = pricePerKm ?? 0;
    final base = baseFare ?? 0;
    final minFare = minDeliveryCharge ?? 0;
    final pdpCharge = pickDropCharge ?? 0;

    // Pick & Drop (PDP) orders pay a flat configured charge; store orders pay
    // base + km×rate, never below the configured minimum delivery charge.
    final double riderEarningRaw;
    if (type == DodooOrderType.pickDrop) {
      riderEarningRaw = pdpCharge;
    } else {
      final calc = base + dist * rate;
      riderEarningRaw = calc < minFare ? minFare : calc;
    }
    final riderEarning = double.parse(riderEarningRaw.toStringAsFixed(2));
    return {
      'order_number': orderId,
      'status': internalStatus,
      // Prefer the order's OWN city code; fall back to the city we synced for.
      'city_code': (cityCode != null && cityCode!.isNotEmpty)
          ? cityCode
          : cityCodeOverride,
      'order_type': orderType ?? type.name,
      'from_address': pickupDisplay,
      'from_latitude': pickLat,
      'from_longitude': pickLng,
      'to_address': dropAddress ?? '',
      if ((landmarkDropAddress ?? '').isNotEmpty)
        'landmark_address': landmarkDropAddress,
      'to_latitude': dropLat,
      'to_longitude': dropLng,
      'distance_in_km': double.parse(dist.toStringAsFixed(2)),
      'estimated_time_minutes': (dist * 4).round().clamp(5, 240),
      // Rider earning (NOT DoDoo's charge). Store the inputs so the breakdown
      // can be shown consistently (km×rate, base, min floor, PDP flat charge).
      'per_km_rate': rate,
      'base_fare': base,
      'min_fare': minFare,
      'total_earning': riderEarning,
      'minimum_fare': riderEarning,
      // Full customer bill + breakdown, for the order detail screen.
      if (price != null) 'items_subtotal': price,
      if (totPrice != null) 'order_total': totPrice,
      if (deliveryCharge != null) 'delivery_charge': deliveryCharge,
      if (tax != null) 'tax': tax,
      if (walletAmount != null) 'wallet_amount': walletAmount,
      if (promotion != null) 'promotion': promotion,
      'customer_name': name ?? '',
      'customer_phone': contactNo ?? '',
      'store_name': storeId ?? storeName ?? '',
      'items_description': itemsSummary,
      'cart_items': cartItems,
      if ((validationCode ?? '').isNotEmpty) 'validation_code': validationCode,
      if ((paymentMode ?? '').isNotEmpty) 'payment_mode': paymentMode,
      // Use the real DoDoo order time as created_at so the list sorts by when
      // the order was actually placed (latest on top) — keeps old backfilled
      // history at the bottom instead of jumping to the top on each sync.
      if (_placedAt() != null) 'created_at': _placedAt(),
      // The original DoDoo order date, shown on the order detail screen.
      if ((orderDate ?? '').isNotEmpty) 'order_date': orderDate,
      'status_updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Parses the DoDoo OrderDate ("2021-02-22 10:11:24") to a DateTime.
  DateTime? _placedAt() =>
      orderDate == null ? null : DateTime.tryParse(orderDate!);

  double? _distanceKm() {
    if (pickLat == null || pickLng == null || dropLat == null || dropLng == null) {
      return null;
    }
    const r = 6371.0;
    final dLat = (dropLat! - pickLat!) * math.pi / 180;
    final dLon = (dropLng! - pickLng!) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(pickLat! * math.pi / 180) *
            math.cos(dropLat! * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.asin(math.sqrt(a));
  }

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
