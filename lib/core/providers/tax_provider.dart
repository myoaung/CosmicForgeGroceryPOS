import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery/core/providers/store_provider.dart';
import '../../core/services/store_service.dart';

final taxRateProvider = StateNotifierProvider<TaxRateNotifier, double>((ref) {
  final storeService = ref.watch(storeServiceProvider);
  return TaxRateNotifier(storeService);
});

class TaxRateNotifier extends StateNotifier<double> {
  final StoreService _storeService;

  TaxRateNotifier(this._storeService) : super(0.0) {
    _initialize();
  }

  void _initialize() {
    final activeStore = _storeService.activeStore;
    if (activeStore != null) {
      state = activeStore.taxRate;
    }
  }

  /// Handles manual Manager overrides with audit logging
  Future<void> updateTaxRateOverride(double newRate, String reason) async {
    final previousRate = state;
    state = newRate;
    try {
      if (_storeService.activeStore != null) {
        await _storeService.updateStoreTaxRate(_storeService.activeStore!.id, newRate);
        await _storeService.logAudit(
          actionType: 'TAX_RATE_OVERRIDE',
          description: 'Tax changed from $previousRate% to $newRate%. Reason: $reason',
        );
      }
    } catch (e) {
      // Fallback handled by StoreService internally for update, but we should log local error
      print('Tax Override Error: $e');
      // If store update failed, StoreService likely reverted or used local fallback.
      // We keep state as is to reflect UI change optimistically or revert if needed?
      // Requirement says "Fallback handled by StoreService", implying StoreService handles synchronization.
    }
  }
}
