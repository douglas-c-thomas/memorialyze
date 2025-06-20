/*
  # Add time period support to journal entries
  
  1. Changes
    - Add time_period_start and time_period_end columns to journal_entries table
    - Ensure policies are created only if they don't exist
  
  2. Security
    - Maintains existing RLS policies
    - Checks for policy existence before creation
*/

-- Add time period columns if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'journal_entries' 
    AND column_name = 'time_period_start'
  ) THEN
    ALTER TABLE journal_entries 
    ADD COLUMN time_period_start INTEGER NOT NULL DEFAULT 2000,
    ADD COLUMN time_period_end INTEGER;
  END IF;
END $$;

-- Drop existing policies if they exist
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'journal_entries' 
    AND policyname = 'Contributors and admins can create entries'
  ) THEN
    DROP POLICY "Contributors and admins can create entries" ON journal_entries;
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'journal_entries' 
    AND policyname = 'Contributors and admins can update own entries'
  ) THEN
    DROP POLICY "Contributors and admins can update own entries" ON journal_entries;
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'journal_entries' 
    AND policyname = 'Group members can view entries'
  ) THEN
    DROP POLICY "Group members can view entries" ON journal_entries;
  END IF;
END $$;

-- Create policies
CREATE POLICY "Contributors and admins can create entries"
  ON journal_entries FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM group_members
      WHERE group_members.group_id = journal_entries.group_id
      AND group_members.user_id = auth.uid()
      AND group_members.role IN ('contributor', 'admin')
    )
  );

CREATE POLICY "Contributors and admins can update own entries"
  ON journal_entries FOR UPDATE TO authenticated
  USING (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM group_members
      WHERE group_members.group_id = journal_entries.group_id
      AND group_members.user_id = auth.uid()
      AND group_members.role IN ('contributor', 'admin')
    )
  );

CREATE POLICY "Group members can view entries"
  ON journal_entries FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM group_members
      WHERE group_members.group_id = journal_entries.group_id
      AND group_members.user_id = auth.uid()
    )
  );

-- Ensure the updated_at trigger exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'update_journal_entries_updated_at'
  ) THEN
    CREATE TRIGGER update_journal_entries_updated_at
      BEFORE UPDATE ON journal_entries
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
  END IF;
END $$;