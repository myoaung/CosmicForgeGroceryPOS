-- COSMIC FORGE GROCERY: INITIAL DATABASE SCHEMA
-- Target Market: Myanmar (MMK / 5% Commercial Tax)

-- 1. Tenants (The Shop Owners)
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_name TEXT NOT NULL,
    plan_type TEXT DEFAULT 'Standard', -- Standard or Pro
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Stores (Specific Locations)
CREATE TABLE stores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    store_name TEXT NOT NULL,
    currency_code TEXT DEFAULT 'MMK',
    tax_rate NUMERIC(4,2) DEFAULT 5.0, -- Myanmar Commercial Tax (5%)
    is_geofence_enabled BOOLEAN DEFAULT true,
    authorized_bssid TEXT, -- For WiFi-based location security
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Inventory Items
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL, -- Pyidaungsu Font Supported
    barcode TEXT UNIQUE,
    price_per_unit NUMERIC(12, 2) NOT NULL,
    uom TEXT DEFAULT 'UNIT', -- 'UNIT' or 'WEIGHT'
    is_tax_exempt BOOLEAN DEFAULT false, -- For essential goods (Rice/Oil)
    current_stock NUMERIC(12, 3) DEFAULT 0.000,
    version INTEGER DEFAULT 1 -- For Sync Version Vectoring
);

-- ENABLE ROW LEVEL SECURITY (RLS)
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- EXAMPLE RLS POLICY: User can only see products belonging to their tenant_id
CREATE POLICY tenant_product_isolation ON products
    FOR ALL USING (tenant_id = (auth.jwt() -> 'app_metadata' ->> 'tenant_id')::UUID);

-- LOGGING: Immutable Audit Trail for Voids and Price Overrides
CREATE TABLE audit_trail (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id),
    performed_by UUID,
    action_type TEXT, -- VOID, REFUND, OVERRIDE
    description TEXT,
    timestamp TIMESTAMPTZ DEFAULT now()
);