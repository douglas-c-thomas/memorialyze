-- Drop all existing policies first
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

-- Create simplified file access policy
CREATE POLICY "File access control"
ON files
FOR ALL
TO authenticated
USING (created_by = auth.uid());

-- Create simplified entry_files policy
CREATE POLICY "Entry files management"
ON entry_files
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 
    FROM journal_entries je
    INNER JOIN group_members gm ON je.group_id = gm.group_id AND gm.user_id = auth.uid()
    WHERE je.id = entry_files.entry_id
    AND gm.role IN ('admin', 'contributor')
  )
);

-- Create group members policies
CREATE POLICY "Group admin access"
ON group_members
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM group_members AS gm
    WHERE gm.group_id = group_members.group_id
    AND gm.user_id = auth.uid()
    AND gm.role = 'admin'
  )
);

CREATE POLICY "Group membership access"
ON group_members
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Add performance indexes
CREATE INDEX IF NOT EXISTS idx_files_created_by ON files(created_by);
CREATE INDEX IF NOT EXISTS idx_group_members_admin ON group_members(group_id, user_id) WHERE role = 'admin';
CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id);