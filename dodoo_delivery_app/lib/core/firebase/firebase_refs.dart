import 'package:cloud_firestore/cloud_firestore.dart';

/// Central reference point for the Firestore data model.
///
/// Collections mirror the previous Supabase tables 1:1 so the migration can
/// happen module-by-module:
///
///   riders/{riderId}                 – rider profile, wallet, status, docs
///   orders/{orderId}                 – delivery orders (city_code, status, …)
///   order_offers/{offerId}           – broadcast offers (rider_id, order_id, …)
///   withdrawal_requests/{id}         – manual + auto payouts
///   wallet_transactions/{id}         – credits/debits ledger
///   rider_tracking/{riderId}         – live location (1 doc per rider)
///   app_settings/{key}               – admin-configurable settings
///   admins/{username}                – admin accounts
///
/// Use these getters everywhere instead of `FirebaseFirestore.instance
/// .collection('...')` so collection names stay consistent.
class Db {
  Db._();

  static FirebaseFirestore get instance => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get riders =>
      instance.collection('riders');

  static CollectionReference<Map<String, dynamic>> get orders =>
      instance.collection('orders');

  static CollectionReference<Map<String, dynamic>> get orderOffers =>
      instance.collection('order_offers');

  static CollectionReference<Map<String, dynamic>> get withdrawalRequests =>
      instance.collection('withdrawal_requests');

  static CollectionReference<Map<String, dynamic>> get walletTransactions =>
      instance.collection('wallet_transactions');

  static CollectionReference<Map<String, dynamic>> get riderTracking =>
      instance.collection('rider_tracking');

  static CollectionReference<Map<String, dynamic>> get appSettings =>
      instance.collection('app_settings');

  static CollectionReference<Map<String, dynamic>> get admins =>
      instance.collection('admins');
}
