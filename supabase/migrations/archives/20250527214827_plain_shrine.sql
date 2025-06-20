-- Drop existing policies if they exist
DO $$ 
BEGIN
  -- Drop files policies
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'files' 
    AND policyname = 'Users can insert their own files'
  ) THEN
    DROP POLICY "Users can insert their own files" ON files;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'files' 
    AND policyname = 'Users can view files they have access to'
  ) THEN
    DROP POLICY "Users can view files they have access to" ON files;
  END IF;

  -- Drop entry_files policies
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'entry_files' 
    AND policyname = 'Contributors and admins can manage entry files'
  ) THEN
    DROP POLICY "Contributors and admins can manage entry files" ON entry_files;
  END IF;
END $$;

-- Recreate policies with proper checks
DO $$ 
BEGIN
  -- Files policies
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

  -- Entry_files policies
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