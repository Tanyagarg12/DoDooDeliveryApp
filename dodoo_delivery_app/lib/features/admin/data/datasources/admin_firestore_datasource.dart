import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/firebase/firebase_refs.dart';
import '../models/admin_models.dart';

/// Admin data layer backed by Firestore (replaces the Supabase datasource).
/// Admin login still uses hardcoded credentials; rider management reads/writes
/// the `riders` collection.
class AdminFirestoreDataSource {
  static const _keyAdminToken = 'admin_access_token';
  static const _adminUsername = 'admin';
  static const _defaultPassword = 'dodoo@123';
  static const _sessionToken = 'FIREBASE_ADMIN_SESSION';

  /// Ensures the anonymous Firebase session needed for Firestore rules.
  Future<void> _ensureAnonSession() async {
    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (_) {/* Anonymous sign-in must be enabled in the console */}
    }
  }

  /// The current admin password, stored at app_settings/admin_password.
  /// Falls back to the default until it's been changed.
  Future<String> _currentPassword() async {
    try {
      final doc = await Db.appSettings.doc('admin_password').get();
      final v = doc.data()?['value']?.toString();
      return (v != null && v.isNotEmpty) ? v : _defaultPassword;
    } catch (_) {
      return _defaultPassword;
    }
  }

  /// Changes the admin password (verifying the current one first).
  Future<void> changePassword(String current, String newPassword) async {
    await _ensureAnonSession();
    final stored = await _currentPassword();
    if (current != stored) {
      throw Exception('Current password is incorrect.');
    }
    final next = newPassword.trim();
    if (next.length < 4) {
      throw Exception('New password must be at least 4 characters.');
    }
    await Db.appSettings
        .doc('admin_password')
        .set({'value': next}, SetOptions(merge: true));
  }

  // ── Token persistence ────────────────────────────────────────────────────

  Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAdminToken);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAdminToken, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAdminToken);
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  Future<({String accessToken, AdminUserModel admin})> login(
    String username,
    String password,
  ) async {
    if (username.trim().toLowerCase() != _adminUsername) {
      throw Exception('Invalid username or password.');
    }
    // Need the anonymous session first so we can read the stored password.
    await _ensureAnonSession();
    if (password != await _currentPassword()) {
      throw Exception('Invalid username or password.');
    }
    await saveToken(_sessionToken);
    return (
      accessToken: _sessionToken,
      admin: const AdminUserModel(
        id: 'admin',
        username: 'admin',
        name: 'DoDoo Admin',
        email: 'Teamdodoo@gmail.com',
      ),
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<DashboardStatsModel> getStats(String token) async {
    final snap = await Db.riders.get();
    int pending = 0, approved = 0, rejected = 0, suspended = 0, online = 0;
    for (final doc in snap.docs) {
      final r = doc.data();
      switch (r['account_status']?.toString()) {
        case 'pending':   pending++;   break;
        case 'approved':  approved++;  break;
        case 'rejected':  rejected++;  break;
        case 'suspended': suspended++; break;
      }
      if (r['current_status']?.toString() == 'online') online++;
    }
    return DashboardStatsModel(
      total: snap.docs.length,
      pending: pending,
      approved: approved,
      rejected: rejected,
      suspended: suspended,
      onlineNow: online,
    );
  }

  // ── Riders list ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getRiders(
    String token, {
    String? status,
    String? search,
  }) async {
    final snap = await Db.riders.get();
    final all = snap.docs.map(_docToMap).toList()
      ..sort((a, b) => (b['created_at']?.toString() ?? '')
          .compareTo(a['created_at']?.toString() ?? ''));

    final counts = <String, dynamic>{
      'pending': 0,
      'approved': 0,
      'rejected': 0,
      'suspended': 0,
    };
    for (final r in all) {
      final s = r['account_status']?.toString() ?? '';
      if (counts.containsKey(s)) counts[s] = (counts[s] ?? 0) + 1;
    }

    var filtered = all;
    if (status != null && status.isNotEmpty) {
      filtered = filtered.where((r) => r['account_status'] == status).toList();
    }
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      filtered = filtered.where((r) {
        final name =
            '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.toLowerCase();
        final phone = r['phone']?.toString() ?? '';
        return name.contains(q) || phone.contains(q);
      }).toList();
    }

    return {
      'riders': filtered.map(_riderRowToJson).toList(),
      'counts': counts,
    };
  }

  // ── Rider detail ──────────────────────────────────────────────────────────

  Future<AdminRiderModel> getRiderDetail(String token, String riderId) async {
    final doc = await Db.riders.doc(riderId).get();
    if (!doc.exists) throw Exception('Rider not found');
    return AdminRiderModel.fromJson(_riderRowToJson(_docToMap(doc)));
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> takeAction(
    String token,
    String riderId,
    String action, {
    String reason = '',
  }) async {
    final newStatus = switch (action) {
      'approve'    => 'approved',
      'reject'     => 'rejected',
      'suspend'    => 'suspended',
      'reactivate' => 'approved',
      _            => action,
    };
    await Db.riders.doc(riderId).update({'account_status': newStatus});
  }

  Future<List<ApprovalLogModel>> getLogs(String token, String riderId) async {
    return [];
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Map<String, dynamic> _docToMap(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map? ?? {});
    data['id'] = doc.id;
    for (final key in data.keys.toList()) {
      if (data[key] is Timestamp) {
        data[key] = (data[key] as Timestamp).toDate().toIso8601String();
      }
    }
    return data;
  }

  static Map<String, dynamic> _riderRowToJson(Map<String, dynamic> r) => {
        ...r,
        'full_name':
            '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim(),
        'joined_date': r['created_at'],
        'approval_logs': <dynamic>[],
      };
}
