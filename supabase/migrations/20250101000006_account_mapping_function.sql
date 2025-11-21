-- VIRGO Financial Dashboard - Account Mapping Function
-- This migration creates a function to map QBO accounts to canonical categories

-- ============================================================================
-- ACCOUNT MAPPING FUNCTION
-- ============================================================================

-- Function to map a single account to a canonical category using fuzzy matching
CREATE OR REPLACE FUNCTION fn_map_account_to_category(
  p_account_id UUID
) RETURNS UUID AS $$
DECLARE
  v_account_name TEXT;
  v_account_type TEXT;
  v_account_subtype TEXT;
  v_category_id UUID;
  v_match_score INTEGER;
  v_best_category_id UUID;
  v_best_score INTEGER := 0;
  v_category_record RECORD;
  v_example TEXT;
BEGIN
  -- Fetch account details
  SELECT name, type, sub_type
  INTO v_account_name, v_account_type, v_account_subtype
  FROM accounts
  WHERE id = p_account_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Account with id % not found', p_account_id;
  END IF;

  -- Try exact match first on account name against source_examples
  FOR v_category_record IN 
    SELECT id, source_examples 
    FROM categories
  LOOP
    FOREACH v_example IN ARRAY v_category_record.source_examples
    LOOP
      -- Exact match (case-insensitive)
      IF LOWER(v_account_name) = LOWER(v_example) THEN
        v_best_category_id := v_category_record.id;
        v_best_score := 100;
        EXIT;
      END IF;
    END LOOP;
    
    EXIT WHEN v_best_score = 100;
  END LOOP;

  -- If no exact match, try fuzzy matching
  IF v_best_score < 100 THEN
    FOR v_category_record IN 
      SELECT id, source_examples 
      FROM categories
    LOOP
      v_match_score := 0;
      
      FOREACH v_example IN ARRAY v_category_record.source_examples
      LOOP
        -- Partial match: check if example is contained in account name
        IF LOWER(v_account_name) LIKE '%' || LOWER(v_example) || '%' THEN
          v_match_score := GREATEST(v_match_score, 80);
        END IF;
        
        -- Partial match: check if account name is contained in example
        IF LOWER(v_example) LIKE '%' || LOWER(v_account_name) || '%' THEN
          v_match_score := GREATEST(v_match_score, 70);
        END IF;
      END LOOP;
      
      -- Keep track of best match
      IF v_match_score > v_best_score THEN
        v_best_score := v_match_score;
        v_best_category_id := v_category_record.id;
      END IF;
    END LOOP;
  END IF;

  -- If still no good match, use QBO account type as fallback
  IF v_best_score < 50 THEN
    -- Map QBO account types to canonical categories
    CASE 
      WHEN v_account_type IN ('Income', 'Other Income') THEN
        SELECT id INTO v_best_category_id 
        FROM categories 
        WHERE canonical_type = 'revenue' 
        LIMIT 1;
        
      WHEN v_account_type IN ('Cost of Goods Sold') THEN
        SELECT id INTO v_best_category_id 
        FROM categories 
        WHERE canonical_type = 'cogs' 
        LIMIT 1;
        
      WHEN v_account_type IN ('Expense', 'Other Expense') THEN
        SELECT id INTO v_best_category_id 
        FROM categories 
        WHERE canonical_type = 'opex' 
        LIMIT 1;
        
      WHEN v_account_type IN ('Bank', 'Other Current Asset', 'Fixed Asset', 'Other Asset', 'Accounts Receivable') THEN
        SELECT id INTO v_best_category_id 
        FROM categories 
        WHERE canonical_type = 'asset' 
        LIMIT 1;
        
      WHEN v_account_type IN ('Accounts Payable', 'Credit Card', 'Other Current Liability', 'Long Term Liability') THEN
        SELECT id INTO v_best_category_id 
        FROM categories 
        WHERE canonical_type = 'liability' 
        LIMIT 1;
        
      WHEN v_account_type IN ('Equity') THEN
        SELECT id INTO v_best_category_id 
        FROM categories 
        WHERE canonical_type = 'equity' 
        LIMIT 1;
        
      ELSE
        -- Default to opex for unmapped expense-like accounts
        SELECT id INTO v_best_category_id 
        FROM categories 
        WHERE canonical_type = 'opex' 
        LIMIT 1;
    END CASE;
  END IF;

  -- Update the account with the mapped category
  UPDATE accounts
  SET mapping_category_id = v_best_category_id
  WHERE id = p_account_id;

  RETURN v_best_category_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- BATCH MAPPING FUNCTION
-- ============================================================================

-- Function to map all accounts for a company
CREATE OR REPLACE FUNCTION fn_map_company_accounts(
  p_company_id UUID
) RETURNS TABLE(
  account_id UUID,
  account_name TEXT,
  category_id UUID,
  category_name TEXT,
  mapping_method TEXT
) AS $$
DECLARE
  v_account_record RECORD;
  v_mapped_category_id UUID;
  v_total_accounts INTEGER := 0;
  v_mapped_accounts INTEGER := 0;
BEGIN
  -- Count total accounts
  SELECT COUNT(*) INTO v_total_accounts
  FROM accounts
  WHERE company_id = p_company_id;

  RAISE NOTICE 'Mapping % accounts for company %', v_total_accounts, p_company_id;

  -- Map each account
  FOR v_account_record IN 
    SELECT id, name, type, mapping_category_id
    FROM accounts
    WHERE company_id = p_company_id
  LOOP
    -- Map the account
    v_mapped_category_id := fn_map_account_to_category(v_account_record.id);
    v_mapped_accounts := v_mapped_accounts + 1;
    
    -- Return result row
    RETURN QUERY
    SELECT 
      v_account_record.id,
      v_account_record.name,
      v_mapped_category_id,
      c.name,
      CASE 
        WHEN v_account_record.mapping_category_id IS NOT NULL THEN 'already_mapped'
        ELSE 'auto_mapped'
      END::TEXT
    FROM categories c
    WHERE c.id = v_mapped_category_id;
  END LOOP;

  RAISE NOTICE 'Successfully mapped % of % accounts', v_mapped_accounts, v_total_accounts;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- HELPER FUNCTION TO CHECK UNMAPPED ACCOUNTS
-- ============================================================================

-- Function to find accounts that need manual review
CREATE OR REPLACE FUNCTION fn_get_unmapped_accounts(
  p_company_id UUID
) RETURNS TABLE(
  account_id UUID,
  account_name TEXT,
  account_type TEXT,
  account_subtype TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    a.id,
    a.name,
    a.type,
    a.sub_type
  FROM accounts a
  WHERE a.company_id = p_company_id
    AND a.mapping_category_id IS NULL
  ORDER BY a.name;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- MANUAL MAPPING FUNCTION
-- ============================================================================

-- Function to manually set account mapping (for admin override)
CREATE OR REPLACE FUNCTION fn_set_account_mapping(
  p_account_id UUID,
  p_category_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
  v_category_exists BOOLEAN;
BEGIN
  -- Verify category exists
  SELECT EXISTS(SELECT 1 FROM categories WHERE id = p_category_id)
  INTO v_category_exists;

  IF NOT v_category_exists THEN
    RAISE EXCEPTION 'Category with id % does not exist', p_category_id;
  END IF;

  -- Update account mapping
  UPDATE accounts
  SET mapping_category_id = p_category_id
  WHERE id = p_account_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Account with id % not found', p_account_id;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON FUNCTION fn_map_account_to_category IS 
  'Maps a single account to a canonical category using fuzzy matching against source_examples. Returns the category_id.';

COMMENT ON FUNCTION fn_map_company_accounts IS 
  'Maps all accounts for a company to canonical categories. Returns a table with mapping results.';

COMMENT ON FUNCTION fn_get_unmapped_accounts IS 
  'Returns all accounts for a company that have not been mapped to a category.';

COMMENT ON FUNCTION fn_set_account_mapping IS 
  'Manually sets the category mapping for an account. Used for admin overrides.';

