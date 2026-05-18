import { useState, useEffect } from "react";
import { Check, X, AlertTriangle, Info } from "lucide-react";

interface AlertDialogProps {
  text: string;
  title: string;
  link?: string
  type?: "success" | "error" | "warning" | "info";
  duration?: number;
  onClose?: () => void;
}

export default function Alert({ title, text, type = "info", link, duration = 5, onClose }: AlertDialogProps) {
  const [visible, setVisible] = useState(true);
  const [closing, setClosing] = useState(false);

  const handleClose = () => {
    setClosing(true);
    setTimeout(() => {
      setVisible(false);
      onClose?.();
    }, 300);
  };

  useEffect(() => {
    const timer = setTimeout(() => {
      handleClose();
    }, duration * 1000);

    return () => clearTimeout(timer);
  }, []);

  if (!visible) return null;

  return (
    <div className="fixed inset-0 flex items-center justify-center z-50 backdrop-blur-sm bg-black/20">
      <div
        className={`w-full max-w-md rounded-2xl shadow-xl border border-gray-200 bg-white overflow-hidden
          ${closing ? "animate-pop-out" : "animate-pop-in"}`}
        role="alert"
      >
        {/* Main Content */}
        <div className="p-6">
          <div className="flex items-start space-x-4">
            {/* Icon */}
            <div className={`flex-shrink-0 w-10 h-10 rounded-full flex items-center justify-center
              ${
                type === "success"
                  ? "bg-green-100 text-green-600"
                  : type === "error"
                  ? "bg-red-100 text-red-600"
                  : type === "warning"
                  ? "bg-amber-100 text-amber-600"
                  : "bg-blue-100 text-blue-600"
              }`}
            >
              {type === "success" && <Check size={20} strokeWidth={2.5} />}
              {type === "error" && <X size={20} strokeWidth={2.5} />}
              {type === "warning" && <AlertTriangle size={20} strokeWidth={2.5} />}
              {type === "info" && <Info size={20} strokeWidth={2.5} />}
            </div>
            
            {/* Content */}
            <div className="flex-1 min-w-0">
              <h2 className="text-lg font-semibold text-gray-900 mb-1">{title}</h2>
              <p className="text-gray-600 text-sm leading-relaxed">{text}</p>
              <a className="text-gray-600 text-sm leading-relaxed" href={link} target="_blank">{link}</a>
            </div>
          </div>
        </div>
        
        {/* Footer */}
        <div className="bg-gray-50 px-6 py-4 border-t border-gray-100">
          <div className="flex justify-end">
            <button
              onClick={handleClose}
              className={`px-5 py-2.5 rounded-lg text-sm font-medium transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2
                ${
                  type === "success"
                    ? "bg-green-700 hover:bg-green-800 text-white focus:ring-green-500"
                    : type === "error"
                    ? "bg-red-700 hover:bg-red-800 text-white focus:ring-red-500"
                    : type === "warning"
                    ? "bg-amber-700 hover:bg-amber-800 text-white focus:ring-amber-500"
                    : "bg-blue-700 hover:bg-blue-800 text-white focus:ring-blue-500"
                }`}
            >
              OK
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
