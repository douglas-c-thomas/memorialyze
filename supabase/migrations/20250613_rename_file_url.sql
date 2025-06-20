-- =========================================
-- 1. Rename 'url' column to 'object_path' in 'files' table
-- =========================================

ALTER TABLE files
RENAME COLUMN url TO object_path;

-- =========================================
-- 2. Optional: Grant Select on new column if needed
-- =========================================
-- GRANT SELECT (object_path) ON files TO authenticated;

-- =========================================
-- 3. Rollback Instructions (manually apply if needed)
-- =========================================
-- To revert:
-- ALTER TABLE files RENAME COLUMN object_path TO url;
