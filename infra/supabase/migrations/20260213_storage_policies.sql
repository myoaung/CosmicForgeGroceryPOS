-- Create the storage bucket for product images
INSERT INTO storage.buckets (id, name, public) VALUES ('product-images', 'product-images', true);

-- Policy: Tenant Upload Access
-- Allow users to upload ONLY to their own tenant folder
CREATE POLICY "Tenant Upload Access"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'product-images' AND
  (storage.foldername(name))[1] = auth.jwt() ->> 'tenant_id'
);

-- Policy: Tenant View Access
-- Allow anyone to view images (public bucket) or restrict if needed.
-- Assuming public read for now as per "public URL" usage.
CREATE POLICY "Public Distribute Access"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'product-images');

-- Policy: Tenant Update/Delete Access
-- Allow users to update/delete ONLY in their tenant folder
CREATE POLICY "Tenant Owner Access"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'product-images' AND
  (storage.foldername(name))[1] = auth.jwt() ->> 'tenant_id'
);

CREATE POLICY "Tenant Delete Access"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'product-images' AND
  (storage.foldername(name))[1] = auth.jwt() ->> 'tenant_id'
);
