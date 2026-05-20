import { Home } from "lucide-react"

const NavComponent = () => {
    return (
        <div className="fixed top-0 left-0 right-0 z-50 bg-teal-300/20 backdrop-blur-md border-b-2 border-teal-200/20">
            <nav className="p-3">
            <div className="max-w-7xl mx-auto flex items-center justify-between">
                <a href='#' className="flex items-center space-x-3">
                    <img src='/assets/logo.jpg' alt='logo' className="w-12 h-12 rounded-full" />
                    <span className="text-2xl font-bold text-gray-800 glyph">Maths with SD</span>
                </a>
                <button onClick={() => {location.href='/teacher/'}} className="flex cursor-pointer items-center space-x-2 border border-b-2 border-r-4 border-teal-200 bg-teal-500 hover:bg-green-600 transition-all duration-300 text-white font-medium py-2.5 px-5 rounded-full shadow-lg hover:shadow-xl transform hover:-translate-y-0.5">
                    <Home className="w-4 h-4" />
                    <span>Home</span>
                </button>
            </div>
            </nav>
        </div>
    )
}

export default NavComponent