# 4. Mobile Application Architecture

## 4.1 Client Overview
The mobile application is built using the Flutter Framework (Dart). It is strongly typed and organized using a Feature-First folder structure.

## 4.2 State Management (Riverpod)
`flutter_riverpod` is the backbone of the application's reactive UI.
- **Providers**: Singletons and application-wide services are injected using simple `Provider` blocks (e.g., `storeServiceProvider`, `authRepositoryProvider`).
- **AsyncNotifiers/Notifiers**: State that requires mutating UI feedback (such as the Cart, Network Status, or Auth Session) utilizes `AsyncNotifierProvider`. 
- **`ref.watch` boundaries**: UI layouts use `ConsumerWidget` or local `Consumer` builder blocks to precisely subscribe to specific state slices, preventing cascading `build` loop bottlenecks (as fixed during the `pos_screen.dart` performance audit).

## 4.3 Offline Persistence (Drift)
`drift` manages local data storage via SQLite. 
- **Encryption**: Uses `sqlcipher_flutter_libs` to encrypt the SQLite database at test securely with a key dynamically derived and stored in Android/iOS native Secure Enclaves (`flutter_secure_storage`).
- **Data Models**: Drift automatically generates type-safe data classes and CRUD operations.
- **Offline Reliability Constraints**: Most views are driven directly off Drift `Stream`s rather than waiting for Supabase HTTP requests.

## 4.4 Feature-First Directory Structure
```text
lib/
├── core/                   # Singleton services, networking, database engine
│   ├── auth/               # Generic authentication logic & RBAC
│   ├── security/           # Hardware guards & geofencing logic
│   ├── sync/               # Background queue workers
│   └── database/           # Drift compilation schema
├── features/               # Domain-specific modules
│   ├── auth/               # Login & PIN screens
│   ├── pos/                # POS terminal, layout, Cart providers
│   ├── products/           # Catalog management
│   ├── admin/              # Tenant admin panels
│   └── dashboard/          # Hub navigation
└── grocery.dart            # Main entrypoint setup
```
