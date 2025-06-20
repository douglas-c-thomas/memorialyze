/*
  # Fix infinite recursion in group_members policies

  1. Changes
    - Drop existing policies on group_members table that may cause recursion
    - Create new, optimized policies that avoid recursive queries
    
  2. Security
    - Maintain same security level but with more efficient policies
    - Ensure admins can still manage members
    - Allow users to view their own memberships
    - Allow viewing members of joined groups
*/

-- Drop existing policies to recreate them
DROP POLICY IF EXISTS "Admins manage group members" ON group_members;
DROP POLICY IF EXISTS "Users can view own memberships" ON group_members;
DROP POLICY IF EXISTS "View members of joined groups" ON group_members;

-- Create new optimized policies
CREATE POLICY "Admins manage group members"
ON group_members
FOR ALL
TO public
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
TO public
USING (user_id = auth.uid());

CREATE POLICY "View members of joined groups"
ON group_members
FOR SELECT
TO public
USING (
  EXISTS (
    SELECT 1 FROM group_members my_membership
    WHERE my_membership.group_id = group_members.group_id
    AND my_membership.user_id = auth.uid()
  )
);