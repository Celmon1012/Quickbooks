-- VIRGO Financial Dashboard - Initial Schema Migration
-- This migration creates all core tables with indexes and constraints

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- Companies table
CREATE TABLE companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  org_metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_companies_created_at ON companies(created_at);

-- QBO Connections table
CREATE TABLE qbo_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  qbo_company_id TEXT NOT NULL,
  oauth_tokens_encrypted TEXT NOT NULL,
  connected_at TIMESTAMPTZ DEFAULT NOW(),
  last_sync_at TIMESTAMPTZ,
  UNIQUE(company_id, qbo_company_id)
);

CREATE INDEX idx_qbo_connections_company ON qbo_connections(company_id);
CREATE INDEX idx_qbo_connections_last_sync ON qbo_connections(last_sync_at);

-- Categories table (canonical financial categories)
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  canonical_type TEXT NOT NULL,
  source_examples TEXT[] DEFAULT ARRAY[]::TEXT[]
);

CREATE INDEX idx_categories_canonical_type ON categories(canonical_type);

-- Accounts table
CREATE TABLE accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  qbo_account_id TEXT NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  sub_type TEXT,
  mapping_category_id UUID REFERENCES categories(id),
  UNIQUE(company_id, qbo_account_id)
);

CREATE INDEX idx_accounts_company ON accounts(company_id);
CREATE INDEX idx_accounts_category ON accounts(mapping_category_id);
CREATE INDEX idx_accounts_type ON accounts(type);

-- Raw Transactions table
CREATE TABLE raw_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  qbo_txn_id TEXT NOT NULL,
  txn_type TEXT NOT NULL,
  date DATE NOT NULL,
  amount NUMERIC(15,2) NOT NULL,
  currency TEXT DEFAULT 'USD',
  account_id UUID REFERENCES accounts(id),
  raw_payload_json JSONB NOT NULL,
  ingestion_ts TIMESTAMPTZ DEFAULT NOW(),
  source_run_id TEXT NOT NULL,
  UNIQUE(company_id, qbo_txn_id)
);

CREATE INDEX idx_raw_txn_company_date ON raw_transactions(company_id, date);
CREATE INDEX idx_raw_txn_source_run ON raw_transactions(source_run_id);
CREATE INDEX idx_raw_txn_account ON raw_transactions(account_id);
CREATE INDEX idx_raw_txn_date ON raw_transactions(date);

-- Monthly P&L table
CREATE TABLE monthly_pl (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  totals_by_account_type JSONB NOT NULL,
  row_version INTEGER DEFAULT 1,
  generated_at TIMESTAMPTZ DEFAULT NOW(),
  source_run_id TEXT NOT NULL,
  UNIQUE(company_id, period_start)
);

CREATE INDEX idx_monthly_pl_company_period ON monthly_pl(company_id, period_start);
CREATE INDEX idx_monthly_pl_source_run ON monthly_pl(source_run_id);

-- Monthly Cash Flow table
CREATE TABLE monthly_cash_flow (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  totals_by_account_type JSONB NOT NULL,
  row_version INTEGER DEFAULT 1,
  generated_at TIMESTAMPTZ DEFAULT NOW(),
  source_run_id TEXT NOT NULL,
  UNIQUE(company_id, period_start)
);

CREATE INDEX idx_monthly_cf_company_period ON monthly_cash_flow(company_id, period_start);
CREATE INDEX idx_monthly_cf_source_run ON monthly_cash_flow(source_run_id);

-- Projections 12-month table
CREATE TABLE projections_12m (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  snapshot_date DATE NOT NULL,
  month DATE NOT NULL,
  revenue_projection NUMERIC(15,2),
  cost_projection NUMERIC(15,2),
  assumptions JSONB DEFAULT '{}'::jsonb,
  UNIQUE(company_id, snapshot_date, month)
);

CREATE INDEX idx_projections_company_snapshot ON projections_12m(company_id, snapshot_date);
CREATE INDEX idx_projections_month ON projections_12m(month);

-- Change Events table (audit log)
CREATE TABLE change_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  entity TEXT NOT NULL,
  entity_id UUID NOT NULL,
  diff_summary JSONB,
  changed_at TIMESTAMPTZ DEFAULT NOW(),
  source_run_id TEXT NOT NULL
);

CREATE INDEX idx_change_events_company ON change_events(company_id, changed_at DESC);
CREATE INDEX idx_change_events_entity ON change_events(entity, entity_id);
CREATE INDEX idx_change_events_source_run ON change_events(source_run_id);

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE companies IS 'Core company records for multi-tenant system';
COMMENT ON TABLE qbo_connections IS 'QuickBooks Online OAuth connections with encrypted tokens';
COMMENT ON TABLE categories IS 'Canonical financial categories for account mapping';
COMMENT ON TABLE accounts IS 'Chart of accounts from QBO mapped to canonical categories';
COMMENT ON TABLE raw_transactions IS 'Raw financial transactions from QBO with full payload preservation';
COMMENT ON TABLE monthly_pl IS 'Pre-aggregated monthly profit & loss summaries';
COMMENT ON TABLE monthly_cash_flow IS 'Pre-aggregated monthly cash flow summaries';
COMMENT ON TABLE projections_12m IS 'Forward-looking 12-month financial projections';
COMMENT ON TABLE change_events IS 'Audit log for data changes and regenerations';

COMMENT ON COLUMN raw_transactions.qbo_txn_id IS 'Unique transaction ID from QuickBooks Online';
COMMENT ON COLUMN raw_transactions.source_run_id IS 'Unique identifier for the sync operation that ingested this transaction';
COMMENT ON COLUMN raw_transactions.raw_payload_json IS 'Complete QBO API response for provenance and debugging';
COMMENT ON COLUMN monthly_pl.row_version IS 'Incremented on each regeneration for change tracking';
COMMENT ON COLUMN monthly_pl.totals_by_account_type IS 'JSON object with keys: revenue, cogs, opex';
