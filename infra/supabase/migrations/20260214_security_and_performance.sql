-- ==============================================================================
-- Migration: 20260214_security_and_performance.sql
-- Description: 
-- 1. Fixes Admin View privilege escalation (Security Invoker).
-- 2. Optimizes RLS policies with subqueries for auth.uid().
-- 3. Adds missing RLS policies for audit_trail, stores, tenants.
-- 4. Adds missing indexes for foreign keys.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Fix Privilege Escalation in Admin View
-- ------------------------------------------------------------------------------

-- Drop the existing view to reset properties
DROP VIEW IF EXISTS public.admin_tenant_health_summary;

-- ------------------------------------------------------------------------------
-- 1.1 Ensure Underlying Table Exists & Has RLS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tenant_health_table (
    tenant_id UUID PRIMARY KEY, -- Assuming matches auth.uid or tenant claim
    last_sync_time TIMESTAMPTZ,
    sync_status TEXT,
    error_count INT DEFAULT 0
);

ALTER TABLE public.tenant_health_table ENABLE ROW LEVEL SECURITY;

-- Policies for tenant_health_table
-- Allow tenants to read/update ONLY their own health record
CREATE POLICY "tenant_health_isolation" ON public.tenant_health_table
USING (tenant_id = (select auth.jwt() ->> 'tenant_id')::uuid);

-- ------------------------------------------------------------------------------
-- 1.2 Recreate Admin View as Security Invoker
-- ------------------------------------------------------------------------------
-- Recreate as a Security Invoker view (Postgres 15+ standard)
-- This ensures the view runs with the permissions of the invoker, not the creator.
CREATE OR REPLACE VIEW public.admin_tenant_health_summary 
WITH (security_invoker = true) 
AS 
SELECT 
  tenant_id,
  last_sync_time,
  sync_status,
  error_count
FROM public.tenant_health_table;

-- ------------------------------------------------------------------------------
-- 2. Optimize Auth RLS Initialization (Performance)
-- ------------------------------------------------------------------------------

-- Problem: Direct auth.uid() or auth.jwt() calls are re-evaluated per row.
-- Fix: Wrap in (select ...) to force single evaluation per query.

-- Fix for Products
-- Note: Dropping and recreating is often cleaner than ALTER POLICY for complex changes, 
-- but ALTER POLICY USING works if policy exists. Assuming policy exists as per directive.
ALTER POLICY "tenant_product_isolation" ON public.products 
USING (tenant_id = (select auth.jwt() ->> 'tenant_id')::uuid);

-- Fix for Transactions
ALTER POLICY "tenant_transaction_isolation" ON public.transactions 
USING (tenant_id = (select auth.jwt() ->> 'tenant_id')::uuid);

-- ------------------------------------------------------------------------------
-- 3. Secure Tables with Missing Policies
-- ------------------------------------------------------------------------------

-- Enable RLS just in case it wasn't
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_trail ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

-- 3.1 Policies for 'stores'
-- Allow users to see/edit only their own tenant's stores
CREATE POLICY "tenant_store_access" ON public.stores
USING (tenant_id = (select auth.jwt() ->> 'tenant_id')::uuid);

-- 3.2 Policies for 'audit_trail'
-- Allow insert (logging) if tenant matches.
-- Allow select (viewing logs) if tenant matches.
CREATE POLICY "tenant_audit_insert" ON public.audit_trail
FOR INSERT 
WITH CHECK (tenant_id = (select auth.jwt() ->> 'tenant_id')::uuid);

CREATE POLICY "tenant_audit_select" ON public.audit_trail
FOR SELECT 
USING (tenant_id = (select auth.jwt() ->> 'tenant_id')::uuid);

-- 3.3 Policies for 'tenants'
-- Allow read access to own tenant record
CREATE POLICY "tenant_read_own" ON public.tenants
FOR SELECT 
USING (id = (select auth.jwt() ->> 'tenant_id')::uuid);

-- Allow update access to own tenant record (e.g. settings)
CREATE POLICY "tenant_update_own" ON public.tenants
FOR UPDATE
USING (id = (select auth.jwt() ->> 'tenant_id')::uuid);

-- ------------------------------------------------------------------------------
-- 4. Performance Indexes for Foreign Keys
-- ------------------------------------------------------------------------------

-- Prevent Full Table Scans on joins and deletes
CREATE INDEX IF NOT EXISTS idx_products_tenant_id ON public.products(tenant_id);
CREATE INDEX IF NOT EXISTS idx_transactions_tenant_id ON public.transactions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_audit_trail_tenant_id ON public.audit_trail(tenant_id);
CREATE INDEX IF NOT EXISTS idx_transaction_items_transaction_id ON public.transaction_items(transaction_id);

