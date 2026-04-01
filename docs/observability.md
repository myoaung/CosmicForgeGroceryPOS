# Observability Baseline

## Stack

- Sentry: application errors and crash reporting
- Prometheus: metrics scraping
- Grafana: dashboards and alerting

## Required Metrics

- `pos_transactions_total`
- `sync_failures_total`
- `api_latency_ms`
- `device_offline_rate`

## Required Events

- checkout
- refund
- inventory update
- device login
- sync errors

## Current Implementation

- `lib/core/services/observability_service.dart` emits structured metrics/events to logs.
- `infra/monitoring/prometheus.yml` provides starter scrape configuration.

## Next Hardening Steps

1. Add Sentry Flutter SDK initialization in `main.dart`.
2. Expose `/metrics` endpoint for sync worker and edge handlers.
3. Import dashboard JSON into Grafana and attach alert rules.
