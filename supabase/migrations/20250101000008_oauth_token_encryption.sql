-- VIRGO Financial Dashboard - OAuth Token Encryption Functions
-- This migration creates functions for securely encrypting and decrypting OAuth tokens

-- ============================================================================
-- ENCRYPTION KEY MANAGEMENT
-- ============================================================================

-- Create a table to store encryption keys (if not using Supabase Vault)
-- Note: In production, consider using Supabase Vault or external key management
CREATE TABLE IF NOT EXISTS encryption_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key_name TEXT UNIQUE NOT NULL,
  key_value TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  rotated_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true
);

-- Insert default encryption key (CHANGE THIS IN PRODUCTION!)
-- In production, generate a secure random key and store it securely
INSERT INTO encryption_keys (key_name, key_value, is_active)
VALUES ('oauth_token_key', 'CHANGE_THIS_TO_A_SECURE_RANDOM_KEY_IN_PRODUCTION', true)
ON CONFLICT (key_name) DO NOTHING;

-- ============================================================================
-- ENCRYPTION FUNCTIONS
-- ============================================================================

/**
 * Encrypt OAuth tokens using pgcrypto
 * 
 * @param token_data TEXT - JSON string containing OAuth tokens
 * @param company_uuid UUID - Company ID for additional entropy
 * @returns JSON with encrypted_tokens field
 */
CREATE OR REPLACE FUNCTION encrypt_oauth_tokens(
  token_data TEXT,
  company_uuid UUID
)
RETURNS JSON AS $$
DECLARE
  encryption_key TEXT;
  encrypted_result TEXT;
  salt TEXT;
BEGIN
  -- Get active encryption key
  SELECT key_value INTO encryption_key
  FROM encryption_keys
  WHERE key_name = 'oauth_token_key' AND is_active = true
  LIMIT 1;
  
  IF encryption_key IS NULL THEN
    RAISE EXCEPTION 'No active encryption key found';
  END IF;
  
  -- Generate salt from company UUID for additional security
  salt := encode(digest(company_uuid::TEXT, 'sha256'), 'hex');
  
  -- Encrypt using AES-256
  encrypted_result := encode(
    encrypt(
      token_data::bytea,
      (encryption_key || salt)::bytea,
      'aes'
    ),
    'base64'
  );
  
  RETURN json_build_object(
    'encrypted_tokens', encrypted_result,
    'encryption_method', 'aes-256',
    'encrypted_at', NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/**
 * Decrypt OAuth tokens using pgcrypto
 * 
 * @param encrypted_tokens TEXT - Base64 encoded encrypted tokens
 * @param company_uuid UUID - Company ID used during encryption
 * @returns JSON with decrypted token data
 */
CREATE OR REPLACE FUNCTION decrypt_oauth_tokens(
  encrypted_tokens TEXT,
  company_uuid UUID
)
RETURNS JSON AS $$
DECLARE
  encryption_key TEXT;
  decrypted_result TEXT;
  salt TEXT;
BEGIN
  -- Get active encryption key
  SELECT key_value INTO encryption_key
  FROM encryption_keys
  WHERE key_name = 'oauth_token_key' AND is_active = true
  LIMIT 1;
  
  IF encryption_key IS NULL THEN
    RAISE EXCEPTION 'No active encryption key found';
  END IF;
  
  -- Generate salt from company UUID (same as encryption)
  salt := encode(digest(company_uuid::TEXT, 'sha256'), 'hex');
  
  -- Decrypt using AES-256
  decrypted_result := convert_from(
    decrypt(
      decode(encrypted_tokens, 'base64'),
      (encryption_key || salt)::bytea,
      'aes'
    ),
    'utf8'
  );
  
  RETURN decrypted_result::JSON;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/**
 * Helper function to get decrypted tokens for a company's QBO connection
 * 
 * @param p_company_id UUID - Company ID
 * @returns JSON with access_token, refresh_token, expires_at, token_type
 */
CREATE OR REPLACE FUNCTION get_qbo_tokens(
  p_company_id UUID
)
RETURNS JSON AS $$
DECLARE
  encrypted_tokens TEXT;
  decrypted_tokens JSON;
BEGIN
  -- Get encrypted tokens from qbo_connections
  SELECT oauth_tokens_encrypted INTO encrypted_tokens
  FROM qbo_connections
  WHERE company_id = p_company_id
  ORDER BY connected_at DESC
  LIMIT 1;
  
  IF encrypted_tokens IS NULL THEN
    RAISE EXCEPTION 'No QBO connection found for company %', p_company_id;
  END IF;
  
  -- Decrypt and return tokens
  decrypted_tokens := decrypt_oauth_tokens(encrypted_tokens, p_company_id);
  
  RETURN decrypted_tokens;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/**
 * Update OAuth tokens (for token refresh)
 * 
 * @param p_company_id UUID - Company ID
 * @param p_new_tokens JSON - New token data
 * @returns BOOLEAN - Success status
 */
CREATE OR REPLACE FUNCTION update_qbo_tokens(
  p_company_id UUID,
  p_new_tokens JSON
)
RETURNS BOOLEAN AS $$
DECLARE
  encrypted_result JSON;
BEGIN
  -- Encrypt new tokens
  encrypted_result := encrypt_oauth_tokens(
    p_new_tokens::TEXT,
    p_company_id
  );
  
  -- Update qbo_connections record
  UPDATE qbo_connections
  SET 
    oauth_tokens_encrypted = encrypted_result->>'encrypted_tokens',
    last_sync_at = NOW()
  WHERE company_id = p_company_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No QBO connection found for company %', p_company_id;
  END IF;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- SECURITY POLICIES
-- ============================================================================

-- Restrict access to encryption_keys table
ALTER TABLE encryption_keys ENABLE ROW LEVEL SECURITY;

-- Only service role can access encryption keys
CREATE POLICY "Service role only access to encryption keys"
  ON encryption_keys
  FOR ALL
  USING (false); -- No user access, only service role via SECURITY DEFINER functions

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON FUNCTION encrypt_oauth_tokens IS 'Encrypts OAuth tokens using AES-256 with company-specific salt';
COMMENT ON FUNCTION decrypt_oauth_tokens IS 'Decrypts OAuth tokens using AES-256 with company-specific salt';
COMMENT ON FUNCTION get_qbo_tokens IS 'Retrieves and decrypts QBO OAuth tokens for a company';
COMMENT ON FUNCTION update_qbo_tokens IS 'Updates QBO OAuth tokens with encryption (used for token refresh)';
COMMENT ON TABLE encryption_keys IS 'Stores encryption keys for OAuth token encryption (use Supabase Vault in production)';

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant execute permissions to authenticated users (RLS will still apply)
GRANT EXECUTE ON FUNCTION encrypt_oauth_tokens TO authenticated;
GRANT EXECUTE ON FUNCTION decrypt_oauth_tokens TO authenticated;
GRANT EXECUTE ON FUNCTION get_qbo_tokens TO authenticated;
GRANT EXECUTE ON FUNCTION update_qbo_tokens TO authenticated;

-- Grant execute to service role (for Pipedream workflows)
GRANT EXECUTE ON FUNCTION encrypt_oauth_tokens TO service_role;
GRANT EXECUTE ON FUNCTION decrypt_oauth_tokens TO service_role;
GRANT EXECUTE ON FUNCTION get_qbo_tokens TO service_role;
GRANT EXECUTE ON FUNCTION update_qbo_tokens TO service_role;
