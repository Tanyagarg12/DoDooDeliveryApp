/// Holds the currently logged-in store's identity for the session.
///
/// Like riders, stores authenticate via the external DoDoo OTP API (not
/// Firebase Phone Auth), so a store is identified by its **phone number**,
/// which is also its Firestore `stores` document id. A Firebase *anonymous*
/// session runs underneath so Firestore rules (`request.auth != null`) pass.
class StoreSession {
  StoreSession._();

  /// The logged-in store's Firestore doc id (== the owner's phone number).
  /// Null when no store is logged in.
  static String? storeId;
}
