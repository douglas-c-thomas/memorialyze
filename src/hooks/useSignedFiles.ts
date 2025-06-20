import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';

export interface StoredFile {
  id: string;
  name: string;
  url: string; // signed
  type: string;
  created_at: string;
}

interface RawFileEntry {
  id: string;
  name: string;
  object_path: string;
  type: string;
  created_at: string;
}

export function useSignedFiles(rawFiles: RawFileEntry[]) {
  const [signedFiles, setSignedFiles] = useState<StoredFile[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const signFiles = async () => {
      if (!rawFiles?.length) return;

      setLoading(true);
      setError(null);

      const results = await Promise.all(
        rawFiles.map(async (file) => {
          const { data, error } = await supabase.storage
            .from('story-files')
            .createSignedUrl(file.object_path, 3600 * 24 * 365); // 1 year

          if (error || !data?.signedUrl) {
            console.warn('Failed to sign', file.object_path);
            return null;
          }

          return {
            id: file.id,
            name: file.name,
            url: data.signedUrl,
            type: file.type,
            created_at: file.created_at,
          } satisfies StoredFile;
        })
      );

      setSignedFiles(results.filter(Boolean) as StoredFile[]);
      setLoading(false);
    };

    signFiles();
  }, [rawFiles]);

  return { signedFiles, loading, error };
}