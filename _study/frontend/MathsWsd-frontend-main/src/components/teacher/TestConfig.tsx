import { useState, useEffect, useMemo } from "react";
import axios from "axios";
import { Award, BookOpen, Calendar, ChevronDown, ChevronUp, Clock, Trash2, Users, Timer, Minus, X, AlertTriangle } from "lucide-react";
import NavComponent from "./NavComponent";
import Alert from "../all/AlertDialog";

interface Test {
  _id: string;
  date: string;
  time: string;
  classNo: number;
  language: string;
  totalMarks: number;
  marksPQ: number;
  timePQ: number;
  negativeMarksPQ: number;
  chapters: string[];
  createdAt: string;
  updatedAt: string;
  __v: number;
}

const BACK = import.meta.env.PUBLIC_BACKEND;

const TestConfig = () => {
  const [test, setTest] = useState<Test[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [expandedChapters, setExpandedChapters] = useState<Record<string, boolean>>({});
  const [deleteId, setDeleteId] = useState<string | null>();
  const [showConfirm, setShowConfirm] = useState(false)

  const toggleChapters = (testId: string) => {
    setExpandedChapters(prev => ({
      ...prev,
      [testId]: !prev[testId]
    }));
  };

  useEffect(() => {
    const fetchTests = async () => {
      try {
        setError(null);
        
        const response = await axios.get<Test[]>(`${BACK}/api/v1/tests`);
        setTest(response.data);
      } catch (err) {
        console.error('Error fetching tests:', err);
        setError('Failed to load tests. Please try again later.');
      } finally {
        setLoading(false);
      }
    };

    fetchTests();
  }, [loading]);

  const allTest = useMemo(() => test, [test]);

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', { 
      weekday: 'short', 
      year: 'numeric', 
      month: 'short', 
      day: 'numeric' 
    });
  };

  const formatTime = (timeString: string) => {
    const [hours, minutes] = timeString.split(':');
    const date = new Date();
    date.setHours(parseInt(hours), parseInt(minutes));
    return date.toLocaleTimeString('en-US', { 
      hour: 'numeric', 
      minute: '2-digit',
      hour12: true 
    });
  };

  // ✅ Skeleton Loader
  if (loading) {
    return (
      <div className="flex justify-center items-center min-h-screen">
        <NavComponent />
        <div className="p-6 w-full max-w-6xl grid gap-6 md:grid-cols-2 lg:grid-cols-3 mt-20">
          {[...Array(6)].map((_, i) => (
            <div
              key={i}
              className="bg-white border border-gray-200 rounded-xl p-6 shadow-sm animate-pulse"
            >
              <div className="h-6 w-32 bg-gray-200 rounded mb-4"></div>
              <div className="h-4 w-24 bg-gray-200 rounded mb-6"></div>
              <div className="space-y-3">
                <div className="h-4 w-full bg-gray-200 rounded"></div>
                <div className="h-4 w-5/6 bg-gray-200 rounded"></div>
                <div className="h-4 w-2/3 bg-gray-200 rounded"></div>
              </div>
              <div className="mt-6 grid grid-cols-3 gap-3">
                <div className="h-16 bg-gray-200 rounded"></div>
                <div className="h-16 bg-gray-200 rounded"></div>
                <div className="h-16 bg-gray-200 rounded"></div>
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex justify-center items-center min-h-screen">
        <NavComponent />
        <div className="max-w-md w-full text-center bg-red-50 border border-red-200 rounded-2xl p-6 shadow-md">
          <AlertTriangle className="mx-auto h-12 w-12 text-red-500" />
          <h2 className="mt-4 text-lg font-semibold text-red-700">
            Error loading tests
          </h2>
          <p className="mt-2 text-sm text-red-600">{error}</p>
        </div>
      </div>
    );
  }

  const confirmDelete = async () => {
    if (!deleteId) return;
    
    try {[
      await axios.delete(`${BACK}/api/v1/tests/delete/${deleteId}`),
      await axios.delete(`${BACK}/api/v1/testResponse/delete/${deleteId}`)
    ]} catch (err) {
      console.error("Delete failed", err);
      setError("Failed to delete question");
    } finally {
      setDeleteId(null)
      setShowConfirm(true)
      setLoading(true)
    }
  };

  return (
    <div>
      <div>
        <NavComponent />
        <div className="p-4 max-w-7xl mt-20 mx-auto">
        <div className="mb-8 bg-rose-200 border border-rose-300 p-2 w-full md:w-2xl rounded-tl-4xl rounded-br-4xl">
          <h2 className="text-3xl md:text-4xl font-bold text-pink-600 mb-2 pl-3">Available Tests</h2>
          <p className="text-pink-800/60 pl-3">Manage and view all scheduled tests</p>
        </div>
        
        {allTest.length > 0 ? (
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {allTest.map((test) => (
              <div 
                key={test._id} 
                className="bg-white border border-gray-200 rounded-xl p-6 shadow-sm hover:shadow-lg transition-all duration-300 hover:border-blue-200"
              >
                {/* Header */}
                <div className="flex justify-between items-start mb-6">
                  <div>
                    <h3 className="text-xl font-bold text-slate-800 mb-2">
                      Class {test.classNo} Test
                    </h3>
                    <div className="flex items-center space-x-2">
                      <span className="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-rose-100 text-rose-800">
                        {test.language}
                      </span>
                      <span className="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-fuchsia-100 text-fuchsia-800">
                        <Users className="w-3 h-3 mr-1" />
                        Class {test.classNo}
                      </span>
                    </div>
                  </div>
                  <button 
                    className="p-2 hover:bg-red-100 rounded-lg transition-colors duration-200 group" 
                    onClick={() => setDeleteId(test._id)}
                  >
                    <Trash2 className="w-5 h-5 text-red-400 group-hover:text-red-600" />
                  </button>
                </div>

                {/* Test Details */}
                <div className="space-y-4 mb-6">
                  <div className="grid grid-cols-1 gap-3">
                    <div className="flex items-center text-gray-700 text-sm bg-gray-50 rounded-lg p-3">
                      <Calendar className="w-4 h-4 mr-3 text-blue-500" />
                      <span className="font-medium">Date:</span>
                      <span className="ml-2 text-gray-900">{formatDate(test.date)}</span>
                    </div>
                    
                    <div className="flex items-center text-gray-700 text-sm bg-gray-50 rounded-lg p-3">
                      <Clock className="w-4 h-4 mr-3 text-green-500" />
                      <span className="font-medium">Time:</span>
                      <span className="ml-2 text-gray-900">{formatTime(test.time)}</span>
                    </div>
                  </div>
                  
                  <div className="grid grid-cols-3 gap-3 text-sm">
                    <div className="flex flex-col items-center text-center p-3 bg-yellow-50 rounded-lg">
                      <Award className="w-5 h-5 text-yellow-600 mb-1" />
                      <span className="text-xs text-gray-600 font-medium">Total Marks</span>
                      <span className="text-lg font-bold text-gray-900">{test.totalMarks}</span>
                    </div>
                    
                    <div className="flex flex-col items-center text-center p-3 bg-purple-50 rounded-lg">
                      <Timer className="w-5 h-5 text-purple-600 mb-1" />
                      <span className="text-xs text-gray-600 font-medium">Per Question</span>
                      <span className="text-lg font-bold text-gray-900">{test.timePQ}m</span>
                    </div>
                    
                    <div className="flex flex-col items-center text-center p-3 bg-red-50 rounded-lg">
                      <Minus className="w-5 h-5 text-red-600 mb-1" />
                      <span className="text-xs text-gray-600 font-medium">Negative</span>
                      <span className="text-lg font-bold text-gray-900">{test.negativeMarksPQ}</span>
                    </div>
                  </div>
                </div>

                {/* Chapters Section */}
                {test.chapters.length > 0 && (
                  <div className="border-t">
                    <div className="flex items-center justify-between pt-4 mb-2 p-1" onClick={() => toggleChapters(test._id)}>
                      <div className="flex items-center">
                        <BookOpen className="w-4 h-4 mr-2 text-indigo-500" />
                        <p className="text-sm font-medium text-gray-700">
                          Chapters ({test.chapters.length})
                        </p>
                      </div>
                      <button
                        className="rounded-full p-1 hover:bg-gray-200 transition-colors duration-200"
                      >
                        {expandedChapters[test._id] ? 
                          <ChevronUp className="w-4 h-4 text-gray-600" /> : 
                          <ChevronDown className="w-4 h-4 text-gray-600" />
                        }
                      </button>
                    </div>
                    
                    {expandedChapters[test._id] && (
                      <div className="flex flex-wrap gap-2">
                        {test.chapters.map((chapter, index) => (
                          <span
                            key={`${chapter}-${index}`}
                            className="inline-flex items-center px-3 py-1 text-xs font-medium bg-indigo-50 text-indigo-700 rounded-full border border-indigo-200 hover:bg-indigo-100 transition-colors duration-200"
                          >
                            {chapter}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>
                )}
              </div>
            ))}
          </div>
        ) : (
          <div className="text-center p-12">
            <div className="max-w-md mx-auto">
              <div className="w-20 h-20 mx-auto mb-6 bg-gradient-to-br from-blue-100 to-indigo-100 rounded-full flex items-center justify-center">
                <BookOpen className="w-10 h-10 text-indigo-500" />
              </div>
              <h3 className="text-xl font-semibold text-gray-800 mb-3">No tests available</h3>
              <p className="text-gray-500 mb-6">Check back later for new tests or contact your instructor.</p>
              <button className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors duration-200" onClick={()=>{location.href="/teacher/test"}}>
                Create New Test
              </button>
            </div>
          </div>
        )}
      </div>
      </div>
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
            Deleting this test config would also delete the corresponding submitted responses.
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

      {showConfirm && <Alert title="DELETED" text="The test and the corresponding responses were successfully deleted" type="success" onClose={()=>setShowConfirm(false)} /> }
    </div>
  );
};

export default TestConfig;
