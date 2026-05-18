import { EyeOff, Eye } from "lucide-react"
import { useState, type ChangeEvent } from "react"

const BACKEND = import.meta.env.PUBLIC_BACKEND

// Language union type
type Language = "Bengali" | "English";

// Type definitions
interface FormData {
    fullName: string
    studentMobile: string
    classNo: number
    guardianName: string
    guardianMobile: string
    password: string
    confirmPassword: string
    language: Language | ""
}

interface FormErrors {
    fullName: string
    studentMobile: string
    classNo: string
    guardianName: string
    guardianMobile: string
    password: string
    confirmPassword: string
    language: string
}

interface FormState {
    isSubmitting: boolean
    isSubmitted: boolean
    isDirty: boolean
}

interface PopupState {
    isVisible: boolean
    type: 'success' | 'error'
    title: string
    message: string
}

const RegisterUser: React.FC = () => {
    // Form data state
    const [formData, setFormData] = useState<FormData>({
        fullName: "",
        studentMobile: "",
        classNo: 0,
        guardianName: "",
        guardianMobile: "",
        password: "",
        confirmPassword: "",
        language: ""
    })

    // Error states
    const [errors, setErrors] = useState<FormErrors>({
        fullName: "",
        studentMobile: "",
        classNo: "",
        guardianName: "",
        guardianMobile: "",
        password: "",
        confirmPassword: "",
        language: ""
    })

    // Form state
    const [formState, setFormState] = useState<FormState>({
        isSubmitting: false,
        isSubmitted: false,
        isDirty: false
    })

    // Popup state
    const [popup, setPopup] = useState<PopupState>({
        isVisible: false,
        type: 'success',
        title: '',
        message: ''
    })

    // Password visibility states
    const [showMainPassword, setShowMainPassword] = useState<boolean>(false)
    const [showConfPassword, setShowConfPassword] = useState<boolean>(false)

    // Password visibility toggles
    const toggleMainPassword = (): void => setShowMainPassword(prev => !prev)
    const toggleConfPassword = (): void => setShowConfPassword(prev => !prev)

    // Show popup
    const showPopup = (type: 'success' | 'error', title: string, message: string): void => {
        setPopup({
            isVisible: true,
            type,
            title,
            message
        })
    }

    // Hide popup
    const hidePopup = (): void => {
        setPopup(prev => ({
            ...prev,
            isVisible: false
        }))
    }

    // Redirect to home page
    const redirectToHome = (): void => {
        window.location.href = '/login'
    }

    // Form validation functions
    const validateFullName = (name: string): string => {
        if (!name.trim()) return "Full name is required"
        if (name.trim().length < 5) return "Full name must be at least 5 characters long"
        if (!/^[a-zA-Z\s]+$/.test(name)) return "Full name can only contain letters and spaces"
        return ""
    }

    const validateMobile = (mobile: string): string => {
        if (!mobile) return "Mobile number is required"
        if (!/^[6-9]\d{9}$/.test(mobile)) return "Mobile number must start with 6-9 and be exactly 10 digits"
        return ""
    }

    const validateClass = (classNo: number): string => {
        if (classNo === 0) return "Please select your class (9, 10, 11 or 12)"
        return ""
    }

    const validateLanguage = (language: Language | ""): string => {
        if (!language) return "Please select your preferred medium (Bengali or English)"
        return ""
    }

    const validatePassword = (password: string): string => {
        if (!password) return "Password is required"
        if (password.length < 6) return "Password must be at least 6 characters long"
        {/*if (!/(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/.test(password)) {
            return "Password must contain at least one uppercase letter, one lowercase letter, and one number"
        }*/}
        return ""
    }

    const validateConfirmPassword = (confirmPassword: string, password: string): string => {
        if (!confirmPassword) return "Please confirm your password"
        if (confirmPassword !== password) return "Passwords do not match"
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

        // Real-time validation for password match
        if (name === "confirmPassword" && formData.password) {
            const confirmError = validateConfirmPassword(value, formData.password)
            setErrors(prev => ({
                ...prev,
                confirmPassword: confirmError
            }))
        }
        if (name === "password" && formData.confirmPassword) {
            const confirmError = validateConfirmPassword(formData.confirmPassword, value)
            setErrors(prev => ({
                ...prev,
                confirmPassword: confirmError
            }))
        }
    }

    // Handle class selection
    const handleClassSelect = (classNumber: number): void => {
        setFormData(prev => ({
            ...prev,
            classNo: classNumber
        }))
        
        // Mark form as dirty
        setFormState(prev => ({
            ...prev,
            isDirty: true
        }))
        
        // Clear class error
        if (errors.classNo) {
            setErrors(prev => ({
                ...prev,
                classNo: ""
            }))
        }
    }

    // Handle language selection
    const handleLanguageSelect = (selectedLanguage: Language): void => {
        setFormData(prev => ({
            ...prev,
            language: selectedLanguage
        }))
        
        // Mark form as dirty
        setFormState(prev => ({
            ...prev,
            isDirty: true
        }))
        
        // Clear language error
        if (errors.language) {
            setErrors(prev => ({
                ...prev,
                language: ""
            }))
        }
    }

    // Validate all fields
    const validateForm = (): FormErrors => {
        return {
            fullName: validateFullName(formData.fullName),
            studentMobile: validateMobile(formData.studentMobile),
            classNo: validateClass(formData.classNo),
            guardianName: validateFullName(formData.guardianName),
            guardianMobile: validateMobile(formData.guardianMobile),
            password: validatePassword(formData.password),
            confirmPassword: validateConfirmPassword(formData.confirmPassword, formData.password),
            language: validateLanguage(formData.language)
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
                // Prepare data for API (exclude confirmPassword)
                const apiData = {
                    fullName: formData.fullName,
                    studentMobile: formData.studentMobile,
                    classNo: formData.classNo,
                    guardianName: formData.guardianName,
                    guardianMobile: formData.guardianMobile,
                    password: formData.password,
                    language: formData.language
                }

                // Make API call to backend
                const response = await fetch(`${BACKEND}/api/v1/student/register`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(apiData)
                })
                
                // Check if response is JSON
                const contentType = response.headers.get('content-type')
                let responseData
                
                if (contentType && contentType.includes('application/json')) {
                    responseData = await response.json()
                } else {
                    // If not JSON, it might be HTML error page
                    const textResponse = await response.text()
                    console.log("Non-JSON Response:", textResponse)
                    
                    // Handle common error cases
                    if (response.status === 409 || textResponse.includes('duplicate') || textResponse.includes('already exists')) {
                        throw new Error('This mobile number is already registered. Please use a different number or try logging in.')
                    } else if (response.status === 400) {
                        throw new Error('Invalid data provided. Please check all fields and try again.')
                    } else if (response.status === 500) {
                        throw new Error('Server error occurred. Please try again later.')
                    } else {
                        throw new Error('Registration failed. Please try again.')
                    }
                }
                
                console.log("API Response:", responseData)
                
                if (!response.ok) {
                    // Handle specific error messages from backend
                    let errorMessage = 'Registration failed'
                    
                    if (responseData.message) {
                        const message = responseData.message.toLowerCase()
                        if (message.includes('mobile') && (message.includes('exists') || message.includes('duplicate') || message.includes('already'))) {
                            errorMessage = 'This mobile number is already registered. Please use a different number or try logging in.'
                        } else if (message.includes('email') && (message.includes('exists') || message.includes('duplicate') || message.includes('already'))) {
                            errorMessage = 'This email is already registered. Please use a different email or try logging in.'
                        } else if (message.includes('validation') || message.includes('invalid')) {
                            errorMessage = 'Please check all fields and ensure they are filled correctly.'
                        } else {
                            errorMessage = responseData.message
                        }
                    }
                    
                    throw new Error(errorMessage)
                }
                
                // Update form state on success (but don't show success view)
                setFormState(prev => ({
                    ...prev,
                    isSubmitting: false,
                    isSubmitted: true
                }))
                
                showPopup('success', 'Registration Successful!', 'Your account has been created successfully. You will be redirected to the login page.')
                
                // Redirect after 2 seconds
                setTimeout(() => {
                    redirectToHome()
                }, 2000)
                
            } else {
                console.log("Form has validation errors:", newErrors)
                setFormState(prev => ({
                    ...prev,
                    isSubmitting: false
                }))
            }
        } catch (error) {
            console.error("API Error:", error)
            
            // Handle API errors
            if (error instanceof Error) {
                showPopup('error', 'Registration Failed', error.message)
            } else {
                showPopup('error', 'Registration Failed', 'An unexpected error occurred. Please try again.')
            }
            
            setFormState(prev => ({
                ...prev,
                isSubmitting: false
            }))
        }
    }

    // Reset form
    const resetForm = (): void => {
        setFormData({
            fullName: "",
            studentMobile: "",
            classNo: 0,
            guardianName: "",
            guardianMobile: "",
            password: "",
            confirmPassword: "",
            language: ""
        })
        setErrors({
            fullName: "",
            studentMobile: "",
            classNo: "",
            guardianName: "",
            guardianMobile: "",
            password: "",
            confirmPassword: "",
            language: ""
        })
        setFormState({
            isSubmitting: false,
            isSubmitted: false,
            isDirty: false
        })
        setShowMainPassword(false)
        setShowConfPassword(false)
    }

    // Check if form is valid
    const isFormValid = (): boolean => {
        const validationErrors = validateForm()
        return !Object.values(validationErrors).some(error => error !== "")
    }

    return (
        <div className="bg-cyan-100 flex items-center justify-center min-h-screen p-4">
            <div className="bg-white p-8 rounded-lg shadow-md w-full max-w-md space-y-3 mt-8 select-none">
                {/* Title */}
                <h2 className="text-2xl font-bold text-center text-blue-600">
                    Register
                </h2>
                
                {/* Student Details */}
                <label className="block font-bold text-lg text-gray-700">Student Details</label>
                
                {/* Full name */}
                <div>
                    <input 
                        name="fullName"
                        value={formData.fullName}
                        onChange={handleChange}
                        placeholder="Enter your full name" 
                        className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 transition-colors ${
                            errors.fullName 
                                ? 'border-red-500 focus:ring-red-500' 
                                : 'border-gray-300 focus:ring-blue-500'
                        }`}
                        type="text" 
                        disabled={formState.isSubmitting}
                    />
                    {errors.fullName && <p className="mt-1 text-sm text-red-600">{errors.fullName}</p>}
                </div>
                
                {/* Student Mobile no */}
                <div>
                    <div className={`flex items-center border rounded-md shadow-sm focus-within:ring-2 transition-colors ${
                        errors.studentMobile 
                            ? 'border-red-500 focus-within:ring-red-500' 
                            : 'border-gray-300 focus-within:ring-blue-500 focus-within:border-blue-500'
                    }`}>
                        <span className="px-3 py-2 bg-gray-50 border-r border-gray-300 text-gray-600 rounded-l-md">+91</span>
                        <input 
                            name="studentMobile"
                            value={formData.studentMobile}
                            onChange={handleChange}
                            type="tel" 
                            pattern="[6-9]{1}[0-9]{9}" 
                            maxLength={10} 
                            className="flex-1 px-3 py-2 border-0 focus:outline-none rounded-r-md" 
                            placeholder="Enter 10-digit number" 
                            disabled={formState.isSubmitting}
                        />
                    </div>
                    {errors.studentMobile && <p className="mt-1 text-sm text-red-600">{errors.studentMobile}</p>}
                </div>

                {/* Class selection */}
                <div>
                    <label className="block text-lg font-bold text-gray-700 mb-2">Select class</label>
                    <div className="flex gap-2">
                        {[9, 10, 11, 12].map((classNumber: number) => (
                            <button 
                                key={classNumber} 
                                type="button" 
                                onClick={() => handleClassSelect(classNumber)} 
                                disabled={formState.isSubmitting}
                                className={`px-6 py-3 rounded-xl font-semibold transition-all duration-300 ease-out disabled:opacity-50 disabled:cursor-not-allowed ${
                                    formData.classNo === classNumber 
                                        ? 'bg-blue-600 text-white shadow-lg shadow-blue-500/25 transform scale-105 ring-2 ring-blue-200' 
                                        : 'bg-gray-50 text-gray-700 hover:bg-blue-50 hover:text-blue-600 hover:shadow-md border border-gray-300 hover:border-blue-300'
                                }`}
                            > 
                                {classNumber} 
                            </button>
                        ))}
                    </div>
                    {errors.classNo && <p className="mt-1 text-sm text-red-600">{errors.classNo}</p>}
                </div>

                {/* Language/Medium selection */}
                <div>
                    <label className="block text-lg font-bold text-gray-700 mb-2">Select medium</label>
                    <div className="flex gap-2">
                        {(["Bengali", "English"] as Language[]).map((lang: Language) => (
                            <button 
                                key={lang} 
                                type="button" 
                                onClick={() => handleLanguageSelect(lang)} 
                                disabled={formState.isSubmitting}
                                className={`px-6 py-3 rounded-xl font-semibold transition-all duration-300 ease-out disabled:opacity-50 disabled:cursor-not-allowed ${
                                    formData.language === lang 
                                        ? 'bg-green-600 text-white shadow-lg shadow-green-500/25 transform scale-105 ring-2 ring-green-200' 
                                        : 'bg-gray-50 text-gray-700 hover:bg-green-50 hover:text-green-600 hover:shadow-md border border-gray-300 hover:border-green-300'
                                }`}
                            > 
                                {lang} 
                            </button>
                        ))}
                    </div>
                    {errors.language && <p className="mt-1 text-sm text-red-600">{errors.language}</p>}
                </div>
                
                {/* Guardian data */}
                <label className="block font-bold text-lg text-gray-700 mt-6">Guardian's Details</label>
                
                {/* Guardian name */}
                <div>
                    <input 
                        name="guardianName"
                        value={formData.guardianName}
                        onChange={handleChange}
                        placeholder="Enter Guardian Name" 
                        className={`w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 transition-colors ${
                            errors.guardianName 
                                ? 'border-red-500 focus:ring-red-500' 
                                : 'border-gray-300 focus:ring-blue-500'
                        }`}
                        type="text"
                        disabled={formState.isSubmitting}
                    />
                    {errors.guardianName && <p className="mt-1 text-sm text-red-600">{errors.guardianName}</p>}
                </div>
                
                {/* Guardian mob no */}
                <div>
                    <div className={`flex items-center border rounded-md shadow-sm focus-within:ring-2 transition-colors ${
                        errors.guardianMobile 
                            ? 'border-red-500 focus-within:ring-red-500' 
                            : 'border-gray-300 focus-within:ring-blue-500 focus-within:border-blue-500'
                    }`}>
                        <span className="px-3 py-2 bg-gray-50 border-r border-gray-300 text-gray-600 rounded-l-md">+91</span>
                        <input 
                            name="guardianMobile"
                            value={formData.guardianMobile}
                            onChange={handleChange}
                            type="tel" 
                            pattern="[6-9]{1}[0-9]{9}" 
                            maxLength={10} 
                            className="flex-1 px-3 py-2 border-0 focus:outline-none rounded-r-md" 
                            placeholder="Enter Guardian mobile number" 
                            disabled={formState.isSubmitting}
                        />
                    </div>
                    {errors.guardianMobile && <p className="mt-1 text-sm text-red-600">{errors.guardianMobile}</p>}
                </div>
                
                {/* Password and confirm password */}
                <label className="block font-bold text-lg text-gray-700 mt-6">Enter Password</label>
                
                {/* Main password */}
                <div>
                    <div className="relative">
                        <input 
                            name="password"
                            value={formData.password}
                            onChange={handleChange}
                            type={showMainPassword ? "text" : "password"} 
                            minLength={6} 
                            className={`w-full px-3 py-2 pr-12 border rounded-md shadow-sm focus:outline-none focus:ring-2 transition-colors ${
                                errors.password 
                                    ? 'border-red-500 focus:ring-red-500' 
                                    : 'border-gray-300 focus:ring-blue-500'
                            }`}
                            placeholder="Enter password" 
                            disabled={formState.isSubmitting}
                        />
                        <button 
                            type="button" 
                            onClick={toggleMainPassword} 
                            disabled={formState.isSubmitting}
                            className="absolute inset-y-0 right-0 flex items-center px-3 text-gray-400 hover:text-gray-800 hover:bg-gray-300 bg-gray-200 rounded-r-md hover:rounded-r-md focus:bg-blue-300 focus:rounded-r-md focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed" 
                        >
                            {showMainPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                        </button>
                    </div>
                    {errors.password && <p className="mt-1 text-sm text-red-600">{errors.password}</p>}
                </div>

                {/* Confirm password */}
                <div>
                    <div className="relative">
                        <input 
                            name="confirmPassword"
                            value={formData.confirmPassword}
                            onChange={handleChange}
                            type={showConfPassword ? "text" : "password"} 
                            minLength={6} 
                            className={`w-full px-3 py-2 pr-12 border rounded-md shadow-sm focus:outline-none focus:ring-2 transition-colors ${
                                errors.confirmPassword 
                                    ? 'border-red-500 focus:ring-red-500' 
                                    : 'border-gray-300 focus:ring-blue-500'
                            }`}
                            placeholder="Confirm password" 
                            disabled={formState.isSubmitting}
                        />
                        <button 
                            type="button" 
                            onClick={toggleConfPassword} 
                            disabled={formState.isSubmitting}
                            className="absolute inset-y-0 right-0 flex items-center px-3 text-gray-400 hover:text-gray-800 hover:bg-gray-300 bg-gray-200 rounded-r-md hover:rounded-r-md focus:bg-blue-300 focus:rounded-r-md focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed" 
                        >
                            {showConfPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                        </button>
                    </div>
                    {errors.confirmPassword && <p className="mt-1 text-sm text-red-600">{errors.confirmPassword}</p>}
                </div>

                {/* Form status indicator */}
                {formState.isDirty && (
                    <div className={`text-sm p-2 rounded ${
                        isFormValid() 
                            ? 'text-green-700 bg-green-50 border border-green-200' 
                            : 'text-amber-700 bg-amber-50 border border-amber-200'
                    }`}>
                        {isFormValid() ? '✓ Form is ready to submit' : '⚠ Please fix the validation errors above'}
                    </div>
                )}
                
                {/* Submit button and conclusion */}
                <button 
                    type="button"
                    onClick={handleSubmit} 
                    disabled={formState.isSubmitting || !formState.isDirty}
                    className={`w-full py-2 px-4 rounded-md shadow focus:outline-none focus:ring-2 focus:ring-blue-500 font-semibold mt-6 transition-all ${
                        formState.isSubmitting 
                            ? 'bg-blue-400 text-white cursor-not-allowed' 
                            : !formState.isDirty
                            ? 'bg-gray-400 text-white cursor-not-allowed'
                            : 'bg-blue-600 text-white hover:bg-blue-700'
                    }`}
                >
                    {formState.isSubmitting ? 'Registering...' : 'Register'}
                </button>
                <p className="text-center mt-4">
                    Already have an account? 
                    <a href="/login" className="text-blue-600 underline ml-1">Log in here</a>
                </p>

                {/* Custom Popup Modal */}
                {popup.isVisible && (
                    <div className="fixed inset-0 bg-teal-300/20 backdrop-blur-md bg-opacity-50 flex items-center justify-center p-4 z-50">
                        <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6 transform transition-all">
                            <div className="flex items-center justify-center mb-4">
                                {popup.type === 'success' ? (
                                    <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center">
                                        <svg className="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                                        </svg>
                                    </div>
                                ) : (
                                    <div className="w-12 h-12 bg-red-100 rounded-full flex items-center justify-center">
                                        <svg className="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                                        </svg>
                                    </div>
                                )}
                            </div>
                            
                            <h3 className={`text-lg font-semibold text-center mb-2 ${
                                popup.type === 'success' ? 'text-green-800' : 'text-red-800'
                            }`}>
                                {popup.title}
                            </h3>
                            
                            <p className="text-gray-600 text-center mb-6">
                                {popup.message}
                            </p>
                            
                            <div className="flex justify-center">
                                <button
                                    onClick={hidePopup}
                                    className={`px-6 py-2 rounded-md font-semibold focus:outline-none focus:ring-2 ${
                                        popup.type === 'success' 
                                            ? 'bg-green-600 text-white hover:bg-green-700 focus:ring-green-500'
                                            : 'bg-red-600 text-white hover:bg-red-700 focus:ring-red-500'
                                    }`}
                                >
                                    {popup.type === 'success' ? 'Continue' : 'Try Again'}
                                </button>
                            </div>
                        </div>
                    </div>
                )}
            </div>
        </div>
    )
}

export default RegisterUser