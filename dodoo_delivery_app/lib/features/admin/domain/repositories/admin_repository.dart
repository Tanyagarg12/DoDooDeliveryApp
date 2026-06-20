import '../entities/admin_entities.dart';

abstract class AdminRepository {
  Future<({String accessToken, AdminUser admin})> login(
    String username,
    String password,
  );

  Future<String?> getSavedToken();
  Future<void> clearToken();

  Future<DashboardStats> getStats(String token);

  Future<RiderListResult> getRiders(
    String token, {
    String? status,
    String? search,
  });

  Future<AdminRider> getRiderDetail(String token, String riderId);

  Future<void> takeAction(
    String token,
    String riderId,
    String action, {
    String reason = '',
  });

  Future<List<ApprovalLog>> getLogs(String token, String riderId);
}
