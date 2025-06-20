import { useParams, Link, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { ArrowLeft, Download, Share2, Heart, BookOpen, Play, Pause, Upload, Image as ImageIcon, FileText, X, Plus, Link as LinkIcon, Edit, AlertCircle, Save, Check } from 'lucide-react';
import Button from '../ui/Button';
import { sampleStories } from '../data/sampleData';
import { useState, useRef, useEffect } from 'react';
import { useDropzone } from 'react-dropzone';
import AudioPlayer from '../ui/AudioPlayer';
import { uploadStoryFile } from '../lib/supabase';
import { supabase } from '@/lib/supabase';
import { useSignedFiles } from '@/hooks/useSignedFiles';

interface UploadedFile {
  id: string;
  file: File;
  preview: string;
  isSaving?: boolean;
  isSaved?: boolean;
  error?: string;
}

interface StoredFile {
  id: string;
  name: string;
  url: string;
  type: string;
  created_at: string;
}

const StoryDetailPage = () => {
  // ... (previous state and other code remains the same)
  const [storedFiles, setStoredFiles] = useState<StoredFile[]>([]);
  const [isLoadingFiles, setIsLoadingFiles] = useState(false);
  const [fileError, setFileError] = useState<string | null>(null);

  useEffect(() => {
    const fetchStoryFiles = async () => {
      console.log('--- StoryDetailPage Component:fetchStoryFiles() ---')
      if (!storyId) return;

      setIsLoadingFiles(true);
      setFileError(null);

      try {
        // First get the file entries from the database
        const { data: fileEntries, error: dbError } = await supabase
          .from('entry_files')
          .select(`
              file_id,
              files:files ( id, name, object_path, type, created_at )
          `)
          .eq('journal_entry_id', storyId);

        if (dbError) throw dbError;

        // Extract file data and set state
        // const files = fileEntries
        //   .map(entry => entry.files)
        //   .filter(Boolean) as StoredFile[];

        const rawFiles = fileEntries
          .map(entry => ({
            id: entry.files.id,
            name: entry.files.name,
            object_path: entry.files.object_path,
            type: entry.files.type,
            created_at: entry.files.created_at
          }))
          .filter(Boolean);

        const { signedFiles: storedFiles, loading: isLoadingFiles } = useSignedFiles(rawFiles);
        setStoredFiles(signedFiles);
      } catch (err) {
        console.error('Error fetching files:', err);
        setFileError('Failed to load attached files');
      } finally {
        setIsLoadingFiles(false);
      }
    };

    fetchStoryFiles();
  }, [storyId]);

  // Update the files display section to show both uploaded and stored files
  const renderFiles = () => (
    <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
      {/* Show stored files */}
      {storedFiles.map((file) => (
        <div key={file.id} className="relative group">
          {file.type.startsWith('image/') ? (
            <img
              src={file.url}
              alt={file.name}
              className="w-full h-32 object-cover rounded-lg"
            />
          ) : (
            <div className="w-full h-32 bg-neutral-100 rounded-lg flex items-center justify-center">
              <FileText size={32} className="text-neutral-400" />
            </div>
          )}
          <div className="absolute inset-0 bg-black/50 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
            <a
              href={file.url}
              download
              className="text-white hover:text-neutral-200"
              onClick={(e) => {
                e.preventDefault();
                window.open(file.url, '_blank');
              }}
            >
              <Download size={20} />
            </a>
          </div>
        </div>
      ))}

      {/* Show newly uploaded files */}
      {uploadedFiles.map((file) => (
        <div key={file.id} className="relative group">
          {file.file.type.startsWith('image/') ? (
            <img
              src={file.preview}
              alt={file.file.name}
              className="w-full h-32 object-cover rounded-lg"
            />
          ) : (
            <div className="w-full h-32 bg-neutral-100 rounded-lg flex items-center justify-center">
              <FileText size={32} className="text-neutral-400" />
            </div>
          )}
          <div className="absolute inset-0 bg-black/50 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-2">
            {!file.isSaved && (
              <Button
                variant="ghost"
                size="sm"
                className="text-white hover:text-primary-500"
                onClick={() => handleSaveFile(file.id)}
                disabled={file.isSaving}
              >
                {file.isSaving ? (
                  <div className="animate-spin rounded-full h-4 w-4 border-2 border-white border-t-transparent" />
                ) : (
                  <Save size={16} />
                )}
                Save
              </Button>
            )}
            <Button
              variant="ghost"
              size="sm"
              className="text-white hover:text-error-500"
              onClick={() => handleRemoveFile(file.id)}
            >
              <X size={16} />
              Remove
            </Button>
          </div>
          {file.error && (
            <div className="absolute bottom-0 left-0 right-0 bg-error-500 text-white text-xs p-1 text-center">
              {file.error}
            </div>
          )}
          {file.isSaved && (
            <div className="absolute top-2 right-2 bg-success-500 text-white rounded-full p-1">
              <Check size={12} />
            </div>
          )}
        </div>
      ))}
    </div>
  );

  // ... (rest of the component remains the same)

  return (
    // ... (previous JSX)
    <div className="mb-8">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <ImageIcon size={20} className="text-primary-500" />
          <h2 className="text-xl font-semibold">Photos & Documents</h2>
        </div>
        <Button variant="ghost" size="sm" onClick={open}>
          <Upload size={16} />
          Add Files
        </Button>
      </div>

      {fileError && (
        <div className="mb-4 p-3 bg-error-50 text-error-600 rounded-lg flex items-center gap-2">
          <AlertCircle size={16} />
          <span>{fileError}</span>
        </div>
      )}

      <div {...getRootProps()} className="border-2 border-dashed border-neutral-200 rounded-lg p-4 text-center hover:border-primary-500 transition-colors cursor-pointer mb-4">
        <input {...getInputProps()} />
        <Upload className="mx-auto mb-2 text-neutral-400" size={24} />
        <p className="text-sm text-neutral-600">Drop files here or click Add Files above</p>
        <p className="text-xs text-neutral-400 mt-1">Supports images and PDFs</p>
      </div>

      {isLoadingFiles ? (
        <div className="flex items-center justify-center py-8">
          <div className="animate-spin rounded-full h-8 w-8 border-2 border-primary-500 border-t-transparent" />
        </div>
      ) : (
        renderFiles()
      )}
    </div>
    // ... (rest of JSX)
  );
};

export default StoryDetailPage;