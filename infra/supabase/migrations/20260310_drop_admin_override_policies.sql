-- ==============================================================================
-- Migration: 20260310_drop_admin_override_policies.sql
-- Purpose:   Remove the overly-permissive admin_override_* policies created in
--            20260308_enterprise_multitenant_rls.sql that granted tenant_admin
--            cross-tenant SELECT access with no tenant_id filter.
--            The correctly-scoped replacements already exist in
--            20260308_enterprise_security_controls.sql via is_admin_role().
-- ==============================================================================

-- Drop all 10 admin_override_* policies from the first migration.
-- These grant SELECT to any 'tenant_admin' with NO tenant_id restriction,
-- allowing cross-tenant data reads.

drop policy if exists admin_override_tenants      on public.tenants;
drop policy if exists admin_override_stores       on public.stores;
drop policy if exists admin_override_users        on public.users;
drop policy if exists admin_override_devices      on public.devices;
drop policy if exists admin_override_products     on public.products;
drop policy if exists admin_override_inventory    on public.inventory;
drop policy if exists admin_override_orders       on public.orders;
drop policy if exists admin_override_order_items  on public.order_items;
drop policy if exists admin_override_payments     on public.payments;
drop policy if exists admin_override_reports      on public.reports;

-- Also drop the first-migration isolation policies that are now superseded by the
-- more hardened policies in 20260308_enterprise_security_controls.sql.
-- These used raw auth.jwt()->>'tenant_id' without the stable jwt_claim() helper.

drop policy if exists tenant_isolation_tenants     on public.tenants;
drop policy if exists tenant_isolation_stores      on public.stores;
drop policy if exists tenant_isolation_users       on public.users;
drop policy if exists tenant_isolation_devices     on public.devices;
drop policy if exists tenant_isolation_products    on public.products;
drop policy if exists tenant_isolation_inventory   on public.inventory;
drop policy if exists tenant_isolation_orders      on public.orders;
drop policy if exists tenant_isolation_order_items on public.order_items;
drop policy if exists tenant_isolation_payments    on public.payments;
drop policy if exists tenant_isolation_reports     on public.reports;

drop policy if exists store_access_tenants         on public.tenants;
drop policy if exists store_access_stores          on public.stores;
drop policy if exists store_access_users           on public.users;
drop policy if exists store_access_devices         on public.devices;
drop policy if exists store_access_products        on public.products;
drop policy if exists store_access_inventory       on public.inventory;
drop policy if exists store_access_orders          on public.orders;
drop policy if exists store_access_order_items     on public.order_items;
drop policy if exists store_access_payments        on public.payments;
drop policy if exists store_access_reports         on public.reports;

drop policy if exists insert_validation_tenants     on public.tenants;
drop policy if exists insert_validation_stores      on public.stores;
drop policy if exists insert_validation_users       on public.users;
drop policy if exists insert_validation_devices     on public.devices;
drop policy if exists insert_validation_products    on public.products;
drop policy if exists insert_validation_inventory   on public.inventory;
drop policy if exists insert_validation_orders      on public.orders;
drop policy if exists insert_validation_order_items on public.order_items;
drop policy if exists insert_validation_payments    on public.payments;
drop policy if exists insert_validation_reports     on public.reports;

-- The authoritative, correctly-scoped policies from
-- 20260308_enterprise_security_controls.sql remain active:
--   tenants_tenant_isolation, stores_tenant_store_isolation,
--   users_tenant_store_isolation, devices_tenant_store_isolation,
--   products_tenant_store_isolation, inventory_tenant_store_isolation,
--   orders_tenant_store_isolation, order_items_tenant_store_isolation,
--   payments_tenant_store_isolation, audit_logs_tenant_store_isolation
-- These all require tenant_id AND store_id to match the JWT, with is_admin_role()
-- as the only bypass — and is_admin_role() still enforces tenant scoping via
-- the JWT claim, not a blanket cross-tenant grant.
