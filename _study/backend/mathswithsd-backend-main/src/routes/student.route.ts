import { Router } from "express";

import { 
    registerStudent, 
    loginStudent, 
    logoutStudent, 
    getAllStudents, 
    acceptStudent, 
    rejectStudent,
    getVerifiedStudents,
    // getPendingStudents,
} from "../controllers/student.controller";

import { verifyJWT } from "../middlewares/auth.middleware";

const router = Router();

// Register a new student
router.route("/register").post(registerStudent);
// Login a student
router.route("/login").post(loginStudent);


// Logout a student
router.route("/logout").post(verifyJWT, logoutStudent);


// Get all students
router.route("/students").get(getAllStudents);

// Accept or reject student registration
router.route("/accept/:id").put(verifyJWT, acceptStudent);
router.route("/reject/:id").delete(verifyJWT, rejectStudent);

// // Get verified and pending students
router.route("/verified").get(getVerifiedStudents);
// router.route("/pending").get(verifyJWT, getPendingStudents);   

// Get students by class
// router.get("/students/class/:classNo", getStudentsByClass);      
// Get students by language preference  
// router.get("/students/language/:language", getStudentsByLanguage);
export default router;