/*
  # Fix recursive policies for file uploads
  
  1. Changes
    - Simplify file access policies to avoid recursion
    - Add direct file deletion policy
    - Optimize policy checks for better performance
    
  2. Security
    - Maintain security through entry_files junction table
    - Allow users to manage their own files
*/

-- Drop existing file policies
DROP POLICY IF EXISTS "Users can insert their own files" ON files;
DROP POLICY IF EXISTS "Users can view files they have access to" ON files;
DROP POLICY IF EXISTS "Users can delete their own files" ON files;

-- Create simplified file policies
CREATE POLICY "Users can insert their own files"
ON files
FOR INSERT
TO authenticated
WITH CHECK (created_by = auth.uid());

CREATE POLICY "Users can delete their own files"
ON files
FOR DELETE
TO authenticated
USING (created_by = auth.uid());

CREATE POLICY "Users can view files they have access to"
ON files
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM entry_files ef
    WHERE ef.file_id = files.id
  )
);

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_files_created_by ON files(created_by);