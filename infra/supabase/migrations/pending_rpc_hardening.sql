-- ===================================================================
-- Pending hardening for pin_login RPC and RBAC reminders
-- ===================================================================

-- [TODO] Create rate-limiting table that tracks pin_login attempts per email+device.
--            Example:
-- CREATE TABLE IF NOT EXISTS public.pin_login_attempts (
--   id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
--   email text NOT NULL,
--   device_id text,
--   attempted_at timestamptz NOT NULL DEFAULT now()
-- );

-- [TODO] Build helper function called from pin_login RPC to abort after N attempts:
-- CREATE OR REPLACE FUNCTION public.throttle_pin_login(email text, device_id text) RETURNS boolean AS $$
-- BEGIN
--   -- Remove stale rows older than 5 minutes
--   DELETE FROM public.pin_login_attempts
--   WHERE attempted_at < now() - interval '5 minutes';
--   -- Count remaining attempts for this email/device
--   IF (
--     (SELECT count(*) FROM public.pin_login_attempts WHERE email = $1 AND (device_id = $2 OR device_id IS NULL)) >= 5
--   ) THEN
--     RETURN FALSE;
--   END IF;
--   INSERT INTO public.pin_login_attempts (email, device_id) VALUES ($1, $2);
--   RETURN TRUE;
-- END;
-- $$ LANGUAGE plpgsql;

-- [TODO] Modify pin_login RPC to call throttle_pin_login before validating pin and to log suspicious activities.
-- [TODO] Ensure pin_login compares hashed PINs (never plaintext) and that device_id/email are part of the payload.

-- [TODO] RBAC reminder: Supabase RLS policies should guard tables based on `auth.jwt()->>'role'`.
-- Example:
-- CREATE POLICY tenant_admins_only ON public.stores FOR ALL TO authenticated USING (
--   (auth.jwt()->>'role') IN ('tenant_admin', 'super_admin')
-- );

-- Once these snippets are implemented, remove this placeholder migration and replace it with the concrete SQL steps.
