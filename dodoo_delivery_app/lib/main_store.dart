import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/store/domain/entities/store_entity.dart';
import 'features/store/presentation/controllers/store_auth_controller.dart';
import 'features/store/presentation/screens/store_account_status_screen.dart';
import 'features/store/presentation/screens/store_home_shell.dart';
import 'features/store/presentation/screens/store_phone_input_screen.dart';
import 'firebase_options.dart';

/// Store/merchant app entry point. Build with:
///   flutter build apk --release -t lib/main_store.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Local notifications (new-order alerts fired while the app is running).
  await NotificationService.instance.init();
  runApp(const ProviderScope(child: DodooStoreApp()));
}

class DodooStoreApp extends StatelessWidget {
  const DodooStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DoDoo Store',
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      home: const _StoreGate(),
    );
  }
}

/// Decides the first screen: no session → login; approved → dashboard;
/// otherwise → the account-status screen.
class _StoreGate extends ConsumerStatefulWidget {
  const _StoreGate();

  @override
  ConsumerState<_StoreGate> createState() => _StoreGateState();
}

class _StoreGateState extends ConsumerState<_StoreGate> {
  bool _checking = true;
  StoreEntity? _store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    StoreEntity? store;
    try {
      store = await ref.read(storeAuthRepositoryProvider).restoreSession();
    } catch (_) {
      store = null;
    }
    if (!mounted) return;
    setState(() {
      _store = store;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.bgLight,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final store = _store;
    if (store == null) return const StorePhoneInputScreen();
    // Approved + already entered the app once → straight to home.
    // Approved but not yet started → show the one-time "Store Approved!"
    // welcome. Not approved → show the pending/rejected status screen.
    if (store.isApproved && store.hasStarted) return StoreHomeShell(store: store);
    return StoreAccountStatusScreen(store: store);
  }
}
