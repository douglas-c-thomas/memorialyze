-- Drop all existing policies
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "File owner access" ON files;
  DROP POLICY IF EXISTS "Entry files access" ON entry_files;
  DROP POLICY IF EXISTS "Group members access" ON group_members;
  DROP POLICY IF EXISTS "View membership" ON group_members;
  DROP POLICY IF EXISTS "Manage membership" ON group_members;
END $$;

-- Files: Direct ownership check only
CREATE POLICY "File owner access"
ON files
FOR ALL
TO authenticated
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- Entry files: Simple ownership check through journal entries
CREATE POLICY "Entry files access"
ON entry_files
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 
    FROM journal_entries 
    WHERE id = entry_files.entry_id
    AND user_id = auth.uid()
  )
);

-- Group members: View policy
CREATE POLICY "View membership"
ON group_members
FOR SELECT
TO authenticated
USING (
  -- Can view if user is a member of the group
  group_id IN (
    SELECT group_id 
    FROM group_members 
    WHERE user_id = auth.uid()
  )
);

-- Group members: Insert policy
CREATE POLICY "Insert membership"
ON group_members
FOR INSERT
TO authenticated
WITH CHECK (
  group_id IN (
    SELECT group_id 
    FROM group_members 
    WHERE user_id = auth.uid()
    AND role = 'admin'
  )
);

-- Group members: Update policy
CREATE POLICY "Update membership"
ON group_members
FOR UPDATE
TO authenticated
USING (
  group_id IN (
    SELECT group_id 
    FROM group_members 
    WHERE user_id = auth.uid()
    AND role = 'admin'
  )
);

-- Group members: Delete policy
CREATE POLICY "Delete membership"
ON group_members
FOR DELETE
TO authenticated
USING (
  group_id IN (
    SELECT group_id 
    FROM group_members 
    WHERE user_id = auth.uid()
    AND role = 'admin'
  )
);

-- Ensure indexes exist for performance
CREATE INDEX IF NOT EXISTS idx_files_created_by ON files(created_by);
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_id ON journal_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user_id ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_admin ON group_members(group_id, user_id) WHERE role = 'admin';