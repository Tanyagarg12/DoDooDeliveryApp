import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/presentation/screens/admin_login_screen.dart';

/// Entry point for the **DoDoo Admin** app — a separate APK from the rider app.
/// Build it with:  flutter build apk --release -t lib/main_admin.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: DodooAdminApp()));
}

class DodooAdminApp extends ConsumerWidget {
  const DodooAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DoDoo Admin',
      theme: AppTheme.light(),
      // Admin screens are designed for light mode — pin it so the UI never
      // renders washed-out under the device's system dark mode.
      themeMode: ThemeMode.light,
      home: const AdminLoginScreen(),
    );
  }
}
