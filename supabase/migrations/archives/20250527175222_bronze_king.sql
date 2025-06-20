/*
  # Add embeddings support
  
  1. Changes
    - Add vector extension for similarity search
    - Add embeddings column to journal_entries
    - Create function for finding similar stories
*/

-- Enable vector extension if not enabled
CREATE EXTENSION IF NOT EXISTS vector;

-- Add embeddings column to journal_entries
ALTER TABLE journal_entries 
ADD COLUMN IF NOT EXISTS content_embedding vector(384);

-- Create function to find similar stories
CREATE OR REPLACE FUNCTION match_stories(
  query_embedding vector(384),
  match_threshold float,
  match_count int
)
RETURNS TABLE (
  id uuid,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    journal_entries.id,
    1 - (journal_entries.content_embedding <=> query_embedding) AS similarity
  FROM journal_entries
  WHERE 1 - (journal_entries.content_embedding <=> query_embedding) > match_threshold
  ORDER BY similarity DESC
  LIMIT match_count;
END;
$$;