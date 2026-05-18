import { FileText, Upload, Image, LoaderCircle, CheckCircle, Clock, Camera, FolderClosed, Crop, X, Trash2, Square, SquareCheck, Delete, CheckCheck, CircleQuestionMark } from "lucide-react";
import NavComponent from "./NavComponent";
import { useEffect, useState, useRef, useMemo } from "react";
import axios from "axios";
import Alert from "../all/AlertDialog";
import KaTeXRender from "../all/KatexRender";
import Cropper, { type ReactCropperElement } from "react-cropper";
import "react-cropper/node_modules/cropperjs/dist/cropper.css"

interface Props {
  chapters: {
    classNo9Chaps: string[];
    classNo10Chaps: string[];
    classNo11Chaps: string[];
    classNo12Chaps: string[];
  };
}

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

const ScanComponent = (props: Props) => {
    const chapters = props.chapters;
    const BACK = import.meta.env.PUBLIC_BACKEND

    const [file, setFile] = useState<File | null>(null);
    const [isUploading, setIsUploading] = useState(false);
    const [extractedQuestions, setExtractedQuestions] = useState<Question[]>([]);
    const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0);
    const [savedCount, setSavedCount] = useState(0);
    const [savedQuestions, setSavedQuestions] = useState<Set<number>>(new Set());
    const [error, setError] = useState<string | null>(null);

    //Question states
    const [editedQuestion, setEditedQuestion] = useState('');
    const [editedOptions, setEditedOptions] = useState<string[]>(['', '', '', '']);
    const [selectedClass, setSelectedClass] = useState<number>(11);
    const [selectedChapter, setSelectedChapter] = useState('');
    const [selectedLanguage, setSelectedLanguage] = useState('Bengali');
    const [correctAnswer, setCorrectAnswer] = useState('');
    const [diagram, setDiagram] = useState<File | null>(null);
    const [previewUrl, setPreviewUrl] = useState<string>('')
    const [cropImage, setCropImage] = useState<string>('');
    const [showImageModal, setShowImageModal] = useState(false);
    const [showDiagram, setShowDiagram] = useState(false)
    const [isCropping, setIsCropping] = useState(false);
    const cropperRef = useRef<ReactCropperElement>(null);
    const [dropdownCh, setDropdownCh] = useState<string[]>([]);
    const [inputFocused, setInputFocused] = useState(false);
    const [isSaving, setIsSaving] = useState(false);
    const [getHelp, setGetHelp] = useState(false)

    // File upload handler
    const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        if (e.target.files && e.target.files[0]) {
        const selectedFile = e.target.files[0];
        const fileType = selectedFile.type;

        const allowedTypes = [
            "application/pdf",
            "image/jpeg",
            "image/jpg",
            "image/png",
            "image/gif",
            "image/webp",
        ];

        if (!allowedTypes.includes(fileType)) {
            setError("Please select a PDF or image file (JPEG, PNG, GIF, WebP).");
            return;
        }

        setError(null);
        setFile(selectedFile);
        }
    };

    // Upload and process file
    const handleUpload = async () => {
        if (!file) {
        setError("Please select a file.");
        return;
        }

        const formData = new FormData();
        formData.append("pdf", file);

        setIsUploading(true);
        setError(null);

        try {
        const response = await axios.post(`${BACK}/api/v1/scan`, formData, {
            headers: { "Content-Type": "multipart/form-data" },
        });

        const data: ExtractedResponse = response.data;

        if (data.success && data.data.questions.length > 0) {
            setExtractedQuestions(data.data.questions);
            setCurrentQuestionIndex(0);
            setSavedCount(0);
            setSavedQuestions(new Set());
            console.log(
            `Extracted ${data.data.total_questions} questions from ${
                data.data.file_type || "PDF"
            }`
            );
        } else {
            setError("No questions found in the file or processing failed.");
        }
        } catch (err) {
        console.error("Upload error:", err);
        setError("Upload failed. Please try again.");
        } finally {
        setIsUploading(false);
        }
    };

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
      
    const handleDiagramChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        if (e.target.files && e.target.files[0]) {
            const file = e.target.files[0];
            setDiagram(file);
            
            const reader = new FileReader();
            reader.onload = (event) => {
                if (event.target?.result) {
                    const imageUrl = event.target.result as string;
                    setPreviewUrl(imageUrl);
                    setCropImage(imageUrl); // Set initial crop image
                }
            };
            reader.readAsDataURL(file);
        }
    };

    const onCrop = () => {
        const cropper = cropperRef.current?.cropper;
        if (cropper) {
            setCropImage(cropper.getCroppedCanvas().toDataURL());
        }
    };

    const chList = useMemo(() => {
  return selectedClass === 9 ? chapters.classNo9Chaps :
         selectedClass === 10 ? chapters.classNo10Chaps :
         selectedClass === 11 ? chapters.classNo11Chaps :
         selectedClass === 12 ? chapters.classNo12Chaps :
         [
           ...chapters.classNo9Chaps,
           ...chapters.classNo10Chaps,
           ...chapters.classNo11Chaps,
           ...chapters.classNo12Chaps
         ];
    }, [
    selectedClass,
    chapters.classNo9Chaps,
    chapters.classNo10Chaps,
    chapters.classNo11Chaps,
    chapters.classNo12Chaps
    ]);

    
    useEffect(() => setDropdownCh(chList), [chList]);

    const searchChapter = (e: any) => {
        const val = e.target.value.toLowerCase();
        setDropdownCh(val ? chList.filter((ch: string) => ch.toLowerCase().includes(val)) : chList); 
    };

  // Save current question with FormData
  const handleSaveQuestion = async () => {
    if (!editedQuestion.trim() || editedOptions.some(opt => !opt.trim()) || !correctAnswer) {
      setError("Please fill in all fields including the correct answer.");
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
      formData.append('classNo', String(selectedClass));
      formData.append('chapter', selectedChapter);
      formData.append('language', selectedLanguage);

      // Handle diagram image
      if (cropImage) {
        // Convert base64 data URL to Blob
        const base64Response = await fetch(cropImage);
        const blob = await base64Response.blob();
        const imageFile = new File([blob], `diagram_${Date.now()}.png`, {
          type: 'image/png',
          lastModified: Date.now()
        });

        formData.append('diagram', imageFile);
      }

      console.log("Sending FormData with diagram:", diagram ? 'Yes' : 'No');
      
      // Log FormData contents for debugging
      for (let [key, value] of formData.entries()) {
        console.log(`${key}:`, value instanceof File ? `File: ${value.name} (${value.size} bytes)` : value);
      }

      // Send FormData request
      await axios.post(`${BACK}/api/v1/question/addQuestion`, formData, {
        headers: { 
          "Content-Type": "multipart/form-data",
        },
      });

      setSavedQuestions(prev => new Set([...prev, currentQuestionIndex]));
      setSavedCount(prev => prev + 1);
      
    } catch (err) {
      console.error("Save error:", err);
      setError("Failed to save question. Please try again.");
    } finally {
      setIsSaving(false);
    }
  };


    // Go to next question
    const handleNextQuestion = () => {
        if (currentQuestionIndex < extractedQuestions.length - 1) {
        setCurrentQuestionIndex(prev => prev + 1);
        } else {
        setError(`All ${extractedQuestions.length} questions have been processed! Saved: ${savedCount}`);
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
    
    const hasQuestions = extractedQuestions.length > 0;
    const isCurrentQuestionSaved = savedQuestions.has(currentQuestionIndex);

    return (
        <div className="max-w-6xl mx-auto p-3 bg-cyan-100 min-h-screen pt-20">
            <NavComponent />

            {/* Upload Section */}
            <div className="bg-white rounded-xl shadow-lg border border-gray-200 p-8 mb-8">
                <div className="flex flex-col items-center space-y-6">
                <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center">
                    <Upload className="w-8 h-8 text-blue-600" />
                </div>

                <div className="text-center">
                    <h2 className="text-2xl font-bold text-gray-900 mb-2">
                    Upload Files
                    </h2>
                    <p className="text-gray-600">
                    Select a PDF or Image file to extract questions from
                    </p>
                </div>

                <div className="flex  gap-4">
                    <label className="cursor-pointer bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg font-medium transition-all duration-200 shadow-sm hover:shadow-md flex items-center space-x-2 focus-within:ring-2 focus-within:ring-blue-500 focus-within:ring-offset-2">
                    <FileText className="w-5 h-5" />
                    <span>PDF</span>
                    <input
                        type="file"
                        accept="application/pdf"
                        onChange={handleFileChange}
                        className="hidden"
                    />
                    </label>
                    <label className="cursor-pointer bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-lg font-medium transition-all duration-200 shadow-sm hover:shadow-md flex items-center space-x-2 focus-within:ring-2 focus-within:ring-green-500 focus-within:ring-offset-2">
                    <Image className="w-5 h-5" />
                    <span>Image</span>
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
                    <p className="text-gray-700 font-medium">Selected: {file.name}</p>
                    <p className="text-sm text-gray-500 mb-4">
                        Type: {file.type.startsWith("image/") ? "Image" : "PDF"}
                    </p>
                    <button
                        onClick={handleUpload}
                        disabled={isUploading}
                        className={`w-full px-6 py-3 rounded-lg font-semibold transition-all duration-200 ${
                        isUploading
                            ? "bg-gray-400 cursor-not-allowed text-gray-600"
                            : "bg-green-600 hover:bg-green-700 text-white shadow-sm hover:shadow-md"
                        }`}
                    >
                        {isUploading ? (
                        <div className="flex items-center justify-center space-x-2">
                            <LoaderCircle className="animate-spin rounded-full h-8 w-8" />
                            <span>Processing...</span>
                        </div>
                        ) : (
                        "🚀 Extract Questions"
                        )}
                    </button>
                    </div>
                )}
                </div>
            </div>

            {hasQuestions && (
                <div className="bg-white rounded-xl shadow-lg border border-gray-200 p-6 lg:p-8">
                    {/* Status Badge */}
                    <div className="mb-6 flex justify-between items-center">
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
                        <div className="rounded-full p-1 bg-amber-100" onClick={()=> setGetHelp(true)}>
                            <CircleQuestionMark color="#eaa222"/>
                        </div>
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
                            {/* <span className="text-xs text-gray-500">
                            {Math.round(((currentQuestionIndex + 1) / extractedQuestions.length) * 100)}% Complete
                            </span> */}
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

                    {/* Diagram upload */}
                    <div className="border border-gray-300 p-2 rounded-lg md:p-4 bg-slate-50">
                        <h1 className="block text-sm font-semibold text-gray-700 mb-4">Upload Diagram Image<i className="text-gray-500 ml-1">(optional)</i></h1>
                        <div className="flex gap-4">
                            <label className="cursor-pointer flex-1 bg-sky-600 hover:bg-sky-700 text-white px-4 py-3 rounded-lg font-medium transition-all duration-200 shadow-sm hover:shadow-md flex items-center space-x-2 focus-within:ring-2 focus-within:ring-blue-500 focus-within:ring-offset-2">
                            <Camera className="w-5 h-5" />
                            <span>Capture</span>
                            {/* <input
                                type="file"
                                capture="environment"
                                accept="image/*"
                                onChange={(e)=>(setDiagram(e.target.files ? e.target.files[0] : null))}
                                className="hidden"
                            /> */}
                            <input
                                type="file"
                                capture="environment"
                                accept="image/*"
                                onChange={handleDiagramChange} // Use the updated handler
                                className="hidden"
                            />
                            </label>
                            <label className="cursor-pointer flex-1 bg-teal-600 hover:bg-teal-700 text-white px-4 py-3 rounded-lg font-medium transition-all duration-200 shadow-sm hover:shadow-md flex items-center space-x-2 focus-within:ring-2 focus-within:ring-green-500 focus-within:ring-offset-2">
                            <FolderClosed className="w-5 h-5" />
                            <span>Upload</span>
                            {/* <input
                                type="file"
                                accept="image/*"
                                onChange={(e)=>(setDiagram(e.target.files ? e.target.files[0] : null))}
                                className="hidden"
                            /> */}
                            <input
                                type="file"
                                accept="image/*"
                                onChange={handleDiagramChange} // Use the updated handler
                                className="hidden"
                            />

                            </label>
                        </div>

                        {diagram && (
                            <div className="flex items-center align-middle gap-1">
                                <div 
                                    className="w-60 rounded-md text-white font-bold p-3 mt-3 flex bg-blue-500 hover:bg-blue-600 cursor-pointer transition-colors" 
                                    onClick={() => setShowImageModal(true)}
                                >
                                    <Image className="mr-2" />
                                    <button>View Image</button>
                                </div>
                                <div className="mr-3 bg-rose-600 p-2.5 mt-2.5 rounded-md" onClick={()=>{setDiagram(null);setPreviewUrl('');setCropImage('')}}>
                                    <Trash2 color="white"/>
                                </div>
                            </div>
                        )}

                    </div>

                    {/* Options Section */}
                    <div className="my-8">
                        <label className="block text-sm font-semibold text-gray-700 mb-4">
                        Answer Options
                        <span className="text-red-500 ml-1">*</span>
                        </label>
                        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                            
                        {['A', 'B', 'C', 'D'].map((letter, index) => {
                            const isSelected = correctAnswer === editedOptions[index];
                            return (
                                <div
                                key={letter}
                                className={`rounded-xl p-2 space-y-3 border cursor-pointer transition-all duration-200
                                    ${isSelected ? "bg-green-100 border-green-500" : "bg-white border-gray-300 hover:border-blue-400"}
                                `}
                                onClick={() => {
                                    if (!isCurrentQuestionSaved) {
                                    setCorrectAnswer(editedOptions[index]);
                                    }
                                }}
                                >
                                <div className="flex items-center gap-2">
                                    <input
                                    type="radio"
                                    checked={isSelected}
                                    onChange={() => {
                                        if (!isCurrentQuestionSaved) {
                                        setCorrectAnswer(editedOptions[index]);
                                        }
                                    }}
                                    className="appearance-none text-green-600 border-gray-300 focus:ring-green-500"
                                    disabled={isCurrentQuestionSaved}
                                    />
                                    {isSelected? (
                                        <SquareCheck color="green"/>
                                    ):(
                                        <Square color="gray"/>
                                    )}
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
                                    placeholder={`Enter option ${letter}...`}
                                    disabled={isCurrentQuestionSaved}
                                    className="flex-1 p-2 border border-gray-300 rounded-lg bg-white/40 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition"
                                    />
                                </div>

                                <div className="text-sm text-gray-700 bg-gray-50 p-3 border border-gray-200 rounded-lg max-h-20 overflow-y-auto">
                                    <KaTeXRender text={editedOptions[index]} />
                                </div>
                                </div>
                            );
                            })}

                        </div>
                    </div>

                    {/* Metadata Section */}
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
                        {/* Class - First on mobile, first on desktop */}
                        <div className="order-1">
                            <label className="block text-sm font-semibold text-gray-700 mb-2">
                                Class
                            </label>
                            <div className="flex gap-2">
                                {[9,10,11,12].map((num)=>(
                                    <button
                                        key={num}
                                        className={`p-2 px-6 rounded-lg border transition 
                                            ${num === selectedClass ? "bg-teal-500 text-white border-teal-600" : "bg-gray-100 border-gray-300 hover:bg-gray-200"}
                                        `}
                                        onClick={() => setSelectedClass(num)}
                                    >
                                        {num}
                                    </button>
                                ))}
                            </div>
                        </div>

                        {/* Language - Second on mobile, second on desktop */}
                        <div className="order-4 md:order-2">
                            <label className="block text-sm font-semibold text-gray-700 mb-2">
                                Language
                            </label>
                            <div className="flex gap-2">
                                {['Bengali','English'].map((lang)=>(
                                    <button
                                        key={lang}
                                        className={`p-2 px-8 rounded-lg border transition 
                                            ${lang === selectedLanguage ? "bg-sky-500 text-white border-sky-600" : "bg-gray-100 border-gray-300 hover:bg-gray-200"}
                                        `}
                                        onClick={() => setSelectedLanguage(lang)}
                                    >
                                        {lang}
                                    </button>
                                ))}
                            </div>
                        </div>
                        
                        {/* Search Chapter - Third on mobile, spans full width */}
                        <div className="relative col-span-1 md:col-span-2 order-2 md:order-3">
                            <label className="block text-sm font-semibold text-gray-700 mb-2">
                                Search Chapter
                            </label>
                            <input 
                                className="bg-slate-100 px-3 py-2 rounded-full w-full border border-gray-300 focus:outline-none focus:border-slate-400" 
                                placeholder="Search for the chapter name..." 
                                onChange={searchChapter}
                                onFocus={() => setInputFocused(true)}
                                onBlur={() => setTimeout(() => setInputFocused(false), 200)}
                            />
                            
                            {inputFocused && dropdownCh.length > 0 && (
                                <div className="absolute top-full left-0 right-0 mt-1 bg-white rounded-lg border border-gray-300 max-h-60 overflow-y-auto shadow-lg z-10">
                                    <ul className="py-2">
                                        {dropdownCh.map((chapter, index) => (
                                            <li 
                                                key={index}
                                                onClick={() => setSelectedChapter(chapter)}
                                                className="px-4 py-2 hover:bg-blue-50 cursor-pointer transition-colors duration-200 border-b border-gray-100 last:border-b-0"
                                            >
                                                <span className="text-gray-800 font-medium">{chapter}</span>
                                            </li>
                                        ))}
                                    </ul>
                                </div>
                            )}
                        </div>

                        {/* Display selected Chapter - Fourth, spans full width */}
                        {selectedChapter && (
                            <div className="flex bg-slate-200 col-span-1 w-fit md:min-w-lg md:col-span-2 order-3 md:order-4 rounded-md border border-neutral-300 p-2 justify-between">
                                <h1 className="mr-4">{selectedChapter}</h1>
                                <button onClick={()=>setSelectedChapter('')}>
                                    <Delete />
                                </button>
                            </div>
                        )}
                    </div>

                    {/* Action Buttons */}
                    <div className="flex flex-col sm:flex-row gap-4 justify-between">
                        <div className="flex w-full gap-3">
                            <button
                            onClick={handlePreviousQuestion}
                            disabled={currentQuestionIndex === 0}
                            aria-label="Go to previous question"
                            className={`flex-1 px-6 py-3 rounded-lg font-medium transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 ${
                                currentQuestionIndex === 0
                                ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                                : 'bg-gray-600 hover:bg-gray-700 text-white shadow-sm hover:shadow-md focus:ring-gray-500'
                            }`}
                            >
                            ← Previous
                            </button>
                            
                            <button
                            type="button"
                            onClick={handleSkipQuestion}
                            disabled={isCurrentQuestionSaved || currentQuestionIndex === extractedQuestions.length - 1}
                            aria-label="Skip to next question"
                            className={`flex-1 px-6 py-3 rounded-lg font-medium transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 ${
                                isCurrentQuestionSaved || currentQuestionIndex === extractedQuestions.length - 1
                                ? 'bg-gray-300 text-gray-500 cursor-not-allowed opacity-80'
                                : 'bg-yellow-600 hover:bg-yellow-700 text-white shadow-sm hover:shadow-md focus:ring-yellow-500'
                            }`}
                            >
                            {isCurrentQuestionSaved ? 'Saved' : 'Skip →'}
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
            <div className="text-center py-16 bg-white rounded-xl shadow-lg border border-gray-200">
            <div className="w-20 h-20 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-6 shadow shadow-gray-300">
                <Upload className="w-10 h-10 text-gray-600 " />
            </div>
            <h3 className="text-xl font-semibold text-gray-900 mb-2">No Questions Yet</h3>
            <p className="text-gray-700 mb-1">Upload a PDF or image file to extract and edit questions</p>
            <p className="text-sm text-gray-500">Supported formats: PDF, JPEG, PNG, GIF, WebP</p>
            </div>
        )}

        {/* Error alerts */}
        {error && <Alert title="Note" text={error} type="error" onClose={()=>setError(null)}/>}

        {previewUrl && showImageModal && (
            <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50">
                <div className="bg-white rounded-lg w-full h-fit max-w-none max-h-none m-4 flex flex-col">
                    {/* Modal Header */}
                    <div className="flex justify-between items-center p-4 border-b bg-gray-50">
                        <h3 className="text-xl font-semibold text-gray-800">
                            {isCropping ? 'Crop Image' : 'Preview Image'}
                        </h3>
                        <div className="flex gap-2">
                            {isCropping ? (
                                <>
                                    <button
                                        onClick={() => {
                                            onCrop();
                                            setIsCropping(false);
                                        }}
                                        className="p-2 text-green-600 hover:text-green-700 hover:bg-green-50 rounded-full transition-colors"
                                    >
                                        <CheckCheck className="w-6 h-6" />
                                    </button>
                                    {/* <button
                                        onClick={() => setIsCropping(false)}
                                        className="p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-full transition-colors"
                                    >
                                        <X className="w-6 h-6" />
                                    </button> */}
                                </>
                            ) : (
                                <>
                                    <button
                                        onClick={() => setIsCropping(true)}
                                        className="p-2 text-blue-600 hover:text-blue-700 hover:bg-blue-50 rounded-full transition-colors"
                                    >
                                        <Crop className="w-6 h-6" />
                                    </button>
                                    <button
                                        onClick={() => {
                                            onCrop()
                                            setShowImageModal(false);
                                            setIsCropping(false);
                                        }}
                                        className="p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-full transition-colors"
                                    >
                                        <X className="w-6 h-6" />
                                    </button>
                                </>
                            )}
                        </div>
                    </div>

                    {/* Modal Body - Full Screen Content */}
                    <div className="flex-1 p-4 overflow-hidden flex items-center justify-center">
                        {isCropping ? (
                            <div className="w-full h-full flex items-center justify-center">
                                <Cropper
                                    ref={cropperRef}
                                    src={previewUrl}
                                    crop={onCrop}
                                    className="max-w-full max-h-full"
                                />
                            </div>
                        ) : (
                            <div className="w-full h-full flex items-center justify-center">
                                <img
                                    src={cropImage || previewUrl}
                                    alt="Preview"
                                    className="max-w-full max-h-full object-contain"
                                />
                            </div>
                        )}
                    </div>
                </div>
            </div>
        )}

        {getHelp && (<Alert title="Help with syntax" text="Visit the page below for detailed instructions." link="https://katex.org/docs/supported.html" onClose={()=>setGetHelp(false)}/>)}
        {/* {getHelp && <MathSyntaxHelpPopup open={true} onClose={()=>setGetHelp(false)} />} */}

        </div>
    );
};

export default ScanComponent;
