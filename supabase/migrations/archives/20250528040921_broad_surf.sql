-- Drop all existing policies
DO $$ 
BEGIN
  -- Drop group_members policies
  DROP POLICY IF EXISTS "Users can manage groups they admin" ON group_members;
  DROP POLICY IF EXISTS "Users can view their memberships" ON group_members;
  DROP POLICY IF EXISTS "Admins manage group members" ON group_members;
  DROP POLICY IF EXISTS "Users can view own memberships" ON group_members;
  DROP POLICY IF EXISTS "View members of joined groups" ON group_members;

  -- Drop files policies
  DROP POLICY IF EXISTS "Users can insert and delete their files" ON files;
  DROP POLICY IF EXISTS "Users can view accessible files" ON files;
  DROP POLICY IF EXISTS "Users can insert their own files" ON files;
  DROP POLICY IF EXISTS "Users can view files they have access to" ON files;

  -- Drop entry_files policies
  DROP POLICY IF EXISTS "Users can manage entry files" ON entry_files;
  DROP POLICY IF EXISTS "Contributors and admins can manage entry files" ON entry_files;
END $$;

-- Recreate the original working policies
CREATE POLICY "Admins manage group members"
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

CREATE POLICY "Users can view own memberships"
ON group_members
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "View members of joined groups"
ON group_members
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM group_members my_membership
    WHERE my_membership.group_id = group_members.group_id
    AND my_membership.user_id = auth.uid()
  )
);

-- Files policies
CREATE POLICY "Users can insert their own files"
ON files
FOR INSERT
TO authenticated
WITH CHECK (created_by = auth.uid());

CREATE POLICY "Users can view files they have access to"
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

-- Entry files policy
CREATE POLICY "Contributors and admins can manage entry files"
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

-- Ensure indexes exist
CREATE INDEX IF NOT EXISTS idx_group_members_user_role ON group_members(user_id, role);
CREATE INDEX IF NOT EXISTS idx_group_members_group_user ON group_members(group_id, user_id);
CREATE INDEX IF NOT EXISTS idx_entry_files_entry_id ON entry_files(entry_id);
CREATE INDEX IF NOT EXISTS idx_files_created_by ON files(created_by);