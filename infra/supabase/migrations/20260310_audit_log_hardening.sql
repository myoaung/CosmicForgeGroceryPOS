-- ==============================================================================
-- Migration: 20260310_audit_log_hardening.sql
-- Purpose:   Harden the audit_logs table so that:
--            1. Authenticated users can NO LONGER INSERT directly (tamper risk).
--            2. Inserts are channelled through a SECURITY DEFINER function that
--               always enforces the caller's JWT tenant/store/user claims.
--            3. SELECT remains scoped to the caller's own records (or admin).
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Drop the permissive all-in-one policy that allowed user-level INSERT
-- ------------------------------------------------------------------------------
drop policy if exists audit_logs_tenant_store_isolation on public.audit_logs;

-- Older policy names from earlier migrations — drop for cleanliness.
drop policy if exists tenant_audit_insert on public.audit_trail;
drop policy if exists tenant_audit_select on public.audit_trail;

-- ------------------------------------------------------------------------------
-- 2. Read-only policy for authenticated users (scoped to own tenant/store/user)
-- ------------------------------------------------------------------------------
create policy audit_logs_read_own
  on public.audit_logs
  for select
  to authenticated
  using (
    public.is_admin_role()
    or (
      tenant_id = public.jwt_claim('tenant_id')
      and store_id = public.jwt_claim('store_id')
      and user_id = public.jwt_claim('sub')
    )
  );

-- Admins can read all logs within their tenant
create policy audit_logs_read_admin
  on public.audit_logs
  for select
  to authenticated
  using (
    public.is_admin_role()
    and tenant_id = public.jwt_claim('tenant_id')
  );

-- ------------------------------------------------------------------------------
-- 3. SECURITY DEFINER insert function — the ONLY authorised write path
--    The function reads tenant/store/user from the caller's JWT so the caller
--    cannot supply arbitrary values.
-- ------------------------------------------------------------------------------
create or replace function public.write_audit_log(
  p_event_type text,
  p_event_data jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id text;
  v_store_id  text;
  v_user_id   text;
begin
  -- Always derive identity from server-side JWT — caller cannot override.
  v_tenant_id := public.jwt_claim('tenant_id');
  v_store_id  := public.jwt_claim('store_id');
  v_user_id   := public.jwt_claim('sub');

  if v_tenant_id = '' or v_user_id = '' then
    raise exception 'write_audit_log: unauthenticated or missing JWT claims'
      using errcode = 'P0003';
  end if;

  insert into public.audit_logs (
    tenant_id,
    store_id,
    user_id,
    event_type,
    event_data
    -- created_at intentionally omitted — server default now() applies
  ) values (
    v_tenant_id,
    v_store_id,
    v_user_id,
    p_event_type,
    p_event_data
  );
end;
$$;

-- Grant execute to authenticated role so the Flutter app can call it via rpc().
grant execute on function public.write_audit_log(text, jsonb) to authenticated;
