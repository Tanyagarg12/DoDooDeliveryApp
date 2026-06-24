import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/admin_firestore_datasource.dart';
import '../../data/repositories/admin_repository_impl.dart';
import '../../domain/entities/admin_entities.dart';
import '../../domain/repositories/admin_repository.dart';
import 'admin_state.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepositoryImpl(AdminFirestoreDataSource());
});

final adminAuthControllerProvider =
    StateNotifierProvider<AdminAuthController, AdminAuthState>((ref) {
  return AdminAuthController(ref.watch(adminRepositoryProvider));
});

final adminRiderListControllerProvider =
    StateNotifierProvider<AdminRiderListController, AdminRiderListState>((ref) {
  return AdminRiderListController(ref.watch(adminRepositoryProvider));
});

final adminRiderDetailControllerProvider = StateNotifierProvider.family<
    AdminRiderDetailController, AdminRiderDetailState, String>(
  (ref, riderId) {
    return AdminRiderDetailController(
      ref.watch(adminRepositoryProvider),
      riderId,
    );
  },
);

// ── Auth controller ───────────────────────────────────────────────────────────

class AdminAuthController extends StateNotifier<AdminAuthState> {
  final AdminRepository _repo;

  AdminAuthController(this._repo) : super(const AdminAuthInitial());

  /// Restores a saved admin login on app start (so the admin stays logged in
  /// until they explicitly log out). Returns true if a session was restored.
  Future<bool> restoreSession() async {
    final token = await _repo.getSavedToken();
    if (token == null || token.isEmpty) return false;
    try {
      await _repo.ensureSession(); // re-establish Firebase anon session
    } catch (_) {}
    state = AdminAuthenticated(
      admin: const AdminUser(
        id: 'admin',
        username: 'admin',
        name: 'DoDoo Admin',
        email: 'Teamdodoo@gmail.com',
      ),
      accessToken: token,
    );
    return true;
  }

  Future<void> login(String username, String password) async {
    state = const AdminAuthLoading();
    try {
      final result = await _repo.login(username, password);
      state = AdminAuthenticated(
        admin: result.admin,
        accessToken: result.accessToken,
      );
    } catch (e) {
      state = AdminAuthError(_msg(e));
    }
  }

  Future<void> logout() async {
    await _repo.clearToken();
    state = const AdminAuthInitial();
  }

  String? get token {
    final s = state;
    return s is AdminAuthenticated ? s.accessToken : null;
  }

  static String _msg(Object e) =>
      e.toString().replaceFirst('Exception: ', '');
}

// ── Rider list controller ─────────────────────────────────────────────────────

class AdminRiderListController extends StateNotifier<AdminRiderListState> {
  final AdminRepository _repo;

  AdminRiderListController(this._repo) : super(const AdminRiderListInitial());

  Future<void> load(
    String token, {
    String filter = 'all',
    String search = '',
    bool silent = false,
  }) async {
    if (!silent) state = const AdminRiderListLoading();
    try {
      final current = _loaded;

      final result = await _repo.getRiders(
        token,
        status: filter == 'all' ? null : filter,
        search: search.isEmpty ? null : search,
      );

      DashboardStats? stats = current?.stats;
      try {
        stats = await _repo.getStats(token);
      } catch (_) {}

      state = AdminRiderListLoaded(
        riders: result.riders,
        counts: result.counts,
        activeFilter: filter,
        stats: stats,
      );
    } catch (e) {
      state = AdminRiderListError(_msg(e));
    }
  }

  Future<void> refresh(String token, {String filter = 'all'}) =>
      load(token, filter: filter, silent: true);

  AdminRiderListLoaded? get _loaded =>
      state is AdminRiderListLoaded ? state as AdminRiderListLoaded : null;

  static String _msg(Object e) =>
      e.toString().replaceFirst('Exception: ', '');
}

// ── Rider detail controller ───────────────────────────────────────────────────

class AdminRiderDetailController
    extends StateNotifier<AdminRiderDetailState> {
  final AdminRepository _repo;
  final String riderId;

  AdminRiderDetailController(this._repo, this.riderId)
      : super(const AdminRiderDetailInitial());

  Future<void> load(String token) async {
    state = const AdminRiderDetailLoading();
    try {
      final rider = await _repo.getRiderDetail(token, riderId);
      state = AdminRiderDetailLoaded(rider);
    } catch (e) {
      state = AdminRiderDetailError(_msg(e));
    }
  }

  Future<void> takeAction(
    String token,
    String action, {
    String reason = '',
  }) async {
    final current = _rider;
    if (current == null) return;
    state = AdminRiderDetailActionLoading(current);
    try {
      await _repo.takeAction(token, riderId, action, reason: reason);
      final updated = await _repo.getRiderDetail(token, riderId);
      state = AdminRiderDetailActionSuccess(
        rider: updated,
        message: _label(action),
      );
    } catch (e) {
      state = AdminRiderDetailError(_msg(e), rider: current);
    }
  }

  AdminRider? get _rider {
    final s = state;
    if (s is AdminRiderDetailLoaded) return s.rider;
    if (s is AdminRiderDetailActionLoading) return s.rider;
    if (s is AdminRiderDetailActionSuccess) return s.rider;
    if (s is AdminRiderDetailError) return s.rider;
    return null;
  }

  static String _label(String action) {
    const labels = {
      'approve': 'Rider approved',
      'reject': 'Rider rejected',
      'suspend': 'Rider suspended',
      'reactivate': 'Rider reactivated',
    };
    return labels[action] ?? 'Action applied';
  }

  static String _msg(Object e) =>
      e.toString().replaceFirst('Exception: ', '');
}
