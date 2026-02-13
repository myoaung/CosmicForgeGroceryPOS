-- ==========================================
-- 0. MOCK SUPABASE AUTH FOR LOCAL DEVELOPMENT
-- ==========================================
-- This section prevents errors when running RLS policies locally.
CREATE SCHEMA IF NOT EXISTS auth;

-- Create a mock function to simulate Supabase's JWT handling
CREATE OR REPLACE FUNCTION auth.jwt() 
RETURNS jsonb 
LANGUAGE sql 
STABLE
AS $$
  -- Returns a dummy UUID to act as the default local tenant
  SELECT '{"app_metadata": {"tenant_id": "00000000-0000-0000-0000-000000000000"}}'::jsonb;
$$;

-- ==========================================
-- 1. CORE MULTI-TENANT TABLES
-- ==========================================

-- Tenants: The Business Owners
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_name TEXT NOT NULL,
    plan_type TEXT DEFAULT 'Standard', 
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Stores: Specific Physical Locations
CREATE TABLE stores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    store_name TEXT NOT NULL,
    currency_code TEXT DEFAULT 'MMK',
    tax_rate NUMERIC(4,2) DEFAULT 5.0, -- Default Myanmar Commercial Tax
    is_geofence_enabled BOOLEAN DEFAULT true,
    authorized_bssid TEXT, -- WiFi-based hardware security
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- 2. INVENTORY & PRODUCT LOGIC
-- ==========================================

-- Products: Support for Pyidaungsu Font & Weight/Unit UoM
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL, 
    barcode TEXT,
    price_per_unit NUMERIC(12, 2) NOT NULL,
    uom TEXT DEFAULT 'UNIT', -- 'UNIT' (snacks) or 'WEIGHT' (produce)
    is_tax_exempt BOOLEAN DEFAULT false, -- For essential goods (Rice/Oil)
    current_stock NUMERIC(12, 3) DEFAULT 0.000,
    version INTEGER DEFAULT 1 -- For Offline-First Sync logic
);

-- ==========================================
-- 3. SECURITY & AUDIT (RLS)
-- ==========================================

-- Enable Row Level Security on all core tables
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Product Isolation Policy: Users only see their own tenant's items
CREATE POLICY tenant_product_isolation ON products
    FOR ALL USING (tenant_id = (auth.jwt() -> 'app_metadata' ->> 'tenant_id')::UUID);

-- Audit Trail: Immutable record of destructive actions
CREATE TABLE audit_trail (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id),
    performed_by UUID,
    action_type TEXT, -- VOID, REFUND, PRICE_OVERRIDE
    description TEXT,
    timestamp TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- 4. SEED DATA (Optional: Creates the default local tenant)
-- ==========================================
INSERT INTO tenants (id, business_name) 
VALUES ('00000000-0000-0000-0000-000000000000', 'Cosmic Forge Local Dev')
ON CONFLICT (id) DO NOTHING;