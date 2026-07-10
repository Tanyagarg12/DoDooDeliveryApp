import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/store_entity.dart';
import '../controllers/store_dashboard_controller.dart';
import 'store_dashboard_screen.dart';
import 'store_menu_view.dart';
import 'store_orders_view.dart';
import 'store_settings_screen.dart';
import 'store_wallet_screen.dart';

/// The approved-store home: Dashboard, Orders, Menu, Wallet, Settings.
/// The active tab is driven by [selectedStoreTabProvider] so widgets deep in
/// a tab (e.g. the dashboard earnings badge) can jump to another tab.
class StoreHomeShell extends ConsumerWidget {
  const StoreHomeShell({super.key, required this.store});

  final StoreEntity store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(selectedStoreTabProvider);
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: IndexedStack(
        index: index,
        children: [
          StoreDashboardScreen(store: store),
          StoreOrdersView(store: store),
          StoreMenuView(store: store),
          StoreWalletScreen(store: store),
          StoreSettingsScreen(store: store),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(selectedStoreTabProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.restaurant_menu_outlined),
              selectedIcon: Icon(Icons.restaurant_menu_rounded),
              label: 'Menu'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Wallet'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings'),
        ],
      ),
    );
  }
}
