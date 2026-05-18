import React, { useState, useEffect, useRef } from 'react';
import axios from 'axios';
import { CheckCircle, Clock, Upload, FileText, Image, FileImage, Camera, X, Crop, Eye, LoaderCircle } from 'lucide-react';
import KaTeXRender from '../all/KatexRender';
import NavComponent from './NavComponent';

// KaTeX type declaration
declare global {
  interface Window {
    katex: {
      renderToString: (tex: string, options?: { displayMode?: boolean }) => string;
    };
    Cropper: any;
  }
}

// Types
interface Question {
  question: string;
  diagram: string | null;
  options: string[];
}

interface ExtractedResponse {
  success: boolean;
  message: string;
  data: {
    file_type?: string;
    pdf_id?: string;
    total_questions: number;
    questions: Question[];
    processing_time: string;
    original_filename?: string;
  };
}

interface Props {
  chapters: { classNo9Chaps: string[]; classNo10Chaps: string[];  classNo11Chaps: string[]; classNo12Chaps: string[]; }
}

const Scan: React.FC<Props> = (props) => {

  const chapters = props.chapters

  // State management
  const [file, setFile] = useState<File | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [extractedQuestions, setExtractedQuestions] = useState<Question[]>([]);
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0);
  const [isSaving, setIsSaving] = useState(false);
  const [savedCount, setSavedCount] = useState(0);
  const [savedQuestions, setSavedQuestions] = useState<Set<number>>(new Set());

  // Current question editing state
  const [editedQuestion, setEditedQuestion] = useState('');
  const [editedOptions, setEditedOptions] = useState<string[]>(['', '', '', '']);
  const [selectedClass, setSelectedClass] = useState('11');
  const [selectedChapter, setSelectedChapter] = useState('');
  const [selectedLanguage, setSelectedLanguage] = useState('Bengali');
  const [correctAnswer, setCorrectAnswer] = useState('');
  const [diagram, setDiagram] = useState<File | null>(null)
  const [diagramImage, setDiagramImage] = useState("")
  const [originalDiagramFile, setOriginalDiagramFile] = useState<File | null>(null);

  // Image upload, crop, and preview states
  const [showImageModal, setShowImageModal] = useState(false);
  const [showCropModal, setShowCropModal] = useState(false);
  const [showPreviewModal, setShowPreviewModal] = useState(false);
  const [cropImage, setCropImage] = useState<string>('');
  const [previewImage, setPreviewImage] = useState<string>('');
  const [currentImageDataUrl, setCurrentImageDataUrl] = useState<string>('');
  const [cropper, setCropper] = useState<any>(null);
  const cropImageRef = useRef<HTMLImageElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [showCamera, setShowCamera] = useState(false);

  // Load Cropper.js
  useEffect(() => {
    const loadCropper = async () => {
      if (!document.querySelector('link[href*="cropper"]')) {
        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = 'https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.5.13/cropper.min.css';
        document.head.appendChild(link);
      }

      if (!window.Cropper) {
        const script = document.createElement('script');
        script.src = 'https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.5.13/cropper.min.js';
        document.head.appendChild(script);
      }
    };

    loadCropper();
  }, []);

  // Initialize edited question when current question changes
  useEffect(() => {
    if (extractedQuestions.length > 0 && currentQuestionIndex < extractedQuestions.length) {
      const current = extractedQuestions[currentQuestionIndex];
      setEditedQuestion(current.question);
      setEditedOptions(
        Array.isArray(current.options) && current.options.length === 4
          ? current.options
          : ['', '', '', '']
      );
      setCorrectAnswer('');
    }
  }, [currentQuestionIndex, extractedQuestions]);

  // Set default chapter when chapters change
  useEffect(() => {
    if (Array.isArray(chapters) && chapters.length > 0) {
      setSelectedChapter(chapters[0]);
    } else if (typeof chapters === 'object' && chapters !== null) {
      const allChapters = Object.values(chapters).flat();
      if (allChapters.length > 0) {
        setSelectedChapter(String(allChapters[0]));
      }
    }
  }, [chapters, selectedChapter]);

  // File upload handler
  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const selectedFile = e.target.files[0];
      const fileType = selectedFile.type;
      
      const allowedTypes = [
        'application/pdf',
        'image/jpeg',
        'image/jpg', 
        'image/png',
        'image/gif',
        'image/webp'
      ];
      
      if (!allowedTypes.includes(fileType)) {
        alert("Please select a PDF or image file (JPEG, PNG, GIF, WebP)");
        return;
      }
      
      setFile(selectedFile);
    }
  };

  // Upload and process file
  const handleUpload = async () => {
    if (!file) {
      alert("Please select a file.");
      return;
    }

    const formData = new FormData();
    formData.append("pdf", file);
    
    setIsUploading(true);
    
    try {
      const response = await axios.post(`${import.meta.env.PUBLIC_BACKEND}/api/v1/scan`, formData, {
        headers: { "Content-Type": "multipart/form-data" },
      });

      const data: ExtractedResponse = response.data;
      
      if (data.success && data.data.questions.length > 0) {
        setExtractedQuestions(data.data.questions);
        setCurrentQuestionIndex(0);
        setSavedCount(0);
        setSavedQuestions(new Set());
        console.log(`Extracted ${data.data.total_questions} questions from ${data.data.file_type || 'PDF'}`);
      } else {
        alert("No questions found in the file or processing failed.");
      }
    } catch (err) {
      console.error("Upload error:", err);
      alert("Upload failed. Please try again.");
    } finally {
      setIsUploading(false);
    }
  };

  // Save current question with FormData
  const handleSaveQuestion = async () => {
    if (!editedQuestion.trim() || editedOptions.some(opt => !opt.trim()) || !correctAnswer) {
      alert("Please fill in all fields including the correct answer.");
      return;
    }

    setIsSaving(true);

    try {
      // Create FormData object
      const formData = new FormData();
      
      // Add text fields
      formData.append('question', editedQuestion.trim());
      formData.append('options', JSON.stringify(editedOptions.map(opt => opt.trim())));
      formData.append('correctAnswer', correctAnswer);
      formData.append('classNo', selectedClass);
      formData.append('chapter', selectedChapter);
      formData.append('language', selectedLanguage);

      // Handle diagram image
      if (diagramImage) {
        // Convert base64 data URL to Blob
        const base64Response = await fetch(diagramImage);
        const blob = await base64Response.blob();
        
        // Create a File object with proper name and type
        const imageFile = new File([blob], `diagram_${Date.now()}.png`, {
          type: 'image/png',
          lastModified: Date.now()
        });
        
        formData.append('diagram', imageFile);
      }

      console.log("Sending FormData with diagram:", diagramImage ? 'Yes' : 'No');
      
      // Log FormData contents for debugging
      for (let [key, value] of formData.entries()) {
        console.log(`${key}:`, value instanceof File ? `File: ${value.name} (${value.size} bytes)` : value);
      }

      // Send FormData request
      await axios.post(`${import.meta.env.PUBLIC_BACKEND}/api/v1/question/addQuestion`, formData, {
        headers: { 
          "Content-Type": "multipart/form-data",
        },
      });

      setSavedQuestions(prev => new Set([...prev, currentQuestionIndex]));
      setSavedCount(prev => prev + 1);
      
    } catch (err) {
      console.error("Save error:", err);
      alert("Failed to save question. Please try again.");
    } finally {
      setIsSaving(false);
    }
  };

  // Go to next question
  const handleNextQuestion = () => {
    if (currentQuestionIndex < extractedQuestions.length - 1) {
      setCurrentQuestionIndex(prev => prev + 1);
    } else {
      alert(`All ${extractedQuestions.length} questions have been processed! Saved: ${savedCount}`);
      setExtractedQuestions([]);
      setCurrentQuestionIndex(0);
      setSavedCount(0);
      setSavedQuestions(new Set());
      setFile(null);
    }
  };

  // Skip current question
  const handleSkipQuestion = () => {
    if (currentQuestionIndex < extractedQuestions.length - 1) {
      setCurrentQuestionIndex(prev => prev + 1);
    }
  };

  // Go to previous question
  const handlePreviousQuestion = () => {
    if (currentQuestionIndex > 0) {
      setCurrentQuestionIndex(prev => prev - 1);
    }
  };

  // Image upload functions
  const showImageOptions = () => {
    setShowImageModal(true);
  };

  const closeImageModal = () => {
    setShowImageModal(false);
    setShowCamera(false);
    if (videoRef.current?.srcObject) {
      const stream = videoRef.current.srcObject as MediaStream;
      stream.getTracks().forEach(track => track.stop());
    }
  };

  const handleImageFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const file = e.target.files[0];
      
      // Store original file
      setOriginalDiagramFile(file);
      
      const reader = new FileReader();
      reader.onload = (event) => {
        if (event.target?.result) {
          setCropImage(event.target.result as string);
          setShowImageModal(false);
          setShowCropModal(true);
        }
      };
      reader.readAsDataURL(file);
    }
  };

  const openCamera = async () => {
    setShowImageModal(false);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment' }
      });
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        setShowCamera(true);
      }
    } catch (err) {
      alert("Camera access denied or not available.");
      console.error('Camera error:', err);
    }
  };

  const captureFromCamera = () => {
    if (videoRef.current && canvasRef.current) {
      const canvas = canvasRef.current;
      const video = videoRef.current;
      const ctx = canvas.getContext('2d');
      
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      
      if (ctx) {
        ctx.drawImage(video, 0, 0);
        const dataUrl = canvas.toDataURL('image/png');
        setCropImage(dataUrl);
        
        // Stop camera
        const stream = video.srcObject as MediaStream;
        if (stream) {
          stream.getTracks().forEach(track => track.stop());
        }
        
        setShowCamera(false);
        setShowCropModal(true);
      }
    }
  };

  const setupCropper = () => {
    if (cropImageRef.current && window.Cropper) {
      if (cropper) {
        cropper.destroy();
      }
      
      const newCropper = new window.Cropper(cropImageRef.current, {
        aspectRatio: NaN,
        viewMode: 1,
        dragMode: 'move',
        autoCropArea: 0.8,
        responsive: true,
        background: false,
        guides: true,
        center: true,
        highlight: true
      });
      
      setCropper(newCropper);
    }
  };

  const performCrop = () => {
    if (cropper) {
      const croppedCanvas = cropper.getCroppedCanvas({
        maxWidth: 1200,
        maxHeight: 1200,
        imageSmoothingQuality: 'high'
      });
      
      const croppedDataUrl = croppedCanvas.toDataURL('image/png');
      setCurrentImageDataUrl(croppedDataUrl);
      setPreviewImage(croppedDataUrl);
      setDiagramImage(croppedDataUrl);
      
      setShowCropModal(false);
      setShowPreviewModal(true);
    }
  };

  const cancelCrop = () => {
    setShowCropModal(false);
    if (cropper) {
      cropper.destroy();
      setCropper(null);
    }
  };

  const resetImageUpload = () => {
    setShowPreviewModal(false);
    setPreviewImage('');
    setCurrentImageDataUrl('');
    setDiagramImage('');
    setOriginalDiagramFile(null);
    if (cropper) {
      cropper.destroy();
      setCropper(null);
    }
  };

  const hasQuestions = extractedQuestions.length > 0;
  const isCurrentQuestionSaved = savedQuestions.has(currentQuestionIndex);

  return (
    <div className="max-w-6xl mx-auto p-6 bg-cyan-100 min-h-screen pt-20">
      <NavComponent />
      <br />

      {/* Upload Section */}
      <div className="bg-cyan-100 rounded-xl shadow-lg border border-gray-200 p-8 mb-8">
        <div className="flex flex-col items-center space-y-6">
          <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center">
            <Upload className="w-8 h-8 text-blue-600" />
          </div>
          
          <div className="text-center">
            <h2 className="text-2xl font-bold text-gray-900 mb-2">Upload Files</h2>
            <p className="text-gray-600">Select a PDF or image file to extract questions</p>
          </div>

          <div className="flex flex-col sm:flex-row gap-4">
            <label className="cursor-pointer bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg font-medium transition-all duration-200 shadow-sm hover:shadow-md flex items-center space-x-2 focus-within:ring-2 focus-within:ring-blue-500 focus-within:ring-offset-2">
              <FileText className="w-5 h-5" />
              <span>Select PDF</span>
              <input
                type="file"
                accept="application/pdf"
                onChange={handleFileChange}
                className="hidden"
              />
            </label>
            <label className="cursor-pointer bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-lg font-medium transition-all duration-200 shadow-sm hover:shadow-md flex items-center space-x-2 focus-within:ring-2 focus-within:ring-green-500 focus-within:ring-offset-2">
              <Image className="w-5 h-5" />
              <span>Select Image</span>
              <input
                type="file"
                accept="image/*"
                onChange={handleFileChange}
                className="hidden"
              />
            </label>
          </div>
          
          {file && (
            <div className="text-center bg-gray-50 rounded-lg p-4 w-full max-w-md">
              <p className="text-gray-700 font-medium">
                Selected: {file.name}
              </p>
              <p className="text-sm text-gray-500 mb-4">
                Type: {file.type.startsWith('image/') ? 'Image' : 'PDF'}
              </p>
              <button
                onClick={handleUpload}
                disabled={isUploading}
                className={`w-full px-6 py-3 rounded-lg font-semibold transition-all duration-200 ${
                  isUploading 
                    ? 'bg-gray-400 cursor-not-allowed text-gray-600' 
                    : 'bg-green-600 hover:bg-green-700 text-white shadow-sm hover:shadow-md'
                }`}
              >
                {isUploading ? (
                  <div className="flex items-center justify-center space-x-2">
                    <LoaderCircle className="animate-spin rounded-full h-8 w-8" color="#2200ed"/>
                    <span>Processing...</span>
                  </div>
                ) : (
                  '🚀 Extract Questions'
                )}
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Question Editor */}
      {true && ( // hasQuestions = true
        <div className="bg-cyan-100 rounded-xl shadow-lg border border-gray-200 p-6 lg:p-8">
          {/* Status Badge */}
          <div className="mb-6">
            {isCurrentQuestionSaved ? (
              <div className="inline-flex items-center px-4 py-2 rounded-full text-sm font-medium bg-green-50 text-green-700 border border-green-200">
                <CheckCircle className="w-4 h-4 mr-2" />
                Question Saved
              </div>
            ) : (
              <div className="inline-flex items-center px-4 py-2 rounded-full text-sm font-medium bg-amber-50 text-amber-700 border border-amber-200">
                <Clock className="w-4 h-4 mr-2" />
                Unsaved Changes
              </div>
            )}
          </div>

          {/* Progress Section */}
          <div className="mb-8">
            <div className="flex justify-between items-center mb-3">
              <span className="text-sm font-semibold text-gray-700">
                Question {currentQuestionIndex + 1} of {extractedQuestions.length}
              </span>
              <div className="flex items-center space-x-4">
                <span className="text-sm text-green-600 font-medium flex items-center">
                  <CheckCircle className="w-4 h-4 mr-1" />
                  Saved: {savedCount}
                </span>
                <span className="text-xs text-gray-500">
                  {Math.round(((currentQuestionIndex + 1) / extractedQuestions.length) * 100)}% Complete
                </span>
              </div>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-3 overflow-hidden">
              <div
                className="bg-gradient-to-r from-blue-500 to-blue-600 h-3 rounded-full transition-all duration-300 ease-out"
                style={{ width: `${((currentQuestionIndex + 1) / extractedQuestions.length) * 100}%` }}
              />
            </div>
          </div>

          {/* Question Text Section */}
          <div className="mb-8">
            <label className="block text-sm font-semibold text-gray-700 mb-3">
              Question Text
              <span className="text-red-500 ml-1">*</span>
            </label>
            <textarea
              value={editedQuestion}
              onChange={(e) => setEditedQuestion(e.target.value)}
              className="w-full p-4 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none transition-all duration-200"
              rows={6}
              placeholder="Enter your question here..."
              disabled={isCurrentQuestionSaved}
            />
            
            {/* KaTeX Preview */}
            <div className="mt-3 p-4 bg-gray-50 border border-gray-200 rounded-lg max-h-40 overflow-y-auto">
              <p className="text-xs font-medium text-gray-600 mb-2">Preview:</p>
              <KaTeXRender text={editedQuestion} />
            </div>
          </div>

          {/* Image upload section with all features */}
          <div className='mb-8 p-6 border border-gray-200 bg-teal-50/30 rounded-lg'>
            <div className="flex items-center justify-between mb-4">
              <h3 className='text-lg font-bold text-gray-800'>Upload diagram 
                <span className='text-sm pl-2 text-gray-500 font-normal'>(Optional)</span>
              </h3>
              {diagramImage && (
                <button
                  onClick={() => setShowPreviewModal(true)}
                  className="text-blue-600 hover:text-blue-800 flex items-center space-x-1 text-sm"
                >
                  <Eye className="w-4 h-4" />
                  <span>View</span>
                </button>
              )}
            </div>
            
            <div className="flex flex-col sm:flex-row gap-3">
              <label
                className="flex-1 bg-blue-600 hover:bg-blue-700 text-white py-4 px-6 rounded-xl font-medium transition-all duration-200 shadow-sm hover:shadow-md flex items-center justify-center space-x-3"
              >
                <Camera className="w-5 h-5" />
                <span>Camera</span>
                <input type='file' capture='environment' className='hidden' accept='image/*' onChange={handleImageFileSelect} />
              </label>
              
              <label className="flex-1 cursor-pointer bg-teal-600 hover:bg-teal-700 text-white py-4 px-6 rounded-xl font-medium transition-all duration-200 shadow-sm hover:shadow-md flex items-center justify-center space-x-3">
                <FileImage className="w-5 h-5" />
                <span>Gallery</span>
                <input
                  type="file"
                  accept="image/*"
                  onChange={handleImageFileSelect}
                  className="hidden"
                />
              </label>
              
              {diagramImage && (
                <button
                  onClick={resetImageUpload}
                  className="bg-red-500 hover:bg-red-600 text-white py-4 px-6 rounded-xl font-medium transition-all duration-200 shadow-sm hover:shadow-md flex items-center justify-center space-x-2"
                >
                  <X className="w-5 h-5" />
                  <span>Remove</span>
                </button>
              )}
            </div>
            
            {diagramImage && (
              <div className="mt-4 p-3 bg-green-50 border border-green-200 rounded-lg">
                <p className="text-green-700 text-sm flex items-center">
                  <CheckCircle className="w-4 h-4 mr-2" />
                  Diagram uploaded successfully
                </p>
              </div>
            )}
          </div>

          {/* Options Section */}
          <div className="mb-8">
            <label className="block text-sm font-semibold text-gray-700 mb-4">
              Answer Options
              <span className="text-red-500 ml-1">*</span>
            </label>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {['A', 'B', 'C', 'D'].map((letter, index) => (
                <div key={letter} className="bg-gray-50 rounded-lg p-4 space-y-3 border border-gray-200">
                  <div className="flex items-center justify-between">
                    <label className="text-sm font-semibold text-gray-700">
                      Option {letter}
                    </label>
                    <div className="flex items-center space-x-2">
                      <input
                        type="radio"
                        name="correctAnswer"
                        value={editedOptions[index]}
                        checked={correctAnswer === editedOptions[index]}
                        onChange={(e) => setCorrectAnswer(e.target.value)}
                        className="w-4 h-4 text-green-600 focus:ring-green-500 focus:ring-offset-0"
                        disabled={isCurrentQuestionSaved}
                      />
                      <span className="text-xs text-gray-600">Correct?</span>
                    </div>
                  </div>
                  <input
                    type="text"
                    value={editedOptions[index]}
                    onChange={(e) => {
                      const newOptions = [...editedOptions];
                      newOptions[index] = e.target.value;
                      setEditedOptions(newOptions);
                      if (correctAnswer === editedOptions[index]) {
                        setCorrectAnswer(e.target.value);
                      }
                    }}
                    className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-200"
                    placeholder={`Enter option ${letter}...`}
                    disabled={isCurrentQuestionSaved}
                  />
                  <div className="text-sm text-gray-600 bg-white p-3 border border-gray-200 rounded-lg max-h-20 overflow-y-auto">
                    <KaTeXRender text={editedOptions[index]} />
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Metadata Section */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-2">
                Class
              </label>
              <select
                value={selectedClass}
                onChange={(e) => setSelectedClass(e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-200"
                disabled={isCurrentQuestionSaved}
              >
                <option value="9">Class 9</option>
                <option value="10">Class 10</option>
                <option value="11">Class 11</option>
                <option value="12">Class 12</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-2">
                Chapter
              </label>
              <select
                value={selectedChapter}
                onChange={(e) => setSelectedChapter(e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-200"
                disabled={isCurrentQuestionSaved}
              >
                {/* {chapters.map(chapter => (
                  <option key={chapter} value={chapter}>
                    {String(chapter)}
                  </option>
                ))} */}
                {Array.isArray(chapters)
              ? chapters.map(chapter => (
                  <option key={chapter} value={chapter}>
                    {String(chapter)}
                  </option>
                ))
              : Object.values(chapters).flat().map(chapter => (
                  <option key={String(chapter)} value={String(chapter)}>
                    {String(chapter)}
                  </option>
                ))}

              </select>
            </div>

            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-2">
                Language
              </label>
              <select
                value={selectedLanguage}
                onChange={(e) => setSelectedLanguage(e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-200"
                disabled={isCurrentQuestionSaved}
              >
                <option value="Bengali">Bengali</option>
                <option value="English">English</option>
              </select>
            </div>
          </div>

          {/* Action Buttons */}
          <div className="flex flex-col sm:flex-row gap-4 justify-between">
            <div className="flex flex-col sm:flex-row gap-3">
              <button
                onClick={handlePreviousQuestion}
                disabled={currentQuestionIndex === 0}
                aria-label="Go to previous question"
                className={`px-6 py-3 rounded-lg font-medium transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 ${
                  currentQuestionIndex === 0
                    ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                    : 'bg-gray-600 hover:bg-gray-700 text-white shadow-sm hover:shadow-md focus:ring-gray-500'
                }`}
              >
                ← Previous
              </button>
              
              <button
                onClick={handleSkipQuestion}
                disabled={currentQuestionIndex === extractedQuestions.length - 1}
                aria-label="Skip to next question"
                className={`px-6 py-3 rounded-lg font-medium transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 ${
                  currentQuestionIndex === extractedQuestions.length - 1
                    ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                    : 'bg-yellow-600 hover:bg-yellow-700 text-white shadow-sm hover:shadow-md focus:ring-yellow-500'
                }`}
              >
                Skip →
              </button>
            </div>

            {/* Save/Next Button */}
            {isCurrentQuestionSaved ? (
              <button
                onClick={handleNextQuestion}
                className="px-8 py-3 rounded-lg font-semibold text-white bg-blue-600 hover:bg-blue-700 transition-all duration-200 shadow-sm hover:shadow-md focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                {currentQuestionIndex === extractedQuestions.length - 1 ? '🏁 Finish' : 'Next →'}
              </button>
            ) : (
              <button
                onClick={handleSaveQuestion}
                disabled={isSaving}
                className={`px-8 py-3 rounded-lg font-semibold transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 ${
                  isSaving
                    ? 'bg-gray-400 cursor-not-allowed text-gray-600'
                    : 'bg-green-600 hover:bg-green-700 text-white shadow-sm hover:shadow-md focus:ring-green-500'
                }`}
              >
                {isSaving ? (
                  <div className="flex items-center space-x-2">
                    <LoaderCircle className="animate-spin rounded-full h-8 w-8" color="#2200ed"/>
                    <span>Saving...</span>
                  </div>
                ) : (
                  '💾 Save Question'
                )}
              </button>
            )}
          </div>
        </div>
      )}

      {/* No Questions State */}
      {!hasQuestions && !isUploading && (
        <div className="text-center py-16 bg-cyan-100 rounded-xl shadow-lg border border-gray-200">
          <div className="w-20 h-20 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-6">
            <Upload className="w-10 h-10 text-gray-400" />
          </div>
          <h3 className="text-xl font-semibold text-gray-900 mb-2">No Questions Yet</h3>
          <p className="text-gray-600 mb-1">Upload a PDF or image file to extract and edit questions</p>
          <p className="text-sm text-gray-500">Supported formats: PDF, JPEG, PNG, GIF, WebP</p>
        </div>
      )}

      {/* Image Upload Options Modal */}
      {showImageModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl shadow-2xl max-w-sm w-full">
            <div className="p-6">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-semibold text-gray-800">Choose Upload Method</h2>
                <button
                  onClick={closeImageModal}
                  className="text-gray-500 hover:text-gray-700 transition-colors"
                >
                  <X className="w-6 h-6" />
                </button>
              </div>
              
              <div className="space-y-3">
                <label className="cursor-pointer w-full bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg transition-colors flex items-center justify-center space-x-2">
                  <FileImage className="w-5 h-5" />
                  <span>Choose from Files</span>
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleImageFileSelect}
                    className="hidden"
                  />
                </label>
                
                <button
                  onClick={openCamera}
                  className="w-full bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-lg transition-colors flex items-center justify-center space-x-2"
                >
                  <Camera className="w-5 h-5" />
                  <span>Take Photo</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Camera Stream */}
      {showCamera && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl shadow-2xl max-w-md w-full">
            <div className="p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-xl font-semibold text-gray-800">Take Photo</h2>
                <button
                  onClick={closeImageModal}
                  className="text-gray-500 hover:text-gray-700 transition-colors"
                >
                  <X className="w-6 h-6" />
                </button>
              </div>
              
              <video
                ref={videoRef}
                autoPlay
                className="w-full rounded-lg mb-4"
                style={{ maxHeight: '300px' }}
              />
              
              <button
                onClick={captureFromCamera}
                className="w-full bg-green-500 hover:bg-green-600 text-white px-6 py-3 rounded-lg transition-colors flex items-center justify-center space-x-2"
              >
                <Camera className="w-5 h-5" />
                <span>Capture Photo</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Crop Modal */}
      {showCropModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-y-auto">
            <div className="p-6">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-semibold text-gray-800">Crop Your Image</h2>
                <button
                  onClick={cancelCrop}
                  className="text-gray-500 hover:text-gray-700 transition-colors"
                >
                  <X className="w-6 h-6" />
                </button>
              </div>
              
              <div className="mb-6">
                <img
                  ref={cropImageRef}
                  src={cropImage}
                  className="max-w-full max-h-96 rounded-lg"
                  onLoad={setupCropper}
                  alt="Crop preview"
                />
              </div>
              
              <div className="flex gap-3 justify-end">
                <button
                  onClick={cancelCrop}
                  className="px-6 py-2 bg-gray-500 hover:bg-gray-600 text-white rounded-lg transition-colors flex items-center space-x-2"
                >
                  <X className="w-4 h-4" />
                  <span>Cancel</span>
                </button>
                <button
                  onClick={performCrop}
                  className="px-6 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg transition-colors flex items-center space-x-2"
                >
                  <Crop className="w-4 h-4" />
                  <span>Crop & Continue</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Preview Modal */}
      {showPreviewModal && previewImage && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl shadow-2xl max-w-2xl w-full">
            <div className="p-6">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-semibold text-gray-800">Image Preview</h2>
                <button
                  onClick={() => setShowPreviewModal(false)}
                  className="text-gray-500 hover:text-gray-700 transition-colors"
                >
                  <X className="w-6 h-6" />
                </button>
              </div>
              
              <div className="text-center mb-6">
                <img
                  src={previewImage}
                  className="max-w-full max-h-96 rounded-lg shadow-md mx-auto"
                  alt="Diagram preview"
                />
              </div>
              
              <div className="flex gap-3 justify-end">
                <button
                  onClick={resetImageUpload}
                  className="px-6 py-2 bg-red-500 hover:bg-red-600 text-white rounded-lg transition-colors flex items-center space-x-2"
                >
                  <X className="w-4 h-4" />
                  <span>Remove Image</span>
                </button>
                <button
                  onClick={showImageOptions}
                  className="px-6 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg transition-colors"
                >
                  Upload New Image
                </button>
              </div>
            </div>
          </div>
        </div>

        
      )}
    </div>
  );
};

export default Scan;