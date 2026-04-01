# 1. Architecture Overview

## 1.1 Executive Summary
Cosmic Forge Grocery POS is an offline-first, multi-tenant Point of Sale (POS) system designed specifically for the Myanmar market. It is built to operate reliably in environments with intermittent internet connectivity while ensuring strict data isolation between different retail tenants.

## 1.2 High-Level Architecture
The system employs a thick-client architecture where the mobile application contains significant business logic and local data storage, syncing with a cloud backend when connectivity is available.

```mermaid
graph TD
    Client[Flutter Mobile POS Client]
    LocalDB[(Drift SQLite Local DB)]
    CloudDB[(Supabase PostgreSQL)]
    Storage[Supabase Storage]
    Auth[Supabase Auth]

    Client <-->|Read/Write (Offline-First)| LocalDB
    Client <-->|Sync (Background Service)| CloudDB
    Client <-->|Images/Receipts| Storage
    Client <-->|JWT/PIN Authn| Auth
```

## 1.3 Key Architectural Patterns
1. **Offline-First via Background Sync**: Primary reads and writes happen against the local SQLite database (`drift`). A robust background sync queue (`SyncQueueWorker`) eventually pushes changes to Supabase utilizing a Last-Write-Wins (LWW) conflict strategy.
2. **Multi-Tenancy at the Edge**: Multi-tenancy is enforced not only at the cloud database level via Row Level Security (RLS) but also on the edge using a `SessionContext` that aggressively filters local SQLite queries by `tenant_id` and `store_id`.
3. **Reactive State Management**: The UI is entirely reactive, driven by Riverpod providers that listen to database streams and state changes, ensuring immediate UI updates upon local data mutations.
4. **Hardware-Bound Security**: Device registration binds physical hardware (via BSSID, IP range, and Device ID) to specific store locations to prevent rogue logins outside physical premises.
