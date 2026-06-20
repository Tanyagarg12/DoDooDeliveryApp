import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../firebase/firestore_service.dart';

/// Firebase Phone Auth service — wraps the callback-based verifyPhoneNumber
/// in a Future-friendly interface.
class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  final _auth = FirebaseAuth.instance;
  String? _verificationId;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  /// Normalises an Indian mobile number to E.164 (+91XXXXXXXXXX), which is
  /// what Firebase phone auth requires. The UI passes bare 10-digit numbers.
  static String toE164(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+')) return digits;
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return '+$digits';
  }

  /// Send OTP to [phone] (bare 10-digit or E.164).
  /// Completes when the SMS code is dispatched (codeSent callback).
  Future<void> sendOtp(String phone) async {
    final completer = Completer<void>();

    await _auth.verifyPhoneNumber(
      phoneNumber: toE164(phone),
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Auto-retrieval on Android — sign in silently
        try {
          await _auth.signInWithCredential(credential);
        } catch (_) {}
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.completeError(Exception(e.message ?? 'Phone verification failed'));
        }
      },
      codeSent: (verificationId, _) {
        _verificationId = verificationId;
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }

  /// Verify the OTP [code] and sign the user in.
  /// Returns the signed-in [User].
  Future<User> verifyOtp(String code) async {
    if (_verificationId == null) {
      throw Exception('No pending OTP. Call sendOtp() first.');
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: code,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user!;
  }

  /// Returns true if a rider document already exists in Firestore.
  Future<bool> riderExists(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('riders').doc(uid).get();
    return doc.exists;
  }

  /// Check whether a phone number is registered in Firestore.
  Future<Map<String, dynamic>?> findRiderByPhone(String phone) async {
    return FirestoreService.instance.findRiderByPhone(phone);
  }

  Future<void> signOut() async {
    _verificationId = null;
    await _auth.signOut();
  }
}
