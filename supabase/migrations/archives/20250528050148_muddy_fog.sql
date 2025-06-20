-- Drop all existing policies
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "File owner access" ON files;
  DROP POLICY IF EXISTS "Entry files access" ON entry_files;
  DROP POLICY IF EXISTS "Member view access" ON group_members;
  DROP POLICY IF EXISTS "Admin management" ON group_members;
END $$;

-- Create simplified file access policy
CREATE POLICY "File owner access"
ON files
FOR ALL
TO authenticated
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- Create direct entry_files policy without group checks
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
USING (user_id = auth.uid());

CREATE POLICY "Admin management"
ON group_members
FOR ALL
TO authenticated
USING (
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
CREATE INDEX IF NOT EXISTS idx_group_members_admin ON group_members(group_id, user_id) WHERE role = 'admin';