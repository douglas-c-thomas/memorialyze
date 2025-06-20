-- Drop all existing policies
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "File owner access" ON files;
  DROP POLICY IF EXISTS "Entry files access" ON entry_files;
  DROP POLICY IF EXISTS "Member view access" ON group_members;
  DROP POLICY IF EXISTS "Admin management" ON group_members;
END $$;

-- Create simple file ownership policy
CREATE POLICY "File owner access"
ON files
FOR ALL
TO authenticated
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- Create entry_files policy that only checks direct ownership
CREATE POLICY "Entry files access"
ON entry_files
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 
    FROM journal_entries
    WHERE id = entry_files.entry_id
    AND user_id = auth.uid()
  )
);

-- Create separate policies for different group_members operations
CREATE POLICY "View own membership"
ON group_members
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "View group members"
ON group_members
FOR SELECT
TO authenticated
USING (
  group_id IN (
    SELECT group_id 
    FROM group_members 
    WHERE user_id = auth.uid()
  )
);

CREATE POLICY "Admin manage members"
ON group_members
FOR INSERT
TO authenticated
WITH CHECK (
  group_id IN (
    SELECT group_id 
    FROM group_members 
    WHERE user_id = auth.uid() 
    AND role = 'admin'
  )
);

CREATE POLICY "Admin update members"
ON group_members
FOR UPDATE
TO authenticated
USING (
  group_id IN (
    SELECT group_id 
    FROM group_members 
    WHERE user_id = auth.uid() 
    AND role = 'admin'
  )
);

CREATE POLICY "Admin delete members"
ON group_members
FOR DELETE
TO authenticated
USING (
  group_id IN (
    SELECT group_id 
    FROM group_members 
    WHERE user_id = auth.uid() 
    AND role = 'admin'
  )
);

-- Ensure all necessary indexes exist
CREATE INDEX IF NOT EXISTS idx_files_created_by ON files(created_by);
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_id ON journal_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user_id ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_admin ON group_members(group_id, user_id) WHERE role = 'admin';