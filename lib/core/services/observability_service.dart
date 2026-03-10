import 'package:flutter/foundation.dart';

class ObservabilityService {
  const ObservabilityService();

  void recordEvent(String event, {Map<String, Object?> metadata = const {}}) {
    debugPrint('[OBS][event] $event ${_format(metadata)}');
  }

  void incrementMetric(
    String metric, {
    int value = 1,
    Map<String, String> labels = const {},
  }) {
    debugPrint('[OBS][metric] $metric +$value ${_format(labels)}');
  }

  void recordLatency(
    String metric,
    Duration latency, {
    Map<String, String> labels = const {},
  }) {
    debugPrint('[OBS][latency] $metric=${latency.inMilliseconds}ms ${_format(labels)}');
  }

  void captureSentryEvent(
    String event, {
    Map<String, Object?> metadata = const {},
    String level = 'warning',
  }) {
    // TODO: wire this to the real Sentry SDK (docs/observability.md covers initialization hooks).
    debugPrint('[SENTRY][placeholder][$level] $event ${_format(metadata)}');
  }

  Map<String, Object> gatherPrometheusMetrics() {
    // TODO: expose actual counters (queue length, retries, errors) via `/metrics` per docs/observability.md.
    return {
      'sync_queue_length': 0,
      'sync_retries_total': 0,
      'sync_errors_total': 0,
    };
  }

  String get prometheusEndpoint => '/metrics'; // Hint for future HTTP server wiring.

  String _format(Map<dynamic, dynamic> fields) {
    if (fields.isEmpty) return '';
    return fields.entries.map((e) => '${e.key}=${e.value}').join(' ');
  }
}
