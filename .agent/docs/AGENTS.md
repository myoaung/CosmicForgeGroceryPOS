# 🤖 AGENT COMMAND CENTER: BUILD & TOOLS

## 1. CORE TECH STACK
- **Mobile**: Flutter (SDK 3.24+). State Management: **Riverpod 2.x**.
- **Backend**: Supabase. Database: **PostgreSQL 15**.
- **DevOps**: Docker Desktop with `docker-compose.yml`.

## 2. AGENT OPERATIONAL DIRECTIVES
- **Code Style**:
  - Use Functional Components and Hooks; strictly avoid legacy Classes for Widgets.
  - Implement Dependency Injection (DI) for all repository layers.
- **Tooling Access**:
  - **Terminal**: Access to `flutter`, `dart`, `git`, and `docker`.
  - **Browser**: Use to verify Supabase Dashboards and Vercel Deployment status.

## 3. LOCAL ENVIRONMENT INITIALIZATION
- **Setup**: `docker-compose up -d postgres redis`
- **Migration**: `supabase migration up` (Initial Schema + RLS triggers).
- **Seed**: Populate `tenant_features` with 'Standard' and 'Pro' tier defaults.

## 4. UI & ASSETS
- **Typography**: Primary font 'Pyidaungsu'. 
- **Bilingual Support**: Use Flutter `intl` for English and Myanmar (Burmese) localization files.