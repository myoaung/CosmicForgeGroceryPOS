import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_provider.dart';
import '../services/sync_service.dart' show SyncService, SupabaseSyncGateway;

// ── Sync status domain ────────────────────────────────────────────────────────

/// The high-level sync state seen by the UI layer.
enum SyncStatus {
  /// Online and all local changes have been pushed to the cloud.
  synced,

  /// There are local changes waiting to be pushed (offline or mid-sync).
  pending,

  /// Device has no network connection.
  offline,

  /// A sync item was rejected because its tenant_id doesn't match the JWT.
  tenantError,

  /// Supabase returned a 403 Forbidden on a push attempt.
  forbidden,
}

/// Immutable snapshot of the current sync state.
class SyncState {
  const SyncState({
    required this.status,
    required this.pendingCount,
    this.lastErrorCode,
    this.lastErrorMessage,
  });

  /// High-level classification.
  final SyncStatus status;

  /// Number of local records not yet confirmed synced.
  final int pendingCount;

  /// HTTP status code of the last sync error (e.g. 403), or null if none.
  final int? lastErrorCode;

  /// Human-readable description of the last error, or null if none.
  final String? lastErrorMessage;

  /// Convenience: true when there are no pending items and status is synced.
  bool get isHealthy => status == SyncStatus.synced && pendingCount == 0;

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    int? lastErrorCode,
    String? lastErrorMessage,
  }) =>
      SyncState(
        status: status ?? this.status,
        pendingCount: pendingCount ?? this.pendingCount,
        lastErrorCode: lastErrorCode ?? this.lastErrorCode,
        lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      );

  @override
  String toString() =>
      'SyncState(status: $status, pending: $pendingCount, '
      'errorCode: $lastErrorCode)';
}

// ── SyncStateNotifier ─────────────────────────────────────────────────────────

/// Reactive notifier exposing the current [SyncState] to the widget tree.
///
/// Consumes the local DB stream for pending-count changes and exposes methods
/// to report errors (403, TENANT_MISMATCH) from the sync service layer.
class SyncStateNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    // Subscribe to the local transactions stream for pending-count updates.
    final db = ref.watch(databaseProvider);
    db.select(db.transactions).watch().listen((all) {
      final pending = all.where((t) => t.syncStatus != 'synced').length;
      _updatePendingCount(pending);
    });

    return const SyncState(status: SyncStatus.pending, pendingCount: 0);
  }

  /// Called by the sync service when a push succeeds and queue is clear.
  void markSynced() {
    state = const SyncState(status: SyncStatus.synced, pendingCount: 0);
  }

  /// Called by connectivity logic when the device goes offline.
  void markOffline() {
    state = state.copyWith(status: SyncStatus.offline);
  }

  /// Called by connectivity logic when the device reconnects.
  void markOnline() {
    if (state.status == SyncStatus.offline) {
      state = state.copyWith(
        status: state.pendingCount > 0 ? SyncStatus.pending : SyncStatus.synced,
      );
    }
  }

  /// Called by [SyncQueueWorker] when a TENANT_MISMATCH dead-letter occurs.
  void reportTenantMismatch({required String details}) {
    state = state.copyWith(
      status: SyncStatus.tenantError,
      lastErrorCode: null,
      lastErrorMessage: 'TENANT_MISMATCH: $details',
    );
  }

  /// Called by [SyncService] when Supabase returns an HTTP error.
  void reportHttpError(int statusCode, String message) {
    final mapped = statusCode == 403
        ? SyncStatus.forbidden
        : SyncStatus.pending; // other HTTP errors keep pending state
    state = state.copyWith(
      status: mapped,
      lastErrorCode: statusCode,
      lastErrorMessage: message,
    );
  }

  /// Clears any error state without changing pending count.
  void clearError() {
    state = state.copyWith(
      status: state.pendingCount > 0 ? SyncStatus.pending : SyncStatus.synced,
      lastErrorCode: null,
      lastErrorMessage: null,
    );
  }

  void _updatePendingCount(int count) {
    // Don't override an active error state — just update the count.
    final keepStatus = state.status == SyncStatus.tenantError ||
            state.status == SyncStatus.forbidden ||
            state.status == SyncStatus.offline
        ? state.status
        : count == 0
            ? SyncStatus.synced
            : SyncStatus.pending;

    state = state.copyWith(
      pendingCount: count,
      status: keepStatus,
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// The underlying [SyncService] instance (unchanged from original).
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  SupabaseClient? client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    // Not initialized in test or offline bootstrap.
  }
  final gateway = client != null ? SupabaseSyncGateway(client) : null;
  final service = SyncService(db, client, gateway);
  ref.onDispose(service.dispose);
  return service;
});

/// Reactive [SyncState] provider for the widget layer.
///
/// ```dart
/// final state = ref.watch(syncStateProvider);
/// ```
final syncStateProvider = NotifierProvider<SyncStateNotifier, SyncState>(
  SyncStateNotifier.new,
);
