-- ==============================================================================
-- Enterprise Schema - Cosmic Forge POS
-- ==============================================================================

create extension if not exists pgcrypto;

create table if not exists tenants (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null unique,
  store_id uuid,
  business_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists stores (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null unique,
  store_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null,
  auth_user_id uuid not null unique,
  role text not null default 'cashier',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists devices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null,
  device_id text not null unique,
  device_name text,
  bssid text,
  ip_range text,
  status text not null default 'active',
  registered_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null,
  sku text not null,
  name text not null,
  price numeric(12,2) not null,
  barcode text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists inventory (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null,
  product_id uuid not null references products(id) on delete cascade,
  quantity numeric(12,3) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null,
  cashier_id uuid,
  total_amount numeric(12,2) not null,
  status text not null default 'completed',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists order_items (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null,
  order_id uuid not null references orders(id) on delete cascade,
  product_id uuid not null references products(id),
  quantity integer not null,
  price numeric(12,2) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists payments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null,
  order_id uuid not null references orders(id) on delete cascade,
  method text not null,
  amount numeric(12,2) not null,
  status text not null default 'captured',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists reports (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null,
  report_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists audit_logs (
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null,
  store_id text not null,
  user_id text not null,
  event_type text not null,
  event_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_tenants_tenant_id on tenants(tenant_id);
create index if not exists idx_tenants_store_id on tenants(store_id);
create index if not exists idx_tenants_created_at on tenants(created_at);

create index if not exists idx_stores_tenant_id on stores(tenant_id);
create index if not exists idx_stores_store_id on stores(store_id);
create index if not exists idx_stores_created_at on stores(created_at);

create index if not exists idx_users_tenant_id on users(tenant_id);
create index if not exists idx_users_store_id on users(store_id);
create index if not exists idx_users_created_at on users(created_at);

create index if not exists idx_devices_tenant_id on devices(tenant_id);
create index if not exists idx_devices_store_id on devices(store_id);
create index if not exists idx_devices_created_at on devices(created_at);

create index if not exists idx_products_tenant_id on products(tenant_id);
create index if not exists idx_products_store_id on products(store_id);
create index if not exists idx_products_barcode on products(barcode);
create index if not exists idx_products_created_at on products(created_at);

create index if not exists idx_inventory_tenant_id on inventory(tenant_id);
create index if not exists idx_inventory_store_id on inventory(store_id);
create index if not exists idx_inventory_created_at on inventory(created_at);

create index if not exists idx_orders_tenant_id on orders(tenant_id);
create index if not exists idx_orders_store_id on orders(store_id);
create index if not exists idx_orders_created_at on orders(created_at);

create index if not exists idx_order_items_tenant_id on order_items(tenant_id);
create index if not exists idx_order_items_store_id on order_items(store_id);
create index if not exists idx_order_items_created_at on order_items(created_at);

create index if not exists idx_payments_tenant_id on payments(tenant_id);
create index if not exists idx_payments_store_id on payments(store_id);
create index if not exists idx_payments_created_at on payments(created_at);

create index if not exists idx_reports_tenant_id on reports(tenant_id);
create index if not exists idx_reports_store_id on reports(store_id);
create index if not exists idx_reports_created_at on reports(created_at);

create index if not exists idx_audit_logs_tenant_id on audit_logs(tenant_id);
create index if not exists idx_audit_logs_store_id on audit_logs(store_id);
create index if not exists idx_audit_logs_user_id on audit_logs(user_id);
create index if not exists idx_audit_logs_event_type on audit_logs(event_type);
create index if not exists idx_audit_logs_created_at on audit_logs(created_at);
