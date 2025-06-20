-- Drop all existing policies
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "File owner access" ON files;
  DROP POLICY IF EXISTS "Entry files access" ON entry_files;
  DROP POLICY IF EXISTS "View own membership" ON group_members;
  DROP POLICY IF EXISTS "View group members" ON group_members;
  DROP POLICY IF EXISTS "Admin manage members" ON group_members;
END $$;

-- Files: Simple ownership check
CREATE POLICY "File owner access"
ON files
FOR ALL
TO authenticated
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- Entry files: Direct ownership check
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

-- Group members: Single policy for all operations
CREATE POLICY "Group members access"
ON group_members
FOR ALL
TO authenticated
USING (
  -- Allow if user is member
  user_id = auth.uid()
  OR
  -- Allow if user is admin of the group
  EXISTS (
    SELECT 1 
    FROM group_members gm 
    WHERE gm.group_id = group_members.group_id 
    AND gm.user_id = auth.uid() 
    AND gm.role = 'admin'
  )
);

-- Ensure indexes exist
CREATE INDEX IF NOT EXISTS idx_files_created_by ON files(created_by);
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_id ON journal_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user_id ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_admin ON group_members(group_id, user_id) WHERE role = 'admin';