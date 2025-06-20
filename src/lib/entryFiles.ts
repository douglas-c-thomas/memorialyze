// src/lib/entryFiles.ts
import { supabase } from '../lib/supabase';
import { PostgrestError } from '@supabase/supabase-js';

interface FileEntry {
    file_id: string;
    files: {
        id: string;
        name: string;
        object_path: string;
        type: string;
        created_at: string;
    };
}

export async function getFilesForEntry(journalEntryId: string): Promise<FileEntry[]> {
    console.log('🔍 getFilesForEntry called with journalEntryId:', journalEntryId);
    const { data, error } = await supabase
        .from('entry_files')
        .select(`
            file_id,
            files:files ( id, name, object_path, type, created_at )
        `)
        .eq('journal_entry_id', journalEntryId);

    console.log('🧾 Supabase raw response:', JSON.stringify(data, null, 2));
    console.log('➡️ total entries to sign:', (data || []).length);

    if (error) {
        throw new Error(`Error fetching files: ${error.message}`);
    }

    const files = await Promise.all(
        (data || []).map(async (entry: any): Promise<FileEntry> => {
            const path = entry.files.object_path;

            const { data: signedData, error: signedError } = await supabase.storage
                .from('story-files')
                .createSignedUrl(path, 3600 * 24 * 365 * 10);

            console.log('Generating signed URL for:', path);
            console.log('Signed URL result:', signedData?.signedUrl);

            if (signedError) {
                throw new Error(`Signed URL error: ${signedError.message}`);
            }

            return {
                file_id: entry.file_id,
                files: {
                    id: String(entry.files.id),
                    name: String(entry.files.name),
                    url: signedData.signedUrl,
                    type: String(entry.files.type),
                    created_at: String(entry.files.created_at),
                },
            };
        })
    );

    return files;
}
