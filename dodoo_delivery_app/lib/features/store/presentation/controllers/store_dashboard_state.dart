import '../../domain/entities/store_entity.dart';

class StoreDashboardState {
  final StoreEntity store;
  final bool isLoading;
  final String? error;
  final int activeOrdersCount;
  final int completedOrdersCount;
  final double todayEarnings;
  final List<Map<String, dynamic>> activeOrders;

  const StoreDashboardState({
    required this.store,
    this.isLoading = false,
    this.error,
    this.activeOrdersCount = 0,
    this.completedOrdersCount = 0,
    this.todayEarnings = 0,
    this.activeOrders = const [],
  });

  bool get hasActiveOrders => activeOrdersCount > 0;
  bool get isStoreOpen => store.isOpen;

  StoreDashboardState copyWith({
    StoreEntity? store,
    bool? isLoading,
    String? error,
    int? activeOrdersCount,
    int? completedOrdersCount,
    double? todayEarnings,
    List<Map<String, dynamic>>? activeOrders,
  }) {
    return StoreDashboardState(
      store: store ?? this.store,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      activeOrdersCount: activeOrdersCount ?? this.activeOrdersCount,
      completedOrdersCount: completedOrdersCount ?? this.completedOrdersCount,
      todayEarnings: todayEarnings ?? this.todayEarnings,
      activeOrders: activeOrders ?? this.activeOrders,
    );
  }
}
