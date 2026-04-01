-- ==============================================================================
-- Migration: 20260308_enterprise_security_controls.sql
-- Purpose: Complete enterprise security controls (RLS + audit + device hardening)
-- ==============================================================================

create extension if not exists pgcrypto;

create or replace function public.jwt_claim(claim_key text)
returns text
language sql
stable
as $$
  select coalesce(auth.jwt() ->> claim_key, '');
$$;

create or replace function public.is_admin_role()
returns boolean
language sql
stable
as $$
  select public.jwt_claim('role') in ('tenant_admin', 'super_admin');
$$;

-- ------------------------------------------------------------------------------
-- Devices hardening
-- ------------------------------------------------------------------------------
alter table if exists public.devices
  add column if not exists device_name text;

alter table if exists public.devices
  add column if not exists status text not null default 'active';

-- ------------------------------------------------------------------------------
-- Audit logs
-- ------------------------------------------------------------------------------
create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  store_id uuid not null,
  user_id uuid not null,
  event_type text not null,
  event_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_audit_logs_tenant_id on public.audit_logs(tenant_id);
create index if not exists idx_audit_logs_store_id on public.audit_logs(store_id);
create index if not exists idx_audit_logs_user_id on public.audit_logs(user_id);
create index if not exists idx_audit_logs_event_type on public.audit_logs(event_type);
create index if not exists idx_audit_logs_created_at on public.audit_logs(created_at);

-- Ensure transaction_items carries tenant/store fields for RLS-enforced joins.
alter table if exists public.transaction_items
  add column if not exists tenant_id uuid;

alter table if exists public.transaction_items
  add column if not exists store_id uuid;

-- ------------------------------------------------------------------------------
-- Enable RLS on all required tables
-- ------------------------------------------------------------------------------
alter table if exists public.tenants enable row level security;
alter table if exists public.stores enable row level security;
alter table if exists public.users enable row level security;
alter table if exists public.devices enable row level security;
alter table if exists public.products enable row level security;
alter table if exists public.inventory enable row level security;
alter table if exists public.orders enable row level security;
alter table if exists public.order_items enable row level security;
alter table if exists public.payments enable row level security;
alter table if exists public.transactions enable row level security;
alter table if exists public.transaction_items enable row level security;
alter table if exists public.audit_logs enable row level security;

-- ------------------------------------------------------------------------------
-- Tenants
-- ------------------------------------------------------------------------------
drop policy if exists tenants_tenant_isolation on public.tenants;
create policy tenants_tenant_isolation
on public.tenants
for all
to authenticated
using (
  public.is_admin_role()
  or tenant_id::text = public.jwt_claim('tenant_id')
)
with check (
  public.is_admin_role()
  or tenant_id::text = public.jwt_claim('tenant_id')
);

-- ------------------------------------------------------------------------------
-- Shared tenant+store scoped policy helper pattern for app tables
-- ------------------------------------------------------------------------------
drop policy if exists stores_tenant_store_isolation on public.stores;
create policy stores_tenant_store_isolation
on public.stores
for all
to authenticated
using (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
)
with check (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
);

drop policy if exists users_tenant_store_isolation on public.users;
create policy users_tenant_store_isolation
on public.users
for all
to authenticated
using (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
)
with check (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
);

drop policy if exists devices_tenant_store_isolation on public.devices;
create policy devices_tenant_store_isolation
on public.devices
for all
to authenticated
using (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
    and status = 'active'
  )
)
with check (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
);

drop policy if exists products_tenant_store_isolation on public.products;
create policy products_tenant_store_isolation
on public.products
for all
to authenticated
using (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
)
with check (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
);

drop policy if exists inventory_tenant_store_isolation on public.inventory;
create policy inventory_tenant_store_isolation
on public.inventory
for all
to authenticated
using (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
)
with check (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
);

drop policy if exists orders_tenant_store_isolation on public.orders;
create policy orders_tenant_store_isolation
on public.orders
for all
to authenticated
using (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
)
with check (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
);

drop policy if exists order_items_tenant_store_isolation on public.order_items;
create policy order_items_tenant_store_isolation
on public.order_items
for all
to authenticated
using (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
)
with check (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
);

drop policy if exists payments_tenant_store_isolation on public.payments;
create policy payments_tenant_store_isolation
on public.payments
for all
to authenticated
using (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
)
with check (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
);

drop policy if exists transactions_tenant_store_isolation on public.transactions;
create policy transactions_tenant_store_isolation
on public.transactions
for all
to authenticated
using (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
)
with check (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
);

drop policy if exists transaction_items_tenant_store_isolation on public.transaction_items;
create policy transaction_items_tenant_store_isolation
on public.transaction_items
for all
to authenticated
using (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
)
with check (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
  )
);

drop policy if exists audit_logs_tenant_store_isolation on public.audit_logs;
create policy audit_logs_tenant_store_insert
on public.audit_logs
for insert
to authenticated
with check (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
    and user_id::text = public.jwt_claim('user_id')
  )
);

create policy audit_logs_tenant_store_select
on public.audit_logs
for select
to authenticated
using (
  public.is_admin_role()
  or (
    tenant_id::text = public.jwt_claim('tenant_id')
    and store_id::text = public.jwt_claim('store_id')
    and user_id::text = public.jwt_claim('user_id')
  )
);

-- ------------------------------------------------------------------------------
-- Storage security hardening (private bucket + tenant ownership)
-- ------------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', false)
on conflict (id) do update set public = false;

drop policy if exists tenant_storage_select on storage.objects;
drop policy if exists tenant_storage_insert on storage.objects;
drop policy if exists tenant_storage_update on storage.objects;
drop policy if exists tenant_storage_delete on storage.objects;

create policy tenant_storage_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'product-images'
  and coalesce(metadata ->> 'tenant_id', (storage.foldername(name))[1]) = public.jwt_claim('tenant_id')
);

create policy tenant_storage_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'product-images'
  and coalesce(metadata ->> 'tenant_id', (storage.foldername(name))[1]) = public.jwt_claim('tenant_id')
);

create policy tenant_storage_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'product-images'
  and coalesce(metadata ->> 'tenant_id', (storage.foldername(name))[1]) = public.jwt_claim('tenant_id')
)
with check (
  bucket_id = 'product-images'
  and coalesce(metadata ->> 'tenant_id', (storage.foldername(name))[1]) = public.jwt_claim('tenant_id')
);

create policy tenant_storage_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'product-images'
  and coalesce(metadata ->> 'tenant_id', (storage.foldername(name))[1]) = public.jwt_claim('tenant_id')
);
