import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/store.dart';
import '../services/store_service.dart';
import '../localization/mmk_rounding.dart';

// Service Provider
final storeServiceProvider = Provider<StoreService>((ref) {
  return StoreService();
});

// StateProvider for the Active Store
// In a real app, this might be a StateNotifier that interacts with the Service
final activeStoreProvider = StateProvider<Store?>((ref) => null);

// Tax Rate Provider is now managed by TaxRateNotifier in tax_provider.dart

// Rounding Logic Provider
final roundingLogicProvider = Provider<Function(double)>((ref) {
  // Always provides the nearest 5/10 MMK rounding logic established in Phase 1
  return roundToNearest5;
});
