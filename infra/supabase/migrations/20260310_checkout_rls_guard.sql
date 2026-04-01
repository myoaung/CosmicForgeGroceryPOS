-- ==============================================================================
-- Migration: 20260310_checkout_rls_guard.sql
-- Purpose:   Add a BEFORE INSERT trigger on `transactions` and
--            `transaction_items` that validates the row's tenant_id matches
--            the caller's JWT claim.
--
--            This is a database-level backstop independent of the Flutter layer.
--            It fires ONLY when a JWT is present (auth.jwt() returns non-null),
--            so service-role migrations and admin tooling are unaffected.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Trigger function
-- ------------------------------------------------------------------------------
create or replace function public.guard_checkout_tenant_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_jwt_tenant text;
begin
  -- Read tenant_id from the JWT. auth.jwt() returns NULL for service-role
  -- and migration sessions, so we only enforce when a real JWT is present.
  v_jwt_tenant := auth.jwt() ->> 'tenant_id';

  if v_jwt_tenant is null or v_jwt_tenant = '' then
    -- No JWT in scope (service-role / migration). Allow the write.
    return new;
  end if;

  -- Reject inserts where the row's tenant_id does not match the JWT.
  if new.tenant_id is distinct from v_jwt_tenant then
    raise exception
      'RLS violation: tenant_id mismatch on %. '
      'JWT tenant=%, row tenant=%',
      TG_TABLE_NAME, v_jwt_tenant, new.tenant_id
      using errcode = 'P0010';
  end if;

  return new;
end;
$$;

-- ------------------------------------------------------------------------------
-- 2. Apply to transactions
-- ------------------------------------------------------------------------------
drop trigger if exists trg_guard_checkout_tenant_transactions
  on public.transactions;

create trigger trg_guard_checkout_tenant_transactions
  before insert on public.transactions
  for each row
  execute function public.guard_checkout_tenant_id();

-- ------------------------------------------------------------------------------
-- 3. Apply to transaction_items
-- ------------------------------------------------------------------------------
drop trigger if exists trg_guard_checkout_tenant_transaction_items
  on public.transaction_items;

create trigger trg_guard_checkout_tenant_transaction_items
  before insert on public.transaction_items
  for each row
  execute function public.guard_checkout_tenant_id();

-- ------------------------------------------------------------------------------
-- NOTE: orders / order_items / payments may also warrant this trigger if your
--       sync layer writes them directly. Add analogous triggers as needed.
-- ------------------------------------------------------------------------------
