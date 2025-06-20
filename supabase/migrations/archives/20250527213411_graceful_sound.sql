/*
  # Add memory storage support
  
  1. Changes
    - Add memory_type column to journal_entries
    - Add files table for storing file metadata
    - Add entry_files junction table
  
  2. Security
    - Enable RLS on new tables
    - Add appropriate policies
*/

-- Add memory_type to journal_entries
ALTER TABLE journal_entries
ADD COLUMN IF NOT EXISTS memory_type TEXT NOT NULL DEFAULT 'story';

-- Create files table
CREATE TABLE IF NOT EXISTS files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  url TEXT NOT NULL,
  type TEXT NOT NULL,
  size INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID NOT NULL REFERENCES auth.users
);

-- Enable RLS on files
ALTER TABLE files ENABLE ROW LEVEL SECURITY;

-- Create entry_files junction table
CREATE TABLE IF NOT EXISTS entry_files (
  entry_id UUID NOT NULL REFERENCES journal_entries ON DELETE CASCADE,
  file_id UUID NOT NULL REFERENCES files ON DELETE CASCADE,
  PRIMARY KEY (entry_id, file_id)
);

-- Enable RLS on entry_files
ALTER TABLE entry_files ENABLE ROW LEVEL SECURITY;

-- Create policies for files
CREATE POLICY "Users can insert their own files"
  ON files FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Users can view files they have access to"
  ON files FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM entry_files ef
    JOIN journal_entries je ON je.id = ef.entry_id
    JOIN group_members gm ON gm.group_id = je.group_id
    WHERE ef.file_id = files.id
    AND gm.user_id = auth.uid()
  ));

-- Create policies for entry_files
CREATE POLICY "Contributors and admins can manage entry files"
  ON entry_files FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM journal_entries je
    JOIN group_members gm ON gm.group_id = je.group_id
    WHERE je.id = entry_files.entry_id
    AND gm.user_id = auth.uid()
    AND gm.role IN ('contributor', 'admin')
  ));