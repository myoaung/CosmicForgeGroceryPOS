# 2. System Components & Dependencies

## 2.1 Core Subsystems
The Grocery POS is divided into distinct execution layers:

### 2.1.1 Presentation Layer (Flutter UI)
- **Features**: Authentication, POS Dashboard, Product Management, Store Switching, Receipts, Admin Settings.
- **Responsibility**: Rendering UI, handling user inputs, and subscribing to Riverpod streams.

### 2.1.2 State & Business Logic Layer (Providers/Use Cases)
- **State Management**: `Riverpod` manages application state (e.g., `CartNotifier`, `authProvider`).
- **Use Cases**: Encapsulates core business transactions (e.g., `CheckoutUseCase`) to ensure data validity before database insertion.

### 2.1.3 Hardware Integration Layer (Services)
- **Receipt Printing**: Native Android Bluetooth integration via `blue_thermal_printer` to communicate with thermal POS printers using ESC/POS commands.
- **Location & Networking**: `geolocator` and `network_info_plus` are utilized for security geofencing and BSSID validation.

### 2.1.4 Data Persistence Layer (Repositories/Database)
- **Local DB**: `Drift` (SQLite) acts as the primary source of truth for the active session. Uses SQLCipher for at-rest encryption.
- **Remote DB**: Supabase acts as the remote synchronization target and cloud backup.

## 2.2 Core Dependencies (`pubspec.yaml`)
- **Flutter SDK**: `>=3.19.0` (Stable)
- **State**: `flutter_riverpod` (^2.5.1)
- **Backend & Auth**: `supabase_flutter` (^2.12.0)
- **Local Database**: `drift` (^2.31.0), `sqlcipher_flutter_libs` (^0.6.8)
- **Security & Hardware**: `flutter_secure_storage` (^9.2.4), `geolocator` (^11.0.0), `blue_thermal_printer` (^1.2.3)
- **Localization**: `intl` (^0.20.2), Custom Pyidaungsu Font (Myanmar Unicode).
