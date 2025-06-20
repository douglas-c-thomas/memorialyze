-- Drop all existing policies first to start fresh
DO $$ 
BEGIN
  -- Drop files policies
  DROP POLICY IF EXISTS "File access control" ON files;
  DROP POLICY IF EXISTS "File basic access" ON files;
  DROP POLICY IF EXISTS "Users can insert their own files" ON files;
  DROP POLICY IF EXISTS "Users can view files they have access to" ON files;
  DROP POLICY IF EXISTS "Users can delete their own files" ON files;

  -- Drop group_members policies
  DROP POLICY IF EXISTS "Group members basic access" ON group_members;
  DROP POLICY IF EXISTS "Admin group management" ON group_members;
  DROP POLICY IF EXISTS "Group admin access" ON group_members;
  DROP POLICY IF EXISTS "Group membership access" ON group_members;
  DROP POLICY IF EXISTS "Admins manage group members" ON group_members;
  DROP POLICY IF EXISTS "Users can view own memberships" ON group_members;
  DROP POLICY IF EXISTS "View members of joined groups" ON group_members;

  -- Drop entry_files policies
  DROP POLICY IF EXISTS "Entry files management" ON entry_files;
  DROP POLICY IF EXISTS "Contributors and admins can manage entry files" ON entry_files;
END $$;

-- Create non-recursive file access policies
CREATE POLICY "File owner access"
ON files
FOR ALL
TO authenticated
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- Create direct entry_files policy without recursive checks
CREATE POLICY "Entry files access"
ON entry_files
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 
    FROM journal_entries je
    WHERE je.id = entry_files.entry_id
    AND je.user_id = auth.uid()
  )
);

-- Create non-recursive group member policies
CREATE POLICY "Member view access"
ON group_members
FOR SELECT
TO authenticated
USING (
  -- Users can view their own memberships
  user_id = auth.uid()
);

CREATE POLICY "Admin management"
ON group_members
FOR ALL
TO authenticated
USING (
  -- Direct check for admin status in the same group
  EXISTS (
    SELECT 1
    FROM group_members gm
    WHERE gm.group_id = group_members.group_id
    AND gm.user_id = auth.uid()
    AND gm.role = 'admin'
  )
);

-- Add optimized indexes
CREATE INDEX IF NOT EXISTS idx_files_created_by ON files(created_by);
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_id ON journal_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user_role ON group_members(user_id, role);
CREATE INDEX IF NOT EXISTS idx_group_members_group_user ON group_members(group_id, user_id);