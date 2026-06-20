/// Rider wallet payout policy.
///
/// • Every morning at 8:00 AM the rider's wallet is auto-transferred to their
///   registered bank account.
/// • A maintenance balance of ₹100 is always kept in the wallet, so only the
///   amount above ₹100 is paid out (and manual withdrawals can't drain below
///   ₹100 either).
///
/// The actual money movement is handled server-side by the daily auto-payout
/// job (see supabase/auto_payout.sql). This class is the single source of truth
/// for the numbers/labels shown in the app.
class PayoutPolicy {
  PayoutPolicy._();

  /// Amount (₹) always kept in the wallet for maintenance.
  static const double minMaintenanceBalance = 100;

  /// Hour of day (local / IST) the auto-payout runs.
  static const int payoutHour = 8;

  /// Human-readable payout time for the UI.
  static const String payoutTimeLabel = '8:00 AM';

  /// The amount a rider can actually withdraw/be paid out right now — the
  /// wallet balance minus the maintenance floor (never negative).
  static double withdrawable(double balance) {
    final amount = balance - minMaintenanceBalance;
    return amount > 0 ? amount : 0;
  }
}
