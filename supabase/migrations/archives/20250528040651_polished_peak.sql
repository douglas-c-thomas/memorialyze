-- Drop existing policies if they exist
DO $$ 
BEGIN
  -- Drop group_members policies
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'group_members' 
    AND policyname = 'Users can manage groups they admin'
  ) THEN
    DROP POLICY "Users can manage groups they admin" ON group_members;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'group_members' 
    AND policyname = 'Users can view their memberships'
  ) THEN
    DROP POLICY "Users can view their memberships" ON group_members;
  END IF;

  -- Drop files policies
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'files' 
    AND policyname = 'Users can insert and delete their files'
  ) THEN
    DROP POLICY "Users can insert and delete their files" ON files;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'files' 
    AND policyname = 'Users can view accessible files'
  ) THEN
    DROP POLICY "Users can view accessible files" ON files;
  END IF;

  -- Drop entry_files policies
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'entry_files' 
    AND policyname = 'Users can manage entry files'
  ) THEN
    DROP POLICY "Users can manage entry files" ON entry_files;
  END IF;
END $$;

-- Create simplified group_members policies
CREATE POLICY "Users can manage groups they admin"
ON group_members
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM group_members gm
    WHERE gm.group_id = group_members.group_id
    AND gm.user_id = auth.uid()
    AND gm.role = 'admin'
  )
);

CREATE POLICY "Users can view their memberships"
ON group_members
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM group_members gm
    WHERE gm.group_id = group_members.group_id
    AND gm.user_id = auth.uid()
  )
);

-- Create files policies
CREATE POLICY "Users can insert and delete their files"
ON files
FOR ALL
TO authenticated
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

CREATE POLICY "Users can view accessible files"
ON files
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM entry_files ef
    JOIN journal_entries je ON je.id = ef.entry_id
    JOIN group_members gm ON gm.group_id = je.group_id
    WHERE ef.file_id = files.id
    AND gm.user_id = auth.uid()
  )
);

-- Create entry_files policies
CREATE POLICY "Users can manage entry files"
ON entry_files
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM journal_entries je
    JOIN group_members gm ON gm.group_id = je.group_id
    WHERE je.id = entry_files.entry_id
    AND gm.user_id = auth.uid()
    AND gm.role IN ('contributor', 'admin')
  )
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_group_members_user_role ON group_members(user_id, role);
CREATE INDEX IF NOT EXISTS idx_group_members_group_user ON group_members(group_id, user_id);
CREATE INDEX IF NOT EXISTS idx_entry_files_entry_id ON entry_files(entry_id);
CREATE INDEX IF NOT EXISTS idx_files_created_by ON files(created_by);