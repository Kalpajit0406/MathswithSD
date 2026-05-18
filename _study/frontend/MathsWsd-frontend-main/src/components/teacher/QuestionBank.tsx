import { Eye, SquarePen, Trash2, X } from "lucide-react";
import { useState, useEffect, useMemo, useCallback } from "react";
import NavComponent from "./NavComponent";
import axios from "axios";
import KaTeXRender from "../all/KatexRender";

const BACKEND = import.meta.env.PUBLIC_BACKEND

interface Question {
  _id: string;
  language: string;
  chapter: string;
  classNo: number;
  correctAnswer: string;
  createdAt: string;
  diagram: string | null;
  options: string[];
  question: string;
  updatedAt: string;
  __v: number;
}

interface Props {
  chapters: {
    classNo9Chaps: string[];
    classNo10Chaps: string[];
    classNo11Chaps: string[];
    classNo12Chaps: string[];
  };
}

const getAllQuestions = async (): Promise<Question[]> => {
  const token = localStorage.getItem("token"); 

  const response = await axios.get(
    `${BACKEND}/api/v1/question/questions`,
    {
      headers: {
        Authorization: `Bearer ${token}`, 
      },
      withCredentials: true, 
    }
  );

  return response.data.success ? response.data.data : [];
};

// Skeletal Loading Component
const QuestionSkeleton = () => (
  <div className="bg-white rounded-lg border border-amber-200 p-6 shadow-sm animate-pulse">
    <div className="flex justify-between items-start mb-4">
      <div className="flex flex-col md:flex-row gap-3">
        <div className="flex gap-2">
          <div className="bg-gray-200 h-6 w-16 rounded-full"></div>
          <div className="bg-gray-200 h-6 w-20 rounded-full"></div>
        </div>
        <div className="bg-gray-200 h-6 w-24 rounded-full"></div>
      </div>
      <div className="flex space-x-2">
        <div className="bg-gray-200 h-8 w-8 rounded"></div>
        <div className="bg-gray-200 h-8 w-8 rounded"></div>
      </div>
    </div>
    
    <div className="mb-6">
      <div className="bg-gray-200 h-4 w-20 rounded mb-2"></div>
      <div className="bg-gray-200 h-20 w-full rounded mb-4"></div>
      
      <div className="bg-gray-200 h-4 w-16 rounded mb-3"></div>
      <div className="space-y-3">
        {[1, 2, 3, 4].map((i) => (
          <div key={i} className="bg-gray-200 h-12 w-full rounded-lg"></div>
        ))}
      </div>
      
      <div className="flex justify-between mt-4 pt-3 border-t border-gray-100">
        <div className="bg-gray-200 h-3 w-24 rounded"></div>
        <div className="bg-gray-200 h-3 w-24 rounded"></div>
      </div>
    </div>
  </div>
);

const QuestionBank = (props: Props) => {
  const [language, setLanguage] = useState<string | null>(null);
  const [classNo, setClassNo] = useState(11);
  const [dropdownCh, setDropdownCh] = useState<string[]>([]);
  const [selectedCh, setSelectedCh] = useState<string[]>([]);
  const [inputFocused, setInputFocused] = useState(false);
  const [allQuestion, setAllQuestion] = useState<Question[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Edit and delete modal state
  const [editingQ, setEditingQ] = useState<Question | null>(null);
  const [editForm, setEditForm] = useState<any>({
    question: "",
    options: [""],
    correctAnswer: "",
    chapter: "",
    language: "",
    diagram: "",
    classNo: 11,
  });
  const [deleteId, setDeleteId] = useState<String | null>(null)

  // Preview States
  const [qsPreview, setQsPreview] = useState(false)
  const [optsPreview, setOptsPreview] = useState(false)

  const chapters = props.chapters;

  const chList = useMemo(() => {
  return classNo === 9 ? chapters.classNo9Chaps :
         classNo === 10 ? chapters.classNo10Chaps :
         classNo === 11 ? chapters.classNo11Chaps :
         classNo === 12 ? chapters.classNo12Chaps :
         [
           ...chapters.classNo9Chaps,
           ...chapters.classNo10Chaps,
           ...chapters.classNo11Chaps,
           ...chapters.classNo12Chaps
         ];
  }, [
    classNo,
    chapters.classNo9Chaps,
    chapters.classNo10Chaps,
    chapters.classNo11Chaps,
    chapters.classNo12Chaps
  ]);


  useEffect(() => setDropdownCh(chList), [chList]);

  const fetchQuestions = async () => {
    setLoading(true);
    try {
      const questions = await getAllQuestions();
      setAllQuestion(questions);
    } catch {
      setError("Failed to fetch questions");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchQuestions();
  }, []);

  const searchChapter = (e: any) => {
    const val = e.target.value.toLowerCase();
    setDropdownCh(val ? chList.filter((ch: string) => ch.toLowerCase().includes(val)) : chList); 
  };

    const handleChapterSelect = (chapter: string) => {
        if (!selectedCh.includes(chapter)) {
            setSelectedCh([...selectedCh, chapter]);
        }
    };

    const removeSelectedChapter = (chapter: string) => { 
        setSelectedCh(selectedCh.filter(ch => ch !== chapter));
    };

  const handleEditClick = (q: Question) => {
    setEditingQ(q);
    setEditForm({
      question: q.question,
      options: q.options,
      correctAnswer: q.correctAnswer,
      chapter: q.chapter,
      language: q.language,
      diagram: q.diagram,
      classNo: q.classNo,
    });
  };

  const handleEditSave = async () => {
    if (!editingQ) return;
    try {
      const token = localStorage.getItem("token");
      
      await axios.put(
        `${BACKEND}/api/v1/question/questions/${editingQ._id}`, 
        editForm,
        {
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
          },
          withCredentials: true,
        }
      );
      
      setEditingQ(null);
      await fetchQuestions();
    } catch (err) {
      console.error("Edit failed", err);
    }
  };

   const handleDeleteClick = useCallback((id: string) => {
    setDeleteId(id);
  }, []);

  const confirmDelete = async () => {
    if (!deleteId) return;
    
    try {
      await axios.delete(`${BACKEND}/api/v1/question/questions/${deleteId}`);
      await fetchQuestions();
    } catch (err) {
      console.error("Delete failed", err);
      setError("Failed to delete question");
    } finally {
      setDeleteId(null);
    }
  };

  return (
    <div className="max-w-6xl mx-auto  min-h-screen bg-cyan-100 pt-10">
      <NavComponent />

      <header className="max-w-3xl bg-teal-100 px-4 py-7 border border-teal-300 rounded-2xl mt-17">
        <h1 className="text-6xl font-extrabold text-emerald-800 pb-10">Question Bank</h1>
        
        {/* Loading/Error states */}
        {loading && <p className="text-blue-600">Loading questions...</p>}
        {error && <p className="text-red-600">Error: {error} </p>}
        
        <h2 className="text-lg font-semibold text-gray-800 mb-2">Select Language:</h2>

          <div className={`inline-flex items-center justify-center p-4 `}>
                <div className="relative bg-sky-100 rounded-2xl p-1 shadow-sm border border-sky-200 backdrop-blur-sm">
                  <div className="flex w-full gap-1">
                    {['Bengali','English'].map((lang) => (
                      <button
                        key={lang}
                        onClick={() => setLanguage(lang)}
                        className={`
                          flex-1 px-6 py-2 rounded-xl font-medium text-sm
                          transition-all duration-300 ease-[cubic-bezier(0.4,0,0.2,1)]
                          ${language === lang
                            ? 'bg-sky-500 text-white shadow-sm scale-[1.02]'
                            : 'text-sky-700 hover:text-sky-800 hover:bg-sky-200/60'
                          }
                          focus:outline-none focus:ring-2 focus:ring-sky-300 focus:ring-offset-1 focus:ring-offset-sky-50
                          active:scale-95
                        `}
                        aria-pressed={language === lang}
                        role="tab"
                      >
                        {lang}
                      </button>
                    ))}
                  </div>
                </div>
              </div>
              <h2 className="text-lg font-semibold text-gray-800 mb-2 mt-6">Select Class:</h2>
            <div className={`inline-flex items-center justify-center p-4 `}>
              <div className="relative bg-sky-100 rounded-2xl p-1 shadow-sm border border-sky-200 backdrop-blur-sm">
                <div className="flex w-full gap-1">
                  {[9,10,11,12,0].map((num) => (
                    <button
                      key={num}
                      onClick={() => setClassNo(num)}
                      className={`
                        flex-1 px-6 py-2 rounded-xl font-medium text-sm
                        transition-all duration-300 ease-[cubic-bezier(0.4,0,0.2,1)]
                        ${classNo=== num
                          ? 'bg-sky-500 text-white shadow-sm scale-[1.02]'
                          : 'text-sky-700 hover:text-sky-800 hover:bg-sky-200/60'
                        }
                        focus:outline-none focus:ring-2 focus:ring-sky-300 focus:ring-offset-1 focus:ring-offset-sky-50
                        active:scale-95
                      `}
                      aria-pressed={classNo === num}
                      role="tab"
                    >
                      {num===0? ("All") : num}
                    </button>
                  ))}
                </div>
              </div>
            </div>
        <p className="mt-4 text-gray-600 italic">
            You have selected <b>{language}</b> of {classNo === 0 ? "all classes" : <>class <b>{classNo}</b></>}
        </p>

        <div className="relative mt-14">
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
                                onClick={() => handleChapterSelect(chapter)}
                                className="px-4 py-2 hover:bg-blue-50 cursor-pointer transition-colors duration-200 border-b border-gray-100 last:border-b-0"
                            >
                                <span className="text-gray-800 font-medium">{chapter}</span>
                            </li>
                        ))}
                    </ul>
                </div>
            )}
        </div>
        
        <div className="max-w-3xl bg-blue-100/60 px-4 py-7 border border-blue-300 rounded-2xl mt-4">
            <h3 className="text-xl font-semibold text-indigo-700 mb-4">Selected Chapters:</h3>
            
            {selectedCh.length > 0 ? (
                <div className="flex flex-wrap gap-2">
                    {selectedCh.map((chapter, index) => (
                        <div 
                            key={index}
                            className="bg-blue-200 px-3 py-1 rounded-lg flex items-center gap-2 border border-blue-400"
                        >
                            <span className="text-blue-900 font-medium">{chapter}</span>
                            <button 
                                onClick={() => removeSelectedChapter(chapter)}
                                className="text-indigo-700 hover:text-indigo-900 transition-colors"
                            >
                                <X size={16} />
                            </button>
                        </div>
                    ))}
                </div>
            ) : (
                <p className="text-gray-600">No chapters selected</p>
            )}
        </div>
      </header>

      <main className="max-w-3xl bg-amber-100 px-4 py-7 border border-amber-300 rounded-2xl mt-4">
        <h3 className="text-xl font-semibold mb-4 text-amber-800">Questions</h3>

        {loading ? (
          <div className="space-y-4">
            {[1, 2, 3].map((i) => (
              <QuestionSkeleton key={i} />
            ))}
          </div>
        ) : (
          allQuestion
            .filter((q) =>
              (language ? q.language === language : true) &&
              (classNo !== 0 ? q.classNo === classNo : true) &&
              (selectedCh.length > 0 ? selectedCh.includes(q.chapter) : true)
            )
            .map((question) => (
              <div key={question._id} className="bg-white rounded-lg border border-amber-200 p-6 shadow-sm">
                <div className="flex justify-between items-start mb-4">
                  <div className="flex flex-col md:flex-row gap-3 text-sm">
                    <div className="flex gap-2 order-1">
                      <span className="bg-blue-100 text-blue-800 border border-blue-200 px-2 py-1 rounded-full font-medium">
                        Class {question.classNo}
                      </span>
                      <span className="bg-green-100 text-green-800 border border-green-200 px-2 py-1 rounded-full font-medium">
                        {question.language}
                      </span>
                    </div>
                    <span className="bg-purple-100 text-purple-800 px-2 py-1 rounded-lg border border-purple-200 font-medium order-2">
                      {question.chapter}
                    </span>
                  </div>
                  <div className="space-x-2">
                    <button
                      onClick={() => handleEditClick(question)}
                      className="text-sm text-blue-500 rounded-2xl px-2 py-1 hover:text-blue-400"
                    >
                      <SquarePen />
                    </button>
                    <button
                      onClick={() => handleDeleteClick(question._id)}
                      className="text-sm text-red-500 rounded-2xl px-2 py-1 hover:text-red-400"
                    >
                      <Trash2 />
                    </button>
                  </div>
                </div>

                <div className="mb-6">
                  <h4 className="text-lg font-semibold">Question:</h4>
                  <KaTeXRender text={question.question} />

                  {/* Diagram (if exists) */}
                  {question.diagram && (
                  <div className="mb-6">
                      <h5 className="font-semibold text-gray-800 mb-2">Diagram:</h5>
                      <div className="bg-gray-50 p-4 rounded-lg">
                          <img src={question.diagram} alt="Question diagram" className="max-w-full h-auto" />
                      </div>
                  </div>
                  )}

                  {/* Options */}
                  <div className="mb-4">
                      <h5 className="font-semibold text-gray-800 mb-3">Options:</h5>
                      <div className="space-y-3">
                          {question.options.map((option, optionIndex) => {
                              const isCorrect = option === question.correctAnswer;
                              return (
                                  <div key={optionIndex} className="flex items-start gap-3">
                                      <div className={`flex-1 p-3 rounded-lg ${
                                          isCorrect 
                                              ? 'bg-green-50 border border-green-200 text-green-800' 
                                              : 'bg-gray-50 border border-gray-200 text-gray-700'
                                      }`}>
                                          <KaTeXRender text={option} />
                                      </div>
                                  </div>
                              );
                          })}
                      </div>
                  </div>

                  {/* Timestamps (optional) */}
                  <div className="flex justify-between text-xs text-gray-500 mt-4 pt-3 border-t border-gray-100">
                      <span>Created: {new Date(question.createdAt).toLocaleDateString()}</span>
                      <span>Updated: {new Date(question.updatedAt).toLocaleDateString()}</span>
                  </div>
                </div>
              </div>
            ))
        )}
      </main>

      {/* Edit Modal */}
      {editingQ && (
        <div className="fixed inset-0 flex items-center justify-center bg-black/60 backdrop-blur-xs z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-lg shadow-lg space-y-3">
            <h3 className="mb-4 text-xl font-semibold text-gray-900">Edit Question</h3>

            {/* Question edit */}
            <div className="">
              <div className="relative">
                <div className="flex justify-between">
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Edit Question
                  </label>
                  <button className="" onClick={() => {setQsPreview(prev => !prev)}}><Eye className="text-gray-700"/></button>
                </div>
                {qsPreview? 
                  (
                    <div className="bg-gray-50 border border-gray-200 rounded-lg p-3">
                      <p className="text-xs font-medium text-gray-500 mb-2">Preview:</p>
                      <div className="min-h-[2rem]">
                        <KaTeXRender text={editForm.question} />
                      </div>
                    </div>
                  )
                :
                  (<textarea
                    value={editForm.question}
                    onChange={(e) => setEditForm({ ...editForm, question: e.target.value })}
                    className="w-full border border-gray-300 rounded-lg p-3 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors resize-none overflow-y-auto"
                    rows={4}
                    placeholder="Enter your question here..."
                  />)}
              </div>
            </div>

            {/* Diagram edit */}
            { editForm.diagram && <div>
              <p className="text-xs font-medium text-gray-500 mb-2 absolute p-1 underline">Will add image preview later</p>
              <textarea
                value={editForm.diagram}
                onChange={(e) => setEditForm({ ...editForm, diagram: e.target.value })}
                className="w-full border border-gray-300 rounded-lg p-3 text-sm py-4.5 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors resize-none overflow-y-scroll"
                />
            </div>}

            {/* Options edit */}
            <div className="">
            <div className="relative">
              <div className="flex justify-between">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Edit Options
                </label>
                <button className="" onClick={() => {setOptsPreview(prev => !prev)}}>
                  <Eye className="text-gray-700"/>
                </button>
              </div>
              {optsPreview ? (
                <div className="bg-gray-50 border border-gray-200 rounded-lg p-3">
                  <p className="text-xs font-medium text-gray-500 mb-2">Preview:</p>
                  <div className="space-y-2">
                    {editForm.options.map((opt: string, i: number) => (
                      <div key={i} className="flex items-center space-x-2">
                        <input
                          type="radio"
                          name="correctAnswerPreview"
                          checked={editForm.correctAnswer === opt}
                          readOnly
                          className="w-4 h-4 text-blue-600"
                        />
                        <div className="min-h-[1.5rem] flex-1">
                          <KaTeXRender text={opt} />
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ) : (
                <div className="space-y-2">
                  {editForm.options.map((opt: string, i: number) => (
                    <div key={i} className="flex items-center space-x-2">
                      <input
                        type="radio"
                        name="correctAnswer"
                        checked={editForm.correctAnswer === opt}
                        onChange={() => setEditForm({ ...editForm, correctAnswer: opt })}
                        className="w-4 h-4 text-blue-600"
                      />
                      <input
                        value={opt}
                        onChange={(e) => {
                          const newOpts = [...editForm.options];
                          newOpts[i] = e.target.value;
                          setEditForm({ ...editForm, options: newOpts });
                        }}
                        className="flex-1 border border-gray-300 rounded-lg p-2 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors"
                        placeholder={`Option ${i + 1}`}
                      />
                    </div>
                  ))}
                </div>
              )}
            </div>
            </div>

            {/* Final submission buttons */}
            <div className="flex justify-end space-x-2">
              <button onClick={() => setEditingQ(null)} className="px-4 py-2 border rounded">
                Cancel
              </button>
              <button onClick={handleEditSave} className="px-4 py-2 bg-blue-600 text-white rounded">
                Save
              </button>
            </div>
          </div>
        </div>
      )}
      
      {deleteId  && (
      <div className="fixed inset-0 flex justify-center items-center bg-black/30 backdrop-blur-lg z-50" onClick={()=> setDeleteId(null)}>
        <div className="bg-white rounded-2xl shadow-xl w-80 p-6 flex flex-col items-center gap-4 relative z-50" onClick={(e)=>e.stopPropagation()}>
          <button className="absolute top-3 right-3 text-gray-400 hover:text-gray-600">
            <X size={20} onClick={()=> setDeleteId(null)}/>
          </button>

          <Trash2
            size={40}
            className="text-red-500 animate-bounce"
          />

          <h1 className="text-xl font-semibold text-gray-800">Confirm Delete</h1>
          <p className="text-sm text-gray-500 text-center">
            Are you sure you want to delete this Question? This action cannot be undone.
          </p>

          <div className="flex gap-3 mt-4 w-full">
            <button className="flex-1 py-2 rounded-xl border border-gray-300 text-gray-600 hover:bg-gray-100" onClick={()=> setDeleteId(null)}>
              Cancel
            </button>
            <button className="flex-1 py-2 rounded-xl bg-red-500 text-white hover:bg-red-600" onClick={confirmDelete}>
              Delete
            </button>
          </div>
        </div>
      </div>
      )}
    </div>
  );
};

export default QuestionBank;