/*
  # Add storage bucket for story files
  
  1. Changes
    - Create storage bucket for story files
    - Set up RLS policies for file access
    - Ensure proper file organization by story ID
  
  2. Security
    - Only authenticated users can upload files
    - Users can only view files from stories they have access to
    - Files must be organized in the stories/ directory
*/

-- Create storage bucket if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM storage.buckets
        WHERE id = 'story-files'
    ) THEN
        INSERT INTO storage.buckets (id, name, public)
        VALUES ('story-files', 'story-files', false);
    END IF;
END $$;

-- Set up RLS policies for the bucket
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Authenticated users can upload story files" ON storage.objects;
    DROP POLICY IF EXISTS "Users can view story files they have access to" ON storage.objects;
END $$;

CREATE POLICY "Authenticated users can upload story files"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'story-files' AND
    (REGEXP_SPLIT_TO_ARRAY(name, '/'))[1] = 'stories'
);

CREATE POLICY "Users can view story files they have access to"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'story-files' AND
    EXISTS (
        SELECT 1 
        FROM journal_entries je
        JOIN group_members gm ON gm.group_id = je.group_id
        WHERE (REGEXP_SPLIT_TO_ARRAY(name, '/'))[2] = je.id::text
        AND gm.user_id = auth.uid()
    )
);