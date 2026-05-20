import { useEffect, useState } from "react";
import { 
  Calendar, 
  Clock, 
  Timer, 
  BarChart3, 
  BookOpen, 
  AlertTriangle, 
  CheckCircle, 
  Play,
  Bell,
  NotebookText 
} from "lucide-react";
import ProfileButton from "./Profile";

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

interface TimeRemaining {
  days: number;
  hours: number;
  minutes: number;
  seconds: number;
}

const BACK = import.meta.env.PUBLIC_BACKEND

const UpcomingTest = () => {
  const [tests, setTests] = useState<TestConfig[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [currentTime, setCurrentTime] = useState(new Date());

  /**
   * Check if a test has expired based on its end time
   * @param test - TestConfig object with date, time, and duration
   * @returns boolean - true if test has ended
   */
  const isTestExpired = (test: TestConfig): boolean => {
    try {
      const testStartTime = new Date(`${test.date}T${test.time}`);
      const testEndTime = new Date(testStartTime.getTime() + (test.timePQ * 60 * 1000));
      
      return currentTime >= testEndTime;
    } catch (error) {
      console.error("Error parsing test time:", error);
      return false;
    }
  };

  /**
   * Calculate detailed time remaining with days, hours, minutes, seconds
   * @param targetTime - Target date/time
   * @returns TimeRemaining object
   */
  const calculateTimeRemaining = (targetTime: Date): TimeRemaining => {
    const diff = targetTime.getTime() - currentTime.getTime();
    
    if (diff <= 0) {
      return { days: 0, hours: 0, minutes: 0, seconds: 0 };
    }

    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
    const seconds = Math.floor((diff % (1000 * 60)) / 1000);

    return { days, hours, minutes, seconds };
  };

  /**
   * Get test status with detailed countdown
   * @param test - TestConfig object
   * @returns object with status, time remaining, and color
   */
  const getTestStatus = (test: TestConfig) => {
    try {
      const testStartTime = new Date(`${test.date}T${test.time}`);
      const testEndTime = new Date(testStartTime.getTime() + (test.timePQ * 60 * 1000));
      
      const now = currentTime;
      
      // Test hasn't started yet
      if (now < testStartTime) {
        const timeRemaining = calculateTimeRemaining(testStartTime);
        return { 
          status: "upcoming", 
          timeRemaining,
          color: "blue",
          isUrgent: timeRemaining.days === 0 && timeRemaining.hours < 1
        };
      }
      
      // Test is currently active
      if (now >= testStartTime && now < testEndTime) {
        const timeRemaining = calculateTimeRemaining(testEndTime);
        return { 
          status: "active", 
          timeRemaining,
          color: "green",
          isUrgent: false
        };
      }
      
      // Test has ended
      return { 
        status: "ended", 
        timeRemaining: { days: 0, hours: 0, minutes: 0, seconds: 0 },
        color: "gray",
        isUrgent: false
      };
    } catch (error) {
      return { 
        status: "error", 
        timeRemaining: { days: 0, hours: 0, minutes: 0, seconds: 0 },
        color: "red",
        isUrgent: false
      };
    }
  };

  /**
   * Format time remaining as a readable string
   * @param timeRemaining - TimeRemaining object
   * @param status - Test status
   * @returns Formatted string
   */
  const formatTimeRemaining = (timeRemaining: TimeRemaining, status: string): string => {
    const { days, hours, minutes, seconds } = timeRemaining;
    
    if (status === "ended") return "Test ended";
    if (status === "error") return "Invalid date";
    
    const prefix = status === "active" ? "Ends in" : "Starts in";
    
    if (days > 0) {
      return `${prefix} ${days}d ${hours}h ${minutes}m ${seconds}s`;
    } else if (hours > 0) {
      return `${prefix} ${hours}h ${minutes}m ${seconds}s`;
    } else if (minutes > 0) {
      return `${prefix} ${minutes}m ${seconds}s`;
    } else {
      return `${prefix} ${seconds}s`;
    }
  };

  /**
   * Format date to a more readable format
   * @param dateString - Date in YYYY-MM-DD format
   * @returns Formatted date string
   */
  const formatDate = (dateString: string): string => {
    try {
      const date = new Date(dateString);
      return date.toLocaleDateString('en-US', {
        weekday: 'short',
        month: 'short',
        day: 'numeric',
        year: 'numeric'
      });
    } catch {
      return dateString;
    }
  };

  /**
   * Format time to 12-hour format with AM/PM
   * @param timeString - Time in HH:MM format
   * @returns Formatted time string
   */
  const formatTime = (timeString: string): string => {
    try {
      const [hours, minutes] = timeString.split(':');
      const hour = parseInt(hours);
      const ampm = hour >= 12 ? 'PM' : 'AM';
      const hour12 = hour % 12 || 12;
      return `${hour12}:${minutes} ${ampm}`;
    } catch {
      return timeString;
    }
  };

  /**
   * Fetch upcoming tests from API
   */
  useEffect(() => {
    const fetchUpcomingTests = async () => {
      try {
        const storedStudent = localStorage.getItem("student");
        if (!storedStudent) {
          setError("Student information not found. Please log in again.");
          return;
        }

        const student = JSON.parse(storedStudent);
        const classNo = student.classNo || student.class_No || student.class || student.class_no;
        const language = student.language || "Bengali"; // Default to Bengali if not specified

        if (!classNo) {
          setError("Class information missing from student profile.");
          return;
        }

        const res = await fetch(`${BACK}/api/v1/tests/${classNo}/${language}`, {
          credentials: "include",
        });

        if (!res.ok) {
          throw new Error(`Failed to fetch tests: ${res.status} ${res.statusText}`);
        }

        const data = await res.json();
        setTests(Array.isArray(data) ? data : []);
      } catch (err: any) {
        console.error("Error fetching tests:", err);
        setError(err.message || "Failed to load upcoming tests");
      } finally {
        setLoading(false);
      }
    };

    fetchUpcomingTests();
  }, []);

  /**
   * Update current time every second for real-time countdown
   */
  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentTime(new Date());
    }, 1000); // Update every second

    return () => clearInterval(timer);
  }, []);

  // Filter out expired tests
  const activeTests = tests.filter(test => !isTestExpired(test));

  // Loading state
  if (loading) {
    return (
      <div>
        {[...Array(3)].map((_, index) => (
          <div key={index} className="bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-200 p-6 rounded-xl shadow-lg mt-4 animate-pulse">
            <div className="flex items-center space-x-3">
              <div className="h-4 bg-blue-300 rounded w-48 animate-pulse"></div>
            </div>
            <div className="mt-4 space-y-3">
              <div className="h-3 bg-blue-200 rounded w-3/4 animate-pulse"></div>
              <div className="h-3 bg-blue-200 rounded w-1/2 animate-pulse"></div>
            </div>
          </div>
        ))}
      </div>
    );
  }


  // Error state
  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 p-6 rounded-xl shadow-lg mt-4">
        <div className="flex items-center space-x-3">
          <AlertTriangle className="w-6 h-6 text-red-500" />
          <h3 className="text-lg font-semibold text-red-800">Error Loading Tests</h3>
        </div>
        <p className="text-red-600 mt-2">{error}</p>
      </div>
    );
  }

  // No tests available
  if (activeTests.length === 0) {
    return (
      <div>
        <div className="bg-gradient-to-r from-green-50 to-emerald-50 border border-green-200 p-6 rounded-xl shadow-lg mt-4">
          <div className="text-center">
            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <CheckCircle className="w-8 h-8 text-green-600" />
            </div>
            <h3 className="text-lg font-semibold text-green-800 mb-2">No Upcoming Tests</h3>
            <p className="text-green-600">You're all caught up! No tests scheduled at the moment.</p>
          </div>
        </div>
        <BottomBar />
      </div>
    );
  }

  // Render active tests
  return (
    <div>
      <div className="bg-gradient-to-r from-yellow-50 to-orange-50 border border-yellow-300 p-6 rounded-xl shadow-lg mt-4">
        {/* Header */}
        <div className="flex items-center space-x-3 mb-6">
          <div className="w-8 h-8 bg-yellow-400 rounded-full flex items-center justify-center">
            <Bell className="w-5 h-5 text-white" />
          </div>
          <h2 className="text-xl font-bold text-yellow-800">
            Upcoming Tests ({activeTests.length})
          </h2>
        </div>

        {/* Tests List */}
        <div className="space-y-4">
          {activeTests.map((test) => {
            const status = getTestStatus(test);
            const timeText = formatTimeRemaining(status.timeRemaining, status.status);
            
            return (
              <div
                key={test._id}
                className={`bg-white rounded-lg p-5 shadow-md border-l-4 hover:shadow-lg transition-all duration-200 ${
                  status.color === 'green' ? 'border-l-green-500' :
                  status.color === 'red' ? 'border-l-red-500' :
                  status.isUrgent ? 'border-l-orange-500 animate-pulse' :
                  status.color === 'blue' ? 'border-l-blue-500' : 'border-l-gray-400'
                }`}
              >
                {/* Test Header */}
                <div className="flex justify-between items-start mb-4">
                  <div className="flex-1">
                    <h3 className="text-lg font-semibold text-gray-800 mb-1">
                      Class {test.classNo} - {test.language.charAt(0).toUpperCase() + test.language.slice(1)}
                    </h3>
                    <div className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${
                      status.color === 'green' ? 'bg-green-100 text-green-800' :
                      status.isUrgent ? 'bg-red-100 text-red-800' :
                      status.color === 'blue' ? 'bg-blue-100 text-blue-800' : 'bg-gray-100 text-gray-800'
                    }`}>
                      <div className={`w-2 h-2 rounded-full mr-2 ${
                        status.color === 'green' ? 'bg-green-500' :
                        status.isUrgent ? 'bg-red-500 animate-pulse' :
                        status.color === 'blue' ? 'bg-blue-500' : 'bg-gray-500'
                      }`} />
                      {timeText}
                    </div>
                  </div>
                </div>

                {/* Countdown Display for Urgent Tests */}
                {(status.status === 'upcoming' && status.isUrgent) && (
                  <div className="bg-red-50 border border-red-200 rounded-lg p-3 mb-4">
                    <div className="flex items-center justify-center space-x-4 text-red-800">
                      <div className="text-center">
                        <div className="text-2xl font-bold">{status.timeRemaining.hours}</div>
                        <div className="text-xs">Hours</div>
                      </div>
                      <div className="text-2xl font-bold">:</div>
                      <div className="text-center">
                        <div className="text-2xl font-bold">{status.timeRemaining.minutes}</div>
                        <div className="text-xs">Minutes</div>
                      </div>
                      <div className="text-2xl font-bold">:</div>
                      <div className="text-center">
                        <div className="text-2xl font-bold">{status.timeRemaining.seconds}</div>
                        <div className="text-xs">Seconds</div>
                      </div>
                    </div>
                  </div>
                )}

                {/* Test Details Grid */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {/* Date & Time */}
                  <div className="space-y-2">
                    <div className="flex items-center space-x-2">
                      <Calendar className="w-4 h-4 text-gray-500" />
                      <span className="text-sm font-medium text-gray-700">Date:</span>
                      <span className="text-sm text-gray-800">{formatDate(test.date)}</span>
                    </div>
                    <div className="flex items-center space-x-2">
                      <Clock className="w-4 h-4 text-gray-500" />
                      <span className="text-sm font-medium text-gray-700">Time:</span>
                      <span className="text-sm text-gray-800">{formatTime(test.time)}</span>
                    </div>
                  </div>

                  {/* Duration & Marks */}
                  <div className="space-y-2">
                    <div className="flex items-center space-x-2">
                      <Timer className="w-4 h-4 text-gray-500" />
                      <span className="text-sm font-medium text-gray-700">Duration:</span>
                      <span className="text-sm text-gray-800">{test.timePQ} minutes</span>
                    </div>
                    <div className="flex items-center space-x-2">
                      <NotebookText className="w-4 h-4 text-gray-500" />
                      <span className="text-sm font-medium text-gray-700">Total Questions:</span>
                      <span className="text-sm text-gray-800">{test.totalMarks/test.marksPQ}</span>
                    </div>
                    <div className="flex items-center space-x-2">
                      <BarChart3 className="w-4 h-4 text-gray-500" />
                      <span className="text-sm font-medium text-gray-700">Total Marks:</span>
                      <span className="text-sm text-gray-800">{test.totalMarks}</span>
                    </div>
                  </div>
                </div>

                {/* Additional Test Details */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                  <div className="flex items-center space-x-2">
                    <BarChart3 className="w-4 h-4 text-gray-500" />
                    <span className="text-sm font-medium text-gray-700">Marks per Question:</span>
                    <span className="text-sm text-gray-800">{test.marksPQ}</span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <AlertTriangle className="w-4 h-4 text-gray-500" />
                    <span className="text-sm font-medium text-gray-700">Negative Marks:</span>
                    <span className="text-sm text-gray-800">{test.negativeMarksPQ}</span>
                  </div>
                </div>

                {/* Chapters */}
                <div className="mt-4">
                  <div className="flex items-start space-x-2">
                    <BookOpen className="w-4 h-4 text-gray-500 mt-0.5" />
                    <div className="flex-1">
                      <span className="text-sm font-medium text-gray-700">Chapters:</span>
                      <div className="flex flex-wrap gap-2 mt-1">
                        {test.chapters.map((chapter, index) => (
                          <span
                            key={index}
                            className="px-2 py-1 bg-blue-100 text-blue-800 text-xs rounded-full font-medium"
                          >
                            {chapter}
                          </span>
                        ))}
                      </div>
                    </div>
                  </div>
                </div>

                {/* Action Button for Active Tests */}
                {status.status === 'active' && (
                  <div className="mt-4 pt-4 border-t border-gray-100">
                    <button
                      onClick={() => window.location.href = '/student/test'}
                      className="w-full bg-green-600 hover:bg-green-700 text-white font-medium py-3 px-4 rounded-lg transition-colors duration-200 flex items-center justify-center space-x-2"
                    >
                      <Play className="w-5 h-5" />
                      <span>Take Test Now</span>
                    </button>
                  </div>
                )}
              </div>
            );
          })}
        </div>

        {/* Footer Info */}
        <div className="mt-6 pt-4 border-t border-yellow-200">
          <div className="flex items-center justify-center space-x-2">
            <Timer className="w-4 h-4 text-yellow-700" />
            <p className="text-xs text-yellow-700 text-center">
              Times shown update in real-time • Please wait for the test to begin
            </p>
          </div>
        </div>
      </div>

      {/* Bottom bar */}
      <BottomBar />
    </div>
  );
};

export default UpcomingTest;

function BottomBar() {
  return (
      <div className="m-2 mt-4">
        <div className="grid grid-cols-2 gap-2">
          <button 
            onClick={()=>{location.href="/student/result"}}
            className="px-6 py-2 w-full  bg-blue-600 text-white font-semibold rounded-lg shadow-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-400 transition">
            View Results
          </button>
          <div>
            <ProfileButton/>
          </div>
        </div>
      </div>
  )
}