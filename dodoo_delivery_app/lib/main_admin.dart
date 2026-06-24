import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/presentation/controllers/admin_controller.dart';
import 'features/admin/presentation/screens/admin_dashboard_screen.dart';
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
      home: const _AdminGate(),
    );
  }
}

/// Keeps the admin logged in across app restarts: restores a saved session on
/// launch and only returns to login after an explicit logout.
class _AdminGate extends ConsumerStatefulWidget {
  const _AdminGate();

  @override
  ConsumerState<_AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends ConsumerState<_AdminGate> {
  bool _checking = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final ok =
        await ref.read(adminAuthControllerProvider.notifier).restoreSession();
    if (mounted) {
      setState(() {
        _loggedIn = ok;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFFF6F7E8),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFBABC2F)),
        ),
      );
    }
    return _loggedIn ? const AdminDashboardScreen() : const AdminLoginScreen();
  }
}
