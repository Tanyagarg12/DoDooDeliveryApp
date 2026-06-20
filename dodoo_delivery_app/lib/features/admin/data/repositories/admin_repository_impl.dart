import '../../domain/entities/admin_entities.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_firestore_datasource.dart';
import '../models/admin_models.dart';

class AdminRepositoryImpl implements AdminRepository {
  final AdminFirestoreDataSource _ds;

  const AdminRepositoryImpl(this._ds);

  @override
  Future<({String accessToken, AdminUser admin})> login(
    String username,
    String password,
  ) async {
    final result = await _ds.login(username, password);
    return (accessToken: result.accessToken, admin: result.admin);
  }

  @override
  Future<String?> getSavedToken() => _ds.getSavedToken();

  @override
  Future<void> clearToken() => _ds.clearToken();

  @override
  Future<DashboardStats> getStats(String token) => _ds.getStats(token);

  @override
  Future<RiderListResult> getRiders(
    String token, {
    String? status,
    String? search,
  }) async {
    final raw = await _ds.getRiders(token, status: status, search: search);
    final ridersList = (raw['riders'] as List? ?? [])
        .map((e) => AdminRiderModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final countsRaw = raw['counts'] as Map<String, dynamic>? ?? {};
    final counts = countsRaw.map(
      (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
    );

    return RiderListResult(riders: ridersList, counts: counts);
  }

  @override
  Future<AdminRider> getRiderDetail(String token, String riderId) =>
      _ds.getRiderDetail(token, riderId);

  @override
  Future<void> takeAction(
    String token,
    String riderId,
    String action, {
    String reason = '',
  }) =>
      _ds.takeAction(token, riderId, action, reason: reason);

  @override
  Future<List<ApprovalLog>> getLogs(String token, String riderId) =>
      _ds.getLogs(token, riderId);
}
