import '../../domain/entities/admin_entities.dart';

// ── Auth state ────────────────────────────────────────────────────────────────

sealed class AdminAuthState {
  const AdminAuthState();
}

class AdminAuthInitial extends AdminAuthState {
  const AdminAuthInitial();
}

class AdminAuthLoading extends AdminAuthState {
  const AdminAuthLoading();
}

class AdminAuthenticated extends AdminAuthState {
  final AdminUser admin;
  final String accessToken;
  const AdminAuthenticated({required this.admin, required this.accessToken});
}

class AdminAuthError extends AdminAuthState {
  final String message;
  const AdminAuthError(this.message);
}

// ── Rider list state ──────────────────────────────────────────────────────────

sealed class AdminRiderListState {
  const AdminRiderListState();
}

class AdminRiderListInitial extends AdminRiderListState {
  const AdminRiderListInitial();
}

class AdminRiderListLoading extends AdminRiderListState {
  const AdminRiderListLoading();
}

class AdminRiderListLoaded extends AdminRiderListState {
  final List<AdminRider> riders;
  final Map<String, int> counts;
  final String activeFilter;
  final DashboardStats? stats;

  const AdminRiderListLoaded({
    required this.riders,
    required this.counts,
    required this.activeFilter,
    this.stats,
  });

  AdminRiderListLoaded copyWith({
    List<AdminRider>? riders,
    Map<String, int>? counts,
    String? activeFilter,
    DashboardStats? stats,
  }) {
    return AdminRiderListLoaded(
      riders: riders ?? this.riders,
      counts: counts ?? this.counts,
      activeFilter: activeFilter ?? this.activeFilter,
      stats: stats ?? this.stats,
    );
  }
}

class AdminRiderListError extends AdminRiderListState {
  final String message;
  const AdminRiderListError(this.message);
}

// ── Rider detail state ────────────────────────────────────────────────────────

sealed class AdminRiderDetailState {
  const AdminRiderDetailState();
}

class AdminRiderDetailInitial extends AdminRiderDetailState {
  const AdminRiderDetailInitial();
}

class AdminRiderDetailLoading extends AdminRiderDetailState {
  const AdminRiderDetailLoading();
}

class AdminRiderDetailLoaded extends AdminRiderDetailState {
  final AdminRider rider;
  const AdminRiderDetailLoaded(this.rider);
}

class AdminRiderDetailActionLoading extends AdminRiderDetailState {
  final AdminRider rider;
  const AdminRiderDetailActionLoading(this.rider);
}

class AdminRiderDetailActionSuccess extends AdminRiderDetailState {
  final AdminRider rider;
  final String message;
  const AdminRiderDetailActionSuccess({
    required this.rider,
    required this.message,
  });
}

class AdminRiderDetailError extends AdminRiderDetailState {
  final String message;
  final AdminRider? rider;
  const AdminRiderDetailError(this.message, {this.rider});
}
