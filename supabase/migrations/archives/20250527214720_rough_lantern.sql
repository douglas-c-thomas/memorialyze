-- Drop existing policies to recreate them with optimized versions
DROP POLICY IF EXISTS "Admins manage group members" ON group_members;
DROP POLICY IF EXISTS "Users can view own memberships" ON group_members;
DROP POLICY IF EXISTS "View members of joined groups" ON group_members;

-- Create new optimized policies
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

-- Add index to improve policy performance
CREATE INDEX IF NOT EXISTS idx_group_members_user_role 
ON group_members(user_id, role);

CREATE INDEX IF NOT EXISTS idx_group_members_group_user
ON group_members(group_id, user_id);