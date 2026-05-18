import React, { useEffect, useState, useRef } from "react";
import KaTeXRender from "../all/KatexRender";
import Alert from "../all/AlertDialog"; // Import your AlertDialog component
import {
  Clock,
  CheckCircle,
  AlertCircle,
  Send,
  Eye,
  RotateCcw,
  ChevronLeft,
  ChevronRight,
  Loader2
} from "lucide-react";

const BACKEND = import.meta.env.PUBLIC_BACKEND

interface Question {
  _id: string;
  chapter: string;
  classNo: number;
  options: string[];
  question: string;
  diagram?: string;
  visited?: boolean;
}

interface AnswerMap {
  [questionId: string]: string;
}

interface TestConfig {
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
}

interface TestResponse {
  questionNumber: number;
  questionId: string;
  selectedOption: string | null;
}

interface RulesPopupProps {
  isOpen: boolean;
  onClose: () => void;
  onAgree: () => void;
}

const RulesPopup: React.FC<RulesPopupProps> = ({ isOpen, onClose, onAgree }) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-96 overflow-y-auto">
        <div className="flex justify-between items-center p-4 border-b">
          <h3 className="text-lg font-semibold text-gray-900">Test Rules & Instructions</h3>
        </div>
        <div className="p-4">
          <div className="space-y-3 text-sm">
            <div className="bg-yellow-50 p-3 rounded border-l-4 border-yellow-400">
              <div className="flex items-center">
                <AlertCircle className="text-yellow-600 mr-2" size={16} />
                <p className="font-semibold text-yellow-800">Important Instructions</p>
              </div>
            </div>
            <ul className="space-y-2 text-gray-700">
              <li className="flex items-start">
                <CheckCircle className="text-green-500 mr-2 mt-0.5 flex-shrink-0" size={16} />
                <span>Once you click "I Agree & Start Test", the test will begin in fullscreen mode</span>
              </li>
              <li className="flex items-start">
                <AlertCircle className="text-red-500 mr-2 mt-0.5 flex-shrink-0" size={16} />
                <span>Do not press ESC or exit fullscreen during the test</span>
              </li>
              <li className="flex items-start">
                <AlertCircle className="text-red-500 mr-2 mt-0.5 flex-shrink-0" size={16} />
                <span>Exiting fullscreen will automatically submit your test</span>
              </li>
              <li className="flex items-start">
                <AlertCircle className="text-red-500 mr-2 mt-0.5 flex-shrink-0" size={16} />
                <span>Window resizing, tab switching, or floating windows will auto-submit the test</span>
              </li>
              <li className="flex items-start">
                <CheckCircle className="text-blue-500 mr-2 mt-0.5 flex-shrink-0" size={16} />
                <span>You cannot restart or retake the test once submitted</span>
              </li>
              <li className="flex items-start">
                <Eye className="text-gray-500 mr-2 mt-0.5 flex-shrink-0" size={16} />
                <span>Navigate between questions using the question grid</span>
              </li>
              <li className="flex items-start">
                <CheckCircle className="text-green-500 mr-2 mt-0.5 flex-shrink-0" size={16} />
                <span>Your answers are saved automatically</span>
              </li>
              <li className="flex items-start">
                <Send className="text-blue-500 mr-2 mt-0.5 flex-shrink-0" size={16} />
                <span>Submit your test before time runs out</span>
              </li>
              <li className="flex items-start">
                <CheckCircle className="text-green-500 mr-2 mt-0.5 flex-shrink-0" size={16} />
                <span>Ensure stable internet connection throughout the test</span>
              </li>
            </ul>
            <div className="flex justify-end space-x-3 mt-6">
              <button
                onClick={onClose}
                className="px-4 py-2 bg-gray-300 text-gray-700 rounded hover:bg-gray-400 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={onAgree}
                className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 transition-colors flex items-center"
              >
                <CheckCircle className="mr-2" size={16} />
                I Agree & Start Test
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const CheckingPopup: React.FC<{ isOpen: boolean }> = ({ isOpen }) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
        <div className="p-6 text-center">
          <Loader2 className="animate-spin text-blue-600 mx-auto mb-4" size={32} />
          <h3 className="text-lg font-semibold text-gray-900 mb-2">Checking...</h3>
          <p className="text-gray-600">Verifying your eligibility...</p>
        </div>
      </div>
    </div>
  );
};

const StudentTest: React.FC = () => {
  // === State ===
  const [questions, setQuestions] = useState<Question[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [answers, setAnswers] = useState<AnswerMap>({});
  const [testStarted, setTestStarted] = useState(false);
  const [timeLeft, setTimeLeft] = useState(0);
  const [intervalId, setIntervalId] = useState<NodeJS.Timeout | null>(null);
  const [startAllowed, setStartAllowed] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [testEndTime, setTestEndTime] = useState<Date | null>(null);
  const [testConfig, setTestConfig] = useState<TestConfig | null>(null);
  const [serverTime, setServerTime] = useState<Date | null>(null);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [loading, setLoading] = useState(true);
  
  // New state for window monitoring
  const [initialWindowSize, setInitialWindowSize] = useState<{width: number, height: number} | null>(null);
  
  // Alert states
  const [alert, setAlert] = useState<{
    show: boolean;
    title: string;
    text: string;
    type: "success" | "error" | "warning" | "info";
  }>({
    show: false,
    title: "",
    text: "",
    type: "info"
  });

  // Other popup states
  const [showRulesPopup, setShowRulesPopup] = useState(false);
  const [showCheckingPopup, setShowCheckingPopup] = useState(false);

  // === Refs ===
  const answersRef = useRef<AnswerMap>(answers);

  // Mock student data - you can replace this with actual localStorage logic
  let classNo: number | null = null;
  let studentMobile: string | null = null;
  let language: string | null = null;
  
  if(typeof window !== 'undefined') {
    const storedStudent = localStorage.getItem("student");
    if (storedStudent) {
      const student = JSON.parse(storedStudent);
      classNo = student.classNo;
      studentMobile = student.studentMobile;
      language = student.language;
    }
  }

  // Helper function to show alerts
  const showAlert = (title: string, text: string, type: "success" | "error" | "warning" | "info" = "info") => {
    setAlert({
      show: true,
      title,
      text,
      type
    });
  };

  const closeAlert = () => {
    setAlert(prev => ({ ...prev, show: false }));
  };

  // FIXED: Enhanced submit function with reason logging
  const autoSubmitExam = (reason: string) => {
    if (submitted || isSubmitting) return;
    
    console.log(`Auto-submitting test due to: ${reason}`);
    
    // CRITICAL FIX: Get the latest answers from ref BEFORE any state updates
    const finalAnswers = { ...answersRef.current };
    
    showAlert("Test Auto-Submitted", `Test automatically submitted due to ${reason}`, "warning");
    
    // Clear timer immediately
    if (intervalId) {
      clearInterval(intervalId);
      setIntervalId(null);
    }
    
    // Submit with captured answers - NO setTimeout delay
    submitTest(finalAnswers);
    
    // Redirect after a short delay to show alert
    setTimeout(() => {
      location.href = "/";
    }, 2000);
  };

  // FIXED: Enhanced window resize handler
  const handleWindowResize = () => {
    if (!testStarted || submitted || isSubmitting) return;
    
    const currentWidth = window.innerWidth;
    const currentHeight = window.innerHeight;
    
    // Store initial dimensions when test starts
    if (!initialWindowSize) {
      setInitialWindowSize({ width: currentWidth, height: currentHeight });
      return;
    }
    
    // Check for significant resize (more than 10% change)
    const widthChange = Math.abs(currentWidth - initialWindowSize.width) / initialWindowSize.width;
    const heightChange = Math.abs(currentHeight - initialWindowSize.height) / initialWindowSize.height;
    
    if (widthChange > 0.1 || heightChange > 0.1) {
      console.log("Significant window resize detected:", {
        initial: initialWindowSize,
        current: { width: currentWidth, height: currentHeight },
        changes: { widthChange: widthChange * 100, heightChange: heightChange * 100 }
      });
      autoSubmitExam("window resize");
    }
  };

  // Enhanced window blur handler (detects floating windows, tab switches, etc.)
  const handleWindowBlur = () => {
    if (!testStarted || submitted || isSubmitting) return;
    console.log("Window blur detected - potential floating window or tab switch");
    autoSubmitExam("window blur/focus loss");
  };

  // Window focus handler for logging
  const handleWindowFocus = () => {
    if (!testStarted || submitted || isSubmitting) return;
    console.log("Window focused again");
  };

  // Mobile-specific handlers for orientation and screen changes
  const handleOrientationChange = () => {
    if (!testStarted || submitted || isSubmitting) return;
    console.log("Orientation change detected");
    // Small delay to allow orientation change to complete
    setTimeout(() => {
      autoSubmitExam("orientation change");
    }, 500);
  };

  // Detect mobile floating windows through screen size changes
  const handleScreenChange = () => {
    if (!testStarted || submitted || isSubmitting) return;
    const availableScreenHeight = window.screen.availHeight;
    const windowHeight = window.innerHeight;
    
    // If window height is significantly less than available screen height,
    // it might indicate a floating window or split screen
    if (windowHeight < availableScreenHeight * 0.8) {
      console.log("Potential floating window detected:", {
        availableScreenHeight,
        windowHeight,
        ratio: windowHeight / availableScreenHeight
      });
      autoSubmitExam("potential floating window");
    }
  };

  // Context menu prevention (right-click)
  const handleContextMenu = (e: Event) => {
    if (testStarted && !submitted) {
      e.preventDefault();
      console.log("Right-click attempt blocked");
    }
  };

  // Enhanced keyboard handler
  const handleKeyDown = (e: KeyboardEvent) => {
    if (!testStarted || submitted || isSubmitting) return;
    
    // Block F12, F11, Ctrl+Shift+I, Ctrl+Shift+J, Ctrl+U, etc.
    if (
      e.key === 'F12' ||
      e.key === 'F11' ||
      (e.ctrlKey && e.shiftKey && (e.key === 'I' || e.key === 'J' || e.key === 'C')) ||
      (e.ctrlKey && e.key === 'u')
    ) {
      e.preventDefault();
      autoSubmitExam("developer tools attempt");
      return;
    }
    
    // Original ESC handling
    if (e.key === 'Escape') {
      e.preventDefault();
      autoSubmitExam("ESC key pressed");
    }
  };

  // Enhanced visibility change handler
  const handleVisibilityChange = () => {
    if (!testStarted || submitted || isSubmitting) return;
    
    if (document.hidden) {
      console.log("Page hidden - tab switch or minimize detected");
      autoSubmitExam("tab switch/minimize");
    }
  };

  // Mouse leave detection (cursor leaving window area)
  const handleMouseLeave = () => {
    if (!testStarted || submitted || isSubmitting) return;
    console.log("Mouse left window area");
    // Could implement auto-submit here if needed for stricter monitoring
  };

  // Enhanced function to select appropriate test from array
  const selectAppropriateTest = (tests: TestConfig[], currentTime: Date): TestConfig | null => {
    console.log("=== TEST SELECTION DEBUG ===");
    console.log("Current server time:", currentTime.toLocaleString());
    console.log("Available tests:", tests.length);

    const availableTests: TestConfig[] = [];
    const debugInfo: any[] = [];

    for (const test of tests) {
      try {
        const testDateTime = new Date(`${test.date}T${test.time}`);
        const testDurationMinutes = test.timePQ; // Use timePQ directly as total duration
        const testEndTime = new Date(testDateTime.getTime() + testDurationMinutes * 60 * 1000);

        const info = {
          id: test._id,
          date: test.date,
          time: test.time,
          start: testDateTime.toLocaleString(),
          end: testEndTime.toLocaleString(),
          duration: testDurationMinutes,
          totalMarks: test.totalMarks,
          timePQ: test.timePQ,
          isStarted: currentTime >= testDateTime,
          isEnded: currentTime >= testEndTime,
          isActive: currentTime >= testDateTime && currentTime <= testEndTime
        };

        debugInfo.push(info);
        console.log(`Test ${test._id}:`);
        console.log(` Date/Time: ${test.date} ${test.time}`);
        console.log(` Start: ${testDateTime.toLocaleString()}`);
        console.log(` End: ${testEndTime.toLocaleString()}`);
        console.log(` Duration: ${testDurationMinutes} minutes`);
        console.log(` Total Marks: ${test.totalMarks}, Total Duration: ${test.timePQ}`);
        console.log(` Is Started: ${info.isStarted}`);
        console.log(` Is Ended: ${info.isEnded}`);
        console.log(` Is Active: ${info.isActive}`);

        // Check if test is available (not ended yet)
        if (currentTime <= testEndTime) {
          availableTests.push(test);
          console.log(` ✓ Available`);
        } else {
          console.log(` ✗ Ended`);
        }
      } catch (error) {
        console.error(`Error processing test ${test._id}:`, error);
      }
    }

    console.log("Debug info:", debugInfo);
    console.log("Available tests after filtering:", availableTests.length);

    if (availableTests.length === 0) {
      console.log("❌ No available tests found");
      // For debugging purposes, let's try to select the most recent test anyway
      if (tests.length > 0) {
        const sortedByDate = [...tests].sort((a, b) => {
          const dateTimeA = new Date(`${a.date}T${a.time}`).getTime();
          const dateTimeB = new Date(`${b.date}T${b.time}`).getTime();
          return dateTimeB - dateTimeA; // Most recent first
        });
        console.log("⚠️ Selecting most recent test for debugging:", sortedByDate[0]._id);
        return sortedByDate[0];
      }
      return null;
    }

    // Sort by start time (earliest first)
    availableTests.sort((a, b) =>
      new Date(`${a.date}T${a.time}`).getTime() - new Date(`${b.date}T${b.time}`).getTime()
    );

    // Find currently active test (started but not ended)
    const currentlyActiveTest = availableTests.find(test => {
      const testStart = new Date(`${test.date}T${test.time}`);
      const testDurationMinutes = test.timePQ; // Use timePQ directly as total duration
      const testEnd = new Date(testStart.getTime() + testDurationMinutes * 60 * 1000);
      return currentTime >= testStart && currentTime <= testEnd;
    });

    if (currentlyActiveTest) {
      console.log("✅ Selected currently active test:", currentlyActiveTest._id);
      return currentlyActiveTest;
    }

    // Otherwise, select the next upcoming test
    const upcomingTest = availableTests.find(test => {
      const testStart = new Date(`${test.date}T${test.time}`);
      return currentTime < testStart;
    });

    if (upcomingTest) {
      console.log("✅ Selected upcoming test:", upcomingTest._id);
      return upcomingTest;
    }

    // If no upcoming tests, return the latest available test
    console.log("✅ Selected latest available test:", availableTests[availableTests.length - 1]._id);
    return availableTests[availableTests.length - 1];
  };

  // Fisher-Yates shuffle implementation
  const fisherYatesShuffle = <T,>(array: T[]): T[] => {
    const shuffled = [...array]; // Create a copy to avoid mutating original
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
  };

  // Enhanced question selection algorithm with Fisher-Yates shuffle
  const selectQuestionsWithPriority = (filteredQuestions: Question[], config: TestConfig): Question[] => {
    console.log(`Selecting questions for test with ${config.totalMarks} total marks and ${config.marksPQ} marks per question`);
    console.log(`Available questions: ${filteredQuestions.length}`);

    // Calculate total number of questions needed
    const totalQuestionsNeeded = Math.floor(config.totalMarks / config.marksPQ);
    console.log(`Total questions needed: ${totalQuestionsNeeded}`);

    if (filteredQuestions.length === 0) {
      console.warn("No questions available");
      return [];
    }

    // If we have fewer questions than required, return all available shuffled
    if (filteredQuestions.length <= totalQuestionsNeeded) {
      console.log("Using all available questions");
      return fisherYatesShuffle(filteredQuestions);
    }

    // Group questions by chapter
    const questionsByChapter: { [key: string]: Question[] } = {};
    filteredQuestions.forEach(question => {
      if (!questionsByChapter[question.chapter]) {
        questionsByChapter[question.chapter] = [];
      }
      questionsByChapter[question.chapter].push(question);
    });

    const selectedQuestions: Question[] = [];
    const usedQuestionIds = new Set<string>();
    const availableChapters = Object.keys(questionsByChapter);

    console.log(`Questions available by chapter:`, Object.keys(questionsByChapter).map(ch => `${ch}: ${questionsByChapter[ch].length}`));

    // Calculate base questions per chapter
    const baseQuestionsPerChapter = Math.floor(totalQuestionsNeeded / availableChapters.length);
    console.log(`Base questions per chapter: ${baseQuestionsPerChapter}`);

    // First phase: Select base questions from each chapter using Fisher-Yates shuffle
    availableChapters.forEach(chapter => {
      const chapterQuestions = fisherYatesShuffle(questionsByChapter[chapter]);
      const questionsToSelect = Math.min(baseQuestionsPerChapter, chapterQuestions.length);
      
      console.log(`Selecting ${questionsToSelect} questions from ${chapter}`);
      
      for (let i = 0; i < questionsToSelect; i++) {
        if (!usedQuestionIds.has(chapterQuestions[i]._id)) {
          selectedQuestions.push(chapterQuestions[i]);
          usedQuestionIds.add(chapterQuestions[i]._id);
        }
      }
    });

    // Second phase: Fill remaining slots randomly from all available questions
    const remainingNeeded = totalQuestionsNeeded - selectedQuestions.length;
    console.log(`Remaining questions needed: ${remainingNeeded}`);

    if (remainingNeeded > 0) {
      const availableQuestions = filteredQuestions.filter(q => !usedQuestionIds.has(q._id));
      const shuffledAvailable = fisherYatesShuffle(availableQuestions);
      
      for (let i = 0; i < Math.min(remainingNeeded, shuffledAvailable.length); i++) {
        selectedQuestions.push(shuffledAvailable[i]);
        usedQuestionIds.add(shuffledAvailable[i]._id);
      }
    }

    // Final shuffle for random order presentation using Fisher-Yates
    const finalSelection = fisherYatesShuffle(selectedQuestions);
    
    console.log(`Final selection: ${finalSelection.length} questions`);
    console.log('Chapter distribution:', finalSelection.reduce((acc, q) => {
      acc[q.chapter] = (acc[q.chapter] || 0) + 1;
      return acc;
    }, {} as { [key: string]: number }));

    return finalSelection;
  };

  // Get server time
  const getServerTime = async (): Promise<Date> => {
    try {
      const response = await fetch(`${BACKEND}/api/v1/time`);
      const data = await response.json();
      return new Date(data.timeStamp);
    } catch (error) {
      console.warn("Failed to get server time, using local time:", error);
      return new Date();
    }
  };

  // Check if student already submitted test
  const checkExistingSubmission = async (): Promise<boolean> => {
    if (!studentMobile || !testConfig?._id) return false;
    
    try {
      const response = await fetch(`${BACKEND}/api/v1/testResponse/check/${studentMobile}/${testConfig._id}`);
      const data = await response.json();
      
      if (data.success && data.data.hasTestResponse) {
        return true;
      }
      return false;
    } catch (error) {
      console.error("Error checking existing submission:", error);
      return false;
    }
  };

  // Load test configuration and questions
  const loadTestConfig = async () => {
    try {
      setLoading(true);
      console.log("Loading test config...");

      if (!classNo || !language) {
        showAlert("Login Required", "Student information not found. Please login again.", "error");
        setLoading(false);
        return;
      }

      // Get server time
      console.log("Getting server time...");
      const currentServerTime = await getServerTime();
      setServerTime(currentServerTime);
      console.log("Server time:", currentServerTime.toLocaleString());

      // Get test config
      console.log("Fetching test configs...");
      console.log("API URL:", `${BACKEND}/api/v1/tests/${classNo}/${language}`);
      
      const configResponse = await fetch(`${BACKEND}/api/v1/tests/${classNo}/${language}`);
      console.log("Response status:", configResponse.status);
      console.log("Response headers:", Object.fromEntries(configResponse.headers.entries()));
      
      const configData = await configResponse.json();
      console.log("=== FULL API RESPONSE DEBUG ===");
      console.log("Raw response:", configData);
      console.log("Type of response:", typeof configData);
      console.log("Is array?", Array.isArray(configData));
      console.log("configData.success:", configData?.success);
      console.log("configData.data:", configData?.data);
      console.log("Type of configData.data:", typeof configData?.data);
      console.log("Is configData.data array?", Array.isArray(configData?.data));
      console.log("configData.data length:", configData?.data?.length);

      // Check if the response is directly an array (like your document shows)
      let testsArray;
      if (Array.isArray(configData)) {
        console.log("Response is directly an array");
        testsArray = configData;
      } else if (configData && configData.success && Array.isArray(configData.data)) {
        console.log("Response has success wrapper with data array");
        testsArray = configData.data;
      } else if (configData && Array.isArray(configData.data)) {
        console.log("Response has data array without success field");
        testsArray = configData.data;
      } else {
        console.error("Unexpected API response format");
        console.error("Expected: Array or {success: true, data: Array}");
        console.error("Got:", configData);
        showAlert("API Error", `Unexpected API response format. Got: ${typeof configData}`, "error");
        setLoading(false);
        return;
      }

      if (!testsArray || testsArray.length === 0) {
        console.error("No tests found in response");
        showAlert("No Tests Found", "No test scheduled for your class and language.", "info");
        setLoading(false);
        return;
      }

      console.log("Processing", testsArray.length, "tests");

      // Select the appropriate test from the array
      const config = selectAppropriateTest(testsArray, currentServerTime);
      
      if (!config) {
        console.error("No test selected by selection algorithm");
        showAlert("No Tests Available", "No active or upcoming tests available for your class and language.", "info");
        setLoading(false);
        return;
      }

      console.log("Selected test config:", config);
      setTestConfig(config);

      // Calculate test timing - Using timePQ as total duration
      const testDateTime = new Date(`${config.date}T${config.time}`);
      const testDurationMinutes = config.timePQ; // Use timePQ directly as total duration
      const calculatedEndTime = new Date(testDateTime.getTime() + testDurationMinutes * 60 * 1000);
      
      setTestEndTime(calculatedEndTime);

      console.log("Test timing:");
      console.log(" Start:", testDateTime.toLocaleString());
      console.log(" End:", calculatedEndTime.toLocaleString());
      console.log(" Duration:", testDurationMinutes, "minutes");

      // Check if test is available
      if (currentServerTime < testDateTime) {
        setStartAllowed(false);
        showAlert("Test Not Started", `Test will start at ${testDateTime.toLocaleString()}. Please wait.`, "info");
        
        // Set timer to allow start when time comes
        const delay = testDateTime.getTime() - currentServerTime.getTime();
        setTimeout(() => {
          setStartAllowed(true);
          closeAlert();
        }, delay);
      } else if (currentServerTime >= calculatedEndTime) {
        setStartAllowed(false);
        setSubmitted(true);
        showAlert("Test Ended", "Test time has ended. You cannot start the test now.", "error");
        setLoading(false);
        return;
      } else {
        setStartAllowed(true);
      }

      // Calculate remaining time
      const remainingTime = Math.max(0, Math.floor((calculatedEndTime.getTime() - currentServerTime.getTime()) / 1000));
      setTimeLeft(remainingTime);
      console.log("Remaining time:", remainingTime, "seconds");

      // Load questions
      console.log("Fetching questions...");
      const token = localStorage.getItem("token") || "";
      
      const questionsResponse = await fetch(
        `${BACKEND}/api/v1/question/filtered-questions/${classNo}/${language}`,
        {
          method: "GET",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
          },
          credentials: "include", // use this instead of withCredentials
        }
      );

      const questionsData = await questionsResponse.json();
      
      if (questionsData.success && questionsData.data) {
        console.log("Total questions from API:", questionsData.data.length);
        
        // Filter questions by chapters in config
        const filteredQuestions = questionsData.data.filter((q: Question) =>
          config.chapters.includes(q.chapter)
        );
        
        console.log("Filtered questions by chapters:", filteredQuestions.length);

        // Use enhanced question selection algorithm
        const selectedQuestions = selectQuestionsWithPriority(filteredQuestions, config);
        
        setQuestions(selectedQuestions);
        console.log("Final selected questions:", selectedQuestions.length);
      } else {
        console.error("Failed to load questions:", questionsData);
        showAlert("Loading Error", "Failed to load questions. Please try again.", "error");
      }

      setLoading(false);
    } catch (error) {
      console.error("Error loading test config:", error);
      showAlert("Loading Error", "Failed to load test configuration. Please try again.", "error");
      setLoading(false);
    }
  };

  // Handle start test button click
  const handleStartTest = async () => {
    if (!testConfig) return;

    setShowCheckingPopup(true);

    // Check if already submitted
    const alreadySubmitted = await checkExistingSubmission();
    
    setShowCheckingPopup(false);

    if (alreadySubmitted) {
      showAlert("Test Already Submitted", "You have already submitted this test. Multiple attempts are not allowed.", "warning");
      setSubmitted(true);
      return;
    }

    // Show rules popup
    setShowRulesPopup(true);
  };

  // FIXED: Handle rules agreement and start test
  const handleAgreeToRules = async () => {
    setShowRulesPopup(false);

    // Request fullscreen
    try {
      await document.documentElement.requestFullscreen();
      setIsFullscreen(true);
    } catch (error) {
      console.warn("Fullscreen request failed:", error);
    }

    // Start the test
    setTestStarted(true);

    // Set initial window size for monitoring
    setInitialWindowSize({
      width: window.innerWidth,
      height: window.innerHeight
    });

    // Mark first question as visited
    if (questions.length > 0) {
      setQuestions(prev => prev.map((q, i) => (i === 0 ? { ...q, visited: true } : q)));
    }
  };

  // FIXED: Handle fullscreen change
  const handleFullscreenChange = () => {
    const isCurrentlyFullscreen = !!document.fullscreenElement;
    setIsFullscreen(isCurrentlyFullscreen);
    
    // Check if we exited fullscreen during an active test
    if (!isCurrentlyFullscreen && testStarted && !submitted && !isSubmitting) {
      console.log("Fullscreen exited during test - auto submitting");
      autoSubmitExam("exiting fullscreen");
    }
  };

  // Submit test
  const submitTest = async (submissionAnswers?: AnswerMap) => {
    if (submitted || isSubmitting || !testConfig) return;

    setIsSubmitting(true);
    setSubmitted(true);

    if (intervalId) {
      clearInterval(intervalId);
      setIntervalId(null);
    }

    // Exit fullscreen
    if (document.fullscreenElement) {
      try {
        await document.exitFullscreen();
      } catch (error) {
        console.warn("Exit fullscreen failed:", error);
      }
    }

    const toSubmit = submissionAnswers || answersRef.current;

    // Prepare responses
    const responses: TestResponse[] = questions.map((q, i) => ({
      questionNumber: i + 1,
      questionId: q._id,
      selectedOption: toSubmit[q._id] || null,
    }));

    // Get current server time for submission
    const currentTime = await getServerTime();

    const submissionData = {
      date: currentTime.toISOString().split('T')[0],
      time: currentTime.toTimeString().split(':').slice(0, 2).join(':'),
      studentMobile,
      testId: testConfig._id,
      responses,
    };

    try {
      const response = await fetch(`${BACKEND}/api/v1/testResponse`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(submissionData)
      });

      const data = await response.json();

      if (data.success) {
        showAlert("Test Submitted", "Test submitted successfully! Thank you for taking the test.", "success");
      } else {
        throw new Error("Submission failed on server");
      }
    } catch (error) {
      console.error("Submission error:", error);
      showAlert("Submission Failed", "Failed to submit test. Please check your internet connection and try again.", "error");
      setIsSubmitting(false);
      setSubmitted(false);
      
      // Restart timer if time remaining
      if (testEndTime && timeLeft > 0) {
        const id = setInterval(() => {
          setTimeLeft(prev => {
            if (prev <= 1) {
              clearInterval(id);
              autoSubmitExam("time limit exceeded");
              return 0;
            }
            return prev - 1;
          });
        }, 1000);
        setIntervalId(id);
      }
    }
  };

  // Format timer display
  const formatTime = (seconds: number): string => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    
    if (hours > 0) {
      return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  // Navigation functions
  const showQuestion = (index: number) => {
    if (submitted || index < 0 || index >= questions.length) return;
    
    setCurrentIndex(index);
    setQuestions(prev => {
      const updated = [...prev];
      updated[index].visited = true;
      return updated;
    });
  };

  const handleAnswer = (questionId: string, option: string) => {
    if (submitted) return;
    
    setAnswers(prev => {
      const updated = { ...prev, [questionId]: option };
      return updated;
    });
  };

  const clearAnswer = () => {
    if (submitted || questions.length === 0) return;
    
    const currentQuestion = questions[currentIndex];
    setAnswers(prev => {
      const updated = { ...prev };
      delete updated[currentQuestion._id];
      return updated;
    });
  };

  // Effects
  useEffect(() => {
    answersRef.current = answers;
  }, [answers]);

  // FIXED: Timer effect - runs when test starts
  useEffect(() => {
    if (!testStarted || submitted) return;

    const id = setInterval(() => {
      setTimeLeft(prev => {
        if (prev <= 1) {
          clearInterval(id);
          // Use ref to get latest answers when time runs out
          autoSubmitExam("time limit exceeded");
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    setIntervalId(id);

    return () => clearInterval(id);
  }, [testStarted, submitted]);

  useEffect(() => {
    loadTestConfig();

    // Add multiple fullscreen change listeners for better browser compatibility
    const fullscreenEvents = [
      'fullscreenchange',
      'webkitfullscreenchange',
      'mozfullscreenchange',
      'MSFullscreenChange'
    ];

    fullscreenEvents.forEach(event => {
      document.addEventListener(event, handleFullscreenChange);
    });

    // Enhanced security event listeners
    const securityEvents = [
      { target: window, event: 'resize', handler: handleWindowResize },
      { target: window, event: 'blur', handler: handleWindowBlur },
      { target: window, event: 'focus', handler: handleWindowFocus },
      { target: window, event: 'orientationchange', handler: handleOrientationChange },
      { target: document, event: 'contextmenu', handler: handleContextMenu },
      { target: document, event: 'keydown', handler: handleKeyDown },
      { target: document, event: 'visibilitychange', handler: handleVisibilityChange },
      { target: document, event: 'mouseleave', handler: handleMouseLeave }
    ];

    // Add screen change monitoring for mobile
    let screenChangeInterval: NodeJS.Timeout | null = null;
    if (testStarted && !submitted) {
      screenChangeInterval = setInterval(handleScreenChange, 2000); // Check every 2 seconds
    }

    securityEvents.forEach(({ target, event, handler }) => {
      target.addEventListener(event, handler as EventListener);
    });

    // Add beforeunload listener
    const handleBeforeUnload = (e: BeforeUnloadEvent) => {
      if (testStarted && !submitted) {
        e.preventDefault();
        submitTest(answersRef.current);
      }
    };
    window.addEventListener('beforeunload', handleBeforeUnload);

    return () => {
      if (intervalId) clearInterval(intervalId);
      if (screenChangeInterval) clearInterval(screenChangeInterval);
      
      // Remove all event listeners
      fullscreenEvents.forEach(event => {
        document.removeEventListener(event, handleFullscreenChange);
      });

      securityEvents.forEach(({ target, event, handler }) => {
        target.removeEventListener(event, handler as EventListener);
      });

      window.removeEventListener('beforeunload', handleBeforeUnload);
    };
  }, [testStarted, submitted, isSubmitting, initialWindowSize]);

  const currentQuestion = questions[currentIndex];

  // Loading state
  if (loading) {
    return (
      <div className="w-full max-w-4xl mx-auto p-4">
        <div className="bg-white rounded-lg shadow-lg p-8 text-center">
          <Loader2 className="animate-spin text-blue-600 mx-auto mb-4" size={48} />
          <h2 className="text-xl font-semibold text-gray-800 mb-2">Loading Test...</h2>
          <p className="text-gray-600">Please wait while we prepare your test.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="w-full max-w-4xl mx-auto p-4">
      {/* Alert Dialog */}
      {alert.show && (
        <Alert
          title={alert.title}
          text={alert.text}
          type={alert.type}
          onClose={closeAlert}
        />
      )}

      {/* Rules Popup */}
      <RulesPopup
        isOpen={showRulesPopup}
        onClose={() => setShowRulesPopup(false)}
        onAgree={handleAgreeToRules}
      />

      {/* Checking Popup */}
      <CheckingPopup isOpen={showCheckingPopup} />

      {/* Main Content */}
      {!testStarted ? (
        submitted ? (
          <div className="bg-green-50 border border-green-200 rounded-lg p-8 text-center">
            <CheckCircle className="text-green-600 mx-auto mb-4" size={64} />
            <h2 className="text-2xl font-semibold text-green-800 mb-2">Test Completed</h2>
            <p className="text-green-700">You have already submitted this test.</p>
          </div>
        ) : (
          <div className="bg-white rounded-lg shadow-lg p-6">
            <h2 className="text-2xl font-bold text-center mb-6 text-gray-800">Test Overview</h2>
            
            {testConfig && (
              <div className="grid md:grid-cols-2 gap-4 mb-6">
                <div className="space-y-2">
                  <p><strong>Class:</strong> {testConfig.classNo}</p>
                  <p><strong>Language:</strong> {testConfig.language}</p>
                  <p><strong>Total Questions:</strong> {questions.length}</p>
                  <p><strong>Total Marks:</strong> {testConfig.totalMarks}</p>
                </div>
                <div className="space-y-2">
                  <p><strong>Marks per Question:</strong> {testConfig.marksPQ}</p>
                  <p><strong>Negative Marks:</strong> {testConfig.negativeMarksPQ}</p>
                  <p className="flex items-center">
                    <Clock className="mr-2" size={16} />
                    <strong>Time Remaining:</strong> {formatTime(timeLeft)}
                  </p>
                  <p><strong>Chapters:</strong> {testConfig.chapters.slice(0, 5).join(", ")}{testConfig.chapters.length > 5 ? "..." : ""}</p>
                </div>
              </div>
            )}

            <div className="text-center">
              <button
                onClick={handleStartTest}
                disabled={!startAllowed || isSubmitting || !testConfig || questions.length === 0}
                className={`px-8 py-3 rounded-lg text-white font-semibold flex items-center mx-auto ${
                  startAllowed && !isSubmitting && testConfig && questions.length > 0
                    ? "bg-blue-600 hover:bg-blue-700 transform hover:scale-105 transition-all"
                    : "bg-gray-400 cursor-not-allowed"
                }`}
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="animate-spin mr-2" size={20} />
                    Starting...
                  </>
                ) : !startAllowed ? (
                  <>
                    <Clock className="mr-2" size={20} />
                    Please Wait...
                  </>
                ) : questions.length === 0 ? (
                  <>
                    <AlertCircle className="mr-2" size={20} />
                    No Questions Available
                  </>
                ) : (
                  <>
                    <CheckCircle className="mr-2" size={20} />
                    Start Test
                  </>
                )}
              </button>
              
              {questions.length === 0 && testConfig && (
                <p className="text-red-600 mt-2 text-sm">
                  No questions found for the selected chapters. Please contact support.
                </p>
              )}
            </div>
          </div>
        )
      ) : submitted ? (
        <div className="bg-green-50 border border-green-200 rounded-lg p-8 text-center">
          <CheckCircle className="text-green-600 mx-auto mb-4" size={64} />
          <h2 className="text-2xl font-semibold text-green-800 mb-2">Test Submitted Successfully!</h2>
          <p className="text-green-700">Thank you for taking the test. You may now close this window.</p>
        </div>
      ) : (
        <>
          {/* Timer and Submit Bar */}
          <div className="bg-gray-900 text-white px-6 py-3 rounded-lg flex justify-between items-center mb-4 sticky top-0 z-10">
            <div className="text-xl font-mono flex items-center">
              <Clock className="mr-2" size={24} />
              {formatTime(timeLeft)}
            </div>
            <button
              onClick={() => submitTest(answersRef.current)}
              disabled={isSubmitting}
              className="bg-red-600 hover:bg-red-700 px-6 py-2 rounded font-semibold disabled:opacity-60 flex items-center transition-colors"
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="animate-spin mr-2" size={16} />
                  Submitting...
                </>
              ) : (
                <>
                  <Send className="mr-2" size={16} />
                  Submit Test
                </>
              )}
            </button>
          </div>

          {/* Question Display */}
          {currentQuestion && (
            <div className="bg-white rounded-lg shadow-lg p-6 mb-4">
              <div className="mb-4">
                <span className="text-sm text-gray-500">Question {currentIndex + 1} of {questions.length}</span>
                <div className="text-xs text-gray-400 mt-1">Chapter: {currentQuestion.chapter}</div>
                <h3 className="text-lg font-medium text-gray-900 mt-1">
                  <KaTeXRender text={currentQuestion.question} />
                </h3>
                {currentQuestion.diagram && (
                  <img
                    src={currentQuestion.diagram}
                    alt="Question diagram"
                    className="mt-3 max-w-full h-auto rounded border"
                  />
                )}
              </div>

              <div className="space-y-3 mb-6">
                {currentQuestion.options.map((option, idx) => (
                  <label
                    key={idx}
                    className={`flex items-center p-3 rounded border cursor-pointer transition-all ${
                      answers[currentQuestion._id] === option
                        ? "bg-blue-50 border-blue-300 text-blue-900"
                        : "bg-gray-50 border-gray-200 hover:bg-gray-100"
                    }`}
                  >
                    <input
                      type="radio"
                      name={`question_${currentIndex}`}
                      value={option}
                      checked={answers[currentQuestion._id] === option}
                      onChange={() => handleAnswer(currentQuestion._id, option)}
                      disabled={isSubmitting}
                      className="mr-3"
                    />
                    <span className="flex-1">
                      <KaTeXRender text={option} />
                    </span>
                  </label>
                ))}
              </div>

              <div className="flex justify-between items-center">
                <div className="space-x-2">
                  <button
                    onClick={() => showQuestion(currentIndex - 1)}
                    disabled={currentIndex === 0 || isSubmitting}
                    className="px-4 py-2 bg-gray-300 text-gray-700 rounded disabled:opacity-50 hover:bg-gray-400 transition-colors flex items-center"
                  >
                    <ChevronLeft className="mr-1" size={16} />
                    Previous
                  </button>
                  <button
                    onClick={() => showQuestion(currentIndex + 1)}
                    disabled={currentIndex === questions.length - 1 || isSubmitting}
                    className="px-4 py-2 bg-blue-600 text-white rounded disabled:opacity-50 hover:bg-blue-700 transition-colors flex items-center"
                  >
                    Next
                    <ChevronRight className="ml-1" size={16} />
                  </button>
                </div>
                <button
                  onClick={clearAnswer}
                  disabled={isSubmitting}
                  className="px-4 py-2 bg-yellow-500 text-white rounded hover:bg-yellow-600 disabled:opacity-50 transition-colors flex items-center"
                >
                  <RotateCcw className="mr-2" size={16} />
                  Clear Answer
                </button>
              </div>
            </div>
          )}

          {/* Question Grid */}
          <div className="bg-white rounded-lg shadow-lg p-4">
            <div className="flex flex-wrap gap-2 mb-4 text-xs">
              <div className="flex items-center">
                <div className="w-4 h-4 bg-green-500 rounded mr-2"></div>
                <span>Answered</span>
              </div>
              <div className="flex items-center">
                <div className="w-4 h-4 bg-red-500 rounded mr-2"></div>
                <span>Visited</span>
              </div>
              <div className="flex items-center">
                <div className="w-4 h-4 border border-gray-400 rounded mr-2"></div>
                <span>Not Visited</span>
              </div>
              <div className="flex items-center">
                <div className="w-4 h-4 bg-blue-500 rounded mr-2"></div>
                <span>Current</span>
              </div>
            </div>

            <div className="grid grid-cols-10 gap-2">
              {questions.map((question, index) => {
                const isAnswered = answers[question._id];
                const isCurrent = index === currentIndex;
                const isVisited = question.visited;

                return (
                  <button
                    key={question._id}
                    onClick={() => showQuestion(index)}
                    disabled={isSubmitting}
                    title={`Question ${index + 1} - ${question.chapter}`}
                    className={`w-10 h-10 rounded font-semibold text-sm border-2 transition-all ${
                      isCurrent
                        ? "bg-blue-500 text-white border-blue-500"
                        : isAnswered
                        ? "bg-green-500 text-white border-green-500"
                        : isVisited
                        ? "bg-red-500 text-white border-red-500"
                        : "border-gray-300 hover:border-gray-500 hover:bg-gray-100"
                    } ${isSubmitting ? "opacity-50" : ""}`}
                  >
                    {index + 1}
                  </button>
                );
              })}
            </div>
          </div>
        </>
      )}
    </div>
  );
};

export default StudentTest;