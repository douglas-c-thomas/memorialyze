-- Drop all existing policies first to ensure a clean slate
DO $$ 
BEGIN
  -- Drop files policies
  DROP POLICY IF EXISTS "File owner access" ON files;
  DROP POLICY IF EXISTS "File access control" ON files;
  DROP POLICY IF EXISTS "Users can insert their own files" ON files;
  DROP POLICY IF EXISTS "Users can view files they have access to" ON files;
  DROP POLICY IF EXISTS "Users can delete their own files" ON files;

  -- Drop group_members policies
  DROP POLICY IF EXISTS "Member view access" ON group_members;
  DROP POLICY IF EXISTS "Admin management" ON group_members;
  DROP POLICY IF EXISTS "Group membership access" ON group_members;
  DROP POLICY IF EXISTS "Group admin access" ON group_members;

  -- Drop entry_files policies
  DROP POLICY IF EXISTS "Entry files access" ON entry_files;
  DROP POLICY IF EXISTS "Entry files management" ON entry_files;
END $$;

-- Create file policies with direct ownership checks
CREATE POLICY "File owner access"
ON files
FOR ALL
TO authenticated
USING (
  -- Simple ownership check
  created_by = auth.uid()
)
WITH CHECK (
  -- Only allow creating files they own
  created_by = auth.uid()
);

-- Create entry_files policy with minimal joins
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

-- Create group_members policies with minimal recursion risk
CREATE POLICY "Member view access"
ON group_members
FOR SELECT
TO authenticated
USING (
  -- Direct membership check
  user_id = auth.uid()
);

CREATE POLICY "Admin management"
ON group_members
FOR ALL
TO authenticated
USING (
  -- Single-level admin check
  EXISTS (
    SELECT 1
    FROM group_members gm
    WHERE gm.group_id = group_members.group_id
    AND gm.user_id = auth.uid()
    AND gm.role = 'admin'
  )
);

-- Create optimized indexes
CREATE INDEX IF NOT EXISTS idx_files_created_by ON files(created_by);
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_id ON journal_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_admin ON group_members(group_id, user_id) WHERE role = 'admin';
CREATE INDEX IF NOT EXISTS idx_group_members_user_role ON group_members(user_id, role);