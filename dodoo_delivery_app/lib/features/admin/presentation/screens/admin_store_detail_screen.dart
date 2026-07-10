import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/dodoo_cities.dart';
import '../../../../core/constants/store_categories.dart';
import '../../../../core/firebase/firebase_refs.dart';
import '../../../../core/widgets/support_modal.dart';
import '../../data/dodoo_store_publisher.dart';

Future<void> _dial(String phone) async {
  final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (cleaned.isEmpty) return;
  final uri = Uri.parse('tel:$cleaned');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

class AdminStoreDetailScreen extends StatefulWidget {
  const AdminStoreDetailScreen({super.key, required this.storeId});
  final String storeId;

  @override
  State<AdminStoreDetailScreen> createState() => _AdminStoreDetailScreenState();
}

class _AdminStoreDetailScreenState extends State<AdminStoreDetailScreen> {
  Map<String, dynamic> _store = {};
  Map<String, dynamic> _docStatus = {};
  final _commentCtrl = TextEditingController();
  final _dodooIdCtrl = TextEditingController(); // fallback manual link
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _dodooIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final doc = await Db.stores.doc(widget.storeId).get();
      final data = Map<String, dynamic>.from(doc.data() ?? {});
      data['id'] = doc.id;
      if (!mounted) return;
      setState(() {
        _store = data;
        _docStatus =
            Map<String, dynamic>.from(data['document_status'] as Map? ?? {});
        _dodooIdCtrl.text = data['dodoo_store_id']?.toString() ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _status => _store['account_status']?.toString() ?? 'pending';

  /// True when every acted-on document is verified (drives is_verified).
  bool get _docsVerified {
    final vals = _docStatus.values.map((v) => v.toString()).toList();
    return vals.isNotEmpty &&
        !vals.contains('pending') &&
        !vals.contains('rejected');
  }

  Future<void> _setDocStatus(String key, String status) async {
    setState(() => _docStatus = {..._docStatus, key: status});
    final verified = _docsVerified;
    try {
      await Db.stores.doc(widget.storeId).set({
        'document_status': {key: status},
        'is_document_verified': verified,
        'is_verified': verified,
      }, SetOptions(merge: true));
    } catch (_) {/* keep optimistic value */}
  }

  Future<void> _saveDodooId() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await Db.stores.doc(widget.storeId).set(
          {'dodoo_store_id': _dodooIdCtrl.text.trim()}, SetOptions(merge: true));
      if (mounted) {
        setState(() =>
            _store = {..._store, 'dodoo_store_id': _dodooIdCtrl.text.trim()});
        _snack('DoDoo Store ID linked.', const Color(0xFF059669));
      }
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  /// Registers (id '0') or updates the store on DoDoo via SaveStore, then
  /// AUTO-fetches its DoDoo Store ID (SaveStore doesn't return it) via
  /// StoreAdminAuthentication and saves it locally. Category is auto-mapped
  /// from the store's category — no manual entry.
  Future<void> _registerOnDodoo() async {
    FocusScope.of(context).unfocus();
    final storeName = (_store['store_name']?.toString() ?? '').trim();
    if (storeName.isEmpty) {
      _snack('Store has no name yet — approve/complete it first.',
          const Color(0xFFDC2626));
      return;
    }
    setState(() => _busy = true);
    final existingId = _dodooIdCtrl.text.trim();

    final outcome = await DodooStorePublisher.publish(
      storeId: widget.storeId,
      store: {..._store, if (existingId.isNotEmpty) 'dodoo_store_id': existingId},
    );
    if (!mounted) return;

    if (!outcome.ok) {
      if (outcome.unreachable) {
        // Server down — the publisher queued it; it'll retry automatically.
        setState(() => _store = {..._store, 'dodoo_publish_pending': true});
        _snack(
          'DoDoo store server is temporarily unreachable — queued. '
          "We'll publish automatically when it's back.",
          const Color(0xFFD97706),
        );
      } else {
        _snack(
            'DoDoo: ${outcome.message ?? 'save failed'}', const Color(0xFFDC2626));
      }
      setState(() => _busy = false);
      return;
    }

    // Success — the publisher already saved the id + cleared the queue flag;
    // mirror it into local state for instant feedback.
    final newId = outcome.dodooId ?? existingId;
    setState(() {
      if (newId.isNotEmpty) _dodooIdCtrl.text = newId;
      _store = {
        ..._store,
        if (newId.isNotEmpty) 'dodoo_store_id': newId,
        'dodoo_publish_pending': false,
      };
    });
    _snack(
      existingId.isNotEmpty
          ? 'Updated on DoDoo.'
          : (newId.isNotEmpty
              ? 'Published to DoDoo · ID $newId'
              : 'Published to DoDoo (ID not linked yet — tap again to link).'),
      const Color(0xFF059669),
    );
    setState(() => _busy = false);
  }

  Future<void> _saveComment() async {
    FocusScope.of(context).unfocus();
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await Db.stores.doc(widget.storeId).set(
          {'admin_comment': text}, SetOptions(merge: true));
      if (mounted) {
        setState(() {
          _store = {..._store, 'admin_comment': text};
          _commentCtrl.clear();
        });
        _snack('Comment sent to store.', const Color(0xFF059669));
      }
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _action(String action) async {
    final needsReason = action == 'reject' || action == 'suspend';
    String reason = '';
    if (needsReason) {
      final r = await _reasonDialog(action);
      if (r == null) return;
      reason = r;
    } else {
      final ok = await _confirmDialog(action);
      if (!ok) return;
    }

    setState(() => _busy = true);
    try {
      if (action == 'reject') {
        // Wipe details so a rejected store re-applies fresh (keeps phone).
        await Db.stores.doc(widget.storeId).update({
          'account_status': 'rejected',
          'store_name': FieldValue.delete(),
          'owner_first_name': FieldValue.delete(),
          'owner_last_name': FieldValue.delete(),
          'category': FieldValue.delete(),
          'email': FieldValue.delete(),
          'address': FieldValue.delete(),
          'fssai_number': FieldValue.delete(),
          'gst_number': FieldValue.delete(),
          'owner_id_number': FieldValue.delete(),
          'storefront_photo_url': FieldValue.delete(),
          'fssai_doc_url': FieldValue.delete(),
          'owner_id_url': FieldValue.delete(),
          'document_status': FieldValue.delete(),
          'pending_profile_changes': FieldValue.delete(),
          'admin_comment': reason.isEmpty ? FieldValue.delete() : reason,
          'is_verified': false,
          'is_document_verified': false,
        });
      } else {
        final status = switch (action) {
          'approve' => 'approved',
          'suspend' => 'suspended',
          'reactivate' => 'approved',
          _ => action,
        };
        await Db.stores.doc(widget.storeId).update({
          'account_status': status,
          if (reason.isNotEmpty) 'admin_comment': reason,
        });
      }
      if (mounted) {
        _snack('Store ${_pastTense(action)}.', const Color(0xFF059669));
      }
      await _load();
      // Approving (or reactivating) also pushes the store to DoDoo so it
      // becomes visible there — no separate button click needed.
      if ((action == 'approve' || action == 'reactivate') && mounted) {
        await _registerOnDodoo();
      }
    } catch (_) {
      if (mounted) _snack('Action failed. Try again.', const Color(0xFFDC2626));
    }
    if (mounted) setState(() => _busy = false);
  }

  void _snack(String msg, Color bg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));

  static String _pastTense(String a) => switch (a) {
        'approve' => 'approved',
        'reject' => 'rejected',
        'suspend' => 'suspended',
        'reactivate' => 'reactivated',
        _ => a,
      };

  Future<String?> _reasonDialog(String action) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('${action[0].toUpperCase()}${action.substring(1)} store'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Reason (shown to the store)',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dCtx, ctrl.text.trim()),
              child: Text('${action[0].toUpperCase()}${action.substring(1)}')),
        ],
      ),
    );
  }

  Future<bool> _confirmDialog(String action) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('${action[0].toUpperCase()}${action.substring(1)} store?'),
        content: Text('Are you sure you want to $action this store?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: action == 'approve'
                    ? const Color(0xFF059669)
                    : const Color(0xFFBABC2F)),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text('${action[0].toUpperCase()}${action.substring(1)}'),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFBABC2F),
        foregroundColor: const Color(0xFF1C1D00),
        title: const Text('Store Details',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          const SupportIconButton(),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _header(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(),
                          ),
                        _actionBar(),
                        const SizedBox(height: 16),
                        _infoSection(),
                        const SizedBox(height: 16),
                        _dodooLinkSection(),
                        const SizedBox(height: 16),
                        _documentsSection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _header() {
    final cat = StoreCategories.byKey(_store['category']?.toString());
    final photo = _store['storefront_photo_url']?.toString() ?? '';
    final name = (_store['store_name']?.toString() ?? '').trim();
    final phone = _store['phone']?.toString() ?? '';
    return Container(
      color: const Color(0xFFBABC2F),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isEmpty
                ? Icon(cat.icon, color: Colors.white, size: 30)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Unnamed store' : name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(cat.label,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                const SizedBox(height: 6),
                if (phone.isNotEmpty)
                  InkWell(
                    onTap: () => _dial(phone),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(phone,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Action bar ───────────────────────────────────────────────────────────
  Widget _actionBar() {
    final actions = switch (_status) {
      'pending' => ['approve', 'reject'],
      'approved' => ['suspend'],
      'suspended' => ['reactivate', 'reject'],
      _ => <String>[], // rejected → re-apply is on the store side
    };
    if (actions.isEmpty) {
      return _card(const Text('This store was rejected. It must re-apply from '
          'the store app.',
          style: TextStyle(color: Colors.grey)));
    }
    return _card(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Actions',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: actions.map((a) {
            final (label, color, icon) = switch (a) {
              'approve' => ('Approve', const Color(0xFF059669), Icons.check_circle),
              'reject' => ('Reject', const Color(0xFFDC2626), Icons.cancel),
              'suspend' => ('Suspend', const Color(0xFFEA580C), Icons.block),
              'reactivate' => (
                  'Reactivate',
                  const Color(0xFFBABC2F),
                  Icons.restart_alt
                ),
              _ => (a, Colors.grey, Icons.circle),
            };
            return FilledButton.icon(
              onPressed: _busy ? null : () => _action(a),
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: FilledButton.styleFrom(backgroundColor: color),
            );
          }).toList(),
        ),
      ],
    ));
  }

  // ── Info ───────────────────────────────────────────────────────────────────
  Widget _infoSection() {
    final owner =
        '${_store['owner_first_name'] ?? ''} ${_store['owner_last_name'] ?? ''}'
            .trim();
    return _card(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Store Information',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 12),
        _row('Owner', owner.isEmpty ? '—' : owner),
        _row('Category', StoreCategories.labelFor(_store['category']?.toString())),
        _cityRow(),
        if ((_store['address']?.toString() ?? '').isNotEmpty)
          _row('Address', _store['address'].toString()),
        if ((_store['email']?.toString() ?? '').isNotEmpty)
          _row('Email', _store['email'].toString()),
        _row('FSSAI', _store['fssai_number']?.toString() ?? '—'),
        _row('GST', _store['gst_number']?.toString() ?? '—'),
        _row(
            _store['owner_id_type'] == 'pan' ? 'PAN' : 'Aadhaar',
            _store['owner_id_number']?.toString() ?? '—'),
        _row('Verified', _docsVerified ? 'Yes' : 'No'),
      ],
    ));
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 92,
                child: Text(label,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
      );

  /// City row with an inline "Change" action (city drives the DoDoo SaveStore
  /// call, so switching it here + re-registering makes the store live there).
  Widget _cityRow() => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
                width: 92,
                child: Text('City',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13))),
            Expanded(
                child: Text(
                    DodooCities.nameFor(_store['city_code']?.toString()),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13))),
            InkWell(
              onTap: _busy ? null : _changeCity,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_location_alt_outlined,
                        size: 15, color: Color(0xFF2563EB)),
                    SizedBox(width: 3),
                    Text('Change',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB))),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> _changeCity() async {
    final current =
        _store['city_code']?.toString() ?? DodooCities.defaultCity.code;
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Change city',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
            for (final c in DodooCities.all)
              ListTile(
                leading: Icon(
                  c.code == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: c.code == current
                      ? const Color(0xFF059669)
                      : Colors.grey,
                ),
                title: Text(c.name),
                subtitle: Text(c.code),
                onTap: () => Navigator.of(sheetCtx).pop(c.code),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || picked == current || !mounted) return;
    setState(() => _busy = true);
    try {
      await Db.stores
          .doc(widget.storeId)
          .set({'city_code': picked}, SetOptions(merge: true));
      if (mounted) {
        setState(() => _store = {..._store, 'city_code': picked});
        _snack(
            'City set to ${DodooCities.nameFor(picked)}. '
            'Approve the store (or tap "Publish to DoDoo") to list it there.',
            const Color(0xFF059669));
      }
    } catch (_) {
      if (mounted) _snack('Could not change city.', const Color(0xFFDC2626));
    }
    if (mounted) setState(() => _busy = false);
  }

  // ── DoDoo marketplace status ────────────────────────────────────────────
  Widget _dodooLinkSection() {
    final linked = (_store['dodoo_store_id']?.toString() ?? '').isNotEmpty;
    final approved = _status == 'approved';
    final pending = _store['dodoo_publish_pending'] == true;
    final cityName = DodooCities.nameFor(_store['city_code']?.toString());

    return _card(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('DoDoo Marketplace',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 12),

        // One clear status line based on where the store is in its lifecycle.
        if (linked)
          _dodooStatusPill(
            color: const Color(0xFF059669),
            icon: Icons.check_circle_rounded,
            title: 'Live on DoDoo',
            subtitle: 'Listed in $cityName · ID ${_store['dodoo_store_id']}',
          )
        else if (approved && pending)
          _dodooStatusPill(
            color: const Color(0xFF2563EB),
            icon: Icons.cloud_sync_rounded,
            title: 'Queued — will publish automatically',
            subtitle:
                "The DoDoo server was unreachable. We'll keep retrying in the "
                'background and list it in $cityName once it responds.',
          )
        else if (approved)
          _dodooStatusPill(
            color: const Color(0xFFD97706),
            icon: Icons.error_outline_rounded,
            title: 'Approved — not live yet',
            subtitle: 'Tap "Publish to DoDoo" to list it in $cityName.',
          )
        else
          _dodooStatusPill(
            color: const Color(0xFF6B7280),
            icon: Icons.schedule_rounded,
            title: 'Goes live automatically when approved',
            subtitle:
                'Approving lists it on DoDoo ($cityName) — nothing else to do.',
          ),

        // Publish / re-publish only matters once the store is approved.
        if (approved) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _registerOnDodoo,
              icon: Icon(
                  linked
                      ? Icons.sync_rounded
                      : (pending
                          ? Icons.refresh_rounded
                          : Icons.cloud_upload_rounded),
                  size: 18),
              label: Text(linked
                  ? 'Re-publish (after edits)'
                  : (pending ? 'Retry publish now' : 'Publish to DoDoo')),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  minimumSize: const Size.fromHeight(46)),
            ),
          ),
        ],

        // Rarely needed — tucked away so the common flow stays clean.
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 4),
            title: Text('Advanced',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Link an existing DoDoo Store ID manually',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _dodooIdCtrl,
                      decoration: const InputDecoration(
                        hintText: 'DoDoo Store ID',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _busy ? null : _saveDodooId,
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFBABC2F),
                        minimumSize: const Size(0, 48)),
                    child: const Text('Link'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ));
  }

  Widget _dodooStatusPill({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade700,
                        height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Documents & verification ────────────────────────────────────────────
  Widget _documentsSection() {
    final docs = <(String, String, String)>[
      ('Storefront Photo', 'storefront',
          _store['storefront_photo_url']?.toString() ?? ''),
      ('FSSAI License', 'fssai', _store['fssai_doc_url']?.toString() ?? ''),
      ('Owner ID', 'owner_id', _store['owner_id_url']?.toString() ?? ''),
    ].where((d) => d.$3.isNotEmpty).toList();

    return _card(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Documents & verification',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 12),
        if (docs.isEmpty)
          const Text('No documents uploaded.',
              style: TextStyle(color: Colors.grey))
        else
          ...docs.map((d) => _docTile(d.$1, d.$2, d.$3)),
        const Divider(height: 24),
        const Text('Comment to store',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        Text('Sent to the store (e.g. "FSSAI image is blurry, re-upload").',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
        if ((_store['admin_comment']?.toString() ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current note shown to store',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E))),
                const SizedBox(height: 3),
                Text(_store['admin_comment'].toString().trim(),
                    style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFF92400E))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _commentCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Message to the store…',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _saveComment,
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Send to store'),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFBABC2F),
                minimumSize: const Size.fromHeight(46)),
          ),
        ),
      ],
    ));
  }

  Widget _docTile(String label, String key, String url) {
    final status = _docStatus[key]?.toString() ?? 'pending';
    final (color, text) = switch (status) {
      'verified' => (const Color(0xFF059669), 'Verified'),
      'rejected' => (const Color(0xFFDC2626), 'Rejected'),
      _ => (const Color(0xFFD97706), 'Pending'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(text,
                    style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white),
                  body: Center(
                      child: InteractiveViewer(child: Image.network(url))),
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 80,
                  color: Colors.grey.shade100,
                  child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (status == 'pending')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _setDocStatus(key, 'verified'),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text('Verify'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                      side: const BorderSide(color: Color(0xFF059669)),
                      minimumSize: const Size(0, 40),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _setDocStatus(key, 'rejected'),
                    icon: const Icon(Icons.cancel_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      minimumSize: const Size(0, 40),
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              status == 'verified'
                  ? 'Verified — returns to pending if the store re-uploads.'
                  : 'Rejected — returns to pending if the store re-uploads.',
              style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  Widget _card(Widget child) => Container(
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
                offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      );
}
