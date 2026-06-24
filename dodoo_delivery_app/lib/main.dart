import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'core/api/rider_firestore_api.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/entities/rider_entity.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/screens/account_status_screen.dart';
import 'features/auth/presentation/screens/phone_input_screen.dart';
import 'features/home/presentation/controllers/rider_dashboard_controller.dart';
import 'features/home/presentation/screens/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase — the app's backend (Firestore, Auth, Storage).
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: DodooRiderApp()));
}

/// Builds the rider map the HomeShell expects from a [RiderEntity].
Map<String, dynamic> riderToMap(RiderEntity? rider) {
  if (rider == null) return <String, dynamic>{};
  return {
    'id': rider.id,
    'first_name': rider.firstName,
    'last_name': rider.lastName,
    'phone': rider.phone,
    'email': rider.email ?? '',
    'address': rider.address ?? '',
    'profile_picture_url': rider.profilePictureUrl ?? '',
    'driving_license_number': rider.drivingLicenseNumber ?? '',
    'aadhar_number': rider.aadhaarNumber ?? '',
    'account_status': rider.accountStatus.name,
    'current_status': rider.currentStatus,
    'wallet_balance': rider.walletBalance,
    'rating': rider.rating,
    'total_orders': rider.totalOrders,
    'is_verified': rider.isVerified,
    'is_document_verified': rider.isDocumentVerified,
  };
}

class DodooRiderApp extends ConsumerWidget {
  const DodooRiderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DoDoo Rider',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/',
      routes: {
        // The gate restores any saved session on launch so a logged-in rider
        // is not asked to sign in again after killing the app.
        '/': (_) => const _RiderGate(),
        '/home': (ctx) {
          final rider =
              ModalRoute.of(ctx)!.settings.arguments as RiderEntity?;
          return HomeShell(api: RiderFirestoreApi(), initialRider: riderToMap(rider));
        },
      },
    );
  }
}

/// Decides the first screen after launch:
///   • no saved session  → login (PhoneInputScreen)
///   • saved + approved   → HomeShell
///   • saved + not approved → AccountStatusScreen
class _RiderGate extends ConsumerStatefulWidget {
  const _RiderGate();

  @override
  ConsumerState<_RiderGate> createState() => _RiderGateState();
}

class _RiderGateState extends ConsumerState<_RiderGate> {
  bool _checking = true;
  RiderEntity? _rider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    RiderEntity? rider;
    try {
      rider = await ref.read(authRepositoryProvider).restoreSession();
    } catch (_) {
      rider = null;
    }
    if (!mounted) return;
    setState(() {
      _rider = rider;
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
    final rider = _rider;
    if (rider == null) return const PhoneInputScreen();
    if (rider.isApproved) {
      return HomeShell(api: RiderFirestoreApi(), initialRider: riderToMap(rider));
    }
    return AccountStatusScreen(rider: rider);
  }
}
