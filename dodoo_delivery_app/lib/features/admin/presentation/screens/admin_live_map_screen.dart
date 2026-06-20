import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/dodoo_cities.dart';
import '../../../../core/constants/map_config.dart';
import '../../../../core/firebase/firebase_refs.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/map_utils.dart';
import '../../../../core/widgets/city_selector.dart';

/// Admin live map — shows ALL riders with their status and last-known/live
/// location. Positions stream in realtime from `rider_tracking`; statuses
/// refresh on a short interval.
class AdminLiveMapScreen extends StatefulWidget {
  const AdminLiveMapScreen({super.key});

  @override
  State<AdminLiveMapScreen> createState() => _AdminLiveMapScreenState();
}

class _RiderRow {
  _RiderRow({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
    this.address,
    this.lat,
    this.lng,
    this.updatedAt,
  });
  final String id;
  final String name;
  final String phone;
  final String status;
  final String? address;
  final double? lat;
  final double? lng;
  final DateTime? updatedAt;

  bool get hasLocation => lat != null && lng != null;
}

class _AdminLiveMapScreenState extends State<AdminLiveMapScreen> {
  GoogleMapController? _map;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _trackSub;
  Timer? _riderTimer;

  /// rider_id → profile {name, phone, status}
  final Map<String, Map<String, dynamic>> _riders = {};
  /// rider_id → tracking {lat, lng, updated_at}
  final Map<String, Map<String, dynamic>> _tracking = {};
  bool _loading = true;
  String? _cityFilter; // null = All cities

  @override
  void initState() {
    super.initState();
    _loadRiders();
    _riderTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _loadRiders(silent: true));
    _subscribeTracking();
  }

  Future<void> _loadRiders({bool silent = false}) async {
    try {
      final snap =
          await Db.riders.where('account_status', isEqualTo: 'approved').get();
      _riders.clear();
      for (final doc in snap.docs) {
        final m = doc.data();
        _riders[doc.id] = {
          'name': '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim(),
          'phone': m['phone']?.toString() ?? '',
          'status': m['current_status']?.toString() ?? 'offline',
          'address': m['address']?.toString() ?? '',
        };
      }
    } catch (_) {/* best-effort */}
    if (mounted) setState(() => _loading = false);
  }

  void _subscribeTracking() {
    // Each rider_tracking doc id is the rider's uid.
    _trackSub = Db.riderTracking.snapshots().listen((snap) {
      if (!mounted) return;
      _tracking.clear();
      for (final doc in snap.docs) {
        final m = Map<String, dynamic>.from(doc.data());
        if (m['updated_at'] is Timestamp) {
          m['updated_at'] =
              (m['updated_at'] as Timestamp).toDate().toIso8601String();
        }
        _tracking[doc.id] = m;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _trackSub?.cancel();
    _riderTimer?.cancel();
    _map?.dispose();
    super.dispose();
  }

  List<_RiderRow> get _rows {
    final list = _riders.entries
        .where((e) =>
            DodooCities.addressInCity(e.value['address'] as String?, _cityFilter))
        .map((e) {
      final t = _tracking[e.key];
      return _RiderRow(
        id: e.key,
        name: (e.value['name'] as String?)?.isNotEmpty == true
            ? e.value['name'] as String
            : 'Rider',
        phone: e.value['phone'] as String? ?? '',
        status: e.value['status'] as String? ?? 'offline',
        address: e.value['address'] as String?,
        lat: t == null ? null : MapUtils.toDouble(t['latitude']),
        lng: t == null ? null : MapUtils.toDouble(t['longitude']),
        updatedAt:
            t == null ? null : DateTime.tryParse(t['updated_at']?.toString() ?? ''),
      );
    }).toList();
    // Online first, then by name.
    list.sort((a, b) {
      int rank(String s) => s == 'online' ? 0 : (s == 'busy' ? 1 : 2);
      final r = rank(a.status).compareTo(rank(b.status));
      return r != 0 ? r : a.name.compareTo(b.name);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final online = rows.where((r) => r.status == 'online').length;
    final located = rows.where((r) => r.hasLocation).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFBABC2F),
        foregroundColor: const Color(0xFF1C1D00),
        title: const Text('Live Riders',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1D00).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$online online • ${rows.length} total',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1D00))),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(MapConfig.defaultLat, MapConfig.defaultLng),
              zoom: 5,
            ),
            onMapCreated: (c) => _map = c,
            markers: _markers(rows),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            padding: const EdgeInsets.only(bottom: 280),
          ),
          if (_loading)
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Loading riders…'),
                  ),
                ),
              ),
            ),
          // Bottom sliding list of all riders.
          DraggableScrollableSheet(
            initialChildSize: 0.32,
            minChildSize: 0.12,
            maxChildSize: 0.85,
            builder: (context, controller) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 12),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        const Text('Riders',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        const Spacer(),
                        Text('$located with live location',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                    child: CitySelector(
                      value: _cityFilter,
                      includeAll: true,
                      label: 'Showing',
                      onChanged: (code) => setState(() => _cityFilter = code),
                    ),
                  ),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(
                            child: Text(_cityFilter == null
                                ? 'No approved riders.'
                                : 'No riders in ${DodooCities.byCode(_cityFilter).name}.'))
                        : ListView.separated(
                            controller: controller,
                            padding: const EdgeInsets.all(12),
                            itemCount: rows.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, i) =>
                                _RiderTile(row: rows[i], onTap: () => _focus(rows[i])),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: located > 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 280),
              child: FloatingActionButton.extended(
                backgroundColor: const Color(0xFFBABC2F),
                foregroundColor: const Color(0xFF1C1D00),
                onPressed: () => _fitAll(rows),
                icon: const Icon(Icons.zoom_out_map_rounded),
                label: const Text('Fit all'),
              ),
            )
          : null,
    );
  }

  Set<Marker> _markers(List<_RiderRow> rows) {
    final markers = <Marker>{};
    for (final r in rows) {
      if (!r.hasLocation) continue;
      markers.add(Marker(
        markerId: MarkerId(r.id),
        position: LatLng(r.lat!, r.lng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(_hue(r.status)),
        infoWindow: InfoWindow(
          title: r.name,
          snippet: '${r.phone} • ${r.status}',
        ),
      ));
    }
    return markers;
  }

  double _hue(String status) => switch (status) {
        'online' => BitmapDescriptor.hueGreen,
        'busy' => BitmapDescriptor.hueOrange,
        _ => BitmapDescriptor.hueAzure,
      };

  Future<void> _focus(_RiderRow r) async {
    if (!r.hasLocation || _map == null) return;
    await _map!
        .animateCamera(CameraUpdate.newLatLngZoom(LatLng(r.lat!, r.lng!), 15));
  }

  Future<void> _fitAll(List<_RiderRow> rows) async {
    if (_map == null) return;
    final pts = [
      for (final r in rows)
        if (r.hasLocation) LatLng(r.lat!, r.lng!)
    ];
    final bounds = MapUtils.boundsFromPoints(pts);
    if (bounds == null) return;
    if (pts.length == 1) {
      await _map!.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 14));
    } else {
      await _map!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    }
  }
}

class _RiderTile extends StatelessWidget {
  const _RiderTile({required this.row, required this.onTap});
  final _RiderRow row;
  final VoidCallback onTap;

  Color get _statusColor => switch (row.status) {
        'online' => AppColors.online,
        'busy' => AppColors.busy,
        _ => AppColors.offline,
      };

  static String _ago(DateTime? t) {
    if (t == null) return 'unknown';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: row.hasLocation ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: _statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(row.phone,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(row.status.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _statusColor)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        row.hasLocation
                            ? (row.status == 'online'
                                ? Icons.my_location_rounded
                                : Icons.location_on_outlined)
                            : Icons.location_off_outlined,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        row.hasLocation
                            ? '${row.lat!.toStringAsFixed(4)}, ${row.lng!.toStringAsFixed(4)}'
                            : 'No location',
                        style: TextStyle(
                            fontSize: 10.5, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  if (row.hasLocation && row.status != 'online')
                    Text(
                      'last seen ${_ago(row.updatedAt)}',
                      style:
                          TextStyle(fontSize: 9.5, color: Colors.grey.shade400),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
