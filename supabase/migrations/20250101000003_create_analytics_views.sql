-- VIRGO Financial Dashboard - Analytics Views Migration
-- This migration creates SQL views for dashboard analytics with provenance tracking

-- ============================================================================
-- v_monthly_pl - Monthly Profit & Loss View
-- ============================================================================

CREATE OR REPLACE VIEW v_monthly_pl AS
SELECT 
  mpl.id AS row_id,
  mpl.company_id,
  mpl.period_start AS start_date,
  mpl.period_end AS end_date,
  (mpl.totals_by_account_type->>'revenue')::numeric AS revenue,
  (mpl.totals_by_account_type->>'cogs')::numeric AS cogs,
  (mpl.totals_by_account_type->>'opex')::numeric AS opex,
  (mpl.totals_by_account_type->>'revenue')::numeric - 
    (mpl.totals_by_account_type->>'cogs')::numeric AS gross_profit,
  (mpl.totals_by_account_type->>'revenue')::numeric - 
    (mpl.totals_by_account_type->>'cogs')::numeric - 
    (mpl.totals_by_account_type->>'opex')::numeric AS net_income,
  mpl.row_version,
  mpl.generated_at,
  mpl.source_run_id,
  (
    SELECT json_agg(rt.id)
    FROM raw_transactions rt
    WHERE rt.company_id = mpl.company_id
      AND rt.date >= mpl.period_start
      AND rt.date <= mpl.period_end
  ) AS transaction_ids
FROM monthly_pl mpl;

COMMENT ON VIEW v_monthly_pl IS 'Monthly P&L view with calculated metrics and transaction provenance';

-- ============================================================================
-- v_monthly_cash_flow - Monthly Cash Flow View
-- ============================================================================

CREATE OR REPLACE VIEW v_monthly_cash_flow AS
SELECT 
  mcf.id AS row_id,
  mcf.company_id,
  mcf.period_start AS start_date,
  mcf.period_end AS end_date,
  (mcf.totals_by_account_type->>'operating')::numeric AS operating_cash_flow,
  (mcf.totals_by_account_type->>'investing')::numeric AS investing_cash_flow,
  (mcf.totals_by_account_type->>'financing')::numeric AS financing_cash_flow,
  (mcf.totals_by_account_type->>'operating')::numeric + 
    (mcf.totals_by_account_type->>'investing')::numeric + 
    (mcf.totals_by_account_type->>'financing')::numeric AS net_cash_flow,
  mcf.row_version,
  mcf.generated_at,
  mcf.source_run_id,
  (
    SELECT json_agg(rt.id)
    FROM raw_transactions rt
    WHERE rt.company_id = mcf.company_id
      AND rt.date >= mcf.period_start
      AND rt.date <= mcf.period_end
  ) AS transaction_ids
FROM monthly_cash_flow mcf;

COMMENT ON VIEW v_monthly_cash_flow IS 'Monthly cash flow view with operating, investing, and financing categories';

-- ============================================================================
-- v_kpis - Key Performance Indicators View
-- ============================================================================

CREATE OR REPLACE VIEW v_kpis AS
SELECT 
  mpl.company_id,
  mpl.period_start,
  mpl.period_end,
  (mpl.totals_by_account_type->>'revenue')::numeric AS revenue,
  (mpl.totals_by_account_type->>'cogs')::numeric AS cogs,
  (mpl.totals_by_account_type->>'opex')::numeric AS opex,
  (mpl.totals_by_account_type->>'revenue')::numeric - 
    (mpl.totals_by_account_type->>'cogs')::numeric AS gross_profit,
  CASE 
    WHEN (mpl.totals_by_account_type->>'revenue')::numeric > 0 
    THEN (
      ((mpl.totals_by_account_type->>'revenue')::numeric - 
       (mpl.totals_by_account_type->>'cogs')::numeric) / 
      (mpl.totals_by_account_type->>'revenue')::numeric * 100
    )
    ELSE 0
  END AS gross_margin_pct,
  (mpl.totals_by_account_type->>'revenue')::numeric - 
    (mpl.totals_by_account_type->>'cogs')::numeric - 
    (mpl.totals_by_account_type->>'opex')::numeric AS net_income,
  CASE 
    WHEN (mpl.totals_by_account_type->>'revenue')::numeric > 0 
    THEN (
      ((mpl.totals_by_account_type->>'revenue')::numeric - 
       (mpl.totals_by_account_type->>'cogs')::numeric - 
       (mpl.totals_by_account_type->>'opex')::numeric) / 
      (mpl.totals_by_account_type->>'revenue')::numeric * 100
    )
    ELSE 0
  END AS net_margin_pct,
  COALESCE((mcf.totals_by_account_type->>'operating')::numeric, 0) AS operating_cash_flow,
  COALESCE((mcf.totals_by_account_type->>'investing')::numeric, 0) AS investing_cash_flow,
  COALESCE((mcf.totals_by_account_type->>'financing')::numeric, 0) AS financing_cash_flow,
  mpl.row_version,
  mpl.generated_at,
  mpl.source_run_id,
  (
    SELECT json_agg(rt.id)
    FROM raw_transactions rt
    WHERE rt.company_id = mpl.company_id
      AND rt.date >= mpl.period_start
      AND rt.date <= mpl.period_end
  ) AS transaction_ids
FROM monthly_pl mpl
LEFT JOIN monthly_cash_flow mcf 
  ON mpl.company_id = mcf.company_id 
  AND mpl.period_start = mcf.period_start;

COMMENT ON VIEW v_kpis IS 'Key performance indicators with margin percentages and cash flow metrics';

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant SELECT permissions to authenticated users (RLS will filter by company_id)
GRANT SELECT ON v_monthly_pl TO authenticated;
GRANT SELECT ON v_monthly_cash_flow TO authenticated;
GRANT SELECT ON v_kpis TO authenticated;

-- Grant SELECT permissions to service role for backend operations
GRANT SELECT ON v_monthly_pl TO service_role;
GRANT SELECT ON v_monthly_cash_flow TO service_role;
GRANT SELECT ON v_kpis TO service_role;
