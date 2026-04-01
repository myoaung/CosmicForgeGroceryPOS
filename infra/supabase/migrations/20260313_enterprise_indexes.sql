-- =====================================================================
-- MULTI-DISCIPLINARY DIRECTIVE: DATABASE OPTIMIZATION
-- =====================================================================
-- Operation Oracle Preparation: 
-- Add high-value composite and single column indexes specifically aimed
-- at reducing table scans during heavy tenant aggregation reports.

-- 1. Tenant ID Indexing (Highest selectivity boundary)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_tenant_id ON public.orders(tenant_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_tenant_id ON public.products(tenant_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_inventory_tenant_id ON public.inventory(tenant_id);

-- 2. Time-series Indexing (For daily/monthly aggregations)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_created_at ON public.orders(created_at DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transactions_created_at ON public.transactions(created_at DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at DESC);

-- 3. Product Aggregation (For inventory_metrics and sales_summary functions)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_order_items_product_id ON public.order_items(product_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transaction_items_product_id ON public.transaction_items(product_id);

-- Explicitly analyze the tables after indexing to update the Postgres query planner
ANALYZE public.orders;
ANALYZE public.products;
ANALYZE public.order_items;
