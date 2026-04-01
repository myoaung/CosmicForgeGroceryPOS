# 5. UI/UX Design System & Navigation

## 5.1 Design Methodology
The UI uses standard **Material 3 Component Design** natively provided by Flutter. High priority was placed on large, tappable tap targets and stark visual contrast since POS environments are often fast-paced and poorly lit. 

## 5.2 Responsive Layouts
- **Tablet Focus**: The primary target for the `pos_screen.dart` is Android Tablets (Landscape). It utilizes a multi-pane layout:
  - **Left Pane (Flex 2)**: Product Grid featuring large tiles with pricing and visual iconography.
  - **Right Pane (Flex 1)**: Sticky Cart breakdown containing a line-item scroll view, subtotal aggregation, and a massive `PAY & PRINT` action button.
- The layout is intrinsically responsive and degrades gracefully onto standard smartphone viewports by wrapping or pushing the Cart into a sliding bottom sheet or separate tab (depending on device query constraints).

## 5.3 Localization & Typography
- **Language**: Core support for Myanmar/Burmese.
- **Typography**: Custom `Pyidaungsu` font family is globally embedded in `pubspec.yaml` to ensure flawless rendering of legacy and standardized Myanmar Unicode characters without operating system fallback errors.
- **Currency Rendering**: All financial aggregates apply `MMK` localization and round to the nearest `5 Kyat` (a common requirement for cash floats in Myanmar retail).

## 5.4 Navigation
Standard Flutter Navigator 2.0 (Router) combined with simple push/pop logic, as deep-linking from exterior apps is not a requirement for an enclosed POS terminal. The navigation generally spawns from the `DashboardScreen` which routes into:
1. `POSLayout` (Terminal)
2. `InventoryScreen`
3. `Admin Settings`
