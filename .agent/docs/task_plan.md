# 📅 PHASE-BY-PHASE IMPLEMENTATION PLAN (DAY-WISE)

## PHASE 1: FOUNDATION (DAYS 1-10)
- **Day 1**: Scaffolding. `flutter create`. Dockerize Local Postgres. Setup CI/CD pipeline on GitHub Actions.
- **Day 2**: Schema Deployment. Create `tenants`, `stores`, `users` with RLS. Seed 1 demo tenant.
- **Day 3**: Auth Integration. Map Supabase JWT to `tenant_id`. Create login/logout UI.
- **Day 4**: SQLite Bridge. Create Drift/Sqflite tables. Implement 'Sync Repository' pattern.
- **Day 5**: Scanner & UI. Integrated Camera Scanner. Logic for `Unit` vs `Weight` items in cart.

## PHASE 2: SECURITY & MULTI-STORE (DAYS 11-20)
- **Day 11**: Store Switcher. Logic for owners to switch between Store_A and Store_B dashboards.
- **Day 12**: Location Guard. Implement GPS Mock Detection and WiFi BSSID verification.
- **Day 13**: VPN Detection middleware using Serverless Edge functions.
- **Day 14-15**: Role-Based UI. Hide 'Report' and 'Settings' menus for 'Cashier' role.

## PHASE 3: MONITORING & DEPLOYMENT (DAYS 21-30)
- **Day 21**: Vercel/Cloudflare Deployment of the Web Dashboard.
- **Day 22**: Feature Toggles. Implement Remote Config switches for 'Pro' features.