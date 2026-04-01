import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery/core/repositories/history_repository.dart';
import 'package:grocery/core/providers/database_provider.dart';
import 'package:grocery/core/providers/store_provider.dart';

final historyProvider = StateNotifierProvider<HistoryNotifier,
    AsyncValue<List<TransactionWithItems>>>((ref) {
  final repo = DriftHistoryRepository(ref.watch(databaseProvider));
  final scope = ref.watch(activeTenantStoreScopeProvider);
  return HistoryNotifier(
    repo,
    tenantId: scope?.tenantId,
    storeId: scope?.storeId,
  );
});

class HistoryNotifier
    extends StateNotifier<AsyncValue<List<TransactionWithItems>>> {
  final HistoryRepository _repo;
  final String? _tenantId;
  final String? _storeId;

  HistoryNotifier(
    this._repo, {
    String? tenantId,
    String? storeId,
  })  : _tenantId = tenantId,
        _storeId = storeId,
        super(const AsyncValue.loading()) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      state = const AsyncValue.loading();
      final tenantId = _tenantId;
      if (tenantId == null || tenantId.isEmpty) {
        state = const AsyncValue.data(<TransactionWithItems>[]);
        return;
      }
      final history = await _repo.fetchRecent(
        limit: 50,
        tenantId: tenantId,
        storeId: _storeId,
      );
      state = AsyncValue.data(history);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await loadHistory();
  }
}
