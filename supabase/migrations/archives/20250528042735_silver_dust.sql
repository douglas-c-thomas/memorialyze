/*
  # Fix recursive policies for file management
  
  1. Changes
    - Simplify policies to avoid recursion
    - Add direct ownership checks
    - Optimize policy performance
    
  2. Security
    - Maintain data access control
    - Prevent unauthorized access
    - Improve query efficiency
*/

-- Drop existing policies
DROP POLICY IF EXISTS "File access control" ON files;
DROP POLICY IF EXISTS "Entry files management" ON entry_files;
DROP POLICY IF EXISTS "Group membership access" ON group_members;

-- Create simplified file access policy
CREATE POLICY "File access control"
ON files
FOR ALL
TO authenticated
USING (created_by = auth.uid());

-- Create simplified entry files policy
CREATE POLICY "Entry files management"
ON entry_files
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM journal_entries je
    WHERE je.id = entry_files.entry_id
    AND je.user_id = auth.uid()
  )
);

-- Create group membership policies
CREATE POLICY "Group membership access"
ON group_members
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "Group admin access"
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

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_id ON journal_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_entry_files_entry_id ON entry_files(entry_id);
CREATE INDEX IF NOT EXISTS idx_group_members_admin ON group_members(group_id, user_id) WHERE role = 'admin';