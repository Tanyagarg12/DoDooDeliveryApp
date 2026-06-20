import 'dart:math' as math;

/// The kind of DoDoo order, derived from the OrderID prefix.
enum DodooOrderType { pickDrop, store, unknown }

/// A single order from the external DoDoo platform API. Tolerant of missing
/// fields (the list and the two detail endpoints share most keys but not all).
class DodooOrder {
  const DodooOrder({
    required this.raw,
    required this.orderId,
    this.status,
    this.name,
    this.contactNo,
    this.pickAddress,
    this.dropAddress,
    this.pickLat,
    this.pickLng,
    this.dropLat,
    this.dropLng,
    this.price,
    this.totPrice,
    this.itemsCategory,
    this.desc,
    this.notes,
    this.paymentMode,
    this.cityCode,
    this.orderDate,
    this.storeName,
    this.title,
  });

  final Map<String, dynamic> raw;
  final String orderId;
  final String? status;
  final String? name;
  final String? contactNo;
  final String? pickAddress;
  final String? dropAddress;
  final double? pickLat;
  final double? pickLng;
  final double? dropLat;
  final double? dropLng;
  final double? price;
  final double? totPrice;
  final String? itemsCategory;
  final String? desc;
  final String? notes;
  final String? paymentMode;
  final String? cityCode;
  final String? orderDate;
  final String? storeName;
  final String? title;

  DodooOrderType get type {
    final id = orderId.toUpperCase();
    if (id.startsWith('PDP')) return DodooOrderType.pickDrop;
    if (id.startsWith('STOR')) return DodooOrderType.store;
    return DodooOrderType.unknown;
  }

  /// The API returns a placeholder row with Title "No Data Found" / id "0"
  /// when an order isn't found.
  bool get isNoData =>
      (title?.toLowerCase().contains('no data') ?? false) ||
      raw['id']?.toString() == '0' ||
      orderId.isEmpty;

  double? get earning => totPrice ?? price;

  factory DodooOrder.fromJson(Map<String, dynamic> j) {
    return DodooOrder(
      raw: j,
      orderId: (j['OrderID'] ?? '').toString(),
      status: j['Status']?.toString(),
      name: j['Name']?.toString(),
      contactNo: j['ContactNo']?.toString(),
      pickAddress: j['PickpAddress']?.toString(),
      dropAddress: j['DropAddress']?.toString(),
      // Pick/Drop has Pick* + Drop*; Store has Lattitude/Longitude (store loc).
      pickLat: _d(j['PickLattitude'] ?? j['Lattitude']),
      pickLng: _d(j['PickLongitude'] ?? j['Longitude']),
      dropLat: _d(j['DropLattitude']),
      dropLng: _d(j['DropLongitude']),
      price: _d(j['Price']),
      totPrice: _d(j['TotPrice']),
      itemsCategory: j['ItemsCategory']?.toString(),
      desc: j['Desc']?.toString(),
      notes: j['Notes']?.toString(),
      paymentMode: j['PaymentMode']?.toString(),
      cityCode: j['CityCode']?.toString(),
      orderDate: (j['OrderDate'] ?? j['Date'])?.toString(),
      storeName: j['StoreName']?.toString(),
      title: j['Title']?.toString(),
    );
  }

  /// A human-readable items summary for display + the rider's order card.
  String get itemsSummary {
    final parts = <String>[];
    if ((storeName ?? '').isNotEmpty) parts.add(storeName!);
    if ((itemsCategory ?? '').isNotEmpty) parts.add(itemsCategory!);
    if ((desc ?? '').isNotEmpty) parts.add(desc!);
    if (parts.isEmpty && (notes ?? '').isNotEmpty) parts.add(notes!);
    return parts.join(' • ');
  }

  /// Maps this external order onto our Supabase `orders` columns so it can be
  /// imported and run through the existing rider-offer workflow.
  ///
  /// [pricePerKm] is used as a fallback fare when the DoDoo order carries no
  /// price (earning = distance × rate).
  ///
  /// [cityCodeOverride] stamps the order with the city it was fetched for (the
  /// admin's selected city), falling back to whatever the API returned.
  Map<String, dynamic> toSupabaseOrder({double? pricePerKm, String? cityCodeOverride}) {
    final dist = _distanceKm();
    var fare = earning ?? 0;
    if (fare <= 0 && pricePerKm != null && dist != null) {
      fare = double.parse((dist * pricePerKm).toStringAsFixed(2));
    }
    return {
      'order_number': orderId,
      'status': 'pending',
      'city_code': cityCodeOverride ?? cityCode,
      'from_address': pickAddress ?? '',
      'from_latitude': pickLat,
      'from_longitude': pickLng,
      'to_address': dropAddress ?? '',
      'to_latitude': dropLat,
      'to_longitude': dropLng,
      if (dist != null) 'distance_in_km': double.parse(dist.toStringAsFixed(2)),
      if (dist != null)
        'estimated_time_minutes': (dist * 4).round().clamp(5, 240),
      'total_earning': fare,
      'minimum_fare': price ?? fare,
      'customer_name': name ?? '',
      'customer_phone': contactNo ?? '',
      'items_description': itemsSummary,
      'status_updated_at': DateTime.now().toIso8601String(),
    };
  }

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
