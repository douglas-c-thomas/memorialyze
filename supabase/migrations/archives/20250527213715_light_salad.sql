/*
  # Add file storage support
  
  1. Changes
    - Add memory_type to journal_entries
    - Create files and entry_files tables
    - Set up RLS policies for file access
  
  2. Security
    - Enable RLS on new tables
    - Create policies for file access control
    - Link files to entries and groups
*/

-- Add memory_type to journal_entries
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'journal_entries' 
    AND column_name = 'memory_type'
  ) THEN
    ALTER TABLE journal_entries
    ADD COLUMN memory_type TEXT NOT NULL DEFAULT 'story';
  END IF;
END $$;

-- Create files table if it doesn't exist
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

-- Create entry_files junction table if it doesn't exist
CREATE TABLE IF NOT EXISTS entry_files (
  entry_id UUID NOT NULL REFERENCES journal_entries ON DELETE CASCADE,
  file_id UUID NOT NULL REFERENCES files ON DELETE CASCADE,
  PRIMARY KEY (entry_id, file_id)
);

-- Enable RLS on entry_files
ALTER TABLE entry_files ENABLE ROW LEVEL SECURITY;

-- Create policies for files if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'files' 
    AND policyname = 'Users can insert their own files'
  ) THEN
    CREATE POLICY "Users can insert their own files"
      ON files FOR INSERT TO authenticated
      WITH CHECK (auth.uid() = created_by);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'files' 
    AND policyname = 'Users can view files they have access to'
  ) THEN
    CREATE POLICY "Users can view files they have access to"
      ON files FOR SELECT TO authenticated
      USING (EXISTS (
        SELECT 1 FROM entry_files ef
        JOIN journal_entries je ON je.id = ef.entry_id
        JOIN group_members gm ON gm.group_id = je.group_id
        WHERE ef.file_id = files.id
        AND gm.user_id = auth.uid()
      ));
  END IF;
END $$;

-- Create policies for entry_files if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'entry_files' 
    AND policyname = 'Contributors and admins can manage entry files'
  ) THEN
    CREATE POLICY "Contributors and admins can manage entry files"
      ON entry_files FOR ALL TO authenticated
      USING (EXISTS (
        SELECT 1 FROM journal_entries je
        JOIN group_members gm ON gm.group_id = je.group_id
        WHERE je.id = entry_files.entry_id
        AND gm.user_id = auth.uid()
        AND gm.role IN ('contributor', 'admin')
      ));
  END IF;
END $$;