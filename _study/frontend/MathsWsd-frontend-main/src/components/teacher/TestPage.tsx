import { useState, useEffect, useMemo } from "react";
import NavComponent from "./NavComponent";
import { BookOpenCheck, X, AlertCircle, CheckCircle, LoaderCircle } from "lucide-react";

interface FormData {
  date: string;
  time: string;
  classNo: number;
  language: string;
  totalMarks: number;
  marksPQ: number;
  timePQ: number;
  negativeMarksPQ: number;
  chapters: string[];
}

interface Question {
  chapter: string;
  classNo: number;
  language: string;
}

interface Props {
  chapters: {
    classNo9Chaps: string[];
    classNo10Chaps: string[];
    classNo11Chaps: string[];
    classNo12Chaps: string[];
  };
}

interface PopupProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  message: string;
  type: 'success' | 'error';
}

const Popup: React.FC<PopupProps> = ({ isOpen, onClose, title, message, type }) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-teal-300/20 backdrop-blur-md bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-2xl p-6 max-w-md mx-4 shadow-2xl transform transition-all">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-3">
            {type === 'success' ? (
              <div className="p-2 bg-green-100 rounded-full">
                <CheckCircle className="w-6 h-6 text-green-600" />
              </div>
            ) : (
              <div className="p-2 bg-red-100 rounded-full">
                <AlertCircle className="w-6 h-6 text-red-600" />
              </div>
            )}
            <h3 className={`text-lg font-semibold ${
              type === 'success' ? 'text-green-800' : 'text-red-800'
            }`}>
              {title}
            </h3>
          </div>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 rounded-full transition-colors"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>
        <p className="text-gray-700 mb-6">
          {message}
        </p>
        <div className="flex justify-end">
          <button
            onClick={onClose}
            className={`px-6 py-2 rounded-lg font-medium transition-colors ${
              type === 'success' 
                ? 'bg-green-500 hover:bg-green-600 text-white' 
                : 'bg-red-500 hover:bg-red-600 text-white'
            }`}
          >
            OK
          </button>
        </div>
      </div>
    </div>
  );
};

const BACKEND = import.meta.env.PUBLIC_BACKEND
// const BACKEND = "http://localhost:4000"

const TestPage = (props: Props) => {

  const [language, setLanguage] = useState<string | null>(null);
  const [date, setDate] = useState('')
  const [time, setTime] = useState('')
  const [classNo, setClassNo] = useState(11)
  const [totalMarks, setTotalMarks] = useState<number>()
  const [marksPQ, setMarksPQ] = useState<number>()
  const [timePQ, setTimePQ] = useState<number>()
  const [nveMarks, setNveMarks] = useState(false)
  const [negativeMarksPQ, setNegativeMarksPQ] = useState<number>(0)
  const [chapterList, setChapterList] = useState<string[]>()
  const [selectedChapters, setSelectedChapters] = useState<string[]>([])
  const [questionCounts, setQuestionCounts] = useState<Record<string, number>>({})
  const [isSubmitting, setIsSubmitting] = useState(false)

  // Popup state
  const [popup, setPopup] = useState<{
    isOpen: boolean;
    title: string;
    message: string;
    type: 'success' | 'error';
  }>({
    isOpen: false,
    title: '',
    message: '',
    type: 'error'
  });

  const chapters = props.chapters 

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


  useEffect(() => setChapterList(chList), [chList])

  // Initialize date and time with current values
  useEffect(() => {
    const now = new Date();
    setDate(now.toISOString().split('T')[0]);
    setTime(now.toTimeString().split(':').slice(0, 2).join(':'));
  }, []);

  // Helper function to show popup
  const showPopup = (title: string, message: string, type: 'success' | 'error') => {
    setPopup({
      isOpen: true,
      title,
      message,
      type
    });
  };

  const closePopup = () => {
    setPopup(prev => ({ ...prev, isOpen: false }));
  };

  // Fetch question counts
  useEffect(() => {
    const fetchQuestionCounts = async () => {
      try {
        console.log('Fetching question counts from:', `${BACKEND}/api/v1/question/questions`);
        // const res = await fetch(`${BACKEND}/api/v1/question/questions`);
        const res = await fetch(`${BACKEND}/api/v1/question/questions`, {
        method: "GET",
        credentials: "include", // if you are using cookies/session auth
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${localStorage.getItem("token") || ""}`, // Include token if available
        },
      });
        
        if (!res.ok) {
          throw new Error(`HTTP error! status: ${res.status}`);
        }
        
        const json = await res.json();
        console.log('API Response:', json);
        
        if (json.success && json.data) {
          const counts: Record<string, number> = {};
          json.data.forEach((q: Question) => {
            const key = `${q.classNo}-${q.chapter}-${q.language}`;
            counts[key] = (counts[key] || 0) + 1;
          });
          console.log('Question counts:', counts);
          setQuestionCounts(counts);
        } else {
          console.warn('API response structure unexpected:', json);
          // Fallback: set some dummy data for testing
          const dummyCounts: Record<string, number> = {};
          chapters.classNo9Chaps.forEach(ch => {
            dummyCounts[`9-${ch}`] = Math.floor(Math.random() * 20) + 5;
          });
          chapters.classNo10Chaps.forEach(ch => {
            dummyCounts[`10-${ch}`] = Math.floor(Math.random() * 20) + 5;
          });
          chapters.classNo11Chaps.forEach(ch => {
            dummyCounts[`11-${ch}`] = Math.floor(Math.random() * 20) + 5;
          });
          chapters.classNo12Chaps.forEach(ch => {
            dummyCounts[`12-${ch}`] = Math.floor(Math.random() * 20) + 5;
          });
          setQuestionCounts(dummyCounts);
        }

      } catch (error) {
        console.error("Failed to fetch questions:", error);
        // Fallback: set some dummy data for testing
        const dummyCounts: Record<string, number> = {};
        chapters.classNo9Chaps.forEach(ch => {
          dummyCounts[`9-${ch}`] = Math.floor(Math.random() * 20) + 5;
        });
        chapters.classNo10Chaps.forEach(ch => {
          dummyCounts[`10-${ch}`] = Math.floor(Math.random() * 20) + 5;
        });
        chapters.classNo11Chaps.forEach(ch => {
          dummyCounts[`11-${ch}`] = Math.floor(Math.random() * 20) + 5;
        });
        chapters.classNo12Chaps.forEach(ch => {
          dummyCounts[`12-${ch}`] = Math.floor(Math.random() * 20) + 5;
        });
        console.log('Using dummy data:', dummyCounts);
        setQuestionCounts(dummyCounts);
      }
    };

    if (chapters.classNo9Chaps.length > 0 || chapters.classNo10Chaps.length > 0 || chapters.classNo11Chaps.length > 0 || chapters.classNo12Chaps.length > 0) {
      fetchQuestionCounts();
    }
  }, [chapters]);

  // Handle chapter selection
  const handleChapterToggle = (chapter: string) => {
    setSelectedChapters(prev =>
      prev.includes(chapter) ? prev.filter(c => c !== chapter) : [...prev, chapter]
    );
  };

  const handleSelectAll = () => {
    if (chapterList) {
      setSelectedChapters(chapterList);
    }
  };

  const handleClearAll = () => setSelectedChapters([]);

  // Generate JSON response
  const generateFormData = (): FormData => ({
    date,
    time,
    classNo,
    language: language || '',
    totalMarks: totalMarks || 0,
    marksPQ: marksPQ || 0,
    timePQ: timePQ || 0,
    negativeMarksPQ: nveMarks ? negativeMarksPQ : 0,
    chapters: selectedChapters
  });

  const handleSubmit = async (e: React.FormEvent) => {

    setIsSubmitting(true)

    e.preventDefault();
    
    // Validation
    if (!language) {
      showPopup('Language Required', 'Please select a language before proceeding.', 'error');
      setIsSubmitting(false)
      return;
    }
    if (!totalMarks) {
      showPopup('Total Marks Required', 'Please enter the total marks for the test.', 'error');
      setIsSubmitting(false)
      return;
    }
    if (!marksPQ) {
      showPopup('Marks Per Question Required', 'Please enter marks per question.', 'error');
      setIsSubmitting(false)
      return;
    }
    if (!timePQ) {
      showPopup('Time Per Question Required', 'Please enter time per question in minutes.', 'error');
      setIsSubmitting(false)
      return;
    }
    if (selectedChapters.length === 0) {
      showPopup('Chapters Required', 'Please select at least one chapter for the test.', 'error');
      setIsSubmitting(false)
      return;
    }

    const output = generateFormData();
    console.log('Sending JSON payload:', JSON.stringify(output, null, 2));

    try {
      const response = await fetch(`${BACKEND}/api/v1/tests`, {
        method: "POST",
        headers: { 
          "Content-Type": "application/json",
        },
        body: JSON.stringify(output),
      });

      console.log('Response status:', response.status);
      console.log('Response headers:', response.headers);

      // Check if response is JSON
      const contentType = response.headers.get('content-type');
      if (!contentType || !contentType.includes('application/json')) {
        const textResponse = await response.text();
        console.error('Non-JSON response received:', textResponse);
        throw new Error(`Server returned non-JSON response (${response.status}): ${textResponse.substring(0, 200)}...`);
      }

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || `HTTP ${response.status}: Something went wrong`);
      }

      showPopup('Success!', 'Test configuration has been saved successfully!', 'success');
      console.log("Saved test config:", data.test);
      
      // Reset form state
      setSelectedChapters([]);
      setTotalMarks(undefined);
      setMarksPQ(undefined);
      setTimePQ(undefined);
      setNegativeMarksPQ(0);
      setNveMarks(false);
      setLanguage(null);
      
    } catch (err) {
      console.error("Failed to submit test config:", err);
      
      if (err instanceof SyntaxError) {
        showPopup('Server Error', 'Server returned invalid response (likely HTML error page). Check if the API endpoint exists and is working.', 'error');
      } else {
        showPopup('Submission Failed', `Failed to submit test configuration: ${err instanceof Error ? err.message : String(err)}`, 'error');
      }
    } finally {
      setIsSubmitting(false)
    }
  };

  return (
    <div className="max-w-6xl mx-auto p-6 min-h-screen bg-cyan-100 pt-10">
      
      <NavComponent />

      {/* Popup Component */}
      <Popup
        isOpen={popup.isOpen}
        onClose={closePopup}
        title={popup.title}
        message={popup.message}
        type={popup.type}
      />

      {/* Header section */}
      <header className="max-w-5xl mx-auto bg-purple-50 px-5 sm:px-8 py-4 sm:py-6 shadow-md shadow-violet-200 rounded-2xl mt-12 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">

        <div className="flex items-center gap-3 sm:gap-4">
          <div className="p-2.5 sm:p-3 bg-purple-200 rounded-2xl text-purple-700 shadow-sm">
            <BookOpenCheck strokeWidth={2.2} size={30} className="sm:size-10" />
          </div>
          <h1 className="text-3xl md:text-5xl font-extrabold text-purple-700 tracking-tight">
            Create Test
          </h1>
        </div>

        <button onClick={() => {location.href="/teacher/test-configs"}} className="w-full sm:w-auto px-5 py-2.5 sm:px-6 sm:py-3 rounded-xl bg-pink-500 text-white font-semibold shadow-md hover:bg-pink-600 hover:shadow-lg transition">
          Check Old Test Configs
        </button>
      </header>
      
      <main className="flex-1 py-7">
        <div onSubmit={handleSubmit} className="bg-white rounded-2xl shadow-xl p-6 md:p-10 transition-all hover:shadow-2xl space-y-6">
          
          {/* Date and Time */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label className="block text-lg font-medium text-gray-700 mb-2">Date</label>
              <input
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                className="w-full px-4 py-3 border bg-purple-50 rounded-xl border-purple-300 shadow-sm focus:outline-none focus:ring-2 focus:ring-purple-400 focus:border-purple-400"
                required
              />
            </div>
            <div>
              <label className="block text-lg font-medium text-gray-700 mb-2">Time</label>
              <input
                type="time"
                value={time}
                onChange={(e) => setTime(e.target.value)}
                className="w-full px-4 py-3 border bg-purple-50 rounded-xl border-purple-300 shadow-sm focus:outline-none focus:ring-2 focus:ring-purple-400 focus:border-purple-400"
                required
              />
            </div>
          </div>

          {/* Selecting Language */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-3">
              Select Language
            </label>
            <div className="inline-flex items-center justify-center">
              <div className="relative bg-sky-100 rounded-2xl p-1 shadow-sm border border-sky-200 backdrop-blur-sm">
                <div className="flex w-2xs gap-1">
                  {['Bengali','English'].map((lang) => (
                    <button
                      key={lang}
                      type="button"
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
          </div>

          {/* Selecting Class (Removed 'Both' option) */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-3">
              Select Class
            </label>
            <div className="inline-flex items-center justify-center">
              <div className="relative bg-purple-100 rounded-2xl p-1 shadow-sm border border-purple-200 backdrop-blur-sm">
                <div className="flex w-2xs gap-1">
                  {[9,10,11,12].map((num) => (
                    <button
                      key={num}
                      type="button"
                      onClick={() => {
                        setClassNo(num);
                        setSelectedChapters([]); // Clear selected chapters when class changes
                      }}
                      className={`
                        flex-1 px-6 py-2 rounded-xl font-medium text-sm
                        transition-all duration-300 ease-[cubic-bezier(0.4,0,0.2,1)]
                        ${classNo === num
                          ? 'bg-purple-500 text-white shadow-sm scale-[1.02]'
                          : 'text-purple-700 hover:text-purple-800 hover:bg-purple-200/60'
                        }
                        focus:outline-none focus:ring-2 focus:ring-purple-300 focus:ring-offset-1 focus:ring-offset-purple-50
                        active:scale-95
                      `}
                      aria-pressed={classNo === num}
                      role="tab"
                    >
                      {num}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>

          {/* Total marks */}
          <div className="space-y-3">
            <label className="block text-sm font-medium text-gray-700">
              Total Marks
            </label>

            <input
              type="number"
              name="totalMarks"
              value={totalMarks || ''}
              min={1}
              onChange={(e) => setTotalMarks(Number(e.target.value))}
              placeholder="Enter total marks..."
              className="bg-purple-50 px-4 py-2 rounded-xl w-4xs border border-purple-300 shadow-sm focus:outline-none focus:ring-2 focus:ring-purple-400 focus:border-purple-400"
            />

            <div className="flex gap-3">
              {[40, 80, 100].map((m) => (
                <button
                  key={m}
                  type="button"
                  onClick={() => setTotalMarks(m)}
                  className={`px-4 py-2 rounded-xl border text-sm font-medium transition 
                    ${
                      totalMarks === m
                        ? "bg-purple-500 text-white border-purple-500"
                        : "bg-white text-gray-700 border-gray-300 hover:bg-purple-50"
                    }`}
                >
                  {m}
                </button>
              ))}
            </div>
          </div>

          {/* Enable/Disable Negative Marks */}
          <div className="mt-8">
            <button
              type="button"
              onClick={() => setNveMarks(!nveMarks)}
              className={`px-4 py-2 rounded-xl font-medium transition shadow-sm
                ${nveMarks 
                  ? "bg-purple-500 text-white hover:bg-purple-600" 
                  : "bg-gray-200 text-gray-700 hover:bg-gray-300"}`}
            >
              {nveMarks ? "Disable Negative Marks" : "Enable Negative Marks"}
            </button>
          </div>
          
          <div className="space-y-4">
            {/* Marks per Question */}
            <div className="flex items-center gap-3">
              <label className="font-medium text-gray-700 w-40">Marks per Question</label>
              <input
                type="number"
                min={1}
                value={marksPQ || ''}
                onChange={(e) => setMarksPQ(Number(e.target.value))}
                className={`p-2 rounded-lg border w-40 focus:outline-none focus:ring-2 transition placeholder:text-gray-400 ${
                  totalMarks
                    ? "bg-white border-gray-300 focus:ring-blue-400"
                    : "bg-gray-100 border-gray-200 text-gray-400 cursor-not-allowed"
                }`}
                placeholder="e.g., 4, 5, 1"
                disabled={!totalMarks}
              />
            </div>

            {/* Time per Question */}
            <div className="flex items-center gap-3">
              <label className="font-medium text-gray-700 w-40">Test Duration (mins)</label>
              <input
                type="number"
                min={1}
                value={timePQ || ''}
                onChange={(e) => setTimePQ(Number(e.target.value))}
                className="p-2 rounded-lg border w-40 bg-white border-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-400 placeholder:text-gray-400"
                placeholder="e.g., 120.."
              />
            </div>

            {/* Negative Marking */}
            <div className="flex items-center gap-3">
              <label className="font-medium text-gray-700 w-40">Negative Marking</label>
              <input
                type="number"
                value={negativeMarksPQ || ''}
                onChange={(e) => setNegativeMarksPQ(Number(e.target.value))}
                className={`p-2 rounded-lg border w-40 focus:outline-none focus:ring-2 transition placeholder:text-gray-400 ${
                  nveMarks
                    ? "bg-white border-gray-300 focus:ring-red-400"
                    : "bg-gray-100 border-gray-200 text-gray-400 cursor-not-allowed"
                }`}
                placeholder="e.g., 0.25, 1,"
                disabled={!nveMarks}
              />
            </div>
          </div>

          {/* Chapter Selection */}
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <h3 className="text-lg font-medium text-gray-700">
                Select Chapters (Class {classNo})
              </h3>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={handleSelectAll}
                  disabled={!language}
                  className={`px-3 py-1 text-sm rounded-lg transition ${
                    !language 
                      ? 'bg-gray-100 text-gray-400 cursor-not-allowed'
                      : 'bg-green-100 text-green-700 hover:bg-green-200'
                  }`}
                >
                  Select All
                </button>
                <button
                  type="button"
                  onClick={handleClearAll}
                  disabled={!language}
                  className={`px-3 py-1 text-sm rounded-lg transition ${
                    !language 
                      ? 'bg-gray-100 text-gray-400 cursor-not-allowed'
                      : 'bg-red-100 text-red-700 hover:bg-red-200'
                  }`}
                >
                  Clear All
                </button>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 max-h-96 overflow-y-auto">
              {chapterList && chapterList.map((ch) => {
                const count = language ? questionCounts[`${classNo}-${ch}-${language}`] || 0 : 0;
                const isDisabled = !language;
                return (
                  <label
                    key={ch}
                    className={`flex items-center justify-between p-3 border-2 rounded-xl transition-all duration-200 ${
                      isDisabled 
                        ? 'border-gray-200 bg-gray-50 text-gray-400 cursor-not-allowed'
                        : selectedChapters.includes(ch)
                        ? 'border-purple-500 bg-purple-50 text-purple-800 cursor-pointer'
                        : 'border-gray-200 hover:border-gray-300 bg-white cursor-pointer'
                    }`}
                  >
                    <div className="flex items-center">
                      <input
                        type="checkbox"
                        checked={selectedChapters.includes(ch)}
                        onChange={() => !isDisabled && handleChapterToggle(ch)}
                        disabled={isDisabled}
                        className="w-4 h-4 text-purple-600 rounded focus:ring-2 focus:ring-purple-500 mr-3 disabled:opacity-50"
                      />
                      <span className="font-medium text-sm">{ch}</span>
                    </div>
                    <span className={`text-xs ml-2 ${isDisabled ? 'text-gray-400' : count > 0 ? 'text-gray-500' : 'text-red-500'}`}>
                      ({count})
                    </span>
                  </label>
                );
              })}
            </div>

            {selectedChapters.length > 0 && (
              <div className="p-3 bg-purple-50 rounded-xl">
                <p className="text-purple-800 font-medium text-sm">
                  Selected: {selectedChapters.length} chapter(s)
                </p>
              </div>
            )}
          </div>

          {/* Submit button */}
          <div className="flex justify-center pt-6">
            {isSubmitting ?(
              <button disabled className="bg-gray-300 text-gray-500 cursor-not-allowed px-8 py-3 rounded-xl font-medium transition-all duration-200"><LoaderCircle className="animate-spin" /></button>
            ):(
            <button 
              type="submit"
              onClick={handleSubmit}
              disabled={selectedChapters.length === 0 || !language || !totalMarks}
              className={`px-8 py-3 rounded-xl font-medium transition-all duration-200 ${
                selectedChapters.length === 0 || !language || !totalMarks
                  ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                  : 'bg-purple-500 text-white hover:bg-purple-600 shadow-lg hover:shadow-xl'
              }`}
            >
              CREATE TEST
            </button>)}
          </div>

        </div>
      </main>
    </div>
  );
};

export default TestPage;
