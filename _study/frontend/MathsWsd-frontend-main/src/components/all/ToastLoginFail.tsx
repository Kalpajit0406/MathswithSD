import { CheckCircle, AlertCircle, X } from "lucide-react"
import { useEffect } from "react"

interface ToastProps {
  text: string
  success?: boolean
  isVisible?: boolean
  onClose?: () => void  // Made optional with ?
  duration?: number
}

const Toast = ({ 
  text, 
  success = true, 
  isVisible = true, 
  onClose, 
  duration = 5000 
}: ToastProps) => {
  useEffect(() => {
    if (isVisible && duration > 0 && onClose) {  // Check if onClose exists
      const timer = setTimeout(() => {
        onClose()
      }, duration)
      
      return () => clearTimeout(timer)
    }
  }, [isVisible, duration, onClose])

  if (!isVisible) return null

  return (
    <div className="fixed top-4 right-4 z-[60] transform transition-all duration-300 ease-out">
      <div className={`${
        success ? 'bg-green-500' : 'bg-red-500'
      } text-white px-6 py-4 rounded-lg shadow-xl flex items-center space-x-3 min-w-[300px] border border-white/20`}>
        {success ? (
          <CheckCircle className="w-5 h-5 flex-shrink-0" />
        ) : (
          <AlertCircle className="w-5 h-5 flex-shrink-0" />
        )}
        <span className="font-medium flex-1">
          {text}
        </span>
        {onClose && (  // Only show close button if onClose is provided
          <button 
            onClick={onClose}
            className={`ml-auto ${
              success ? 'hover:bg-green-600' : 'hover:bg-red-600'
            } rounded-full p-1 transition-colors`}
          >
            <X className="w-4 h-4" />
          </button>
        )}
      </div>
    </div>
  )
}

export default Toast