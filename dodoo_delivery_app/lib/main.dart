import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'core/api/rider_firestore_api.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/presentation/screens/admin_login_screen.dart';
import 'features/auth/domain/entities/rider_entity.dart';
import 'features/auth/presentation/screens/phone_input_screen.dart';
import 'features/home/presentation/controllers/rider_dashboard_controller.dart';
import 'features/home/presentation/screens/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase — the app's backend (Firestore, Auth, Storage).
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: DodooRiderApp()));
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
        '/': (_) => const PhoneInputScreen(),
        '/admin': (_) => const AdminLoginScreen(),
        '/home': (ctx) {
          final rider =
              ModalRoute.of(ctx)!.settings.arguments as RiderEntity?;
          final api = RiderFirestoreApi();
          final riderMap = rider == null
              ? <String, dynamic>{}
              : {
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
          return HomeShell(api: api, initialRider: riderMap);
        },
      },
    );
  }
}
