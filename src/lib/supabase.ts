import { createClient } from '@supabase/supabase-js';
import { v4 as uuidv4 } from 'uuid';
import { FileUpload } from '../types/Story';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export async function saveMemory(data: {
  groupId: string;
  title: string;
  content: string;
  files: FileUpload[];
  emotions: string[];
  people: string[];
  timePeriod?: { start: number; end?: number };
}) {
  const { groupId, title, content, files, emotions, people, timePeriod } = data;

  try {
    // Get current user
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError) throw userError;
    if (!user) throw new Error('No authenticated user');

    // Insert journal entry
    const { data: entry, error: entryError } = await supabase
      .from('journal_entries')
      .insert({
        group_id: groupId,
        user_id: user.id,
        title,
        content,
        memory_type: 'memory',
        time_period_start: timePeriod?.start || new Date().getFullYear(),
        time_period_end: timePeriod?.end
      })
      .select()
      .single();

    if (entryError) throw entryError;

    // Upload files
    const filePromises = files.map(async ({ file }) => {
      const fileExt = file.name.split('.').pop();
      const fileName = `${uuidv4()}.${fileExt}`;
      const filePath = `memories/${entry.id}/${fileName}`;

      console.log('Uploading file:', {
        fileName,
        filePath,
        userId: user.id,
        entryId: entry.id
      });

      const { error: uploadError } = await supabase.storage
        .from('memory-files')
        .upload(filePath, file);

      if (uploadError) throw uploadError;

      const { data: { publicUrl } } = supabase.storage
        .from('memory-files')
        .getPublicUrl(filePath);

      // Insert file metadata
      const { data: fileData, error: fileError } = await supabase
        .from('files')
        .insert({
          name: file.name,
          url: publicUrl,
          type: file.type,
          size: file.size,
          created_by: user.id
        })
        .select()
        .single();

      if (fileError) throw fileError;

      console.log('DUG:  Linking file to the entry in saveMemory():', {
        fileName,
        filePath,
        userId: user.id,
        file_id: fileData.id,
        entryId: entry.id
      });

      // Link file to entry
      const { error: linkError } = await supabase
        .from('entry_files')
        .insert({
          entry_id: entry.id,
          file_id: fileData.id,
          journal_entry_id: entry.id
        });

      if (linkError) throw linkError;

      return fileData;
    });

    await Promise.all(filePromises);

    return entry;
  } catch (error) {
    console.error('Error saving memory:', error);
    throw error;
  }
}

export async function uploadStoryFile(file: File, storyId: string): Promise<string> {
  try {
    // Get current user
    console.log('Current user: ' + await supabase.auth.getUser());
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError) throw userError;
    if (!user) throw new Error('No authenticated user');

    console.log('Starting file upload:', {
      fileName: file.name,
      storyId,
      userId: user.id
    });

    const fileExt = file.name.split('.').pop();
    const fileName = `${uuidv4()}.${fileExt}`;
    const filePath = `stories/${storyId}/${fileName}`;

    // Upload to storage bucket
    const { error: uploadError } = await supabase.storage
      .from('story-files')
      .upload(filePath, file);

    if (uploadError) throw uploadError;

    console.log('File uploaded successfully: filePath');

    // Insert file metadata
    const { data: fileData, error: fileError } = await supabase
      .from('files')
      .insert({
        name: file.name,
        url: filePath,
        type: file.type,
        size: file.size,
        created_by: user.id
      })
      .select()
      .single();

    if (fileError) throw fileError;

    console.log('File metadata inserted:', {
      fileId: fileData.id,
      fileName: fileData.name,
      url: fileData.url
    });

    console.log('DUG:  Linking file to the entry in uploadStoryFile():', {
      fileName,
      filePath,
      userId: user.id,
      file_id: fileData.id,
      entryId: storyId
    });

    // Create entry_files link
    const { error: linkError } = await supabase
      .from('entry_files')
      .insert({
        entry_id: storyId,
        file_id: fileData.id,
        journal_entry_id: storyId
      });

    if (linkError) throw linkError;

    console.log('File linked to story successfully');

    const { data, error } = await supabase.storage
      .from('story-files')
      .createSignedUrl(filePath, 3600 * 24 * 365 * 10);

    console.log('Signed URL:', {
      filePath: filePath,
      signedURL: data?.signedUrl
    });

    if (error || !data?.signedUrl) {
      throw error || new Error('No signed URL returned');
    }

    return data.signedUrl;

  } catch (error) {
    console.error('Error uploading file:', error);
    throw new Error('Failed to upload file');
  }
}

export async function deleteStoryFile(filePath: string): Promise<void> {
  try {
    const { error } = await supabase.storage
      .from('story-files')
      .remove([filePath]);

    if (error) {
      throw new Error('Failed to delete file');
    }
  } catch (error) {
    console.error('Error deleting file:', error);
    throw error;
  }
}