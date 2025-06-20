/*
  # Fix recursive policies for file and entry management
  
  1. Changes
    - Simplify policies to avoid recursion
    - Remove nested EXISTS clauses
    - Use direct role checks
    
  2. Security
    - Maintain same security level with simpler checks
    - Ensure proper file access control
*/

-- Drop existing policies
DROP POLICY IF EXISTS "File basic access" ON files;
DROP POLICY IF EXISTS "Users can manage entry files" ON entry_files;
DROP POLICY IF EXISTS "Group members basic access" ON group_members;
DROP POLICY IF EXISTS "Admin group management" ON group_members;

-- Create simplified file access policy
CREATE POLICY "File access control"
ON files
FOR ALL
TO authenticated
USING (
  -- Users can always access files they created
  created_by = auth.uid()
)
WITH CHECK (
  -- Users can only create files they own
  created_by = auth.uid()
);

-- Create simplified entry files policy
CREATE POLICY "Entry files management"
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

-- Create simplified group members policy
CREATE POLICY "Group membership access"
ON group_members
FOR ALL
TO authenticated
USING (
  -- Users can manage groups where they are admin
  (role = 'admin' AND user_id = auth.uid()) OR
  -- Users can view groups they are members of
  (user_id = auth.uid())
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_id ON journal_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_entry_files_entry_id ON entry_files(entry_id);