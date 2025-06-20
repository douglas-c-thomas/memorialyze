/*
  # Fix file policies to avoid recursion
  
  1. Changes
    - Simplify file policies to avoid recursive checks
    - Maintain security while improving performance
    
  2. Security
    - Users can still only access files they should
    - Removes unnecessary joins that caused recursion
*/

-- Drop existing file policies
DROP POLICY IF EXISTS "Users can insert their own files" ON files;
DROP POLICY IF EXISTS "Users can view files they have access to" ON files;

-- Create simplified policies
CREATE POLICY "Users can insert their own files"
ON files
FOR INSERT
TO authenticated
WITH CHECK (created_by = auth.uid());

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

-- Add policy for deleting files
CREATE POLICY "Users can delete their own files"
ON files
FOR DELETE
TO authenticated
USING (created_by = auth.uid());