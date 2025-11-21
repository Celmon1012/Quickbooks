-- VIRGO Financial Dashboard - Monthly Aggregation Functions
-- This migration creates SQL functions for generating monthly P&L and cash flow aggregations

-- ============================================================================
-- FUNCTION: fn_generate_monthly_pl
-- Purpose: Aggregate raw transactions into monthly P&L summaries
-- Parameters:
--   p_company_id: UUID of the company
--   p_period_start: Start date of the period (typically first day of month)
--   p_period_end: End date of the period (typically last day of month)
--   p_source_run_id: Unique identifier for this aggregation run
-- Returns: UUID of the created/updated monthly_pl record
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_generate_monthly_pl(
  p_company_id UUID,
  p_period_start DATE,
  p_period_end DATE,
  p_source_run_id TEXT
) RETURNS UUID AS $$
DECLARE
  v_row_id UUID;
  v_totals JSONB;
  v_revenue NUMERIC := 0;
  v_cogs NUMERIC := 0;
  v_opex NUMERIC := 0;
BEGIN
  -- Validate input parameters
  IF p_company_id IS NULL THEN
    RAISE EXCEPTION 'company_id cannot be NULL';
  END IF;
  
  IF p_period_start IS NULL OR p_period_end IS NULL THEN
    RAISE EXCEPTION 'period_start and period_end cannot be NULL';
  END IF;
  
  IF p_period_start > p_period_end THEN
    RAISE EXCEPTION 'period_start must be before or equal to period_end';
  END IF;
  
  IF p_source_run_id IS NULL OR p_source_run_id = '' THEN
    RAISE EXCEPTION 'source_run_id cannot be NULL or empty';
  END IF;

  -- Aggregate transactions by category type
  -- Calculate revenue
  SELECT COALESCE(SUM(rt.amount), 0) INTO v_revenue
  FROM raw_transactions rt
  JOIN accounts acc ON rt.account_id = acc.id
  JOIN categories cat ON acc.mapping_category_id = cat.id
  WHERE rt.company_id = p_company_id
    AND rt.date >= p_period_start
    AND rt.date <= p_period_end
    AND cat.canonical_type = 'revenue';

  -- Calculate COGS
  SELECT COALESCE(SUM(rt.amount), 0) INTO v_cogs
  FROM raw_transactions rt
  JOIN accounts acc ON rt.account_id = acc.id
  JOIN categories cat ON acc.mapping_category_id = cat.id
  WHERE rt.company_id = p_company_id
    AND rt.date >= p_period_start
    AND rt.date <= p_period_end
    AND cat.canonical_type = 'cogs';

  -- Calculate Operating Expenses
  SELECT COALESCE(SUM(rt.amount), 0) INTO v_opex
  FROM raw_transactions rt
  JOIN accounts acc ON rt.account_id = acc.id
  JOIN categories cat ON acc.mapping_category_id = cat.id
  WHERE rt.company_id = p_company_id
    AND rt.date >= p_period_start
    AND rt.date <= p_period_end
    AND cat.canonical_type = 'opex';

  -- Build totals JSON object
  v_totals := jsonb_build_object(
    'revenue', v_revenue,
    'cogs', v_cogs,
    'opex', v_opex
  );

  -- Upsert monthly_pl record with idempotency
  INSERT INTO monthly_pl (
    company_id,
    period_start,
    period_end,
    totals_by_account_type,
    row_version,
    generated_at,
    source_run_id
  ) VALUES (
    p_company_id,
    p_period_start,
    p_period_end,
    v_totals,
    1,
    NOW(),
    p_source_run_id
  )
  ON CONFLICT (company_id, period_start)
  DO UPDATE SET
    period_end = EXCLUDED.period_end,
    totals_by_account_type = EXCLUDED.totals_by_account_type,
    row_version = monthly_pl.row_version + 1,
    generated_at = NOW(),
    source_run_id = EXCLUDED.source_run_id
  RETURNING id INTO v_row_id;

  RETURN v_row_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNCTION: fn_generate_monthly_cash_flow
-- Purpose: Aggregate raw transactions into monthly cash flow summaries
-- Parameters:
--   p_company_id: UUID of the company
--   p_period_start: Start date of the period
--   p_period_end: End date of the period
--   p_source_run_id: Unique identifier for this aggregation run
-- Returns: UUID of the created/updated monthly_cash_flow record
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_generate_monthly_cash_flow(
  p_company_id UUID,
  p_period_start DATE,
  p_period_end DATE,
  p_source_run_id TEXT
) RETURNS UUID AS $$
DECLARE
  v_row_id UUID;
  v_totals JSONB;
  v_operating NUMERIC := 0;
  v_investing NUMERIC := 0;
  v_financing NUMERIC := 0;
BEGIN
  -- Validate input parameters
  IF p_company_id IS NULL THEN
    RAISE EXCEPTION 'company_id cannot be NULL';
  END IF;
  
  IF p_period_start IS NULL OR p_period_end IS NULL THEN
    RAISE EXCEPTION 'period_start and period_end cannot be NULL';
  END IF;
  
  IF p_period_start > p_period_end THEN
    RAISE EXCEPTION 'period_start must be before or equal to period_end';
  END IF;
  
  IF p_source_run_id IS NULL OR p_source_run_id = '' THEN
    RAISE EXCEPTION 'source_run_id cannot be NULL or empty';
  END IF;

  -- Map account types to cash flow categories
  -- Operating cash flow: Income and Expense accounts
  SELECT COALESCE(SUM(rt.amount), 0) INTO v_operating
  FROM raw_transactions rt
  JOIN accounts acc ON rt.account_id = acc.id
  WHERE rt.company_id = p_company_id
    AND rt.date >= p_period_start
    AND rt.date <= p_period_end
    AND acc.type IN ('Income', 'Expense', 'Other Income', 'Other Expense', 'Cost of Goods Sold');

  -- Investing cash flow: Fixed Asset and Other Asset accounts
  SELECT COALESCE(SUM(rt.amount), 0) INTO v_investing
  FROM raw_transactions rt
  JOIN accounts acc ON rt.account_id = acc.id
  WHERE rt.company_id = p_company_id
    AND rt.date >= p_period_start
    AND rt.date <= p_period_end
    AND acc.type IN ('Fixed Asset', 'Other Asset');

  -- Financing cash flow: Long Term Liability and Equity accounts
  SELECT COALESCE(SUM(rt.amount), 0) INTO v_financing
  FROM raw_transactions rt
  JOIN accounts acc ON rt.account_id = acc.id
  WHERE rt.company_id = p_company_id
    AND rt.date >= p_period_start
    AND rt.date <= p_period_end
    AND acc.type IN ('Long Term Liability', 'Equity');

  -- Build totals JSON object
  v_totals := jsonb_build_object(
    'operating', v_operating,
    'investing', v_investing,
    'financing', v_financing
  );

  -- Upsert monthly_cash_flow record with idempotency
  INSERT INTO monthly_cash_flow (
    company_id,
    period_start,
    period_end,
    totals_by_account_type,
    row_version,
    generated_at,
    source_run_id
  ) VALUES (
    p_company_id,
    p_period_start,
    p_period_end,
    v_totals,
    1,
    NOW(),
    p_source_run_id
  )
  ON CONFLICT (company_id, period_start)
  DO UPDATE SET
    period_end = EXCLUDED.period_end,
    totals_by_account_type = EXCLUDED.totals_by_account_type,
    row_version = monthly_cash_flow.row_version + 1,
    generated_at = NOW(),
    source_run_id = EXCLUDED.source_run_id
  RETURNING id INTO v_row_id;

  RETURN v_row_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON FUNCTION fn_generate_monthly_pl IS 
  'Aggregates raw transactions into monthly P&L summaries by category type (revenue, cogs, opex). Idempotent: safe to re-run with same parameters. Increments row_version on updates.';

COMMENT ON FUNCTION fn_generate_monthly_cash_flow IS 
  'Aggregates raw transactions into monthly cash flow summaries by account type mapping. Maps to operating, investing, and financing cash flow categories. Idempotent: safe to re-run with same parameters. Increments row_version on updates.';

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant execute permissions to authenticated users (via RLS)
GRANT EXECUTE ON FUNCTION fn_generate_monthly_pl TO authenticated;
GRANT EXECUTE ON FUNCTION fn_generate_monthly_cash_flow TO authenticated;

-- Grant execute permissions to service role (for Pipedream workflows)
GRANT EXECUTE ON FUNCTION fn_generate_monthly_pl TO service_role;
GRANT EXECUTE ON FUNCTION fn_generate_monthly_cash_flow TO service_role;

