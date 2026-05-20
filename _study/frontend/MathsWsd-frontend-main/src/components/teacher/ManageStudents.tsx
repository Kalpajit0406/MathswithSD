import React, { useEffect, useState } from "react";
import axios from "axios";
import { 
  Clock, 
  CheckCircle, 
  Phone, 
  BookOpen, 
  Languages, 
  User, 
  UserCheck, 
  Trash2,
  Users,
  AlertCircle,
  CircleQuestionMark
} from "lucide-react";
import NavComponent from "./NavComponent";

interface Student {
  _id: string;
  fullName: string;
  studentMobile: string;
  classNo: 9 | 10 | 11 | 12; 
  language: "Bengali" | "English";
  guardianName: string;
  guardianMobile: string;
  verified: boolean;
}

const BACK = import.meta.env.PUBLIC_BACKEND;

const ManageStudent: React.FC = () => {
  const [pendingStudents, setPendingStudents] = useState<Student[]>([]);
  const [verifiedStudents, setVerifiedStudents] = useState<Student[]>([]);
  
  // Filter states
  const [selectedLanguage, setSelectedLanguage] = useState<string>('all');
  const [selectedClass, setSelectedClass] = useState<string | number>('all');

  // Custom popup alert states
  const [showAlert, setShowAlert] = useState(false);
  const [alertConfig, setAlertConfig] = useState({
    title: '',
    message: '',
    type: 'confirm' as 'confirm' | 'success' | 'error',
    onConfirm: () => {},
    onCancel: () => {}
  });

  const fetchStudents = async () => {
    try {
      const res = await axios.get(`${BACK}/api/v1/student/students`, {
        withCredentials: true,
      });
      if (res.data.success) {
        setPendingStudents(res.data.unverified || []);
        setVerifiedStudents(res.data.verified || []);
      }
    } catch (err) {
      console.error("Error fetching students:", err);
      showPopupAlert({
        title: 'Error!',
        message: 'Failed to fetch students. Please try again.',
        type: 'error',
        onConfirm: () => setShowAlert(false),
        onCancel: () => {}
      });
    }
  };

  const showPopupAlert = (config: typeof alertConfig) => {
    setAlertConfig(config);
    setShowAlert(true);
  };

  const handleAccept = (id: string) => {
    showPopupAlert({
      title: 'Confirm Accept',
      message: 'Are you sure you want to accept this student?',
      type: 'confirm',
      onConfirm: () => {
        confirmAccept(id);
        setShowAlert(false);
      },
      onCancel: () => setShowAlert(false)
    });
  };

  const confirmAccept = async (id: string) => {
    try {
      const token = localStorage.getItem('token');
      await axios.put(`${BACK}/api/v1/student/accept/${id}`, {}, {
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
          },
          withCredentials: true,
      }
    );
      await fetchStudents();
      showPopupAlert({
        title: 'Success!',
        message: 'Student accepted successfully.',
        type: 'success',
        onConfirm: () => setShowAlert(false),
        onCancel: () => {}
      });
    } catch (err) {
      console.error("Error verifying student:", err);
      showPopupAlert({
        title: 'Error!',
        message: 'Failed to accept student. Please try again.',
        type: 'error',
        onConfirm: () => setShowAlert(false),
        onCancel: () => {}
      });
    }
  };

  const handleDelete = (id: string) => {
    showPopupAlert({
      title: 'Confirm Delete',
      message: 'Are you sure you want to delete this student? This action cannot be undone.',
      type: 'confirm',
      onConfirm: () => {
        confirmDelete(id);
        setShowAlert(false);
      },
      onCancel: () => setShowAlert(false)
    });
  };

  const confirmDelete = async (id: string) => {
    try {
      const token = localStorage.getItem("toke");
      await axios.delete(`${BACK}/api/v1/student/reject/${id}`, {
        headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
          },
        withCredentials: true,
      });
      await fetchStudents();
      showPopupAlert({
        title: 'Success!',
        message: 'Student deleted successfully.',
        type: 'success',
        onConfirm: () => setShowAlert(false),
        onCancel: () => {}
      });
    } catch (err) {
      console.error("Error deleting student:", err);
      showPopupAlert({
        title: 'Error!',
        message: 'Failed to delete student. Please try again.',
        type: 'error',
        onConfirm: () => setShowAlert(false),
        onCancel: () => {}
      });
    }
  };

  // Filter functions
  const filterStudents = (students: Student[]) => {
    return students.filter(student => {
      const languageMatch = selectedLanguage === 'all' || student.language === selectedLanguage;
      const classMatch = selectedClass === 'all' || student.classNo === selectedClass;
      return languageMatch && classMatch;
    });
  };

  const filteredPendingStudents = filterStudents(pendingStudents);
  const filteredVerifiedStudents = filterStudents(verifiedStudents.filter(s => s.studentMobile !== "7278000101"));

  useEffect(() => {
    fetchStudents();
  }, []);

  return (
    <div className="min-h-screen bg-cyan-100">
      <NavComponent />
      <div className=" space-y-8 max-w-6xl mx-auto pt-24 pb-10">
        
        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
          <div className="bg-white rounded-xl shadow-lg p-6 border-l-4 border-amber-500">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600">Pending Approvals</p>
                <p className="text-3xl font-bold text-amber-600">{filteredPendingStudents.length}</p>
              </div>
              <Clock className="h-12 w-12 text-amber-500" />
            </div>
          </div>
          <div className="bg-white rounded-xl shadow-lg p-6 border-l-4 border-green-500">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600">Verified Students</p>
                <p className="text-3xl font-bold text-green-600">
                  {filteredVerifiedStudents.length}
                </p>
              </div>
              <UserCheck className="h-12 w-12 text-green-500" />
            </div>
          </div>
        </div>

        {/* Filter Controls */}
        <div className="bg-white rounded-xl shadow-lg p-6 mb-8">
          <h3 className="text-xl font-semibold text-gray-800 mb-6">Filter Students</h3>
          
          {/* Language Filter */}
          <div className="mb-6">
            <h4 className="text-lg font-semibold text-gray-800 mb-3">Language:</h4>
            <div className="inline-flex items-center justify-center p-1">
              <div className="relative bg-sky-100 rounded-2xl p-1 shadow-sm border border-sky-200 backdrop-blur-sm">
                <div className="flex w-full gap-1">
                  {[
                    { value: 'all', label: 'All' },
                    { value: 'Bengali', label: 'Bengali' },
                    { value: 'English', label: 'English' }
                  ].map((lang) => (
                    <button
                      key={lang.value}
                      onClick={() => setSelectedLanguage(lang.value)}
                      className={`
                        flex-1 px-6 py-2 rounded-xl font-medium text-sm
                        transition-all duration-300 ease-[cubic-bezier(0.4,0,0.2,1)]
                        ${selectedLanguage === lang.value
                          ? 'bg-sky-500 text-white shadow-sm scale-[1.02]'
                          : 'text-sky-700 hover:text-sky-800 hover:bg-sky-200/60'
                        }
                        focus:outline-none focus:ring-2 focus:ring-sky-300 focus:ring-offset-1 focus:ring-offset-sky-50
                        active:scale-95
                      `}
                      aria-pressed={selectedLanguage === lang.value}
                      role="tab"
                    >
                      {lang.label}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>

          {/* Class Filter */}
          <div className="mb-6">
            <h4 className="text-lg font-semibold text-gray-800 mb-3">Class:</h4>
            <div className="inline-flex items-center justify-center p-1">
              <div className="relative bg-sky-100 rounded-2xl p-1 shadow-sm border border-sky-200 backdrop-blur-sm">
                <div className="flex w-full gap-1">
                  {[
                    { value: 'all', label: 'All' },
                    { value: 9, label: '9' },
                    { value: 10, label: '10' },
                    { value: 11, label: '11' },
                    { value: 12, label: '12' }
                  ].map((cls) => (
                    <button
                      key={cls.value}
                      onClick={() => setSelectedClass(cls.value)}
                      className={`
                        flex-1 px-6 py-2 rounded-xl font-medium text-sm
                        transition-all duration-300 ease-[cubic-bezier(0.4,0,0.2,1)]
                        ${selectedClass === cls.value
                          ? 'bg-sky-500 text-white shadow-sm scale-[1.02]'
                          : 'text-sky-700 hover:text-sky-800 hover:bg-sky-200/60'
                        }
                        focus:outline-none focus:ring-2 focus:ring-sky-300 focus:ring-offset-1 focus:ring-offset-sky-50
                        active:scale-95
                      `}
                      aria-pressed={selectedClass === cls.value}
                      role="tab"
                    >
                      {cls.label}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>

          <p className="text-gray-600 italic">
            Showing <b>{selectedLanguage}</b> language students from <b>{selectedClass === 'all' ? 'all classes' : `class ${selectedClass}`}</b>
          </p>
        </div>

        {/* Pending Students */}
        <div className="bg-slate-100 rounded-xl shadow-lg overflow-hidden">
          <div className="bg-orange-500 px-6 py-4">
            <div className="flex items-center gap-3">
              <Clock className="h-6 w-6 text-white" />
              <h2 className="text-2xl font-bold text-white">Pending Approvals</h2>
            </div>
          </div>
          
          <div className="p-6">
            {filteredPendingStudents.length === 0 ? (
              <div className="text-center py-12">
                <AlertCircle className="h-16 w-16 text-gray-300 mx-auto mb-4" />
                <p className="text-gray-500 text-lg">
                  {pendingStudents.length === 0 ? 'No pending approvals' : 'No students match the current filters'}
                </p>
              </div>
            ) : (
              <div className="grid gap-6">
                {filteredPendingStudents.map((student) => (
                  <div key={student._id} className="bg-gradient-to-r from-amber-50 to-orange-50 border border-amber-200 rounded-xl p-6 hover:shadow-lg transition-all duration-200">
                    <div className="flex items-start justify-between mb-4">
                      <div className="flex items-center gap-3">
                        <div className="bg-amber-100 p-2 rounded-full">
                          <User className="h-5 w-5 text-amber-600" />
                        </div>
                        <div>
                          <h3 className="text-xl font-bold text-amber-800">{student.fullName}</h3>
                          <div className="grid grid-cols-2 sm:grid-cols-1 items-center gap-4 mt-2 text-sm text-gray-600">
                            <div className="flex items-center gap-1 col-span-2">
                              <Phone className="h-4 w-4" />
                              <span>{student.studentMobile}</span>
                            </div>
                            <div className="flex items-center gap-1">
                              <BookOpen className="h-4 w-4" />
                              <span>Class {student.classNo}</span>
                            </div>
                            <div className="flex items-center gap-1">
                              <Languages className="h-4 w-4" />
                              <span>{student.language}</span>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                    
                    <div className="bg-white rounded-lg p-4 mb-4 border border-neutral-200">
                      <div className="flex items-center gap-2 mb-2">
                        <Users className="h-4 w-4 text-gray-500" />
                        <span className="text-sm font-medium text-gray-700">Guardian Information</span>
                      </div>
                      <div className="flex items-center gap-4 text-sm text-gray-600">
                        <span className="font-medium">{student.guardianName}</span>
                        <div className="flex items-center gap-1">
                          <Phone className="h-3 w-3" />
                          <span>{student.guardianMobile}</span>
                        </div>
                      </div>
                    </div>
                    
                    <div className="flex gap-3">
                      <button
                        onClick={() => handleAccept(student._id)}
                        className="flex items-center gap-2 bg-green-600 text-white px-6 py-3 rounded-lg hover:bg-green-700 transition-colors font-medium"
                      >
                        <CheckCircle className="h-4 w-4" />
                        Accept
                      </button>
                      <button
                        onClick={() => handleDelete(student._id)}
                        className="flex items-center gap-2 bg-red-600 text-white px-6 py-3 rounded-lg hover:bg-red-700 transition-colors font-medium"
                      >
                        <Trash2 className="h-4 w-4" />
                        Reject
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Verified Students */}
        <div className="bg-slate-100 rounded-xl shadow-lg overflow-hidden">
          <div className="bg-emerald-500 px-6 py-4">
            <div className="flex items-center gap-3">
              <UserCheck className="h-6 w-6 text-white" />
              <h2 className="text-2xl font-bold text-white">Verified Students</h2>
            </div>
          </div>
          
          <div className="p-6">
            {filteredVerifiedStudents.length === 0 ? (
              <div className="text-center py-12">
                <Users className="h-16 w-16 text-gray-300 mx-auto mb-4" />
                <p className="text-gray-500 text-lg">
                  {verifiedStudents.filter(s => s.studentMobile !== "7278000101").length === 0 
                    ? 'No verified students' 
                    : 'No students match the current filters'}
                </p>
              </div>
            ) : (
              <div className="grid gap-6">
                {filteredVerifiedStudents.map((student) => (
                    <div key={student._id} className="bg-gradient-to-r from-green-50 to-emerald-50 border border-green-200 rounded-xl p-6 hover:shadow-lg transition-all duration-200">
                      <div className=" items-start justify-between mb-4">
                        <div className="flex items-center gap-3 ">
                          <div className="bg-green-100 p-2 rounded-full">
                            <UserCheck className="h-5 w-5 text-green-600" />
                          </div>
                          <div>
                            <h3 className="text-xl font-bold text-green-800">{student.fullName}</h3>
                            <div className="grid grid-cols-2 sm:grid-cols-1 items-center gap-4 mt-2 text-sm text-gray-600 ">
                              <div className="flex items-center gap-1 col-span-2">
                                <Phone className="h-4 w-4" />
                                <span>{student.studentMobile}</span>
                              </div>
                              <div className="flex items-center gap-1">
                                <BookOpen className="h-4 w-4" />
                                <span>Class {student.classNo}</span>
                              </div>
                              <div className="flex items-center gap-1">
                                <Languages className="h-4 w-4" />
                                <span>{student.language}</span>
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                      
                      <div className="bg-white rounded-lg p-4 mb-4 border border-neutral-200">
                        <div className="flex items-center gap-2 mb-2">
                          <Users className="h-4 w-4 text-gray-500" />
                          <span className="text-sm font-medium text-gray-700">Guardian Information</span>
                        </div>
                        <div className="flex items-center gap-4 text-sm text-gray-600">
                          <span className="font-medium">{student.guardianName}</span>
                          <div className="flex items-center gap-1">
                            <Phone className="h-3 w-3" />
                            <span>{student.guardianMobile}</span>
                          </div>
                        </div>
                      </div>
                      
                      <button
                        onClick={() => handleDelete(student._id)}
                        className="flex items-center gap-2 bg-red-600 text-white px-6 py-3 rounded-lg hover:bg-red-700 transition-colors font-medium"
                      >
                        <Trash2 className="h-4 w-4" />
                        Delete
                      </button>
                    </div>
                  ))}
              </div>
            )}
          </div>
        </div>

        {/* Custom Popup Alert */}
        {showAlert && (
          <div className="fixed inset-0 flex justify-center items-center bg-black/50 backdrop-blur-sm z-50">
            <div className="bg-white rounded-2xl shadow-xl w-96 p-6 flex flex-col items-center gap-4">
              <div className="flex items-center justify-center w-16 h-16 rounded-full mb-2">
                {alertConfig.type === 'success' && (
                  <CheckCircle size={48} className="text-green-500" />
                )}
                {alertConfig.type === 'error' && (
                  <Trash2 size={48} className="text-red-500 bg-red-100 rounded-full p-2" />
                )}
                {alertConfig.type === 'confirm' && (
                  <CircleQuestionMark size={48} className="text-rose-500 animate-bounce" />
                )}
              </div>

              <h2 className="text-xl font-semibold text-gray-800 text-center">
                {alertConfig.title}
              </h2>
              
              <p className="text-sm text-gray-600 text-center">
                {alertConfig.message}
              </p>

              <div className="flex gap-3 mt-4 w-full">
                {alertConfig.type === 'confirm' && (
                  <>
                    <button 
                      className="flex-1 py-2 px-4 rounded-xl border border-gray-300 text-gray-600 hover:bg-gray-100 transition-colors"
                      onClick={alertConfig.onCancel}
                    >
                      Cancel
                    </button>
                    <button 
                      className="flex-1 py-2 px-4 rounded-xl bg-red-500 text-white hover:bg-red-600 transition-colors"
                      onClick={alertConfig.onConfirm}
                    >
                      Confirm
                    </button>
                  </>
                )}
                
                {(alertConfig.type === 'success' || alertConfig.type === 'error') && (
                  <button 
                    className="w-full py-2 px-4 rounded-xl bg-blue-500 text-white hover:bg-blue-600 transition-colors"
                    onClick={alertConfig.onConfirm}
                  >
                    OK
                  </button>
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default ManageStudent;
