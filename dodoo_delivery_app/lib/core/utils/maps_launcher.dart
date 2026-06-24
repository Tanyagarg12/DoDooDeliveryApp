import 'package:url_launcher/url_launcher.dart';

/// Opens the Google Maps app (or browser) with driving directions to a
/// destination. Works WITHOUT coordinates by falling back to the address text —
/// important because DoDoo store orders often have no lat/lng.
///
/// Returns true if a maps app/browser was launched.
Future<bool> openDirections({
  double? lat,
  double? lng,
  String? address,
}) async {
  String destination;
  if (lat != null && lng != null) {
    destination = '$lat,$lng';
  } else if ((address ?? '').trim().isNotEmpty) {
    destination = Uri.encodeComponent(address!.trim());
  } else {
    return false; // nothing to navigate to
  }

  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=$destination&travelmode=driving',
  );
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}

/// Helper that reads the typical order map and navigates to the right leg:
/// before pickup → the pickup/store; after pickup → the drop address.
Future<bool> openOrderDirections(
  Map<String, dynamic> order, {
  required bool toPickup,
}) {
  num? toNum(dynamic v) =>
      v is num ? v : (v is String ? num.tryParse(v) : null);
  final lat = toNum(order[toPickup ? 'from_latitude' : 'to_latitude']);
  final lng = toNum(order[toPickup ? 'from_longitude' : 'to_longitude']);
  final address = (toPickup
          ? order['from_address']
          : (order['to_address'] ?? order['landmark_address']))
      ?.toString();
  return openDirections(
    lat: lat?.toDouble(),
    lng: lng?.toDouble(),
    address: address,
  );
}
