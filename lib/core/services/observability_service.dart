import 'package:flutter/foundation.dart';

class ObservabilityService {
  const ObservabilityService();

  static final List<Map<String, dynamic>> _sentryBreadcrumbs = [];
  static int _syncRetriesTotal = 0;
  static int _syncErrorsTotal = 0;
  static int _syncQueueLength = 0;
  static Duration _lastSyncLatency = Duration.zero;
  static Duration _totalOfflineDuration = Duration.zero;

  void recordEvent(String event, {Map<String, Object?> metadata = const {}}) {
    debugPrint('[OBS][event] $event ${_format(metadata)}');
    _sentryBreadcrumbs.add({
      'type': 'event', 
      'event': event, 
      'metadata': metadata, 
      'timestamp': DateTime.now().toIso8601String()
    });
    if (_sentryBreadcrumbs.length > 50) _sentryBreadcrumbs.removeAt(0);
  }

  void incrementMetric(
    String metric, {
    int value = 1,
    Map<String, String> labels = const {},
  }) {
    debugPrint('[OBS][metric] $metric +$value ${_format(labels)}');
    if (metric == 'sync.retry' || metric == 'sync_retry') _syncRetriesTotal += value;
    if (metric == 'sync.error' || metric == 'sync.failure') _syncErrorsTotal += value;
    if (metric == 'sync.queue_length') _syncQueueLength = value;
  }

  void recordLatency(
    String metric,
    Duration latency, {
    Map<String, String> labels = const {},
  }) {
    debugPrint('[OBS][latency] $metric=${latency.inMilliseconds}ms ${_format(labels)}');
    if (metric == 'sync_latency') _lastSyncLatency = latency;
    if (metric == 'offline_duration') _totalOfflineDuration += latency;
  }

  void captureSentryEvent(
    String event, {
    Map<String, Object?> metadata = const {},
    String level = 'warning',
  }) {
    debugPrint('[SENTRY][local_fallback][$level] $event ${_format(metadata)}');
    _sentryBreadcrumbs.add({
      'type': 'sentry_event', 
      'event': event, 
      'level': level, 
      'metadata': metadata, 
      'timestamp': DateTime.now().toIso8601String()
    });
    if (_sentryBreadcrumbs.length > 50) _sentryBreadcrumbs.removeAt(0);
  }

  Map<String, Object> gatherPrometheusMetrics() {
    return {
      'sync_queue_length': _syncQueueLength,
      'sync_retries_total': _syncRetriesTotal,
      'sync_errors_total': _syncErrorsTotal,
      'sync_latency_ms': _lastSyncLatency.inMilliseconds,
      'offline_duration_ms': _totalOfflineDuration.inMilliseconds,
    };
  }

  String get prometheusEndpoint => '/metrics'; // Hint for future HTTP server wiring.

  String _format(Map<dynamic, dynamic> fields) {
    if (fields.isEmpty) return '';
    return fields.entries.map((e) => '${e.key}=${e.value}').join(' ');
  }
}
