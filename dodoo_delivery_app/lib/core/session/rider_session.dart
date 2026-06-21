/// Holds the currently logged-in rider's identity for the session.
///
/// Since OTP is handled by the external DoDoo API (not Firebase Phone Auth),
/// riders are identified by their **phone number**, which is also their
/// Firestore `riders` document id. A Firebase *anonymous* session runs
/// underneath purely so Firestore security rules (`request.auth != null`) pass.
class RiderSession {
  RiderSession._();

  /// The logged-in rider's Firestore doc id (== their phone number).
  /// Null when no rider is logged in.
  static String? riderId;
}
