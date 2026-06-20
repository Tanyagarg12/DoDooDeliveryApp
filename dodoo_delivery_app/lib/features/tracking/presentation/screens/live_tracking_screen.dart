import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/rider_firestore_api.dart';
import '../../../../core/constants/map_config.dart';
import '../../../../core/constants/support_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/map_utils.dart';
import '../../data/location_tracking_service.dart';
import '../../data/tracking_repository.dart';

/// Full-screen live tracking for one active delivery.
///
/// Shows the rider's live GPS marker (following the device), the pickup and
/// drop markers, the optimized driving route, and a bottom panel with the
/// delivery status stepper + actions (advance status, navigate, call customer).
///
/// Pops with the latest order status [String] so the caller can refresh.
class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key, required this.order});

  final Map<String, dynamic> order;

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final _tracker = LocationTrackingService.instance;
  final _repo = TrackingRepository();
  final _api = RiderFirestoreApi();

  GoogleMapController? _map;
  StreamSubscription<Position>? _posSub;

  LatLng? _riderPos;
  List<LatLng> _route = const [];
  RouteResult? _routeInfo;
  bool _followRider = true;
  bool _busy = false;
  String _status = 'accepted';
  String? _error;

  // Delivery status flow — matches the backend status strings used elsewhere.
  static const _flow = [
    'accepted',
    'picked_up',
    'in_transit',
    'reached',
    'completed',
  ];
  static const _flowLabels = {
    'accepted': 'Going to Pickup',
    'picked_up': 'Picked Up',
    'in_transit': 'On the Way',
    'reached': 'Reached Destination',
    'completed': 'Delivered',
  };

  String get _orderId => widget.order['id']?.toString() ?? '';

  LatLng? get _pickup {
    final lat = MapUtils.toDouble(widget.order['from_latitude']);
    final lng = MapUtils.toDouble(widget.order['from_longitude']);
    return (lat != null && lng != null) ? LatLng(lat, lng) : null;
  }

  LatLng? get _drop {
    final lat = MapUtils.toDouble(widget.order['to_latitude']);
    final lng = MapUtils.toDouble(widget.order['to_longitude']);
    return (lat != null && lng != null) ? LatLng(lat, lng) : null;
  }

  @override
  void initState() {
    super.initState();
    _status = widget.order['status']?.toString() ?? 'accepted';
    _init();
  }

  Future<void> _init() async {
    final readiness = await _tracker.start(orderId: _orderId);
    if (!mounted) return;
    if (readiness != LocationReadiness.ready) {
      setState(() => _error = _readinessMessage(readiness));
      return;
    }

    // Seed with a one-shot fix so the map centres immediately.
    final first = _tracker.lastPosition ?? await _tracker.currentPosition();
    if (mounted && first != null) {
      setState(() => _riderPos = LatLng(first.latitude, first.longitude));
    }

    _posSub = _tracker.stream.listen(_onPosition);
    _loadRoute();
  }

  void _onPosition(Position pos) {
    if (!mounted) return;
    setState(() => _riderPos = LatLng(pos.latitude, pos.longitude));
    if (_followRider && _map != null) {
      _map!.animateCamera(
        CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
      );
    }
  }

  /// Builds the route from the rider's current position (or pickup) to the
  /// destination, choosing the relevant leg based on delivery stage.
  Future<void> _loadRoute() async {
    final drop = _drop;
    if (drop == null) return;

    // Before pickup → route to pickup; after pickup → route to drop.
    final beforePickup = _status == 'accepted';
    final origin = _riderPos ?? _pickup ?? drop;
    final destination = beforePickup ? (_pickup ?? drop) : drop;

    final result = await _repo.fetchRoute(origin: origin, destination: destination);
    if (!mounted) return;
    setState(() {
      _route = result.points;
      _routeInfo = result;
    });
    _fitBounds();
  }

  Future<void> _fitBounds() async {
    if (_map == null) return;
    final pts = <LatLng>[
      ?_riderPos,
      ?_pickup,
      ?_drop,
      ..._route,
    ];
    final bounds = MapUtils.boundsFromPoints(pts);
    if (bounds == null) return;
    await _map!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _advance(String next) async {
    setState(() => _busy = true);
    try {
      await _api.updateOrderStatus(_orderId, next);
      if (!mounted) return;
      setState(() => _status = next);
      if (next == 'completed') {
        await _tracker.stop();
        if (mounted) Navigator.pop(context, _status);
        return;
      }
      _loadRoute(); // re-route for the new leg
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update status: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _navigate() async {
    final target = _status == 'accepted' ? (_pickup ?? _drop) : _drop;
    if (target == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${target.latitude},${target.longitude}&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Riders never get the customer's number — calls go to support instead.
  Future<void> _callSupport() async {
    final uri = Uri.parse('tel:${SupportConfig.supportPhone}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _map?.dispose();
    // Note: we intentionally do NOT stop the tracker here — tracking should
    // continue in the background until the delivery is completed or the rider
    // goes offline. It is stopped on 'completed' and on going offline.
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final initial = _riderPos ??
        _pickup ??
        _drop ??
        const LatLng(MapConfig.defaultLat, MapConfig.defaultLng);

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initial,
              zoom: MapConfig.defaultZoom,
            ),
            onMapCreated: (c) {
              _map = c;
              _fitBounds();
            },
            markers: _markers(),
            polylines: _polylines(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            zoomControlsEnabled: false,
            padding: const EdgeInsets.only(bottom: 280),
            onCameraMoveStarted: () {
              // User dragged the map → stop auto-follow until they recenter.
              if (_followRider) setState(() => _followRider = false);
            },
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _CircleBtn(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context, _status),
                  ),
                  const Spacer(),
                  if (_routeInfo?.isOptimized == true &&
                      _routeInfo?.durationText != null)
                    _Pill(
                      icon: Icons.alt_route_rounded,
                      label:
                          '${_routeInfo!.durationText} • ${_routeInfo!.distanceText}',
                    ),
                ],
              ),
            ),
          ),

          // Recenter FAB
          Positioned(
            right: 12,
            bottom: 296,
            child: _CircleBtn(
              icon: _followRider
                  ? Icons.my_location_rounded
                  : Icons.location_searching_rounded,
              onTap: () {
                setState(() => _followRider = true);
                if (_riderPos != null) {
                  _map?.animateCamera(CameraUpdate.newLatLng(_riderPos!));
                }
              },
            ),
          ),

          if (_error != null) _ErrorBanner(message: _error!, onRetry: _init),

          // Bottom status + actions panel
          Align(
            alignment: Alignment.bottomCenter,
            child: _StatusPanel(
              order: widget.order,
              status: _status,
              flow: _flow,
              labels: _flowLabels,
              busy: _busy,
              onAdvance: _advance,
              onNavigate: _navigate,
              onCallSupport: _callSupport,
            ),
          ),
        ],
      ),
    );
  }

  Set<Marker> _markers() {
    final markers = <Marker>{};
    if (_pickup != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickup!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Pickup',
          snippet: widget.order['from_address']?.toString(),
        ),
      ));
    }
    if (_drop != null) {
      markers.add(Marker(
        markerId: const MarkerId('drop'),
        position: _drop!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Drop',
          snippet: widget.order['to_address']?.toString(),
        ),
      ));
    }
    if (_riderPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('rider'),
        position: _riderPos!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        flat: true,
        anchor: const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(title: 'You'),
      ));
    }
    return markers;
  }

  Set<Polyline> _polylines() {
    if (_route.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _route,
        color: AppColors.primary,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  String _readinessMessage(LocationReadiness r) {
    switch (r) {
      case LocationReadiness.serviceDisabled:
        return 'Location services are turned off. Enable GPS to start tracking.';
      case LocationReadiness.denied:
        return 'Location permission denied. Grant access to share your live location.';
      case LocationReadiness.deniedForever:
        return 'Location permission permanently denied. Enable it in app settings.';
      case LocationReadiness.ready:
        return '';
    }
  }
}

// ── Bottom status panel ─────────────────────────────────────────────────────

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.order,
    required this.status,
    required this.flow,
    required this.labels,
    required this.busy,
    required this.onAdvance,
    required this.onNavigate,
    required this.onCallSupport,
  });

  final Map<String, dynamic> order;
  final String status;
  final List<String> flow;
  final Map<String, String> labels;
  final bool busy;
  final void Function(String next) onAdvance;
  final VoidCallback onNavigate;
  final VoidCallback onCallSupport;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final step = flow.indexOf(status);
    final next = (step >= 0 && step < flow.length - 1) ? flow[step + 1] : null;
    final customer = order['customer_name']?.toString() ?? '';
    final items = (order['items_description'] ?? order['items'])?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.delivery_dining_rounded,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order #${order['order_number'] ?? '—'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    labels[status] ?? status,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onPrimaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Customer + items details (no phone number — privacy).
            if (customer.isNotEmpty || items.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : const Color(0xFFF8FAF0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (customer.isNotEmpty)
                      _DetailLine(
                          icon: Icons.person_rounded, label: 'Customer', value: customer),
                    if (items.isNotEmpty) ...[
                      if (customer.isNotEmpty) const SizedBox(height: 8),
                      _DetailLine(
                          icon: Icons.inventory_2_rounded, label: 'Items', value: items),
                    ],
                  ],
                ),
              ),

            _Stepper(flow: flow, labels: labels, current: step),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('Navigate'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: cs.primary,
                      side: BorderSide(color: cs.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCallSupport,
                    icon: const Icon(Icons.support_agent_rounded, size: 18),
                    label: const Text('Support'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: AppColors.online,
                      side: const BorderSide(color: AppColors.online),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (busy || next == null) ? null : () => onAdvance(next),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onPrimary),
                      )
                    : Icon(
                        next == 'completed'
                            ? Icons.check_circle_rounded
                            : Icons.arrow_forward_rounded,
                        size: 18),
                label: Text(
                  next == null
                      ? 'Delivery Complete'
                      : 'Mark: ${labels[next] ?? next}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper(
      {required this.flow, required this.labels, required this.current});
  final List<String> flow;
  final Map<String, String> labels;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(flow.length, (i) {
        final done = i <= current;
        final active = i == current;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: active ? 26 : 18,
                      height: active ? 26 : 18,
                      decoration: BoxDecoration(
                        color: done ? AppColors.primary : Colors.transparent,
                        border: Border.all(
                          color: done ? AppColors.primary : AppColors.offline,
                          width: active ? 2.5 : 1.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: done
                          ? Icon(Icons.check_rounded,
                              size: active ? 13 : 10, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[flow[i]] ?? flow[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8.5,
                        height: 1.1,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w400,
                        color: done ? AppColors.primary : AppColors.offline,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < flow.length - 1)
                Container(
                  width: 16,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 22),
                  color: i < current
                      ? AppColors.primary
                      : AppColors.offline.withValues(alpha: 0.3),
                ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Small shared widgets ────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({
    required this.icon,
    required this.onTap,
  });
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : Colors.white;
    final fg = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: bg,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 22, color: fg),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      top: 70,
      child: Material(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.location_off_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5)),
              ),
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
