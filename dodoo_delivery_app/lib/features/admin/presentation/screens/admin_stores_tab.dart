import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/dodoo_cities.dart';
import '../../../../core/constants/store_categories.dart';
import '../../../../core/firebase/firebase_refs.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/widgets/city_selector.dart';
import '../../../../core/widgets/fade_in.dart';
import '../../data/dodoo_store_publisher.dart';
import 'admin_store_detail_screen.dart';

/// Admin Stores tab — live list of registered stores with approve/reject flow
/// (via the detail screen). Mirrors the Riders tab. Streams `stores` so new
/// registrations + changes appear instantly and notify the admin.
class AdminStoresTab extends StatefulWidget {
  const AdminStoresTab({super.key});

  @override
  State<AdminStoresTab> createState() => _AdminStoresTabState();
}

class _AdminStoresTabState extends State<AdminStoresTab> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<Map<String, dynamic>> _stores = [];
  String _filter = 'all'; // all | pending | approved | rejected | suspended
  String? _city; // null = all cities
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _loading = true;

  // Stores we've already alerted about needing review (first snapshot silent).
  final Set<String> _notified = {};
  bool _firstSnapshot = true;

  // Auto-retry: stores queued to publish to DoDoo (server was unreachable) are
  // re-attempted in the background. Guards prevent overlap / double-attempts.
  Timer? _retryTimer;
  final Set<String> _publishing = {};
  bool _sweeping = false;
  bool _didInitialSweep = false;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.init();
    _sub = Db.stores.snapshots().listen(_onSnapshot, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
    // Periodically retry any stores queued for DoDoo publish.
    _retryTimer = Timer.periodic(
        const Duration(seconds: 90), (_) => _sweepPendingPublishes());
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _sub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Retries publishing any approved store that was queued because the DoDoo
  /// server was unreachable. Runs in the background (no UI); the stores stream
  /// reflects a successful link automatically. Guarded so sweeps don't overlap
  /// and a store isn't attempted twice at once.
  Future<void> _sweepPendingPublishes() async {
    if (_sweeping) return;
    final targets = _stores
        .where((s) =>
            s['account_status'] == 'approved' &&
            (s['dodoo_store_id']?.toString() ?? '').isEmpty &&
            s['dodoo_publish_pending'] == true &&
            !_publishing.contains(s['id'].toString()))
        .toList();
    if (targets.isEmpty) return;
    _sweeping = true;
    for (final s in targets) {
      final id = s['id'].toString();
      _publishing.add(id);
      try {
        await DodooStorePublisher.publish(storeId: id, store: s);
      } catch (_) {
        // Still unreachable — stays queued; the next tick retries.
      }
      _publishing.remove(id);
    }
    _sweeping = false;
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    final list = snap.docs.map((d) {
      final m = Map<String, dynamic>.from(d.data());
      m['id'] = d.id;
      final ca = m['created_at'];
      if (ca is Timestamp) m['created_at'] = ca.toDate().toIso8601String();
      return m;
    }).toList()
      ..sort((a, b) => (b['created_at']?.toString() ?? '')
          .compareTo(a['created_at']?.toString() ?? ''));

    // Notify for stores that newly need review (new registration or edits).
    final needReview = <String, String>{};
    for (final s in list) {
      if (_needsReview(s)) {
        needReview[s['id'].toString()] =
            (s['store_name'] ?? '').toString().trim().isEmpty
                ? 'A store'
                : s['store_name'].toString();
      }
    }
    final first = _firstSnapshot;
    _firstSnapshot = false;
    var count = 0;
    for (final e in needReview.entries) {
      if (_notified.contains(e.key)) continue;
      _notified.add(e.key);
      if (first || count >= 5) continue;
      count++;
      NotificationService.instance
          .showApproval(
            title: 'Store needs review',
            body: '${e.value} is awaiting your review.',
          )
          .ignore();
    }
    _notified.removeWhere((id) => !needReview.containsKey(id));

    if (mounted) {
      setState(() {
        _stores = list;
        _loading = false;
      });
    }

    // Kick off one retry sweep shortly after the first load (in case the DoDoo
    // server has since come back). The periodic timer handles later attempts.
    if (!_didInitialSweep) {
      _didInitialSweep = true;
      unawaited(_sweepPendingPublishes());
    }
  }

  static bool _needsReview(Map<String, dynamic> s) {
    if (s['account_status'] == 'pending') return true;
    final ppc = s['pending_profile_changes'];
    if (ppc is Map && ppc.isNotEmpty) return true;
    final ds = s['document_status'];
    return ds is Map && ds.values.any((v) => v.toString() == 'pending');
  }

  List<Map<String, dynamic>> get _filtered {
    return _stores.where((s) {
      if (_filter != 'all' && s['account_status'] != _filter) return false;
      if (!DodooCities.addressInCity(s['address']?.toString(), _city) &&
          s['city_code'] != _city &&
          _city != null) {
        return false;
      }
      if (_query.isNotEmpty) {
        final hay =
            '${s['store_name'] ?? ''} ${s['owner_first_name'] ?? ''} ${s['owner_last_name'] ?? ''} ${s['phone'] ?? ''}'
                .toLowerCase();
        if (!hay.contains(_query)) return false;
      }
      return true;
    }).toList();
  }

  Map<String, int> get _counts {
    final c = {'pending': 0, 'approved': 0, 'rejected': 0, 'suspended': 0};
    for (final s in _stores) {
      final st = s['account_status']?.toString() ?? '';
      if (c.containsKey(st)) c[st] = c[st]! + 1;
    }
    return c;
  }

  int get _openCount =>
      _stores.where((s) => s['current_status'] == 'open').length;

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          child: CitySelector(
            value: _city,
            includeAll: true,
            onChanged: (code) => setState(() => _city = code),
          ),
        ),
        if (!_loading)
          _StoreStatsBar(
              total: _stores.length, open: _openCount, counts: _counts),
        _FilterBar(
          active: _filter,
          counts: _counts,
          searchCtrl: _searchCtrl,
          onFilter: (f) => setState(() => _filter = f),
          onSearch: (q) => setState(() => _query = q.trim().toLowerCase()),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? _empty()
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      itemBuilder: (ctx, i) => FadeIn(
                        index: i,
                        child: _StoreCard(
                          store: list[i],
                          onTap: () => Navigator.push(
                            ctx,
                            MaterialPageRoute(
                              builder: (_) => AdminStoreDetailScreen(
                                  storeId: list[i]['id'].toString()),
                            ),
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No stores${_filter == 'all' ? '' : ' ($_filter)'} yet',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
}

// ── Stats bar (fleet overview, matches the Riders tab) ──────────────────────

/// Store overview — mirrors the Riders "Fleet overview": a heading + a
/// horizontal row of gradient stat chips with colored circular icons.
class _StoreStatsBar extends StatelessWidget {
  const _StoreStatsBar({
    required this.total,
    required this.open,
    required this.counts,
  });
  final int total;
  final int open;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, int value, Color color, IconData icon})>[
      (label: 'Total', value: total, color: const Color(0xFFBABC2F), icon: Icons.storefront_rounded),
      (label: 'Open', value: open, color: const Color(0xFF2563EB), icon: Icons.bolt_rounded),
      (label: 'Pending', value: counts['pending'] ?? 0, color: const Color(0xFFD97706), icon: Icons.hourglass_bottom_rounded),
      (label: 'Approved', value: counts['approved'] ?? 0, color: const Color(0xFF059669), icon: Icons.verified_rounded),
      (label: 'Rejected', value: counts['rejected'] ?? 0, color: const Color(0xFFDC2626), icon: Icons.cancel_rounded),
      (label: 'Suspended', value: counts['suspended'] ?? 0, color: const Color(0xFFEA580C), icon: Icons.block_rounded),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(
              children: [
                const Icon(Icons.insights_rounded,
                    size: 16, color: Color(0xFF6B6E00)),
                const SizedBox(width: 6),
                Text('Store overview',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: Colors.grey.shade700)),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  FadeIn(
                    index: i,
                    child: _StoreStatChip(
                      label: items[i].label,
                      value: items[i].value,
                      color: items[i].color,
                      icon: items[i].icon,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreStatChip extends StatelessWidget {
  const _StoreStatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$value',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1.0)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ──────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.active,
    required this.counts,
    required this.searchCtrl,
    required this.onFilter,
    required this.onSearch,
  });
  final String active;
  final Map<String, int> counts;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Filter tabs (same pill style as the Riders section).
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                'all',
                'pending',
                'approved',
                'rejected',
                'suspended',
              ].map((f) {
                final isActive = active == f;
                final count = f == 'all' ? null : counts[f];
                return GestureDetector(
                  onTap: () => onFilter(f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFBABC2F)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _label(f),
                          style: TextStyle(
                            color:
                                isActive ? Colors.white : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (count != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 11,
                                color: isActive
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Search (always visible, live).
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearch,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search store name, owner or phone…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          searchCtrl.clear();
                          onSearch('');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  static String _label(String f) {
    if (f == 'all') return 'All';
    return '${f[0].toUpperCase()}${f.substring(1)}';
  }
}

// ── Store card ──────────────────────────────────────────────────────────────

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store, required this.onTap});
  final Map<String, dynamic> store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = store['account_status']?.toString() ?? 'pending';
    final needsReview = _AdminStoresTabState._needsReview(store);
    final cat = StoreCategories.byKey(store['category']?.toString());
    final photo = store['storefront_photo_url']?.toString() ?? '';
    final name = (store['store_name']?.toString() ?? '').trim();
    final owner =
        '${store['owner_first_name'] ?? ''} ${store['owner_last_name'] ?? ''}'
            .trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: needsReview
            ? const BorderSide(color: Color(0xFFD97706), width: 1.5)
            : BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              // Avatar with a live open/closed status dot (like the rider card).
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFF2F5A0),
                    backgroundImage:
                        photo.isNotEmpty ? NetworkImage(photo) : null,
                    child: photo.isEmpty
                        ? Icon(cat.icon, color: const Color(0xFF8A8C00))
                        : null,
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: store['current_status'] == 'open'
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(name.isEmpty ? 'Unnamed store' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                        if (store['is_verified'] == true) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              size: 15, color: Color(0xFF2563EB)),
                        ],
                        const Spacer(),
                        _StatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${cat.label}  ·  ${owner.isEmpty ? 'No owner' : owner}  ·  ${DodooCities.nameFor(store['city_code']?.toString())}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (needsReview) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: const Text('Needs review',
                            style: TextStyle(
                                color: Color(0xFF92400E),
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      'approved' => (const Color(0xFF065F46), const Color(0xFFD1FAE5)),
      'rejected' => (const Color(0xFF991B1B), const Color(0xFFFEE2E2)),
      'suspended' => (const Color(0xFF9A3412), const Color(0xFFFFEDD5)),
      _ => (const Color(0xFF92400E), const Color(0xFFFEF3C7)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status.isEmpty
            ? status
            : '${status[0].toUpperCase()}${status.substring(1)}',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
