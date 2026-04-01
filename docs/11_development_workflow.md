# 11. Development Workflow & Repository Governance

## 11.1 Branching Strategy
Standard Git-Flow:
- `main`: Absolutely stable. Deploys to Vercel/Play Store.
- `develop`: Primary integration branch.
- `feature/*`: Short-lived isolated tickets.
- `hotfix/*`: Emergency patches directly applied to Main (bypassing develop only during outages).

## 11.2 Definition of Done
A PR cannot be merged via branch-protection rules unless it fulfills:
- **Clean Compilation**: 0 Linter Warnings from `flutter analyze`.
- **Testing Constraints**: Test suites pass (`Exit Code 0`) and coverage strictly exceeds 70%.
- **Vulnerability Checks**: Snyk/Trivy pass entirely clean for zero new injected packages or known insecure HTTP configurations. 

## 11.3 Database Migration Flow
PostgreSQL structures are managed via `supabase migrations`.
1. Modify schema utilizing raw SQL under `infra/supabase/migrations`.
2. NEVER modify historically committed `.sql` files; instead, append new incremental upgrades explicitly defining triggers and `FOR INSERT / SELECT` explicit RLS policies.
3. Drift UI code runs `flutter pub run build_runner build -d`, compiling the localized dart models directly off the new SQLite analogs to Supabase.
