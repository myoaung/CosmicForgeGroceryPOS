-- ==============================================================================
-- Migration: 20260310_storage_policy_hardening.sql
-- Purpose:   Remove the metadata->>'tenant_id' fallback from storage object
--            policies. The metadata field is client-supplied at upload time and
--            can be set to any value. Enforce tenant isolation purely via the
--            object path (folder name), which is controlled by our upload logic.
--
--            Folder convention enforced by the Flutter app:
--              product-images/{tenant_id}/{filename}
-- ==============================================================================

-- Drop existing storage policies
drop policy if exists tenant_storage_select on storage.objects;
drop policy if exists tenant_storage_insert on storage.objects;
drop policy if exists tenant_storage_update on storage.objects;
drop policy if exists tenant_storage_delete on storage.objects;

-- SELECT: folder name[1] must match caller's tenant_id
create policy tenant_storage_select
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = public.jwt_claim('tenant_id')
  );

-- INSERT: caller must upload into their own tenant folder
create policy tenant_storage_insert
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = public.jwt_claim('tenant_id')
  );

-- UPDATE: existing object must be in caller's tenant folder
create policy tenant_storage_update
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = public.jwt_claim('tenant_id')
  )
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = public.jwt_claim('tenant_id')
  );

-- DELETE: caller can only delete objects in their own tenant folder
create policy tenant_storage_delete
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = public.jwt_claim('tenant_id')
  );
