-- Drop all existing policies
DROP POLICY IF EXISTS "Users can insert their own files" ON files;
DROP POLICY IF EXISTS "Users can view files they have access to" ON files;
DROP POLICY IF EXISTS "Users can delete their own files" ON files;
DROP POLICY IF EXISTS "Admins can manage group members" ON group_members;
DROP POLICY IF EXISTS "Users can view their own memberships" ON group_members;
DROP POLICY IF EXISTS "View members of joined groups" ON group_members;

-- Create simplified group_members policies
CREATE POLICY "Group members basic access"
ON group_members
FOR SELECT
TO authenticated
USING (
  -- Allow users to see their own memberships
  user_id = auth.uid() OR
  -- Allow users to see other members in groups they belong to
  group_id IN (
    SELECT group_id FROM group_members
    WHERE user_id = auth.uid()
  )
);

CREATE POLICY "Admin group management"
ON group_members
FOR ALL
TO authenticated
USING (
  group_id IN (
    SELECT group_id FROM group_members
    WHERE user_id = auth.uid()
    AND role = 'admin'
  )
);

-- Create simplified file policies
CREATE POLICY "File basic access"
ON files
FOR ALL
TO authenticated
USING (
  -- Users can manage their own files
  created_by = auth.uid()
)
WITH CHECK (
  -- Users can only create files they own
  created_by = auth.uid()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_group_members_user_role ON group_members(user_id, role);
CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_files_created_by ON files(created_by);