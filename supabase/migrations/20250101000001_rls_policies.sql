-- VIRGO Financial Dashboard - Row Level Security Policies
-- This migration enables RLS and creates policies for multi-tenant data isolation

-- ============================================================================
-- USER-COMPANY ACCESS MAPPING TABLE
-- ============================================================================

-- Create user_company_access table to map authenticated users to companies
CREATE TABLE user_company_access (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'viewer', -- viewer, editor, admin
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, company_id)
);

CREATE INDEX idx_user_company_access_user ON user_company_access(user_id);
CREATE INDEX idx_user_company_access_company ON user_company_access(company_id);

COMMENT ON TABLE user_company_access IS 'Maps authenticated users to companies they can access';
COMMENT ON COLUMN user_company_access.user_id IS 'References auth.users(id) from Supabase Auth';
COMMENT ON COLUMN user_company_access.role IS 'User role: viewer (read-only), editor (read-write), admin (full access)';

-- ============================================================================
-- ENABLE ROW LEVEL SECURITY ON ALL TABLES
-- ============================================================================

ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE qbo_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE monthly_pl ENABLE ROW LEVEL SECURITY;
ALTER TABLE monthly_cash_flow ENABLE ROW LEVEL SECURITY;
ALTER TABLE projections_12m ENABLE ROW LEVEL SECURITY;
ALTER TABLE change_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_company_access ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES FOR COMPANIES TABLE
-- ============================================================================

-- Users can view companies they have access to
CREATE POLICY "Users can view their companies"
  ON companies
  FOR SELECT
  USING (
    id IN (
      SELECT company_id 
      FROM user_company_access 
      WHERE user_id = auth.uid()
    )
  );

-- Users with admin role can insert companies
CREATE POLICY "Admins can insert companies"
  ON companies
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 
      FROM user_company_access 
      WHERE user_id = auth.uid() 
        AND company_id = companies.id 
        AND role = 'admin'
    )
  );

-- Users with admin role can update companies
CREATE POLICY "Admins can update companies"
  ON companies
  FOR UPDATE
  USING (
    id IN (
      SELECT company_id 
      FROM user_company_access 
      WHERE user_id = auth.uid() 
        AND role = 'admin'
    )
  );

-- Users with admin role can delete companies
CREATE POLICY "Admins can delete companies"
  ON companies
  FOR DELETE
  USING (
    id IN (
      SELECT company_id 
      FROM user_company_access 
      WHERE user_id = auth.uid() 
        AND role = 'admin'
    )
  );

-- ============================================================================
-- RLS POLICIES FOR QBO_CONNECTIONS TABLE
-- ============================================================================

CREATE POLICY "Users can view their company connections"
  ON qbo_connections
  FOR SELECT
  USING (
    company_id IN (
      SELECT company_id 
      FROM user_company_access 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage connections"
  ON qbo_connections
  FOR ALL
  USING (
    company_id IN (
      SELECT company_id 
      FROM user_company_access 
      WHERE user_id = auth.uid() 
        AND role = 'admin'
    )
  );

-- ============================================================================
-- RLS POLICIES FOR CATEGORIES TABLE (GLOBAL READ ACCESS)
-- ============================================================================

-- Categories are global reference data - all authenticated users can read
CREATE POLICY "All users can view categories"
  ON categories
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Only service role can modify categories
CREATE POLICY "Service role can manage categories"
  ON categories
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role');

-- ============================================================================
-- RLS POLICIES FOR ACCOUNTS TABLE
-- ============================================================================

CREATE POLICY "Users can view their company accounts"
  ON accounts
  FOR SELECT
  USING (
    company_id IN (
      SELECT company_id 
      FROM user_company_access 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Editors can manage accounts"
  ON accounts
  FOR ALL
  USING (
    company_id IN (
      SELECT company_id 
      FROM user_company_access 
      WHERE user_id = auth.uid() 
        AND role IN ('editor', 'admin')
    )
  );

-- ============================================================================
-- RLS POLICIES FOR RAW_TRANSACTIONS TABLE
-- ============================================================================

CREATE POLICY "Users can view their company transactions"
  ON raw_transactions
  FOR SELECT
  USING (
    company_id IN (
      SELECT company_id 
      FROM user_company_access 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Service role can manage transactions"
  ON raw_transactions
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role');

-- ============================================================================
-- RLS POLICIES FOR MONTHLY_PL TABLE
-- ============================================================================

CREATE POLICY "Users can view their company P&L"
  ON monthly_pl
  FOR SELECT
  USING (
    company_id IN (
      SELECT company_id 
      FROM user_company_access 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Service role can manage P&L"
  ON monthly_pl
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role');

-- ============================================================================
-- RLS POLICIES FOR MONTHLY_CASH_FLOW TABLE
-- ============================================================================

CREATE POLICY "Users can view their company cash flow"
  ON monthly_cash_flow
  FOR SELECT
  USING (
    company_id IN (
      SELECT company_id 
      FROM user_company_access 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Service role can manage cash flow"
  ON monthly_cash_flow
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role');

-- ============================================================================
-- RLS POLICIES FOR PROJECTIONS_12M TABLE
-- ============================================================================

CREATE POLICY "Users can view their company projections"
  ON projections_12m
  FOR SELECT
  USING (
    company_id IN (
      SELECT company_id 
      FROM user_company_access 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Service role can manage projections"
  ON projections_12m
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role');

-- ============================================================================
-- RLS POLICIES FOR CHANGE_EVENTS TABLE
-- ============================================================================

CREATE POLICY "Users can view their company change events"
  ON change_events
  FOR SELECT
  USING (
    company_id IN (
      SELECT company_id 
      FROM user_company_access 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Service role can manage change events"
  ON change_events
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role');

-- ============================================================================
-- RLS POLICIES FOR USER_COMPANY_ACCESS TABLE
-- ============================================================================

-- Users can view their own access records
CREATE POLICY "Users can view their own access"
  ON user_company_access
  FOR SELECT
  USING (user_id = auth.uid());

-- Admins can manage access for their companies
CREATE POLICY "Admins can manage company access"
  ON user_company_access
  FOR ALL
  USING (
    company_id IN (
      SELECT company_id 
      FROM user_company_access 
      WHERE user_id = auth.uid() 
        AND role = 'admin'
    )
  );
