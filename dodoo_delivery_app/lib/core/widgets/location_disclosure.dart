import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

const _kLocationDisclosureKey = 'location_disclosure_accepted_v1';

/// Google Play **Prominent Disclosure** for background location.
///
/// Shows a one-time consent screen that explains — in plain language, BEFORE
/// the Android system location dialog — that the app collects location in the
/// background and why. Required by Play policy for `ACCESS_BACKGROUND_LOCATION`.
///
/// Returns `true` if the rider consents (or already did previously); the caller
/// should only then proceed to request the OS permission / go online.
Future<bool> ensureLocationDisclosure(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kLocationDisclosureKey) ?? false) return true;
  if (!context.mounted) return false;

  final consented = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.my_location_rounded, color: AppColors.primary),
      title: const Text('Location sharing while you deliver'),
      content: const SingleChildScrollView(
        child: Text(
          'DoDoo Rider collects your location to share it with DoDoo — '
          'including in the background, even when the app is closed or not in '
          'use — while you are Online and on a delivery.\n\n'
          'We use it to assign nearby orders to you and to show your live '
          'location on the delivery map so the order can be tracked.\n\n'
          'Your location is shared only while you are Online, and sharing stops '
          'as soon as you go Offline.\n\n'
          'Do you want to continue and allow location access?',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );

  if (consented == true) {
    await prefs.setBool(_kLocationDisclosureKey, true);
    return true;
  }
  return false;
}
