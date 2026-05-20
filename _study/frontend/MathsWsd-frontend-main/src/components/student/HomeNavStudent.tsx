import { LogOut, CheckCircle, X, AlertCircle } from "lucide-react";
import { useState, useCallback } from "react";
import Toast from "../all/ToastLoginFail";

const BACK = import.meta.env.PUBLIC_BACKEND;

const NavComponent = () => {
  const [isLoggingOut, setIsLoggingOut] = useState(false);
  const [showToast, setShowToast] = useState(false);
  const [toastType, setToastType] = useState(true); // 'success' or 'error'

  const showSuccessToast = () => {
    setToastType(true);
    setShowToast(true);
    setTimeout(() => setShowToast(false), 3000);
  };

  const showErrorToast = () => {
    setToastType(false);
    setShowToast(true);
    setTimeout(() => setShowToast(false), 3000);
  };

  const logout = useCallback(async () => {
    if (isLoggingOut) return;
    setIsLoggingOut(true);

    try {
      // Get token from localStorage (adjust key name as per your app)
      const token = localStorage.getItem('token');
      
      const headers: Record<string, string> = {
        "Content-Type": "application/json",
      };

      // Add Authorization header if token exists
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }

      const response = await fetch(`${BACK}/api/v1/student/logout`, {
        method: "POST",
        credentials: "include", // This ensures cookies are sent
        headers,
      });

      const result = await response.json();

      if (response.ok) {
        localStorage.clear();
        sessionStorage.clear();

        showSuccessToast();
        setTimeout(() => {
          window.location.href = "/login";
        }, 1500);
      } else {
        throw new Error(result.message || "Logout failed");
      }
    } catch (error) {
      console.error("Logout error:", error);
      
      // Type-safe error handling
      const errorMessage = error instanceof Error ? error.message : String(error);
      
      // Check if it's an auth error vs network error
      if (errorMessage.includes('Unauthorized') || errorMessage.includes('401')) {
        // If unauthorized, clear storage and redirect anyway
        localStorage.clear();
        sessionStorage.clear();
        showSuccessToast(); // Show success since user will be logged out
        setTimeout(() => {
          window.location.href = "/login";
        }, 1500);
      } else {
        // For other errors, show error toast but still redirect
        localStorage.clear();
        sessionStorage.clear();
        showErrorToast();
        setTimeout(() => {
          window.location.href = "/login";
        }, 1500);
      }
    } finally {
      setIsLoggingOut(false);
    }
  }, [isLoggingOut]);

  return (
    <>
      {/* Toast Notification */}
      {/*showToast && (
        <div className="fixed top-4 right-4 z-[60] transform transition-all duration-300 ease-out">
          <div className={`${
            toastType === 'success' ? 'bg-green-500' : 'bg-red-500'
          } text-white px-6 py-4 rounded-lg shadow-xl flex items-center space-x-3 min-w-[300px] border border-white/20`}>
            {toastType === 'success' ? (
              <CheckCircle className="w-5 h-5 flex-shrink-0" />
            ) : (
              <AlertCircle className="w-5 h-5 flex-shrink-0" />
            )}
            <span className="font-medium">
              {toastType === 'success' 
                ? 'Successfully logged out!' 
                : 'Something went wrong while logging out'
              }
            </span>
            <button 
              onClick={() => setShowToast(false)}
              className={`ml-auto ${
                toastType === 'success' ? 'hover:bg-green-600' : 'hover:bg-red-600'
              } rounded-full p-1 transition-colors`}
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>
      )*/}
      {toastType ? (<Toast 
        text="Successfully logged out!"
        isVisible={showToast}
        onClose={() => setShowToast(false)}
      />):(
        <Toast 
          text='Something went wrong while logging out'
          success={false}
          isVisible={showToast}
          onClose={() => setShowToast(false)}
        />
      )}

      <div className="fixed top-0 left-0 right-0 z-50 bg-teal-300/20 backdrop-blur-md border-b-2 border-teal-200/20">
        <nav className="p-3">
          <div className="max-w-7xl mx-auto flex items-center justify-between">
            <a href="/" className="flex items-center space-x-3">
              <img src="/assets/logo.jpg" alt="logo" className="w-12 h-12 rounded-full" />
              <span className="text-2xl font-bold text-gray-800 glyph">Maths with SD</span>
            </a>
            <button
              onClick={logout}
              disabled={isLoggingOut}
              className={`flex items-center space-x-2 border border-b-2 border-r-4 border-red-200 ${
                isLoggingOut
                  ? "bg-gray-400 cursor-not-allowed"
                  : "bg-red-500 hover:bg-red-600"
              } transition-all duration-300 text-white font-medium py-2.5 px-5 rounded-full shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 disabled:transform-none disabled:shadow-lg`}
            >
              <LogOut className={`w-4 h-4`} />
             {/* <span>{isLoggingOut ? "Logging out..." : "Logout"}</span> */}
              <span>{"Logout"}</span>
            </button>
          </div>
        </nav>
      </div>
    </>
  );
};

export default NavComponent;