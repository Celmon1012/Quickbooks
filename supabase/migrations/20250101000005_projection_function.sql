-- VIRGO Financial Dashboard - Projection Generation Function
-- This migration creates the SQL function for generating 12-month forward projections

-- ============================================================================
-- FUNCTION: fn_generate_projection
-- Purpose: Generate 12-month forward financial projections based on historical data
-- Parameters:
--   p_company_id: UUID of the company
-- Returns: INTEGER count of projection records created/updated
-- 
-- Algorithm:
--   1. Calculate 6-month moving average for revenue and costs from monthly_pl
--   2. Apply 2% monthly growth rate assumption (configurable)
--   3. Generate projections for next 12 months
--   4. Store assumptions in JSONB for transparency
--   5. Use current date as snapshot_date for versioning
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_generate_projection(
  p_company_id UUID
) RETURNS INTEGER AS $$
DECLARE
  v_snapshot_date DATE := CURRENT_DATE;
  v_avg_revenue NUMERIC;
  v_avg_costs NUMERIC;
  v_growth_rate NUMERIC := 1.02; -- 2% monthly growth assumption
  v_month_offset INTEGER;
  v_projection_month DATE;
  v_inserted_count INTEGER := 0;
  v_historical_months INTEGER;
  v_revenue_projection NUMERIC;
  v_cost_projection NUMERIC;
BEGIN
  -- Validate input parameters
  IF p_company_id IS NULL THEN
    RAISE EXCEPTION 'company_id cannot be NULL';
  END IF;

  -- Check if company exists
  IF NOT EXISTS (SELECT 1 FROM companies WHERE id = p_company_id) THEN
    RAISE EXCEPTION 'Company with id % does not exist', p_company_id;
  END IF;

  -- Calculate 6-month moving average for revenue and costs
  -- Use data from the last 6 complete months
  SELECT 
    AVG((totals_by_account_type->>'revenue')::numeric),
    AVG(
      COALESCE((totals_by_account_type->>'cogs')::numeric, 0) + 
      COALESCE((totals_by_account_type->>'opex')::numeric, 0)
    ),
    COUNT(*)
  INTO v_avg_revenue, v_avg_costs, v_historical_months
  FROM monthly_pl
  WHERE company_id = p_company_id
    AND period_start >= CURRENT_DATE - INTERVAL '6 months'
    AND period_start < CURRENT_DATE
  ORDER BY period_start DESC
  LIMIT 6;

  -- Check if we have sufficient historical data
  IF v_historical_months = 0 THEN
    RAISE NOTICE 'No historical data found for company %. Cannot generate projections.', p_company_id;
    RETURN 0;
  END IF;

  -- Log warning if less than 6 months of data
  IF v_historical_months < 6 THEN
    RAISE NOTICE 'Only % months of historical data available for company %. Projections may be less accurate.', 
      v_historical_months, p_company_id;
  END IF;

  -- Default to 0 if no revenue or costs found
  v_avg_revenue := COALESCE(v_avg_revenue, 0);
  v_avg_costs := COALESCE(v_avg_costs, 0);

  -- Generate 12 months of forward projections
  FOR v_month_offset IN 1..12 LOOP
    -- Calculate the projection month (first day of each future month)
    v_projection_month := DATE_TRUNC('month', CURRENT_DATE) + 
                          (v_month_offset || ' months')::INTERVAL;
    
    -- Apply compound growth rate
    v_revenue_projection := v_avg_revenue * POWER(v_growth_rate, v_month_offset);
    v_cost_projection := v_avg_costs * POWER(v_growth_rate, v_month_offset);
    
    -- Insert or update projection record
    INSERT INTO projections_12m (
      company_id,
      snapshot_date,
      month,
      revenue_projection,
      cost_projection,
      assumptions
    ) VALUES (
      p_company_id,
      v_snapshot_date,
      v_projection_month,
      ROUND(v_revenue_projection, 2),
      ROUND(v_cost_projection, 2),
      jsonb_build_object(
        'method', 'moving_average_6m',
        'growth_rate_monthly', v_growth_rate,
        'growth_rate_annual', ROUND(POWER(v_growth_rate, 12), 4),
        'base_revenue_avg', ROUND(v_avg_revenue, 2),
        'base_costs_avg', ROUND(v_avg_costs, 2),
        'historical_months_used', v_historical_months,
        'projection_month_offset', v_month_offset,
        'generated_at', NOW()
      )
    )
    ON CONFLICT (company_id, snapshot_date, month)
    DO UPDATE SET
      revenue_projection = EXCLUDED.revenue_projection,
      cost_projection = EXCLUDED.cost_projection,
      assumptions = EXCLUDED.assumptions;
    
    v_inserted_count := v_inserted_count + 1;
  END LOOP;

  -- Log successful completion
  RAISE NOTICE 'Generated % projection records for company % using % months of historical data', 
    v_inserted_count, p_company_id, v_historical_months;

  RETURN v_inserted_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON FUNCTION fn_generate_projection IS 
  'Generates 12-month forward financial projections based on 6-month moving average with 2% monthly growth assumption. Returns count of projection records created/updated. Stores all assumptions in JSONB for transparency and auditability.';

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant execute permissions to authenticated users (via RLS)
GRANT EXECUTE ON FUNCTION fn_generate_projection TO authenticated;

-- Grant execute permissions to service role (for Pipedream workflows)
GRANT EXECUTE ON FUNCTION fn_generate_projection TO service_role;

-- ============================================================================
-- EXAMPLE USAGE
-- ============================================================================

-- Example: Generate projections for a company
-- SELECT fn_generate_projection('company-uuid-here');

-- Example: View generated projections
-- SELECT 
--   month,
--   revenue_projection,
--   cost_projection,
--   revenue_projection - cost_projection AS net_projection,
--   assumptions->>'method' AS method,
--   assumptions->>'growth_rate_monthly' AS growth_rate
-- FROM projections_12m
-- WHERE company_id = 'company-uuid-here'
--   AND snapshot_date = CURRENT_DATE
-- ORDER BY month;
