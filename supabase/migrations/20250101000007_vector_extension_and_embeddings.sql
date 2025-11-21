-- Migration: Enable pgvector extension and create embeddings table
-- Description: Sets up vector extension for RAG/AI features and creates embeddings table
--              with proper indexes for semantic search
-- Requirements: 8.1-8.6

-- Enable pgvector extension for vector similarity search
CREATE EXTENSION IF NOT EXISTS vector;

-- Create embeddings table for storing vectorized financial data
CREATE TABLE embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL, -- 'monthly_row', 'raw_chunk', 'projection'
  entity_id UUID NOT NULL,
  period_start DATE,
  period_end DATE,
  source_run_id TEXT NOT NULL,
  generated_at TIMESTAMPTZ NOT NULL,
  content_text TEXT NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  embedding vector(1536), -- OpenAI ada-002 dimension
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add comment to table
COMMENT ON TABLE embeddings IS 'Stores vector embeddings of financial data for RAG/AI semantic search';

-- Add comments to key columns
COMMENT ON COLUMN embeddings.entity_type IS 'Type of entity: monthly_row, raw_chunk, or projection';
COMMENT ON COLUMN embeddings.entity_id IS 'Reference to the source entity (monthly_pl.id, raw_transactions.id, etc.)';
COMMENT ON COLUMN embeddings.source_run_id IS 'Tracks which data ingestion operation created this embedding';
COMMENT ON COLUMN embeddings.generated_at IS 'Timestamp when the source data was generated';
COMMENT ON COLUMN embeddings.content_text IS 'Human-readable text representation of the data';
COMMENT ON COLUMN embeddings.metadata IS 'Additional metadata (row_id_list, txn_count, assumptions, etc.)';
COMMENT ON COLUMN embeddings.embedding IS 'Vector embedding (1536 dimensions for OpenAI ada-002)';

-- Create index on company_id for filtering by company
CREATE INDEX idx_embeddings_company ON embeddings(company_id);

-- Create index on entity_type and entity_id for lookups
CREATE INDEX idx_embeddings_entity ON embeddings(entity_type, entity_id);

-- Create vector similarity search index using ivfflat
-- Note: ivfflat is an approximate nearest neighbor index optimized for cosine similarity
-- The lists parameter (100) should be adjusted based on data volume:
-- - Small datasets (<100k rows): lists = rows / 1000
-- - Large datasets: lists = sqrt(rows)
CREATE INDEX idx_embeddings_vector ON embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Create composite index for common query patterns (company + entity_type)
CREATE INDEX idx_embeddings_company_entity_type ON embeddings(company_id, entity_type);

-- Create index on source_run_id for tracking data lineage
CREATE INDEX idx_embeddings_source_run ON embeddings(source_run_id);

-- Create index on period_start for time-based queries
CREATE INDEX idx_embeddings_period ON embeddings(period_start, period_end);

-- Enable Row Level Security on embeddings table
ALTER TABLE embeddings ENABLE ROW LEVEL SECURITY;

-- Create RLS policy for embeddings (company-scoped access)
CREATE POLICY "Users can only access their company's embeddings"
  ON embeddings
  FOR ALL
  USING (company_id IN (
    SELECT company_id FROM user_company_access 
    WHERE user_id = auth.uid()
  ));

-- Add check constraint to validate entity_type values
ALTER TABLE embeddings ADD CONSTRAINT check_entity_type 
  CHECK (entity_type IN ('monthly_row', 'raw_chunk', 'projection'));

-- Add check constraint to ensure embedding dimension is correct
ALTER TABLE embeddings ADD CONSTRAINT check_embedding_dimension
  CHECK (vector_dims(embedding) = 1536);
