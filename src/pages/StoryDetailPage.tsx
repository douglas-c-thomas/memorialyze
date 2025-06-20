import { useParams, Link, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { ArrowLeft, Download, Share2, Heart, BookOpen, Play, Pause, Upload, Image as ImageIcon, FileText, X, Plus, Link as LinkIcon, Edit, AlertCircle, Save, Check } from 'lucide-react';
import Button from '../components/ui/Button';
import { sampleStories } from '../data/sampleData';
import { useState, useRef, useEffect } from 'react';
import { useDropzone } from 'react-dropzone';
import AudioPlayer from '../components/ui/AudioPlayer';
import { uploadStoryFile } from '../lib/supabase';
import { getFilesForEntry } from '../lib/entryFiles';

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

interface UploadedFile {
  id: string;
  file: File;
  preview: string;
  isSaving?: boolean;
  isSaved?: boolean;
  error?: string;
}

const StoryDetailPage = () => {
  const { storyId } = useParams<{ storyId: string }>();
  const navigate = useNavigate();
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [isLiked, setIsLiked] = useState(false);
  const [showShareModal, setShowShareModal] = useState(false);
  const [showLinkModal, setShowLinkModal] = useState(false);
  const [selectedStoryForLink, setSelectedStoryForLink] = useState<string | null>(null);
  const [linkType, setLinkType] = useState<'continuation' | 'related' | 'response'>('related');

  // TODO: consider extracting this logic into a custom hook like `useEntryFiles(journalEntryId)` for reuse
  const [files, setFiles] = useState<FileEntry[]>([]);

  const [uploadedFiles, setUploadedFiles] = useState<UploadedFile[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [linkedStories, setLinkedStories] = useState<any[]>([]);
  const audioRef = useRef<HTMLAudioElement>(null);


  const { getRootProps, getInputProps, open } = useDropzone({
    accept: {
      'image/*': ['.png', '.jpg', '.jpeg', '.gif'],
      'application/pdf': ['.pdf']
    },
    noClick: true,
    onDrop: async (acceptedFiles) => {
      try {
        setIsLoading(true);
        setError(null);
        
        const newFiles = acceptedFiles.map(file => ({
          id: crypto.randomUUID(),
          file,
          preview: URL.createObjectURL(file)
        }));
        
        // Simulate file upload
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        setUploadedFiles(prev => [...prev, ...newFiles]);
      } catch (err) {
        setError('Failed to upload files');
      } finally {
        setIsLoading(false);
      }
    }
  });

  const handleSaveFile = async (fileId: string) => {
    try {
      setUploadedFiles(prev => prev.map(f => 
        f.id === fileId ? { ...f, isSaving: true, error: undefined } : f
      ));

      const fileToSave = uploadedFiles.find(f => f.id === fileId);
      if (!fileToSave) return;

      const url = await uploadStoryFile(fileToSave.file, storyId!);
      
      console.log('File upload to URL:', {
        url: url
      });

      // Update file status
      setUploadedFiles(prev => prev.map(f => 
        f.id === fileId ? { ...f, isSaving: false, isSaved: true } : f
      ));

      // Here you would typically update the story's documents array
      // For now, we'll just show a success message
      console.log('File saved:', url);
    } catch (err) {
      console.error('Error saving file:', err);
      setUploadedFiles(prev => prev.map(f => 
        f.id === fileId ? { ...f, isSaving: false, error: 'Failed to save file' } : f
      ));
    }
  };

  // Find the story from sample data
  const story = sampleStories.find(s => s.id === storyId);

  useEffect(() => {
    if (story) {
      // Convert duration string to seconds
      const [minutes, seconds] = story.duration.split(':').map(Number);
      setDuration(minutes * 60 + seconds);
    }
  }, [story]);

  // Cleanup previews when component unmounts
  useEffect(() => {
    return () => {
      uploadedFiles.forEach(file => {
        URL.revokeObjectURL(file.preview);
      });
    };
  }, [uploadedFiles]);

  useEffect(() => {
    async function fetchFiles() {
      console.log('📦 Running fetchFiles for storyId:', storyId);
      try {
        const results = await getFilesForEntry(storyId as string);
        setFiles(results);
      } catch (err: any) {
        setError(err.message);
      }
    }

    if (storyId != null) {
      fetchFiles();
    }
  }, [storyId]);

  useEffect(() => {
    // Simulate fetching linked stories
    const fetchLinkedStories = async () => {
      try {
        setIsLoading(true);
        setError(null);
        
        // Simulate API call
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        setLinkedStories([
          {
            id: '2',
            title: "Dad's World War II Stories",
            date: 'August 3, 2023',
            relationship: 'continuation'
          },
          {
            id: '3',
            title: 'The Family Thanksgiving Tradition',
            date: 'November 20, 2023',
            relationship: 'related'
          }
        ]);
      } catch (err) {
        setError('Failed to fetch linked stories');
      } finally {
        setIsLoading(false);
      }
    };
    
    fetchLinkedStories();
  }, []);



  if (!story) {
    return (
      <div className="container mx-auto px-4 py-12">
        <div className="max-w-md mx-auto text-center">
          <h1 className="text-3xl font-serif font-bold mb-4">Story Not Found</h1>
          <p className="mb-6">The story you're looking for doesn't exist or has been removed.</p>
          <Button as={Link} to="/stories" variant="primary">
            <ArrowLeft size={18} />
            Back to Stories
          </Button>
        </div>
      </div>
    );
  }
  
  const handleLinkStory = () => {
    setShowLinkModal(true);
  };

  const handleShare = () => {
    setShowShareModal(true);
  };

  const handleDownload = async () => {
    try {
      setIsLoading(true);
      setError(null);

      // Simulate API call delay
      await new Promise(resolve => setTimeout(resolve, 1000));

      // Create a text file with story content
      const content = `${story.title}\nBy ${story.narrator}\n\n${story.excerpt}`;
      const blob = new Blob([content], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      
      const a = document.createElement('a');
      a.href = url;
      a.download = `${story.title.toLowerCase().replace(/\s+/g, '-')}.txt`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (err) {
      setError('Failed to download story');
    } finally {
      setIsLoading(false);
    }
  };

  const handleRemoveFile = async (fileId: string) => {
    try {
      setIsLoading(true);
      setError(null);

      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 500));

      setUploadedFiles(prev => {
        const fileToRemove = prev.find(f => f.id === fileId);
        if (fileToRemove) {
          URL.revokeObjectURL(fileToRemove.preview);
        }
        return prev.filter(f => f.id !== fileId);
      });
    } catch (err) {
      setError('Failed to remove file');
    } finally {
      setIsLoading(false);
    }
  };

  const handleConfirmLink = async () => {
    try {
      setIsLoading(true);
      setError(null);

      if (!selectedStoryForLink) {
        throw new Error('Please select a story to link');
      }

      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1000));

      const linkedStory = sampleStories.find(s => s.id === selectedStoryForLink);
      if (linkedStory) {
        setLinkedStories(prev => [...prev, {
          id: linkedStory.id,
          title: linkedStory.title,
          date: linkedStory.date,
          relationship: linkType
        }]);
      }

      setShowLinkModal(false);
      setSelectedStoryForLink(null);
      setLinkType('related');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to link story');
    } finally {
      setIsLoading(false);
    }
  };
  
  return (
    <div className="container mx-auto px-4 py-12">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="max-w-4xl mx-auto"
      >
        <div className="flex items-center justify-between mb-6">
          <Button as={Link} to="/stories" variant="ghost" className="text-neutral-600">
            <ArrowLeft size={18} />
            Back to Stories
          </Button>
          
          <div className="flex items-center gap-2">
            <Button 
              as={Link} 
              to={`/stories/${storyId}/review`}
              variant="ghost" 
              className="text-neutral-600"
            >
              <Edit size={18} />
              Edit Story
            </Button>
            <Button 
              variant="ghost" 
              className={`text-neutral-600 ${isLiked ? 'text-primary-500' : ''}`}
              onClick={() => setIsLiked(!isLiked)}
            >
              <Heart size={18} className={isLiked ? 'fill-current' : ''} />
              {isLiked ? 'Liked' : 'Like'}
            </Button>
            <Button variant="ghost" className="text-neutral-600" onClick={handleShare}>
              <Share2 size={18} />
              Share
            </Button>
            <Button 
              variant="ghost" 
              className="text-neutral-600" 
              onClick={handleDownload}
              disabled={isLoading}
            >
              <Download size={18} />
              Download
            </Button>
          </div>
        </div>

        {error && (
          <div className="mb-6 p-4 bg-error-50 text-error-700 rounded-lg flex items-center gap-2">
            <AlertCircle size={18} />
            <span>{error}</span>
          </div>
        )}
        
        <div className="relative rounded-2xl overflow-hidden mb-8">
          <img 
            src={story.coverImage} 
            alt={story.title} 
            className="w-full h-80 object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-transparent to-transparent"></div>
          <div className="absolute bottom-0 left-0 right-0 p-6 md:p-8">
            <span className={`inline-block px-3 py-1 rounded-full text-xs font-medium text-white ${
              story.category === 'childhood' ? 'bg-secondary-500' : 
              story.category === 'family' ? 'bg-primary-500' : 
              'bg-accent-500'
            }`}>
              {story.category}
            </span>
            <h1 className="text-3xl md:text-4xl font-serif font-bold text-white mt-2">{story.title}</h1>
          </div>
        </div>
        
        <div className="bg-white rounded-xl shadow-md p-6 md:p-8 mb-8">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
            <div>
              <div className="flex items-center gap-2 text-sm text-neutral-600 mb-1">
                <span>Narrated by:</span>
                <span className="font-medium">{story.narrator}</span>
              </div>
              <div className="flex items-center gap-2 text-sm text-neutral-600">
                <span>Recorded on:</span>
                <span className="font-medium">{story.date}</span>
              </div>
            </div>
          </div>
          
          {story.mediaType === 'audio' && story.audioUrl && (
            <div className="mb-8">
              <AudioPlayer
                src={story.audioUrl}
                onTimeUpdate={(time) => setCurrentTime(time)}
                onEnded={() => setIsPlaying(false)}
              />
            </div>
          )}
          
          <div className="mb-8">
            <div className="flex items-center gap-2 mb-4">
              <BookOpen size={20} className="text-primary-500" />
              <h2 className="text-xl font-semibold">Transcript</h2>
            </div>
            
            <div className="prose max-w-none">
              <p className="mb-4">
                {story.excerpt}
              </p>
              <p className="mb-4">
                I remember it was the summer of '85, and my grandparents had this beautiful farm house out in the countryside. Every weekend, we'd pile into dad's old station wagon and make the two-hour drive. The moment we'd arrive, the smell of grandma's apple pie would greet us before we even got out of the car.
              </p>
              <p className="mb-4">
                The house had this huge wrap-around porch where we'd sit in the evenings watching fireflies light up the fields. My brother and I would spend hours exploring the barn, climbing hay bales, and running through the cornfields playing hide and seek.
              </p>
              <p>
                Grandpa had these old stories he'd tell us about growing up during the Depression. He'd sit us down after dinner, his voice deep and gravelly from years of working outdoors, and transport us to a different time. I wish I had recorded those stories somehow. They felt so vivid then, but the details are fading now. That's why I wanted to record this memory - so my children and grandchildren can have these stories preserved in a way I never did.
              </p>
            </div>
          </div>

          <div className="mb-8">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <LinkIcon size={20} className="text-primary-500" />
                <h2 className="text-xl font-semibold">Related Stories</h2>
              </div>
              <Button variant="ghost" size="sm" onClick={handleLinkStory}>
                <Plus size={16} />
                Link Story
              </Button>
            </div>

            {linkedStories.length > 0 ? (
              <div className="space-y-3">
                {linkedStories.map((linkedStory) => (
                  <Link
                    key={linkedStory.id}
                    to={`/stories/${linkedStory.id}`}
                    className="block p-4 bg-neutral-50 rounded-lg hover:bg-neutral-100 transition-colors"
                  >
                    <div className="flex items-center justify-between">
                      <div>
                        <h3 className="font-medium mb-1">{linkedStory.title}</h3>
                        <p className="text-sm text-neutral-500">{linkedStory.date}</p>
                      </div>
                      <span className="text-xs px-2 py-1 bg-primary-100 text-primary-700 rounded-full">
                        {linkedStory.relationship === 'continuation' ? 'Continues Story' :
                         linkedStory.relationship === 'response' ? 'Response' : 'Related Memory'}
                      </span>
                    </div>
                  </Link>
                ))}
              </div>
            ) : (
              <div className="text-center py-8 bg-neutral-50 rounded-lg">
                <LinkIcon size={24} className="mx-auto mb-2 text-neutral-400" />
                <p className="text-neutral-600 mb-2">No related stories yet</p>
                <Button variant="primary" size="sm" onClick={handleLinkStory}>
                  <Plus size={16} />
                  Link a Story
                </Button>
              </div>
            )}
          </div>
          
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
            
            <div {...getRootProps()} className="border-2 border-dashed border-neutral-200 rounded-lg p-4 text-center hover:border-primary-500 transition-colors cursor-pointer mb-4">
              <input {...getInputProps()} />
              <Upload className="mx-auto mb-2 text-neutral-400" size={24} />
              <p className="text-sm text-neutral-600">Drop files here or click Add Files above</p>
              <p className="text-xs text-neutral-400 mt-1">Supports images and PDFs</p>
            </div>

            <div className="mt-4">
              <h2 className="text-lg font-semibold mb-2">Uploaded Files</h2>
              {error && <p className="text-red-500">{error}</p>}
              {files.length === 0 ? (
                <p className="text-sm text-gray-500">No files uploaded yet.</p>
              ) : (
                <ul className="list-disc list-inside text-sm text-gray-700">
                  {files.map((fileEntry) => (
                    <li key={fileEntry.file_id}>{fileEntry.files.name}</li>
                  ))}
                </ul>
              )}
            </div>            
            
            <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
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

              {story.documents?.map((doc, index) => (
                <div key={index} className="relative group">
                  {doc.type === 'image' ? (
                    <img
                      src={doc.url}
                      alt={doc.name}
                      className="w-full h-32 object-cover rounded-lg"
                    />
                  ) : (
                    <div className="w-full h-32 bg-neutral-100 rounded-lg flex items-center justify-center">
                      <FileText size={32} className="text-neutral-400" />
                    </div>
                  )}
                  <div className="absolute inset-0 bg-black/50 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                    <button className="text-white hover:text-neutral-200">
                      <Download size={20} />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
          
          <div className="bg-white rounded-xl shadow-md p-6 md:p-8">
            <div className="flex items-center gap-2 mb-4">
              <svg className="w-5 h-5 text-primary-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <circle cx="12" cy="12" r="10"></circle>
                <path d="M12 16v-4"></path>
                <path d="M12 8h.01"></path>
              </svg>
              <h2 className="text-xl font-semibold">Story Details</h2>
            </div>
            
            <div className="grid md:grid-cols-2 gap-6">
              <div>
                <h3 className="text-sm uppercase font-medium text-neutral-500 mb-2">People Mentioned</h3>
                <div className="flex flex-wrap gap-2">
                  {story.tags.map((tag, index) => (
                    <span 
                      key={index}
                      className="px-3 py-1 bg-neutral-100 rounded-full text-sm text-neutral-700"
                    >
                      {tag}
                    </span>
                  ))}
                </div>
              </div>
              
              <div>
                <h3 className="text-sm uppercase font-medium text-neutral-500 mb-2">Emotions</h3>
                <div className="flex flex-wrap gap-2">
                  <span className="px-3 py-1 bg-primary-50 text-primary-700 rounded-full text-sm">Nostalgic</span>
                  <span className="px-3 py-1 bg-secondary-50 text-secondary-700 rounded-full text-sm">Joyful</span>
                  <span className="px-3 py-1 bg-accent-50 text-accent-700 rounded-full text-sm">Reflective</span>
                </div>
              </div>
              
              <div>
                <h3 className="text-sm uppercase font-medium text-neutral-500 mb-2">Time Period</h3>
                <span className="text-neutral-800">1980s</span>
              </div>
              
              <div>
                <h3 className="text-sm uppercase font-medium text-neutral-500 mb-2">Location</h3>
                <span className="text-neutral-800">Countryside, Midwestern United States</span>
              </div>
            </div>
          </div>
        </div>
      </motion.div>

      {showShareModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-6 max-w-lg w-full mx-4">
            <h2 className="text-xl font-semibold mb-4">Share Story</h2>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">
                  Story Link
                </label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    value={`${window.location.origin}/stories/${storyId}`}
                    readOnly
                    className="flex-1 p-2 border border-neutral-200 rounded-lg bg-neutral-50"
                  />
                  <Button
                    variant="primary"
                    onClick={() => {
                      navigator.clipboard.writeText(
                        `${window.location.origin}/stories/${storyId}`
                      );
                    }}
                  >
                    Copy
                  </Button>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-1">
                  Share via
                </label>
                <div className="flex gap-2">
                  <Button variant="ghost" className="flex-1">
                    Email
                  </Button>
                  <Button variant="ghost" className="flex-1">
                    Messages
                  </Button>
                  <Button variant="ghost" className="flex-1">
                    WhatsApp
                  </Button>
                </div>
              </div>
            </div>

            <div className="flex justify-end mt-6">
              <Button variant="ghost" onClick={() => setShowShareModal(false)}>
                Close
              </Button>
            </div>
          </div>
        </div>
      )}

      {showLinkModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-6 max-w-lg w-full mx-4">
            <h2 className="text-xl font-semibold mb-4">Link Related Story</h2>
            
            <div className="mb-4">
              <label className="block text-sm font-medium text-neutral-700 mb-1">
                Relationship Type
              </label>
              <select
                value={linkType}
                onChange={(e) => setLinkType(e.target.value as typeof linkType)}
                className="w-full p-2 border border-neutral-200 rounded-lg"
              >
                <option value="continuation">Continues This Story</option>
                <option value="related">Related Memory</option>
                <option value="response">Response to This Story</option>
              </select>
            </div>

            <div className="mb-6">
              <label className="block text-sm font-medium text-neutral-700 mb-1">
                Select Story
              </label>
              <div className="space-y-2">
                {sampleStories
                  .filter(s => s.id !== storyId)
                  .map(story => (
                    <button
                      key={story.id}
                      onClick={() => setSelectedStoryForLink(story.id)}
                      className={`w-full p-3 text-left rounded-lg transition-colors ${
                        selectedStoryForLink === story.id
                          ? 'bg-primary-50 border border-primary-200'
                          : 'bg-neutral-50 hover:bg-neutral-100'
                      }`}
                    >
                      <h3 className="font-medium">{story.title}</h3>
                      <p className="text-sm text-neutral-500">{story.date}</p>
                    </button>
                  ))
                }
              </div>
            </div>

            <div className="flex justify-end gap-2">
              <Button 
                variant="ghost" 
                onClick={() => setShowLinkModal(false)}
                disabled={isLoading}
              >
                Cancel
              </Button>
              <Button 
                variant="primary"
                onClick={handleConfirmLink}
                disabled={!selectedStoryForLink || isLoading}
              >
                {isLoading ? 'Linking...' : 'Link Story'}
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default StoryDetailPage;