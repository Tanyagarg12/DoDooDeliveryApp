import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/support_modal.dart';
import '../../domain/entities/admin_entities.dart';
import 'admin_rider_performance.dart';
import '../controllers/admin_controller.dart';
import '../controllers/admin_state.dart';

/// Opens the phone dialer for [phone] (no-op if empty / can't launch).
Future<void> _dialPhone(String phone) async {
  final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (cleaned.isEmpty) return;
  final uri = Uri.parse('tel:$cleaned');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

class AdminRiderDetailScreen extends ConsumerStatefulWidget {
  const AdminRiderDetailScreen({super.key, required this.riderId});
  final String riderId;

  @override
  ConsumerState<AdminRiderDetailScreen> createState() =>
      _AdminRiderDetailScreenState();
}

class _AdminRiderDetailScreenState
    extends ConsumerState<AdminRiderDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String? get _token =>
      ref.read(adminAuthControllerProvider.notifier).token;

  Future<void> _load() async {
    final token = _token;
    if (token == null) return;
    ref
        .read(adminRiderDetailControllerProvider(widget.riderId).notifier)
        .load(token);
  }

  Future<void> _takeAction(
    BuildContext ctx,
    AdminRider rider,
    String action,
  ) async {
    final needsReason = action == 'reject' || action == 'suspend';
    String reason = '';

    if (needsReason) {
      final result = await _showReasonDialog(ctx, action);
      if (result == null) return;
      reason = result;
    } else {
      final confirmed = await _showConfirmDialog(ctx, action, rider.fullName);
      if (!confirmed) return;
    }

    final token = _token;
    if (token == null) return;

    await ref
        .read(adminRiderDetailControllerProvider(widget.riderId).notifier)
        .takeAction(token, action, reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(adminRiderDetailControllerProvider(widget.riderId));

    ref.listen<AdminRiderDetailState>(
      adminRiderDetailControllerProvider(widget.riderId),
      (_, next) {
        if (next is AdminRiderDetailActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.message),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
        if (next is AdminRiderDetailError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.message),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
          if (next.rider != null) {
            ref
                .read(adminRiderDetailControllerProvider(widget.riderId)
                    .notifier)
                .load(_token ?? '');
          }
        }
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFBABC2F),
        foregroundColor: const Color(0xFF1C1D00),
        title: const Text('Rider Details',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          const SupportIconButton(),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(AdminRiderDetailState state) {
    if (state is AdminRiderDetailLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is AdminRiderDetailError && state.rider == null) {
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

    final rider = _rider(state);
    if (rider == null) return const SizedBox.shrink();

    final isActionLoading = state is AdminRiderDetailActionLoading;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _ProfileHeader(rider: rider),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _ActionBar(
                    rider: rider,
                    loading: isActionLoading,
                    onAction: (a) => _takeAction(context, rider, a),
                  ),
                  const SizedBox(height: 16),
                  _InfoSection(rider: rider),
                  const SizedBox(height: 16),
                  RiderPerformanceSection(riderId: widget.riderId),
                  const SizedBox(height: 16),
                  _DocumentsSection(rider: rider),
                  const SizedBox(height: 16),
                  _AuditLog(logs: rider.approvalLogs),
                  if (rider.accountStatus == 'approved') ...[
                    const SizedBox(height: 16),
                    _SuspendSection(
                      loading: isActionLoading,
                      onSuspend: () => _takeAction(context, rider, 'suspend'),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  AdminRider? _rider(AdminRiderDetailState state) {
    if (state is AdminRiderDetailLoaded) return state.rider;
    if (state is AdminRiderDetailActionLoading) return state.rider;
    if (state is AdminRiderDetailActionSuccess) return state.rider;
    if (state is AdminRiderDetailError) return state.rider;
    return null;
  }

  Future<String?> _showReasonDialog(BuildContext ctx, String action) {
    final ctrl = TextEditingController();
    final label = action == 'reject' ? 'Rejection reason' : 'Suspension reason';
    return showDialog<String>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Text('${_actionLabel(action)} rider'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Enter reason (visible to rider in audit log)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, ctrl.text.trim()),
            child: Text(_actionLabel(action)),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(
    BuildContext ctx,
    String action,
    String name,
  ) async {
    final result = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Text('${_actionLabel(action)} rider?'),
        content: Text(
          'Are you sure you want to $action $name?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: action == 'approve'
                  ? const Color(0xFF059669)
                  : const Color(0xFFBABC2F),
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(_actionLabel(action)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static String _actionLabel(String action) {
    const map = {
      'approve': 'Approve',
      'reject': 'Reject',
      'suspend': 'Suspend',
      'reactivate': 'Reactivate',
    };
    return map[action] ?? action;
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.rider});
  final AdminRider rider;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFBABC2F),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        children: [
          _LargeAvatar(url: rider.profilePictureUrl, name: rider.fullName),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rider.fullName.isNotEmpty ? rider.fullName : 'Unknown',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                if (rider.phone.isNotEmpty)
                  InkWell(
                    onTap: () => _dialPhone(rider.phone),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_rounded,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            rider.phone,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Text('No phone',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                _StatusBadgeLarge(status: rider.accountStatus),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeAvatar extends StatelessWidget {
  const _LargeAvatar({this.url, required this.name});
  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: 36,
        backgroundImage: NetworkImage(url!),
      );
    }
    return CircleAvatar(
      radius: 36,
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      child: Text(
        initials,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
      ),
    );
  }
}

class _StatusBadgeLarge extends StatelessWidget {
  const _StatusBadgeLarge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = _cfg(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.isNotEmpty
            ? '${status[0].toUpperCase()}${status.substring(1)}'
            : status,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

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

// ── Action bar ────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.rider,
    required this.loading,
    required this.onAction,
  });
  final AdminRider rider;
  final bool loading;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final actions = _availableActions(rider.accountStatus);
    if (actions.isEmpty) return const SizedBox.shrink();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Actions',
              style:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions
                  .map((a) => _ActionButton(
                        action: a,
                        onPressed: () => onAction(a),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  static List<String> _availableActions(String status) {
    switch (status) {
      case 'pending':
        return ['approve', 'reject'];
      case 'approved':
        // Suspend is shown separately at the bottom of the page.
        return [];
      case 'rejected':
        return ['approve'];
      case 'suspended':
        return ['reactivate', 'reject'];
      default:
        return [];
    }
  }
}

// ── Suspend section (bottom danger zone) ───────────────────────────────────────

class _SuspendSection extends StatelessWidget {
  const _SuspendSection({required this.loading, required this.onSuspend});
  final bool loading;
  final VoidCallback onSuspend;

  static const _orange = Color(0xFFEA580C);

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.block, color: _orange, size: 18),
              SizedBox(width: 8),
              Text('Suspend rider',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Suspending stops this rider from receiving new orders. They stay '
            'registered and you can reactivate them anytime. A reason is '
            'recorded in the audit trail.',
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onSuspend,
                    icon: const Icon(Icons.block, size: 18),
                    label: const Text('Suspend rider'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _orange,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.onPressed});
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _cfg(action);
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  static (String, Color, IconData) _cfg(String action) {
    switch (action) {
      case 'approve':
        return ('Approve', const Color(0xFF059669), Icons.check_circle);
      case 'reject':
        return ('Reject', const Color(0xFFDC2626), Icons.cancel);
      case 'suspend':
        return ('Suspend', const Color(0xFFEA580C), Icons.block);
      case 'reactivate':
        return ('Reactivate', const Color(0xFFBABC2F), Icons.restart_alt);
      default:
        return (action, Colors.grey, Icons.circle);
    }
  }
}

// ── Info section ──────────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.rider});
  final AdminRider rider;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Personal Information',
              style:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          _InfoRow(
            'Phone',
            rider.phone.isEmpty ? '—' : rider.phone,
            onTap: rider.phone.isEmpty ? null : () => _dialPhone(rider.phone),
            icon: Icons.call_rounded,
          ),
          if (rider.email?.isNotEmpty ?? false)
            _InfoRow('Email', rider.email!),
          if (rider.address?.isNotEmpty ?? false)
            _InfoRow('Address', rider.address!),
          _InfoRow('Joined', _fmtDate(rider.joinedDate)),
          _InfoRow('Rating', '${rider.rating.toStringAsFixed(1)} ★'),
          _InfoRow('Total Orders', '${rider.totalOrders}'),
          _InfoRow('Online Status', rider.currentStatus),
          _InfoRow('Verified', rider.isVerified ? 'Yes' : 'No'),
          _InfoRow('Docs Verified', rider.isDocumentVerified ? 'Yes' : 'No'),
          if (rider.aadhaarNumber?.isNotEmpty ?? false)
            _InfoRow('Aadhaar', rider.aadhaarNumber!),
          if (rider.drivingLicenseNumber?.isNotEmpty ?? false)
            _InfoRow('DL Number', rider.drivingLicenseNumber!),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.onTap, this.icon});
  final String label;
  final String value;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tappable = onTap != null;
    final valueWidget = tappable
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: const Color(0xFF2563EB)),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF2563EB),
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          )
        : Text(
            value,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }
}

// ── Documents section ─────────────────────────────────────────────────────────

class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({required this.rider});
  final AdminRider rider;

  @override
  Widget build(BuildContext context) {
    final docs = <(String, String?)>[
      ('Profile Photo', rider.profilePictureUrl),
      ('Aadhaar Front', rider.aadhaarFrontUrl),
      ('Aadhaar Back', rider.aadhaarBackUrl),
      ('Driving License', rider.drivingLicenseImageUrl),
    ].where((d) => d.$2 != null && d.$2!.isNotEmpty).toList();

    if (docs.isEmpty) {
      return _Card(
        child: const Text(
          'No documents uploaded yet.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Documents',
              style:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          ...docs.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.$1,
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  _DocImage(url: d.$2!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocImage extends StatelessWidget {
  const _DocImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, e, s) => Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Audit log ─────────────────────────────────────────────────────────────────

class _AuditLog extends StatelessWidget {
  const _AuditLog({required this.logs});
  final List<ApprovalLog> logs;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Audit Trail',
              style:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          if (logs.isEmpty) ...[
            const SizedBox(height: 8),
            const Text('No actions logged yet.',
                style: TextStyle(color: Colors.grey)),
          ] else ...[
            const SizedBox(height: 12),
            ...logs.asMap().entries.map(
                  (entry) => _LogEntry(
                    log: entry.value,
                    isLast: entry.key == logs.length - 1,
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _LogEntry extends StatelessWidget {
  const _LogEntry({required this.log, required this.isLast});
  final ApprovalLog log;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _cfg(log.action);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          Column(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, size: 12, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade200,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        log.actionLabel,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: color,
                            fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        _fmtDateTime(log.timestamp),
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    log.adminName.isNotEmpty
                        ? 'By ${log.adminName}'
                        : 'System',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12),
                  ),
                  if (log.reason != null && log.reason!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.grey.shade200),
                      ),
                      child: Text(
                        log.reason!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDateTime(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  static (Color, IconData) _cfg(String action) {
    switch (action) {
      case 'approved':
        return (const Color(0xFF059669), Icons.check_circle);
      case 'rejected':
        return (const Color(0xFFDC2626), Icons.cancel);
      case 'suspended':
        return (const Color(0xFFEA580C), Icons.block);
      case 'reactivated':
        return (const Color(0xFFBABC2F), Icons.restart_alt);
      case 'registered':
        return (const Color(0xFF2563EB), Icons.person_add);
      default:
        return (Colors.grey, Icons.circle);
    }
  }
}

// ── Shared card ───────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
