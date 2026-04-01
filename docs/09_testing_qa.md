# 9. Testing Strategy & QA Processes

## 9.1 Overall Philosophy
The Grocery POS enforces a strict Testing Pyramid logic prioritizing deep architectural tests over shallow UI rendering. Minimum enforcement boundary is **70% coverage** via `lcov`.

## 9.2 Layer Definition

### 1. Unit Testing
Deep-testing isolated Business Logic (`CartNotifier`, `CheckoutUseCase`). Validates standard behaviors (Item adding) and complex edge cases (Mocking missing `SessionContext` values during RLS propagation).

### 2. Widget (Component) Testing
Tests atomic UI behaviors (`pos_screen.dart`, `store_switcher.dart`). Mocks Riverpod dependencies heavily and ensures interactions emit the correct state mutations (e.g. testing the UI rebuild constraints within the cart Consumer).

### 3. Verification & Architecture Smoke Tests
Validates the structural integrity of the project utilizing Dart reflection:
- **`architecture_verification_test.dart`**: Crawls the Drift database codebase to assert that absolutely all tables rigidly adhere to the mandatory `Offline-First Columns` (`isDirty`, `syncStatus`, `version`).

### 4. Chaos & Integration Testing
Simulates harsh networking states within `test/chaos/...`:
- **`checkout_chaos_test.dart`**: Imitates a process crash *mid-checkout* to guarantee database transaction rollbacks execute cleanly without duplicating receipts.
- **`sync_resilience_test.dart`**: Triggers deliberate `ConflictException` and evaluates the Exponential Backoff loop inside the `SyncQueueWorker` and verifies accurate metrics dispatch to the `ObservabilityService`.
