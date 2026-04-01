-- ==============================================================================
-- Migration: 20260308_enterprise_multitenant_rls.sql
-- Purpose: Enterprise multi-tenant schema + RLS policies for Cosmic Forge POS
-- ==============================================================================

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ------------------------------------------------------------------------------
-- Core Tables
-- ------------------------------------------------------------------------------

create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null unique,
  store_id uuid,
  business_name text not null,
  plan_type text default 'enterprise',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.stores (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null unique,
  store_name text not null,
  timezone text not null default 'Asia/Yangon',
  currency_code text not null default 'MMK',
  tax_rate numeric(8,4) not null default 0.05,
  bssid text,
  ip_range text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null,
  auth_user_id uuid not null unique,
  role text not null default 'cashier',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null,
  device_id text not null unique,
  bssid text,
  ip_range text,
  registered_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null,
  sku text not null,
  name text not null,
  price numeric(12,2) not null,
  barcode text,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null,
  product_id uuid not null references public.products(id) on delete cascade,
  quantity numeric(12,3) not null default 0,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null,
  cashier_id uuid,
  total_amount numeric(12,2) not null,
  status text not null default 'completed',
  device_id text,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null,
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity integer not null,
  price numeric(12,2) not null,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null,
  order_id uuid not null references public.orders(id) on delete cascade,
  method text not null,
  amount numeric(12,2) not null,
  status text not null default 'captured',
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null,
  report_type text not null,
  period_start timestamptz not null,
  period_end timestamptz not null,
  payload jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------------------------
-- Indexes
-- ------------------------------------------------------------------------------
create index if not exists idx_tenants_tenant_id on public.tenants(tenant_id);
create index if not exists idx_tenants_store_id on public.tenants(store_id);
create index if not exists idx_tenants_created_at on public.tenants(created_at);

create index if not exists idx_stores_tenant_id on public.stores(tenant_id);
create index if not exists idx_stores_store_id on public.stores(store_id);
create index if not exists idx_stores_created_at on public.stores(created_at);

create index if not exists idx_users_tenant_id on public.users(tenant_id);
create index if not exists idx_users_store_id on public.users(store_id);
create index if not exists idx_users_created_at on public.users(created_at);

create index if not exists idx_devices_tenant_id on public.devices(tenant_id);
create index if not exists idx_devices_store_id on public.devices(store_id);
create index if not exists idx_devices_created_at on public.devices(created_at);

create index if not exists idx_products_tenant_id on public.products(tenant_id);
create index if not exists idx_products_store_id on public.products(store_id);
create index if not exists idx_products_barcode on public.products(barcode);
create index if not exists idx_products_created_at on public.products(created_at);

create index if not exists idx_inventory_tenant_id on public.inventory(tenant_id);
create index if not exists idx_inventory_store_id on public.inventory(store_id);
create index if not exists idx_inventory_created_at on public.inventory(created_at);

create index if not exists idx_orders_tenant_id on public.orders(tenant_id);
create index if not exists idx_orders_store_id on public.orders(store_id);
create index if not exists idx_orders_created_at on public.orders(created_at);

create index if not exists idx_order_items_tenant_id on public.order_items(tenant_id);
create index if not exists idx_order_items_store_id on public.order_items(store_id);
create index if not exists idx_order_items_created_at on public.order_items(created_at);

create index if not exists idx_payments_tenant_id on public.payments(tenant_id);
create index if not exists idx_payments_store_id on public.payments(store_id);
create index if not exists idx_payments_created_at on public.payments(created_at);

create index if not exists idx_reports_tenant_id on public.reports(tenant_id);
create index if not exists idx_reports_store_id on public.reports(store_id);
create index if not exists idx_reports_created_at on public.reports(created_at);

-- ------------------------------------------------------------------------------
-- updated_at triggers
-- ------------------------------------------------------------------------------
drop trigger if exists trg_tenants_updated_at on public.tenants;
create trigger trg_tenants_updated_at before update on public.tenants
for each row execute function public.set_updated_at();

drop trigger if exists trg_stores_updated_at on public.stores;
create trigger trg_stores_updated_at before update on public.stores
for each row execute function public.set_updated_at();

drop trigger if exists trg_users_updated_at on public.users;
create trigger trg_users_updated_at before update on public.users
for each row execute function public.set_updated_at();

drop trigger if exists trg_devices_updated_at on public.devices;
create trigger trg_devices_updated_at before update on public.devices
for each row execute function public.set_updated_at();

drop trigger if exists trg_products_updated_at on public.products;
create trigger trg_products_updated_at before update on public.products
for each row execute function public.set_updated_at();

drop trigger if exists trg_inventory_updated_at on public.inventory;
create trigger trg_inventory_updated_at before update on public.inventory
for each row execute function public.set_updated_at();

drop trigger if exists trg_orders_updated_at on public.orders;
create trigger trg_orders_updated_at before update on public.orders
for each row execute function public.set_updated_at();

drop trigger if exists trg_order_items_updated_at on public.order_items;
create trigger trg_order_items_updated_at before update on public.order_items
for each row execute function public.set_updated_at();

drop trigger if exists trg_payments_updated_at on public.payments;
create trigger trg_payments_updated_at before update on public.payments
for each row execute function public.set_updated_at();

drop trigger if exists trg_reports_updated_at on public.reports;
create trigger trg_reports_updated_at before update on public.reports
for each row execute function public.set_updated_at();

-- ------------------------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------------------------
alter table public.tenants enable row level security;
alter table public.stores enable row level security;
alter table public.users enable row level security;
alter table public.devices enable row level security;
alter table public.products enable row level security;
alter table public.inventory enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.reports enable row level security;

-- Drop existing policies to keep migration idempotent.
drop policy if exists tenant_isolation_tenants on public.tenants;
drop policy if exists tenant_isolation_stores on public.stores;
drop policy if exists tenant_isolation_users on public.users;
drop policy if exists tenant_isolation_devices on public.devices;
drop policy if exists tenant_isolation_products on public.products;
drop policy if exists tenant_isolation_inventory on public.inventory;
drop policy if exists tenant_isolation_orders on public.orders;
drop policy if exists tenant_isolation_order_items on public.order_items;
drop policy if exists tenant_isolation_payments on public.payments;
drop policy if exists tenant_isolation_reports on public.reports;

drop policy if exists store_access_tenants on public.tenants;
drop policy if exists store_access_stores on public.stores;
drop policy if exists store_access_users on public.users;
drop policy if exists store_access_devices on public.devices;
drop policy if exists store_access_products on public.products;
drop policy if exists store_access_inventory on public.inventory;
drop policy if exists store_access_orders on public.orders;
drop policy if exists store_access_order_items on public.order_items;
drop policy if exists store_access_payments on public.payments;
drop policy if exists store_access_reports on public.reports;

drop policy if exists insert_validation_tenants on public.tenants;
drop policy if exists insert_validation_stores on public.stores;
drop policy if exists insert_validation_users on public.users;
drop policy if exists insert_validation_devices on public.devices;
drop policy if exists insert_validation_products on public.products;
drop policy if exists insert_validation_inventory on public.inventory;
drop policy if exists insert_validation_orders on public.orders;
drop policy if exists insert_validation_order_items on public.order_items;
drop policy if exists insert_validation_payments on public.payments;
drop policy if exists insert_validation_reports on public.reports;

drop policy if exists admin_override_tenants on public.tenants;
drop policy if exists admin_override_stores on public.stores;
drop policy if exists admin_override_users on public.users;
drop policy if exists admin_override_devices on public.devices;
drop policy if exists admin_override_products on public.products;
drop policy if exists admin_override_inventory on public.inventory;
drop policy if exists admin_override_orders on public.orders;
drop policy if exists admin_override_order_items on public.order_items;
drop policy if exists admin_override_payments on public.payments;
drop policy if exists admin_override_reports on public.reports;

create policy tenant_isolation_tenants on public.tenants
for all using (tenant_id = (select (auth.jwt()->>'tenant_id')::uuid));
create policy tenant_isolation_stores on public.stores
for all using (tenant_id = (select (auth.jwt()->>'tenant_id')::uuid));
create policy tenant_isolation_users on public.users
for all using (tenant_id = (select (auth.jwt()->>'tenant_id')::uuid));
create policy tenant_isolation_devices on public.devices
for all using (tenant_id = (select (auth.jwt()->>'tenant_id')::uuid));
create policy tenant_isolation_products on public.products
for all using (tenant_id = (select (auth.jwt()->>'tenant_id')::uuid));
create policy tenant_isolation_inventory on public.inventory
for all using (tenant_id = (select (auth.jwt()->>'tenant_id')::uuid));
create policy tenant_isolation_orders on public.orders
for all using (tenant_id = (select (auth.jwt()->>'tenant_id')::uuid));
create policy tenant_isolation_order_items on public.order_items
for all using (tenant_id = (select (auth.jwt()->>'tenant_id')::uuid));
create policy tenant_isolation_payments on public.payments
for all using (tenant_id = (select (auth.jwt()->>'tenant_id')::uuid));
create policy tenant_isolation_reports on public.reports
for all using (tenant_id = (select (auth.jwt()->>'tenant_id')::uuid));

create policy store_access_tenants on public.tenants
for all using (store_id is null or store_id = (select (auth.jwt()->>'store_id')::uuid));
create policy store_access_stores on public.stores
for all using (store_id = (select (auth.jwt()->>'store_id')::uuid));
create policy store_access_users on public.users
for all using (store_id = (select (auth.jwt()->>'store_id')::uuid));
create policy store_access_devices on public.devices
for all using (store_id = (select (auth.jwt()->>'store_id')::uuid));
create policy store_access_products on public.products
for all using (store_id = (select (auth.jwt()->>'store_id')::uuid));
create policy store_access_inventory on public.inventory
for all using (store_id = (select (auth.jwt()->>'store_id')::uuid));
create policy store_access_orders on public.orders
for all using (store_id = (select (auth.jwt()->>'store_id')::uuid));
create policy store_access_order_items on public.order_items
for all using (store_id = (select (auth.jwt()->>'store_id')::uuid));
create policy store_access_payments on public.payments
for all using (store_id = (select (auth.jwt()->>'store_id')::uuid));
create policy store_access_reports on public.reports
for all using (store_id = (select (auth.jwt()->>'store_id')::uuid));

create policy insert_validation_tenants on public.tenants
for insert with check (tenant_id = (select (auth.jwt()->>'tenant_id')::uuid));
create policy insert_validation_stores on public.stores
for insert with check (tenant_id = (select (auth.jwt()->>'tenant_id')::uuid));
create policy insert_validation_users on public.users
for insert with check (
  tenant_id = (select (auth.jwt()->>'tenant_id')::uuid) and
  store_id = (select (auth.jwt()->>'store_id')::uuid)
);
create policy insert_validation_devices on public.devices
for insert with check (
  tenant_id = (select (auth.jwt()->>'tenant_id')::uuid) and
  store_id = (select (auth.jwt()->>'store_id')::uuid)
);
create policy insert_validation_products on public.products
for insert with check (
  tenant_id = (select (auth.jwt()->>'tenant_id')::uuid) and
  store_id = (select (auth.jwt()->>'store_id')::uuid)
);
create policy insert_validation_inventory on public.inventory
for insert with check (
  tenant_id = (select (auth.jwt()->>'tenant_id')::uuid) and
  store_id = (select (auth.jwt()->>'store_id')::uuid)
);
create policy insert_validation_orders on public.orders
for insert with check (
  tenant_id = (select (auth.jwt()->>'tenant_id')::uuid) and
  store_id = (select (auth.jwt()->>'store_id')::uuid)
);
create policy insert_validation_order_items on public.order_items
for insert with check (
  tenant_id = (select (auth.jwt()->>'tenant_id')::uuid) and
  store_id = (select (auth.jwt()->>'store_id')::uuid)
);
create policy insert_validation_payments on public.payments
for insert with check (
  tenant_id = (select (auth.jwt()->>'tenant_id')::uuid) and
  store_id = (select (auth.jwt()->>'store_id')::uuid)
);
create policy insert_validation_reports on public.reports
for insert with check (
  tenant_id = (select (auth.jwt()->>'tenant_id')::uuid) and
  store_id = (select (auth.jwt()->>'store_id')::uuid)
);

create policy admin_override_tenants on public.tenants
for select using ((select auth.jwt()->>'role') = 'tenant_admin');
create policy admin_override_stores on public.stores
for select using ((select auth.jwt()->>'role') = 'tenant_admin');
create policy admin_override_users on public.users
for select using ((select auth.jwt()->>'role') = 'tenant_admin');
create policy admin_override_devices on public.devices
for select using ((select auth.jwt()->>'role') = 'tenant_admin');
create policy admin_override_products on public.products
for select using ((select auth.jwt()->>'role') = 'tenant_admin');
create policy admin_override_inventory on public.inventory
for select using ((select auth.jwt()->>'role') = 'tenant_admin');
create policy admin_override_orders on public.orders
for select using ((select auth.jwt()->>'role') = 'tenant_admin');
create policy admin_override_order_items on public.order_items
for select using ((select auth.jwt()->>'role') = 'tenant_admin');
create policy admin_override_payments on public.payments
for select using ((select auth.jwt()->>'role') = 'tenant_admin');
create policy admin_override_reports on public.reports
for select using ((select auth.jwt()->>'role') = 'tenant_admin');
