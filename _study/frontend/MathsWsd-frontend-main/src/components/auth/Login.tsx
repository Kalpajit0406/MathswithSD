import { useState, type ChangeEvent } from "react"
import { EyeOff, Eye, ArrowRight, Sparkles, Trophy, Star, Zap, Heart, LoaderCircle, Meh, Frown, CircleAlert, User, UserRoundX, UserLock } from "lucide-react"
import Toast from "../all/ToastLoginFail"

// Environment variables - access at module level
const PUBLIC_ROLE = import.meta.env.PUBLIC_ROLE;
const API_BASE = "https://api.mathswithsd.in/api/v1";

// Type definitions
interface FormData {
    mobileNo: string
    password: string
}

interface FormErrors {
    mobileNo: string
    password: string
}

interface FormState {
    isSubmitting: boolean
    isSubmitted: boolean
    isDirty: boolean
    loginAttempts: number
}

interface Student {
    _id: string;
    fullName: string;
    studentMobile: string;
    class_No: string;
    guardianName: string;
    guardianMobile: string;
    verified: boolean;
}

const Login: React.FC = () => {
    // Form data state
    const [formData, setFormData] = useState<FormData>({
        mobileNo: '',
        password: ''
    })

    // Error states
    const [errors, setErrors] = useState<FormErrors>({
        mobileNo: '',
        password: ''
    })

    // Form state
    const [formState, setFormState] = useState<FormState>({
        isSubmitting: false,
        isSubmitted: false,
        isDirty: false,
        loginAttempts: 0
    })

    // Password visibility state
    const [showPassword, setShowPassword] = useState<boolean>(false)
    const [showConfetti, setShowConfetti] = useState<boolean>(false)
    const [showUnverifiedPopup, setShowUnverifiedPopup] = useState<boolean>(false)

    // Password visibility toggle
    const togglePassword = (): void => setShowPassword(prev => !prev)

    // Form validation functions
    const validateMobile = (mobile: string): string => {
        if (!mobile) return "Mobile number is required"
        if (!/^[6-9]\d{9}$/.test(mobile)) return "Enter a valid 10-digit mobile number"
        return ""
    }

    const validatePassword = (password: string): string => {
        if (!password) return "Password is required"
        if (password.length < 6) return "Password must be at least 6 characters"
        return ""
    }

    // Handle input changes
    const handleChange = (e: ChangeEvent<HTMLInputElement>): void => {
        const { name, value } = e.target
        
        // Update form data
        setFormData(prev => ({
            ...prev,
            [name]: value
        }))

        // Mark form as dirty
        setFormState(prev => ({
            ...prev,
            isDirty: true
        }))

        // Clear error when user starts typing
        if (errors[name as keyof FormErrors]) {
            setErrors(prev => ({
                ...prev,
                [name]: ""
            }))
        }
    }

    // Validate all fields
    const validateForm = (): FormErrors => {
        return {
            mobileNo: validateMobile(formData.mobileNo),
            password: validatePassword(formData.password)
        }
    }

    // Handle form submission
    const handleSubmit = async (): Promise<void> => {
        // Set submitting state
        setFormState(prev => ({
            ...prev,
            isSubmitting: true
        }))

        try {
            // Validate all fields
            const newErrors = validateForm()
            setErrors(newErrors)

            // Check if there are any errors
            const hasErrors = Object.values(newErrors).some(error => error !== "")
            
            if (!hasErrors) {
                // Step 1: Login API call
                const loginResponse = await fetch(`${API_BASE}/student/login`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    credentials: 'include',
                    body: JSON.stringify({ 
                        studentMobile: formData.mobileNo, 
                        password: formData.password 
                    })
                });

                if (!loginResponse.ok) {
                    const errorData = await loginResponse.json();
                    throw new Error(errorData.message || 'Login failed');
                }

                const loginData = await loginResponse.json();
                const { accessToken, refreshToken, user, role } = loginData.data;

                // Store tokens and user data temporarily
                const tempToken = accessToken;
                const tempRole = role;

                // Step 2: Fetch all students to verify student status
                const studentResponse = await fetch(`${API_BASE}/student/students`, {
                    method: 'GET',
                    credentials: 'include',
                    headers: {
                        'Authorization': `Bearer ${tempToken}`,
                        'Content-Type': 'application/json'
                    }
                });

                if (!studentResponse.ok) {
                    throw new Error('Failed to fetch student data');
                }

                const studentData = await studentResponse.json();
                const allStudents = [
                    ...(studentData?.verified || []),
                    ...(studentData?.unverified || []),
                ];

                // Step 3: Find student by mobile
                const student = allStudents.find((s: Student) => s.studentMobile === formData.mobileNo);

                if (!student) {
                    throw new Error("Student not found in records.");
                }

                // Step 4: Check if student is verified
                if (!student.verified) {
                    // Clear any stored data for unverified user
                    localStorage.clear();
                    // Show unverified popup instead of generic error
                    setShowUnverifiedPopup(true);
                    setFormState(prev => ({
                        ...prev,
                        isSubmitting: false
                    }))
                    return; // Exit early for unverified users
                }

                // Step 5: Store data only for verified students
                localStorage.setItem("token", tempToken);
                localStorage.setItem("role", tempRole);
                localStorage.setItem("student", JSON.stringify(student));
                
                console.log("Login successful:", { user, role, student });
                
                // Update form state for success
                setFormState(prev => ({
                    ...prev,
                    isSubmitting: false,
                    isSubmitted: true,
                    loginAttempts: 0
                }))
                
                // Trigger confetti animation
                setShowConfetti(true)
                
                // Step 6: Redirect based on role after animation
                setTimeout(() => {
                    // Use the module-level constant instead
                    if (tempRole === PUBLIC_ROLE) {
                        window.location.href = "/teacher";
                    } else {
                        window.location.href = "/";
                    }
                }, 3000)
                
            } else {
                console.log("Form has validation errors:", newErrors)
                setFormState(prev => ({
                    ...prev,
                    isSubmitting: false
                }))
            }
        } catch (error: any) {
            console.error("Login error:", error)
            
            setFormState(prev => ({
                ...prev,
                isSubmitting: false,
                loginAttempts: prev.loginAttempts + 1
            }))
            
            // Handle different error types
            let errorMessage = "Login failed. Please try again.";
            
            if (error instanceof Error) {
                // Check for specific error patterns
                if (error.message.includes("Unexpected token") || 
                    error.message.includes("JSON") || 
                    error.message.includes("<!DOCTYPE")) {
                    errorMessage = "Either mobile number or password is incorrect.";
                } else if (error.message.includes("not verified")) {
                    errorMessage = error.message; // Keep verification message
                } else if (error.message.includes("not found")) {
                    errorMessage = "Either mobile number or password is incorrect.";
                } else if (error.message.includes("401") || 
                          error.message.includes("Unauthorized") ||
                          error.message.includes("Invalid credentials")) {
                    errorMessage = "Either mobile number or password is incorrect.";
                } else {
                    errorMessage = error.message;
                }
            } else if (error && typeof error === 'object' && 'response' in error) {
                const response = (error as any).response;
                errorMessage = response?.data?.message || "Either mobile number or password is incorrect.";
            }
            
            // Clear any stored data on error
            localStorage.clear();
            
            setErrors({
                mobileNo: "",
                password: errorMessage
            })
        }
    }

    // Reset form
    const resetForm = (): void => {
        setFormData({
            mobileNo: '',
            password: ''
        })
        setErrors({
            mobileNo: '',
            password: ''
        })
        setFormState({
            isSubmitting: false,
            isSubmitted: false,
            isDirty: false,
            loginAttempts: 0
        })
        setShowPassword(false)
        setShowConfetti(false)
        setShowUnverifiedPopup(false)
    }

    // Check if form is valid
    const isFormValid = (): boolean => {
        const validationErrors = validateForm()
        return !Object.values(validationErrors).some(error => error !== "") && 
               formData.mobileNo.length > 0 && 
               formData.password.length > 0
    }

    // Check if too many attempts
    const tooManyAttempts = formState.loginAttempts >= 3

    return (
        <div className="bg-cyan-100 flex items-center justify-center min-h-screen p-4">
            {/* Unverified Student Popup */}
            {showUnverifiedPopup && (
                <div className="fixed inset-0 bg-teal-300/20 backdrop-blur-md bg-opacity-50 flex items-center justify-center z-50 p-4">
                    <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6 space-y-4 relative">
                        {/* Warning Icon */}
                        <div className="text-center">
                            <div className="w-16 h-16 mx-auto bg-red-100 rounded-full flex items-center justify-center mb-4">
                                <UserRoundX className="w-8 h-8 text-red-500" />
                            </div>
                            <h3 className="text-xl font-bold text-red-600 mb-2">Account Not Verified</h3>
                            <p className="text-gray-700 mb-4">
                                Your account is not verified yet. Please contact your teacher for verification to access your dashboard.
                            </p>
                            <div className="flex items-center justify-center gap-2 text-amber-600 mb-4">
                                <Star className="w-5 h-5" />
                                <span className="font-medium">Verification Required</span>
                                <Star className="w-5 h-5" />
                            </div>
                        </div>
                        
                        <button
                            onClick={() => {
                                setShowUnverifiedPopup(false);
                                resetForm();
                            }}
                            className="w-full bg-red-500 hover:bg-red-600 text-white py-3 px-4 rounded-lg font-semibold transition-colors flex items-center justify-center gap-2"
                        >
                            I Understand
                        </button>
                    </div>
                </div>
            )}

            <div className="bg-white rounded-2xl shadow-xl w-full max-w-md p-6 space-y-3 select-none relative overflow-hidden">
                {/* Background decorative elements */}
                {showConfetti && (
                    <div className="absolute inset-0 pointer-events-none">
                        <div className="absolute top-4 left-4 text-yellow-400 animate-bounce">
                            <Star className="w-4 h-4" />
                        </div>
                        <div className="absolute top-6 right-6 text-pink-400 animate-pulse">
                            <Heart className="w-3 h-3" />
                        </div>
                        <div className="absolute top-12 left-1/2 text-purple-400 animate-spin">
                            <Sparkles className="w-3 h-3" />
                        </div>
                        <div className="absolute bottom-20 right-4 text-green-400 animate-bounce" style={{animationDelay: '0.5s'}}>
                            <Zap className="w-4 h-4" />
                        </div>
                        <div className="absolute bottom-16 left-6 text-blue-400 animate-pulse" style={{animationDelay: '1s'}}>
                            <Trophy className="w-3 h-3" />
                        </div>
                    </div>
                )}

                {/* Title */}
                <h2 className="text-3xl font-extrabold text-center text-blue-600 flex items-center justify-center gap-2">
                    {formState.isSubmitted ? (
                    <div className="text-center py-8 space-y-6">
                        {/* Brand Header in Success */}
                        <div className="flex items-center justify-center gap-3 mb-4">
                            <img 
                                src="/assets/logo.jpg" 
                                alt="Maths with SD Logo" 
                                className="h-10 w-10 rounded-full border-2 border-gray-200 shadow-md"
                            />
                            <h1 className="text-xl font-bold text-gray-800">Maths with SD</h1>
                        </div>
                        
                        {/* Success Icon */}
                        <div className="w-20 h-20 mx-auto bg-gradient-to-br from-sky-400 to-cyan-500 rounded-full flex items-center justify-center shadow-lg">
                            <User className="w-12 h-12 text-white" />
                        </div>
                        
                        {/* Success Message */}
                        <div className="space-y-2">
                            <h3 className="text-2xl font-bold text-gray-800">Login Successful!</h3>
                            <p className="text-gray-600 text-sm">You will be redirected to your dashboard shortly</p>
                        </div>
                        
                        {/* Skeletal Loader */}
                        <div className="space-y-3 pt-4">
                            <div className="flex items-center justify-center gap-2 text-blue-600 mb-4">
                                <span className="text-sm font-medium">Preparing your dashboard...</span>
                            </div>
                            
                            {/* Dashboard Preview Skeleton */}
                            <div className="space-y-3 bg-gray-50 p-4 rounded-lg">
                                {/* Header skeleton */}
                                <div className="flex items-center gap-3">
                                    <div className="w-8 h-8 bg-gray-200 rounded-full animate-pulse"></div>
                                    <div className="h-4 bg-gray-200 rounded animate-pulse flex-1"></div>
                                </div>
                                
                                {/* Content skeleton */}
                                <div className="space-y-2">
                                    <div className="h-3 bg-gray-200 rounded animate-pulse w-3/4"></div>
                                    <div className="h-3 bg-gray-200 rounded animate-pulse w-1/2"></div>
                                </div>
                                
                                {/* Cards skeleton */}
                                <div className="grid grid-cols-2 gap-2 mt-3">
                                    <div className="h-16 bg-gray-200 rounded animate-pulse"></div>
                                    <div className="h-16 bg-gray-200 rounded animate-pulse"></div>
                                </div>
                            </div>
                        </div>
                    </div>
                ) : (
                        "Login"
                    )}
                </h2>

                {formState.isSubmitted ? (

                    <Toast
                        text="Log in successful"
                        isVisible={true}
                    />
                ) : (
                    <>
                        {/* Enhanced Error Display */}
                        {errors.password && !tooManyAttempts && (
                            <div className="bg-red-50 border border-red-200 text-red-700 p-4 rounded-lg text-sm flex items-start gap-3">
                                <div className="w-5 h-5 mt-0.5 flex-shrink-0">
                                    {errors.password.includes("not verified") ? (
                                        <UserLock className="w-5 h-5" />
                                    ) : errors.password.includes("not found") ? (
                                        <UserRoundX className="w-5 h-5" />
                                    ) : (
                                        <Frown className="w-5 h-5" />
                                    )}
                                </div>
                                <div>
                                    <div className="font-medium mb-1">
                                        {errors.password.includes("not verified") ? "Account Not Verified" :
                                         errors.password.includes("not found") ? "Student Not Found" :
                                         "Login Failed"}
                                    </div>
                                    <div>{errors.password}</div>
                                </div>
                            </div>
                        )}

                        {/* Too many attempts warning */}
                        {tooManyAttempts && (
                            <div className="bg-red-50 border border-red-200 text-red-700 p-3 rounded-lg text-sm flex items-center gap-2">
                                <Meh className="w-4 h-4" />
                                Too many failed attempts. Please wait before trying again.
                            </div>
                        )}

                        {/* Login attempts indicator */}
                        {formState.loginAttempts > 0 && formState.loginAttempts < 3 && (
                            <div className="bg-amber-50 border border-amber-200 text-amber-700 p-3 rounded-lg text-sm flex items-center gap-2">
                                <CircleAlert className="w-4 h-4" />
                                Failed login attempt {formState.loginAttempts} of 3
                            </div>
                        )}

                        {/* Mobile number */}
                        <div className="space-y-1">
                            <label className="block font-medium text-lg text-gray-700">Enter Mobile Number:</label>
                            <div className={`flex items-center border rounded-lg shadow-sm focus-within:ring-2 transition-colors ${
                                errors.mobileNo 
                                    ? 'border-red-500 focus-within:ring-red-500' 
                                    : 'border-gray-300 focus-within:ring-blue-500 focus-within:border-blue-500'
                            }`}>
                                <span className="px-3 py-2 bg-gray-50 border-r border-gray-300 text-gray-600 rounded-l-lg">+91</span>
                                <input 
                                    name="mobileNo"
                                    value={formData.mobileNo}
                                    onChange={handleChange}
                                    type="tel" 
                                    pattern="[6-9]{1}[0-9]{9}" 
                                    maxLength={10} 
                                    className="flex-1 px-3 py-2 border-0 focus:outline-none rounded-r-lg" 
                                    placeholder="Enter 10-digit number" 
                                    disabled={formState.isSubmitting || tooManyAttempts}
                                />
                            </div>
                            {errors.mobileNo && <p className="mt-1 text-sm text-red-600">{errors.mobileNo}</p>}
                        </div>

                        {/* Password */}
                        <div className="space-y-1">
                            <label className="block font-medium text-lg text-gray-700">Enter Password:</label>
                            <div className="relative">
                                <input 
                                    name="password"
                                    value={formData.password}
                                    onChange={handleChange}
                                    type={showPassword ? "text" : "password"} 
                                    minLength={6} 
                                    className={`w-full px-3 py-2 pr-12 border rounded-lg shadow-sm focus:outline-none focus:ring-2 transition-colors ${
                                        errors.password 
                                            ? 'border-red-500 focus:ring-red-500' 
                                            : 'border-gray-300 focus:ring-blue-500'
                                    }`}
                                    placeholder="Enter password" 
                                    disabled={formState.isSubmitting || tooManyAttempts}
                                />
                                <button 
                                    type="button" 
                                    onClick={togglePassword} 
                                    disabled={formState.isSubmitting || tooManyAttempts}
                                    className="absolute inset-y-0 right-0 flex items-center px-3 text-gray-400 hover:text-gray-800 hover:bg-gray-300 bg-gray-200 rounded-r-lg focus:bg-blue-300 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                                >
                                    {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                                </button>
                            </div>
                            {errors.password && <p className="mt-1 text-sm text-red-600">{errors.password}</p>}
                        </div>

                        {/* Form status indicator */}
                        {formState.isDirty && !tooManyAttempts && (
                            <div className={`text-sm p-3 rounded-lg transition-colors flex items-center gap-2 ${
                                isFormValid() 
                                    ? '' // 'text-green-700 bg-green-50 border border-green-200' 
                                    : 'text-amber-700 bg-amber-50 border border-amber-200'
                            }`}>
                                {isFormValid() ? (
                                    <></>
                                ) : (
                                    <>
                                        <Star className="w-4 h-4" />
                                        Please fill in all required fields
                                    </>
                                )}
                            </div>
                        )}

                        {/* Submit button */}
                        <button 
                            type="button"
                            onClick={handleSubmit}
                            disabled={formState.isSubmitting || !formState.isDirty || !isFormValid() || tooManyAttempts}
                            className={`w-full py-3 px-4 rounded-lg shadow-lg focus:outline-none focus:ring-4 focus:ring-blue-300 font-semibold transition-all duration-300 flex items-center justify-center gap-2 ${
                                formState.isSubmitting 
                                    ? 'bg-blue-400 text-white cursor-not-allowed' 
                                    : tooManyAttempts
                                    ? 'bg-red-400 text-white cursor-not-allowed'
                                    : !formState.isDirty || !isFormValid()
                                    ? 'bg-gray-400 text-white cursor-not-allowed'
                                    : 'bg-blue-600 hover:bg-blue-700 text-white hover:shadow-xl'
                            }`}
                        >
                            {formState.isSubmitting ? (
                                <>
                                    <LoaderCircle className="w-5 h-5 animate-spin" />
                                    Logging in...
                                </>
                            ) : tooManyAttempts ? (
                                <>
                                    <EyeOff className="w-5 h-5" />
                                    Too Many Attempts
                                </>
                            ) : (
                                <>
                                    <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
                                    Log in
                                </>
                            )}
                        </button>

                        {/* Registration link */}
                        <p className="text-center mt-4 flex items-center justify-center gap-1">
                            Don't have an account?
                            <a href="/register" className="text-blue-600 underline hover:text-blue-800 flex items-center gap-1">
                                <Sparkles className="w-3 h-3" />
                                Register here
                            </a>
                        </p>
                    </>
                )}
            </div>
        </div>
    )
}

export default Login