import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/dodoo_cities.dart';
import '../../../../core/services/notification_center.dart';
import '../../../../core/widgets/city_selector.dart';
import '../../../../core/widgets/fade_in.dart';
import '../../../../core/widgets/support_modal.dart';
import '../../../notifications/presentation/notifications_screen.dart';
import '../../domain/entities/admin_entities.dart';
import '../controllers/admin_controller.dart';
import '../controllers/admin_state.dart';
import 'admin_live_map_screen.dart';
import 'admin_login_screen.dart';
import 'admin_orders_tab.dart';
import 'admin_profile_screen.dart';
import 'admin_rider_detail_screen.dart';
import 'admin_settings_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  String _activeFilter = 'all';
  String? _riderCity; // null = All cities (filters the Riders tab by address)
  final _searchCtrl = TextEditingController();
  late final TabController _tab;
  final _ordersKey = GlobalKey<AdminOrdersTabState>();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    AdminProfile.instance.load();
    NotificationCenter.instance.load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String? get _token =>
      ref.read(adminAuthControllerProvider.notifier).token;

  Future<void> _load({bool silent = false}) async {
    final token = _token;
    if (token == null) return;
    await ref.read(adminRiderListControllerProvider.notifier).load(
          token,
          filter: _activeFilter,
          search: _searchCtrl.text.trim(),
          silent: silent,
        );
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(adminRiderListControllerProvider);
    final authState = ref.watch(adminAuthControllerProvider);

    final adminName = authState is AdminAuthenticated
        ? authState.admin.name.isNotEmpty
            ? authState.admin.name
            : authState.admin.username
        : 'Admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7E8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFBABC2F),
        foregroundColor: const Color(0xFF1C1D00),
        elevation: 0,
        scrolledUnderElevation: 2,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFCED03F), Color(0xFFBABC2F), Color(0xFFA6A828)],
            ),
          ),
        ),
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1D00).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.person_rounded, size: 18),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Image.asset(
                'assets/images/dodoo_status.png',
                height: 28,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorBuilder: (_, _, _) => const Text('DoDoo Admin',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, letterSpacing: 0.2)),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFF1C1D00),
          indicatorWeight: 3,
          labelColor: const Color(0xFF1C1D00),
          unselectedLabelColor: const Color(0xFF1C1D00).withValues(alpha: 0.55),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Orders'),
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'Riders'),
          ],
        ),
        actions: [
          // Only the two most-used quick actions stay as icons; everything
          // else lives in the account menu so the bar never crowds on phones.
          const _BarBell(),
          _BarButton(
            icon: Icons.map_rounded,
            tooltip: 'Live Riders',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminLiveMapScreen()),
            ),
          ),
          const SizedBox(width: 2),
          PopupMenuButton<String>(
            tooltip: 'Account',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            icon: AdminAvatar(name: adminName, radius: 17),
            onSelected: (value) async {
              switch (value) {
                case 'refresh':
                  _load();
                  _ordersKey.currentState?.load(silent: true);
                case 'support':
                  showSupportSheet(context);
                case 'profile':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminProfileScreen()),
                  );
                  if (mounted) setState(() {});
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminSettingsScreen()),
                  );
                case 'logout':
                  await ref.read(adminAuthControllerProvider.notifier).logout();
                  if (!mounted) return;
                  // ignore: use_build_context_synchronously
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text('Signed in as $adminName',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'refresh',
                child: _MenuRow(Icons.refresh_rounded, 'Refresh'),
              ),
              const PopupMenuItem(
                value: 'support',
                child: _MenuRow(Icons.support_agent_rounded, 'Help & Support'),
              ),
              const PopupMenuItem(
                value: 'profile',
                child: _MenuRow(Icons.account_circle_outlined, 'Profile'),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: _MenuRow(Icons.settings_outlined, 'Settings'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: _MenuRow(Icons.logout_rounded, 'Logout',
                    color: Color(0xFFDC2626)),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ── Tab 1: Orders (auto-synced from DoDoo + monitor) ───────────
          AdminOrdersTab(key: _ordersKey),

          // ── Tab 2: Riders (approve / reject / manage) ──────────────────
          Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                child: CitySelector(
                  value: _riderCity,
                  includeAll: true,
                  onChanged: (code) => setState(() => _riderCity = code),
                ),
              ),
              if (listState is AdminRiderListLoaded && listState.stats != null)
                _StatsBar(stats: listState.stats!),
              _FilterBar(
                activeFilter: _activeFilter,
                searchCtrl: _searchCtrl,
                counts: listState is AdminRiderListLoaded
                    ? listState.counts
                    : const {},
                onFilterChanged: (f) {
                  setState(() => _activeFilter = f);
                  _load();
                },
                onSearchSubmit: (_) {
                  setState(() {}); // refresh the clear button
                  _load(silent: true);
                },
              ),
              Expanded(child: _buildBody(listState)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AdminRiderListState state) {
    if (state is AdminRiderListLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is AdminRiderListError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(state.message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (state is AdminRiderListLoaded) {
      final riders = state.riders
          .where((r) => DodooCities.addressInCity(r.address, _riderCity))
          .toList();
      if (riders.isEmpty) {
        return _EmptyState(filter: _activeFilter, city: _riderCity);
      }
      return RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: riders.length,
          itemBuilder: (ctx, i) => FadeIn(
            index: i,
            child: _RiderCard(
              rider: riders[i],
              onTap: () => _openDetail(riders[i]),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _openDetail(AdminRider rider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminRiderDetailScreen(riderId: rider.id),
      ),
    ).then((_) => _load(silent: true));
  }
}

// ── Stats bar ─────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, int value, Color color, IconData icon})>[
      (label: 'Total', value: stats.total, color: const Color(0xFFBABC2F), icon: Icons.groups_rounded),
      (label: 'Online', value: stats.onlineNow, color: const Color(0xFF2563EB), icon: Icons.bolt_rounded),
      (label: 'Pending', value: stats.pending, color: const Color(0xFFD97706), icon: Icons.hourglass_bottom_rounded),
      (label: 'Approved', value: stats.approved, color: const Color(0xFF059669), icon: Icons.verified_rounded),
      (label: 'Rejected', value: stats.rejected, color: const Color(0xFFDC2626), icon: Icons.cancel_rounded),
      (label: 'Suspended', value: stats.suspended, color: const Color(0xFFEA580C), icon: Icons.block_rounded),
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
                Text(
                  'Fleet overview',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: Colors.grey.shade700,
                  ),
                ),
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
                    child: _StatChip(
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

class _StatChip extends StatelessWidget {
  const _StatChip({
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
              Text(
                '$value',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.0),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.activeFilter,
    required this.searchCtrl,
    required this.counts,
    required this.onFilterChanged,
    required this.onSearchSubmit,
  });

  final String activeFilter;
  final TextEditingController searchCtrl;
  final Map<String, int> counts;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSearchSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Filter tabs
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
                final isActive = activeFilter == f;
                final count = f == 'all' ? null : counts[f];
                return GestureDetector(
                  onTap: () => onFilterChanged(f),
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
                            color: isActive
                                ? Colors.white
                                : Colors.grey.shade700,
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

          // Search (always visible, live)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchSubmit,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search rider name or phone…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          searchCtrl.clear();
                          onSearchSubmit('');
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

// ── Rider card ────────────────────────────────────────────────────────────────

class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.rider, required this.onTap});
  final AdminRider rider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with a live current-status dot.
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _Avatar(url: rider.profilePictureUrl, name: rider.fullName),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _statusDot(rider.currentStatus),
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
                          child: Text(
                            rider.fullName.isNotEmpty
                                ? rider.fullName
                                : 'Unknown',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                color: Color(0xFF0F1300)), // high-contrast ink
                          ),
                        ),
                        if (rider.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              size: 15, color: Color(0xFF2563EB)),
                        ],
                        const Spacer(),
                        _StatusBadge(status: rider.accountStatus),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone_rounded,
                            size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          rider.phone.isEmpty ? 'No phone' : rider.phone,
                          style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _meta(Icons.star_rounded,
                            rider.rating.toStringAsFixed(1),
                            color: const Color(0xFFD97706)),
                        _meta(Icons.inventory_2_rounded,
                            '${rider.totalOrders} orders'),
                        _meta(Icons.event_rounded,
                            'Joined ${_fmtDate(rider.joinedDate)}'),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(Icons.chevron_right, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusDot(String s) => switch (s) {
        'online' => const Color(0xFF22C55E),
        'busy' => const Color(0xFFF97316),
        _ => const Color(0xFF94A3B8),
      };

  Widget _meta(IconData icon, String text, {Color? color}) {
    final c = color ?? const Color(0xFF475569);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: c)),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({this.url, required this.name});
  final String? url;
  final String name;

  static const double _r = 26;

  @override
  Widget build(BuildContext context) {
    // Uploaded photo (with graceful fallback to initials if it fails to load),
    // otherwise the rider's initials on a lime tint.
    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url!,
          width: _r * 2,
          height: _r * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initialsCircle(),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : _initialsCircle(),
        ),
      );
    }
    return _initialsCircle();
  }

  Widget _initialsCircle() {
    return Container(
      width: _r * 2,
      height: _r * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFBABC2F).withValues(alpha: 0.30),
            const Color(0xFFBABC2F).withValues(alpha: 0.14),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: Color(0xFF5C6000),
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cfg.$2,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label(status),
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: cfg.$1),
      ),
    );
  }

  static String _label(String s) =>
      s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;

  static (Color, Color) _cfg(String s) {
    switch (s) {
      case 'pending':
        return (const Color(0xFF92400E), const Color(0xFFFEF3C7));
      case 'approved':
        return (const Color(0xFF065F46), const Color(0xFFD1FAE5));
      case 'rejected':
        return (const Color(0xFF991B1B), const Color(0xFFFEE2E2));
      case 'suspended':
        return (const Color(0xFF9A3412), const Color(0xFFFFEDD5));
      default:
        return (const Color(0xFF374151), const Color(0xFFF3F4F6));
    }
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter, this.city});
  final String filter;
  final String? city;

  @override
  Widget build(BuildContext context) {
    final base = filter == 'all' ? 'No riders' : 'No $filter riders';
    final msg = city == null
        ? '$base registered yet.'
        : '$base in ${DodooCities.byCode(city).name}.';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            msg,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── App bar action button ─────────────────────────────────────────────────────

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        constraints: const BoxConstraints(),
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          foregroundColor: const Color(0xFF1C1D00),
          backgroundColor: const Color(0xFF1C1D00).withValues(alpha: 0.08),
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(8),
        ),
      ),
    );
  }
}

// ── Account menu row ───────────────────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

// ── App bar notification bell ──────────────────────────────────────────────────

class _BarBell extends StatelessWidget {
  const _BarBell();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AppNotification>>(
      valueListenable: NotificationCenter.instance.notifier,
      builder: (context, items, _) {
        final unread = items.where((n) => !n.read).length;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: IconButton(
            tooltip: 'Notifications',
            constraints: const BoxConstraints(),
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFF1C1D00),
              backgroundColor: const Color(0xFF1C1D00).withValues(alpha: 0.08),
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(8),
            ),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              backgroundColor: const Color(0xFFDC2626),
              child: const Icon(Icons.notifications_rounded, size: 20),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        );
      },
    );
  }
}
