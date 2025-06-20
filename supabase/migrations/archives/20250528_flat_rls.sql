-- =========================================
-- 1. Schema Changes: FK from entry_files to journal_entries
-- =========================================

ALTER TABLE entry_files
ADD COLUMN journal_entry_id UUID;

ALTER TABLE entry_files
ADD CONSTRAINT fk_entry_files_journal_entry
FOREIGN KEY (journal_entry_id)
REFERENCES journal_entries(id)
ON DELETE CASCADE;

-- =========================================
-- 2. Materialized View: Precomputed user access
-- =========================================

DROP MATERIALIZED VIEW IF EXISTS user_entry_access;

CREATE MATERIALIZED VIEW user_entry_access AS
SELECT
  gm.user_id,
  je.id AS journal_entry_id
FROM group_members gm
JOIN journal_entries je ON gm.group_id = je.group_id;

-- You can also create an index for better performance
CREATE INDEX idx_user_entry_access_user_entry
  ON user_entry_access(user_id, journal_entry_id);

-- =========================================
-- 3. Clean and Safe RLS Policies
-- =========================================

-- GROUP MEMBERS
DROP POLICY IF EXISTS "View membership" ON group_members;
DROP POLICY IF EXISTS "Insert membership" ON group_members;
DROP POLICY IF EXISTS "Update membership" ON group_members;
DROP POLICY IF EXISTS "Delete membership" ON group_members;

CREATE POLICY "View own memberships" ON group_members
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Insert own membership" ON group_members
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Update own membership" ON group_members
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Delete own membership" ON group_members
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- JOURNAL ENTRIES
DROP POLICY IF EXISTS "Contributors and admins can create entries" ON journal_entries;
DROP POLICY IF EXISTS "Contributors and admins can update own entries" ON journal_entries;
DROP POLICY IF EXISTS "Group members can view entries" ON journal_entries;

CREATE POLICY "User can insert journal entries" ON journal_entries
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "User can update their journal entries" ON journal_entries
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "User can view their journal entries" ON journal_entries
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- ENTRY FILES
DROP POLICY IF EXISTS "Entry files access" ON entry_files;

CREATE POLICY "Allow insert of entry files" ON entry_files
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM journal_entries
      WHERE journal_entries.id = entry_files.journal_entry_id
        AND journal_entries.user_id = auth.uid()
    )
  );

CREATE POLICY "Allow read of entry files via view" ON entry_files
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_entry_access
      WHERE user_entry_access.user_id = auth.uid()
        AND user_entry_access.journal_entry_id = entry_files.journal_entry_id
    )
  );

-- =========================================
-- 4. (Optional) Auto-refresh materialized view on demand
-- =========================================
-- You can refresh it manually or trigger via Supabase Function

-- REFRESH MATERIALIZED VIEW user_entry_access;
