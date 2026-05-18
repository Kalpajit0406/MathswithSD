import React, { useEffect, useState, useCallback } from "react";
import axios from "axios";
import jsPDF from 'jspdf';
import { Download, Users, Clock, Trophy, X, Languages } from 'lucide-react';
import Alert from "../all/AlertDialog";

interface Student {
  _id: string;
  fullName: string;
  studentMobile: string;
  classNo: 9 | 10 | 11 | 12;
  language: 'Bengali' | 'English';
  verified: boolean;
}

interface LeaderboardEntry {
  studentMobile: string;
  name: string;
  language: string;
  classNo: number;
  score: number | null;
  participated: boolean;
  timeTakenSeconds?: number | null;
  timeTakenFormatted?: string | null;
  correctAnswers?: number;
  wrongAnswers?: number;
  percentage?: number | null;
}

const BACKEND = import.meta.env.PUBLIC_BACKEND;

let marksPQ = 1;
let negativeMarksPQ = 0;

const quotes = [
  "Believe you can and you're halfway there.",
  "Don't watch the clock; do what it does. Keep going.",
  "Hard work beats talent when talent doesn't work hard.",
  "Success is not final, failure is not fatal: It is the courage to continue that counts.",
  "The only limit to our realization of tomorrow is our doubts of today.",
  "Education is the most powerful weapon which you can use to change the world.",
  "The future belongs to those who believe in the beauty of their dreams.",
  "Success is where preparation and opportunity meet.",
];

const getRandomQuote = () => quotes[Math.floor(Math.random() * quotes.length)];

function getScheduledDateTime(test?: any) {
  return new Date(`${test.date}T${test.time}:00`);
}

function formatDuration(seconds: number | null) {
  if (seconds === null || seconds === undefined) return "-";
  const min = Math.floor(seconds / 60);
  const sec = seconds % 60;
  return `${min.toString().padStart(2,'0')}:${sec.toString().padStart(2,'0')} min`;
}

// Skeleton component
const SkeletonRow = () => (
  <tr className="animate-pulse">
    <td className="py-4 px-6"><div className="h-8 w-8 bg-gray-300 rounded-full"></div></td>
    <td className="py-4 px-6"><div className="h-4 bg-gray-300 rounded w-32"></div></td>
    <td className="py-4 px-6"><div className="h-4 bg-gray-300 rounded w-20"></div></td>
    <td className="py-4 px-6"><div className="h-4 bg-gray-300 rounded w-16"></div></td>
    <td className="py-4 px-6"><div className="h-4 bg-gray-300 rounded w-16"></div></td>
    <td className="py-4 px-6"><div className="h-4 bg-gray-300 rounded w-20"></div></td>
  </tr>
);

const TeacherLeaderboard: React.FC = () => {
  // State management
  const [allStudents, setAllStudents] = useState<Student[]>([]);
  const [leaderboardData, setLeaderboardData] = useState<{[key: string]: LeaderboardEntry[]}>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Filter states
  const [selectedClass, setSelectedClass] = useState<9 | 10 | 11 | 12 | null>(null);
  const [selectedLanguage, setSelectedLanguage] = useState<'Bengali' | 'English' | null>(null);
  
  // Test data
  const [latestTests, setLatestTests] = useState<{[key: string]: any}>({});
  const [quotes, setQuotes] = useState<{[key: string]: string}>({});

  const getLatestTestForClass = useCallback(async (classNo: number, language: string) => {
    try {
      const response = await axios.get(`${BACKEND}/api/v1/tests/${classNo}/${language}`);
      const tests: any[] = response.data;      

      //console.log(response.data);
      

      marksPQ = response.data[0].marksPQ;
      negativeMarksPQ = tests[0].negativeMarksPQ;
      // console.log(marksPQ, negativeMarksPQ);
      
      
      
      if (!tests || tests.length === 0) return null;
      return tests.reduce((a, b) => {
        return new Date(`${a.date}T${a.time}`) > new Date(`${b.date}T${b.time}`) ? a : b;
      });
    } catch (err) {
      console.error(`Failed to fetch tests for class ${classNo} and language ${language}:`, err);
      return null;
    }
  }, []);

  const fetchAllData = useCallback(async () => {
    try {
      setError(null);
      setLoading(true);

      // Fetch all verified students
      const studentRes = await axios.get(`${BACKEND}/api/v1/student/verified`);      
      const students: Student[] = studentRes.data.data;
      setAllStudents(students);

      // Fetch latest tests for all combinations
      const testPromises = [];
      for (const cls of [9, 10, 11, 12]) {
        for (const lang of ['Bengali', 'English']) {
          testPromises.push(
            getLatestTestForClass(cls, lang).then(test => ({
              class: cls,
              language: lang,
              test
            }))
          );
        }
      }

      const testResults = await Promise.all(testPromises);
      const testsMap: {[key: string]: any} = {};
      testResults.forEach(result => {
        testsMap[`${result.class}-${result.language}`] = result.test;
      });
      setLatestTests(testsMap);

      const token = localStorage.getItem("token")

      // Fetch all questions for scoring
      const questionsRes = await axios.get(`${BACKEND}/api/v1/question/questions`,
            {
            headers: {
                Authorization: `Bearer ${token}`, 
            },
            withCredentials: true,
            }
          )
        
      const questions = questionsRes.data.data;

      // Process leaderboard data for all combinations
      const leaderboards: {[key: string]: LeaderboardEntry[]} = {};
      const quotesMap: {[key: string]: string} = {};

      for (const cls of [9, 10, 11, 12]) {
        for (const lang of ['Bengali', 'English']) {
          const key = `${cls}-${lang}`;
          const classStudents = students.filter(s => s.classNo === cls && s.language === lang);
          const latestTest = testsMap[key];
          quotesMap[key] = getRandomQuote();

          if (!latestTest) {
            leaderboards[key] = classStudents.map((student) => ({
              studentMobile: student.studentMobile,
              name: student.fullName,
              language: student.language,
              classNo: student.classNo,
              score: null,
              participated: false,
              timeTakenSeconds: null,
              timeTakenFormatted: null,
              correctAnswers: 0,
              wrongAnswers: 0,
              percentage: null,
            }));
            continue;
          }

          const leaderboardPromises = classStudents.map(async (student) => {
            try {
              const res = await axios.get(`${BACKEND}/api/v1/testResponse/res/all`);
              //const latestResponse = res.data.data;
              const responses: any[] = res.data.data || [];
    
                const latestResponse = responses.find(
                  (resp) =>
                    resp.studentMobile === student.studentMobile
                );
        
              

              if (!latestResponse) {
                return {
                  studentMobile: student.studentMobile,
                  name: student.fullName,
                  language: student.language,
                  classNo: student.classNo,
                  score: null,
                  participated: false,
                  timeTakenSeconds: null,
                  timeTakenFormatted: null,
                  correctAnswers: 0,
                  wrongAnswers: 0,
                  percentage: null,
                };
              }

              // Calculate scores
              let correct = 0, wrong = 0, skipped = 0;
              for (const r of latestResponse.responses) {
                const question = questions.find((q: any) => q._id === r.questionId);
                if (!question) continue;
                if (r.selectedOption === null) {
                  skipped++;
                  continue;
                }
                if (r.selectedOption === question.correctAnswer) correct++;
                else wrong++;
              }

              const score = (correct * marksPQ) - (wrong * negativeMarksPQ);
              const totalQuestions = correct + wrong + skipped;
              const percentage = totalQuestions > 0 ? (correct / totalQuestions) * 100 : 0;

              // Calculate time taken
              const scheduledTime = getScheduledDateTime(latestTest);
              const submittedTime = new Date(latestResponse.createdAt);
              let timeTakenSeconds = Math.floor((submittedTime.getTime() - scheduledTime.getTime()) / 1000);
              if (timeTakenSeconds < 0) timeTakenSeconds = 0;

              return {
                studentMobile: student.studentMobile,
                name: student.fullName,
                language: student.language,
                classNo: student.classNo,
                score,
                participated: true,
                timeTakenSeconds,
                timeTakenFormatted: formatDuration(timeTakenSeconds),
                correctAnswers: correct,
                wrongAnswers: wrong,
                percentage,
              };
            } catch (err) {
              return {
                studentMobile: student.studentMobile,
                name: student.fullName,
                language: student.language,
                classNo: student.classNo,
                score: null,
                participated: false,
                timeTakenSeconds: null,
                timeTakenFormatted: null,
                correctAnswers: 0,
                wrongAnswers: 0,
                percentage: null,
              };
            }
          });

          const leaderboard = await Promise.all(leaderboardPromises);
          
          // Sort: participated students first (by score desc, then time asc), then non-participated
          leaderboard.sort((a, b) => {
            // Non-participated go to end
            if (!a.participated && !b.participated) return 0;
            if (!a.participated) return 1;
            if (!b.participated) return -1;
            
            // Both participated: sort by score desc, then time asc
            if (b.score !== a.score) return (b.score || 0) - (a.score || 0);
            return (a.timeTakenSeconds ?? Infinity) - (b.timeTakenSeconds ?? Infinity);
          });

          leaderboards[key] = leaderboard;
        }
      }

      setLeaderboardData(leaderboards);
      setQuotes(quotesMap);
      setLoading(false);
    } catch (error) {
      console.error("Failed to fetch leaderboard data:", error);
      setError("Failed to load leaderboard data. Please try again later.");
      setLoading(false);
    }
  }, [getLatestTestForClass]);

  useEffect(() => {
    fetchAllData();
  }, [fetchAllData]);

  // PDF Export for specific table
  const exportToPDF = (entries: LeaderboardEntry[], classNo: number, language: string, quote: string) => {
    const doc = new jsPDF();
    let currentY = 20;

    // Header
    doc.setFontSize(12);
    doc.setFont('helvetica', 'italic');
    doc.setTextColor(60, 60, 60);
    doc.text(`"${quote}"`, 105, currentY, { align: 'center' });
    currentY += 10;

    doc.setFontSize(18);
    doc.setFont('helvetica', 'bold');
    doc.setTextColor(0, 0, 0);
    doc.text(`Class ${classNo} - ${language} Leaderboard`, 105, currentY, { align: 'center' });
    currentY += 15;

    // Minimal table
    const startY = currentY;
    const rowHeight = 10;
    const colWidths = [20, 60, 30, 30];
    const tableWidth = colWidths.reduce((a, b) => a + b, 0);
    const startX = (210 - tableWidth) / 2;

    const colPositions = [startX];
    for (let i = 1; i < colWidths.length; i++) {
      colPositions[i] = colPositions[i-1] + colWidths[i-1];
    }

    // Headers
    const headers = ["Pos", "Name", "Score", "Time"];
    doc.setFontSize(10);
    doc.setFont('helvetica', 'bold');
    doc.setFillColor(240, 240, 240);
    doc.rect(startX, startY - 6, tableWidth, rowHeight, 'F');
    headers.forEach((header, i) => {
      doc.text(header, colPositions[i] + colWidths[i]/2, startY, { align: 'center' });
    });

    // Data rows
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);

    let participatedCount = 0;
    entries.forEach((entry, rowIndex) => {
      const y = startY + (rowIndex + 1) * rowHeight;
      
      // Position number logic
      let positionText = "-";
      if (entry.participated) {
        participatedCount++;
        positionText = participatedCount.toString();
        
        // Background colors for top 3
        if (participatedCount === 1) {
          doc.setFillColor(255, 235, 59); // Yellow
          doc.roundedRect(colPositions[0] + 1, y - 6, colWidths[0] - 2, rowHeight - 1, 1, 1, 'F');
        } else if (participatedCount === 2) {
          doc.setFillColor(148, 163, 184); // Slate
          doc.roundedRect(colPositions[0] + 1, y - 6, colWidths[0] - 2, rowHeight - 1, 1, 1, 'F');
        } else if (participatedCount === 3) {
          doc.setFillColor(127, 29, 29); // Red-900/30 equivalent
          doc.roundedRect(colPositions[0] + 1, y - 6, colWidths[0] - 2, rowHeight - 1, 1, 1, 'F');
        }
      }
      
      doc.text(positionText, colPositions[0] + colWidths[0]/2, y, { align: 'center' });
      doc.text(entry.name, colPositions[1] + 2, y, { align: 'left' });
      doc.text(
        entry.score !== null ? entry.score.toFixed(2) : "-",
        colPositions[2] + colWidths[2]/2, y, { align: 'center' }
      );
      doc.text(entry.timeTakenFormatted ?? "-", colPositions[3] + colWidths[3]/2, y, { align: 'center' });
    });

    const timestamp = new Date().toISOString().slice(0, 10);
    doc.save(`Class${classNo}_${language}_Leaderboard_${timestamp}.pdf`);
  };

  const clearFilters = () => {
    setSelectedClass(null);
    setSelectedLanguage(null);
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-cyan-100 py-8 my-18">
        <div className="container mx-auto px-4 max-w-7xl">
          <div className="text-center mb-8">
            {/* <h1 className="text-4xl font-bold text-gray-900 mb-3">Student Leaderboard</h1> */}
            <p className="text-lg text-gray-600">Loading performance data...</p>
          </div>
          
          {/* Skeleton for 4 tables */}
          {[9, 10, 11, 12].map(cls => 
            ['Bengali', 'English'].map(lang => (
              <div key={`${cls}-${lang}`} className="bg-white/70 backdrop-blur-md border border-white/20 rounded-2xl shadow-xl overflow-hidden mb-8">
                <div className="bg-gray-400 text-white p-6">
                  <div className="h-6 bg-white/20 rounded w-48 mb-2"></div>
                  <div className="h-4 bg-white/20 rounded w-64"></div>
                </div>
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead className="bg-gray-50/70">
                      <tr>
                        <th className="py-4 px-6 text-left">Position</th>
                        <th className="py-4 px-6 text-left">Name</th>
                        <th className="py-4 px-6 text-left">Score</th>
                        <th className="py-4 px-6 text-left">Percentage</th>
                        <th className="py-4 px-6 text-left">Time</th>
                        <th className="py-4 px-6 text-left">Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      <SkeletonRow />
                      <SkeletonRow />
                    </tbody>
                  </table>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-50 via-blue-50 to-indigo-100 flex items-center justify-center">
        <Alert 
          title="Error Loading Data" 
          text={error} 
          type="error" 
          onClose={() => setError(null)} 
        />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-cyan-100 py-8 mt-18">
      <div className="container mx-auto px-4 max-w-7xl">
      
        {/* Filter Controls */}
        <div className=" backdrop-blur-md border border-white/20 rounded-2xl shadow-xl p-6 mb-8 bg-gradient-to-t from-lime-300/60 to-emerald-200">

        {/* Header */}
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold text-gray-900 mb-3 bg-yellow-600 bg-clip-text">
            Student Leaderboard
          </h1>
          <p className="text-lg text-gray-600">Track student performance across languages and classes</p>
        </div>

        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:gap-6">

            {/* Class Selection */}
            <div className="flex flex-wrap items-center gap-2">
              <Users className="w-5 h-5 text-gray-600" />
              <span className="font-medium text-gray-700">Class:</span>
              {[9, 10, 11, 12].map((cls) => (
                <button
                  key={cls}
                  onClick={() =>
                    setSelectedClass(selectedClass === cls ? null : (cls as 9 | 10 | 11 | 12))
                  }
                  className={`px-4 py-2 rounded-lg font-medium text-sm transition-all ${
                    selectedClass === cls
                      ? "bg-teal-700 text-white shadow-lg"
                      : "bg-white/60 text-indigo-600 hover:bg-indigo-50 border border-indigo-200"
                  }`}
                >
                  {cls}
                </button>
              ))}
            </div>

            {/* Language Selection */}
            <div className="flex flex-wrap items-center gap-2">
              <Languages />
              <span className="font-medium text-gray-700">Language:</span>
              {["Bengali", "English"].map((lang) => (
                <button
                  key={lang}
                  onClick={() =>
                    setSelectedLanguage(
                      selectedLanguage === lang ? null : (lang as "Bengali" | "English")
                    )
                  }
                  className={`px-4 py-2 rounded-lg font-medium text-sm transition-all ${
                    selectedLanguage === lang
                      ? "bg-cyan-600 text-white shadow-lg"
                      : "bg-white/60 text-purple-900/70 hover:bg-purple-50 border border-purple-200"
                  }`}
                >
                  {lang}
                </button>
              ))}
            </div>
          </div>

          {/* Clear Filters */}
          {(selectedClass || selectedLanguage) && (
            <button
              onClick={clearFilters}
              className="flex items-center justify-center gap-2 px-4 py-2 bg-slate-500/40 text-white rounded-lg hover:bg-gray-600 transition-colors"
            >
              <X className="w-4 h-4" />
              Clear
            </button>
          )}
        </div>
      </div>


        {/* Leaderboard Tables */}
        {[9, 10, 11, 12].map(cls => 
          ['Bengali', 'English'].map(lang => {
            const key = `${cls}-${lang}`;
            const entries = leaderboardData[key] || [];
            const quote = quotes[key] || "";
            const participatedCount = entries.filter(entry => entry.participated).length;
            const totalCount = entries.length;

            // Filter logic
            const shouldShow = (!selectedClass || selectedClass === cls) && 
                             (!selectedLanguage || selectedLanguage === lang);

            if (!shouldShow) return null;

            return (
              <div key={key} className="bg-white/70 backdrop-blur-md border border-white/20 rounded-2xl shadow-xl overflow-hidden mb-8">
                {/* Table Header */}
                <div className="bg-gradient-to-t from-amber-600/90 to-orange-600 text-white p-6">
                  <div className="flex justify-between items-start">
                    <div>
                      <h2 className="text-2xl font-bold mb-2 flex items-center gap-2">
                        <Trophy className="w-6 h-6" />
                        Class {cls} - {lang}
                      </h2>
                      <p className="italic text-indigo-100 mb-3">"{quote}"</p>
                      <div className="flex items-center gap-4 text-sm text-indigo-200">
                        <div className="flex items-center gap-1">
                          <Users className="w-4 h-4" />
                          {participatedCount}/{totalCount} students
                        </div>
                      </div>
                    </div>
                    <button 
                      onClick={() => exportToPDF(entries, cls, lang, quote)}
                      className="flex items-center gap-2 bg-white/20 hover:bg-white/30 backdrop-blur-sm border border-white/30 rounded-xl px-4 py-2 text-white font-medium transition-all duration-200 hover:scale-105"
                    >
                      <Download className="w-6 h-6" />
                      <p className="text-xs sm:text-md">Export PDF</p>
                    </button>
                  </div>
                </div>

                {/* Table Content */}
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead className="bg-gray-50/70 backdrop-blur-sm">
                      <tr>
                        <th className="py-4 px-6 text-left font-semibold text-gray-700">Position</th>
                        <th className="py-4 px-6 text-left font-semibold text-gray-700">Name</th>
                        <th className="py-4 px-6 text-left font-semibold text-gray-700">Score</th>
                        <th className="py-4 px-6 text-left font-semibold text-gray-700">Percentage</th>
                        <th className="py-4 px-6 text-left font-semibold text-gray-700">Time Taken</th>
                        <th className="py-4 px-6 text-left font-semibold text-gray-700">Status</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100/70">
                      {entries.map((entry, index) => {
                        // Calculate position for participated students
                        let position = "-";
                        let positionNumber = 0;
                        if (entry.participated) {
                          const participatedBefore = entries.slice(0, index).filter(e => e.participated).length;
                          positionNumber = participatedBefore + 1;
                          position = positionNumber.toString();
                        }

                        return (
                          <tr
                            key={`${entry.studentMobile}-${index}`}
                            className="hover:bg-sky-50/50 transition-colors duration-200"
                          >
                            <td className="py-4 px-6">
                              {entry.participated ? (
                                <div className="flex items-center">
                                  <span
                                    className={`inline-flex items-center justify-center w-8 h-8 rounded-full text-sm font-bold shadow-lg ${
                                      positionNumber === 1
                                        ? "bg-yellow-400 text-black"
                                        : positionNumber === 2
                                        ? "bg-slate-400 text-white"
                                        : positionNumber === 3
                                        ? "bg-red-900/30 text-white"
                                        : "bg-gradient-to-r from-sky-400 to-sky-600 text-white"
                                    }`}
                                  >
                                    {position}
                                  </span>
                                </div>
                              ) : (
                                <span className="text-gray-400">-</span>
                              )}
                            </td>
                            <td className="py-4 px-6">
                              <div className="font-medium text-gray-900">{entry.name}</div>
                              <div className="text-sm text-gray-500">{entry.studentMobile}</div>
                            </td>
                            <td className="py-4 px-6">
                              {entry.score !== null ? (
                                <div>
                                  <span className="font-bold text-lg text-gray-900">{entry.score.toFixed(2)}</span>
                                  <div className="text-xs text-gray-500">
                                    ✓ {entry.correctAnswers} ✗ {entry.wrongAnswers}
                                  </div>
                                </div>
                              ) : (
                                <span className="text-gray-400">-</span>
                              )}
                            </td>
                            <td className="py-4 px-6">
                              {entry.percentage !== null && entry.percentage !== undefined ? (
                                <div className="flex items-center">
                                  <div className="flex-1">
                                    <div className="flex items-center">
                                      <span className="text-sm font-medium text-gray-900 mr-2">
                                        {entry.percentage.toFixed(1)}%
                                      </span>
                                    </div>
                                    <div className="w-full bg-gray-200 rounded-full h-2 mt-1">
                                      <div
                                        className="bg-gradient-to-r from-green-400 to-green-600 h-2 rounded-full transition-all duration-300"
                                        style={{ width: `${Math.min(entry.percentage, 100)}%` }}
                                      ></div>
                                    </div>
                                  </div>
                                </div>
                              ) : (
                                <span className="text-gray-400">-</span>
                              )}
                            </td>
                            <td className="py-4 px-6">
                              {entry.participated ? (
                                <div className="flex items-center gap-1">
                                  <Clock className="w-4 h-4 text-gray-500" />
                                  <span className="font-medium text-gray-700">{entry.timeTakenFormatted}</span>
                                </div>
                              ) : (
                                <span className="text-gray-400">-</span>
                              )}
                            </td>
                            <td className="py-4 px-6">
                              <span
                                className={`inline-flex px-3 py-1 text-xs font-medium rounded-full ${
                                  entry.participated 
                                    ? "bg-green-100 text-green-800" 
                                    : "bg-red-100 text-red-800"
                                }`}
                              >
                                {entry.participated ? "✓ Participated" : "✗ Not Participated"}
                              </span>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>

                {entries.length === 0 && (
                  <div className="p-12 text-center">
                    <div className="text-gray-400 text-6xl mb-4">📊</div>
                    <h3 className="text-xl font-semibold text-gray-600 mb-2">No Data Found</h3>
                    <p className="text-gray-500">
                      No students found for Class {cls} - {lang}.
                    </p>
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};

export default TeacherLeaderboard;
