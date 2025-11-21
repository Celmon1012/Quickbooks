-- VIRGO Financial Dashboard - Seed Categories
-- This migration populates the categories table with canonical financial categories

-- ============================================================================
-- SEED CANONICAL FINANCIAL CATEGORIES
-- ============================================================================

-- Insert canonical categories with source examples for account mapping
INSERT INTO categories (name, canonical_type, source_examples) VALUES
  (
    'Revenue',
    'revenue',
    ARRAY[
      'Income',
      'Sales',
      'Service Revenue',
      'Product Revenue',
      'Consulting Revenue',
      'Subscription Revenue',
      'Other Income',
      'Sales of Product Income',
      'Service/Fee Income',
      'Unapplied Cash Payment Income'
    ]
  ),
  (
    'Cost of Goods Sold',
    'cogs',
    ARRAY[
      'COGS',
      'Cost of Sales',
      'Direct Costs',
      'Cost of Goods Sold',
      'Job Expenses',
      'Job Materials',
      'Subcontractors',
      'Supplies & Materials - COGS',
      'Direct Labor',
      'Freight & Delivery - COGS'
    ]
  ),
  (
    'Operating Expenses',
    'opex',
    ARRAY[
      'Rent',
      'Salaries',
      'Wages',
      'Marketing',
      'Advertising',
      'Utilities',
      'Office Supplies',
      'Insurance',
      'Professional Fees',
      'Legal & Professional Fees',
      'Accounting',
      'Bank Charges',
      'Depreciation',
      'Meals & Entertainment',
      'Travel',
      'Telephone',
      'Internet',
      'Software',
      'Subscriptions',
      'Repairs & Maintenance',
      'Taxes & Licenses',
      'Payroll Expenses',
      'Employee Benefits',
      'Office Expenses',
      'Miscellaneous'
    ]
  ),
  (
    'Assets',
    'asset',
    ARRAY[
      'Cash',
      'Bank',
      'Checking',
      'Savings',
      'Accounts Receivable',
      'A/R',
      'Inventory',
      'Inventory Asset',
      'Prepaid Expenses',
      'Fixed Assets',
      'Equipment',
      'Furniture & Fixtures',
      'Vehicles',
      'Buildings',
      'Land',
      'Accumulated Depreciation',
      'Other Current Assets',
      'Other Assets',
      'Undeposited Funds'
    ]
  ),
  (
    'Liabilities',
    'liability',
    ARRAY[
      'Accounts Payable',
      'A/P',
      'Credit Card',
      'Credit Cards',
      'Loans Payable',
      'Notes Payable',
      'Line of Credit',
      'Payroll Liabilities',
      'Sales Tax Payable',
      'Accrued Expenses',
      'Other Current Liabilities',
      'Long Term Liabilities',
      'Mortgage Payable'
    ]
  ),
  (
    'Equity',
    'equity',
    ARRAY[
      'Owner Equity',
      'Owners Equity',
      'Retained Earnings',
      'Opening Balance Equity',
      'Capital Stock',
      'Common Stock',
      'Paid-In Capital',
      'Distributions',
      'Dividends Paid',
      'Partner Equity',
      'Member Equity'
    ]
  )
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify that all 6 canonical categories were inserted
DO $$
DECLARE
  category_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO category_count FROM categories;
  
  IF category_count < 6 THEN
    RAISE EXCEPTION 'Categories seed failed: expected 6 categories, found %', category_count;
  END IF;
  
  RAISE NOTICE 'Successfully seeded % categories', category_count;
END $$;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON COLUMN categories.canonical_type IS 'One of: revenue, cogs, opex, asset, liability, equity';
COMMENT ON COLUMN categories.source_examples IS 'Array of common QBO account names that map to this category';
