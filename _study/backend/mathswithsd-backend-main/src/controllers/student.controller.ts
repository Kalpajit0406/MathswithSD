import { Request, Response } from "express";
import { Student } from "../models/student.models";
import { asyncHandler } from "../utils/asyncHandler";
import { ApiError } from "../utils/ApiError";
import { ApiResponse } from "../utils/ApiResponse";

// Interface for authenticated request
interface AuthenticatedRequest extends Request {
  student?: {
    _id: string;
  };
}

// Interface for registration request body
interface RegisterStudentBody {
  fullName: string;
  studentMobile: string;
  classNo: 9 | 10 | 11 | 12;
  password: string;
  guardianName?: string;
  guardianMobile: string;
  language: "Bengali" | "English";
}

// Interface for login request body
interface LoginStudentBody {
  studentMobile: string;
  password: string;
}

// Interface for token generation return type
interface TokenResponse {
  accessToken: string;
  refreshToken: string;
}

const generateAccessAndRefreshTokens = async (studentId: string): Promise<TokenResponse> => {
    try {
        const student = await Student.findById(studentId);
        if (!student) {
            throw new ApiError(404, "Student not found");
        }

        const accessToken = student.generateAccessToken();
        const refreshToken = student.generateRefreshToken();

        student.refreshToken = refreshToken;
        await student.save({ validateBeforeSave: false });

        return { accessToken, refreshToken };
    } catch (error) {
        console.error("Token generation error:", error);
        throw new ApiError(500, "Something went wrong while generating access and refresh token");
    }
};

const registerStudent = asyncHandler(async (req: Request<{}, {}, RegisterStudentBody>, res: Response) => {
    // Get student details from frontend
    const { fullName, studentMobile, classNo, password, guardianName, guardianMobile, language } = req.body;

    // Validation - not empty
    if (
        [fullName, studentMobile, classNo, guardianName, password, guardianMobile, language].some((field) =>
            field?.toString().trim() === ""
        )
    ) {
        throw new ApiError(400, "All fields are required");
    }

    // Check if student already exists: by mobile
    const existedStudent = await Student.findOne({ studentMobile });

    if (existedStudent) {
        throw new ApiError(409, "Student with mobile no. already exists");
    }

    // Create student object - create entry in db
    const student = await Student.create({
        fullName,
        studentMobile,
        classNo,
        password,
        guardianName,
        guardianMobile,
        language,
        verified: false
    });

    // Remove password and refresh token field from response
    const createdStudent = await Student.findById(student._id).select(
        "-password -refreshToken"
    );

    if (!createdStudent) {
        throw new ApiError(500, "Something went wrong while registering the student");
    }

    return res.status(201).json(
        new ApiResponse(200, createdStudent, "Student registered Successfully")
    );
});

const loginStudent = asyncHandler(async (req: Request<{}, {}, LoginStudentBody>, res: Response) => {
    // Get frontend data from req.body
    const { studentMobile, password } = req.body;

    if (!studentMobile) {
        throw new ApiError(400, "Mobile no. is required");
    }

    // Find student by mobile
    const student = await Student.findOne({ studentMobile });

    if (!student) {
        throw new ApiError(404, "Student does not exist");
    }

    const isPasswordValid = await student.isPasswordCorrect(password);

    if (!isPasswordValid) {
        throw new ApiError(401, "Invalid student credentials!");
    }

    // Generate access token & refresh token
    const { accessToken, refreshToken } = await generateAccessAndRefreshTokens(student._id as string);

    // If DB call is expensive operation --> Update object, or call DB
    const loggedInStudent = await Student.findById(student._id).select("-password -refreshToken");

    // Frontend can't modify, only server could edit
    const options = {
        httpOnly: true,
        secure: true
    };

    let role: string = 'student';

    // Updated teacher mobile number as requested
    if (studentMobile === '7278000101') {
        role = process.env.SECRET_ROLE as string;
    }

    return res
        .status(200)
        .cookie("accessToken", accessToken, options)
        .cookie("refreshToken", refreshToken, options)
        .json(
            new ApiResponse(
                200,
                {
                    user: loggedInStudent,
                    role,
                    accessToken,
                    refreshToken
                },
                "Student logged in Successfully"
            )
        );
});

const logoutStudent = asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
    if (!req.student) {
        throw new ApiError(401, "Unauthorized request");
    }

    await Student.findByIdAndUpdate(
        req.student._id,
        {
            $set: {
                refreshToken: null
            }
        },
        {
            new: true
        }
    );

    const options = {
        httpOnly: true,
        secure: true
    };

    return res
        .status(200)
        .clearCookie("accessToken", options)
        .clearCookie("refreshToken", options)
        .json(new ApiResponse(200, {}, "Student logged out"));
});

// This will return all students, both verified and unverified
const getAllStudents = async (req: Request, res: Response): Promise<void> => {
    try {
        const students = await Student.find().select("-password -refreshToken");

        const verified = students.filter((s) => s.verified === true);
        const unverified = students.filter((s) => s.verified === false);

        res.status(200).json({
            success: true,
            verified,
            unverified,
        });
    } catch (error: any) {
        res.status(500).json({
            success: false,
            message: "Failed to fetch students",
            error: error.message,
        });
    }
};

// Accept student (set verified to true)
const acceptStudent = async (req: Request<{ id: string }>, res: Response): Promise<void> => {
    try {
        const { id } = req.params;

        const updatedStudent = await Student.findByIdAndUpdate(
            id,
            { verified: true },
            { new: true }
        ).select("-password -refreshToken");

        if (!updatedStudent) {
            res.status(404).json({
                success: false,
                message: "Student not found",
            });
            return;
        }

        res.status(200).json({
            success: true,
            message: "Student accepted and verified successfully",
            data: updatedStudent,
        });
    } catch (error: any) {
        res.status(500).json({
            success: false,
            message: "Failed to verify student",
            error: error.message,
        });
    }
};

// Reject student (delete)
const rejectStudent = async (req: Request<{ id: string }>, res: Response): Promise<void> => {
    try {
        const { id } = req.params;

        const deletedStudent = await Student.findByIdAndDelete(id);

        if (!deletedStudent) {
            res.status(404).json({
                success: false,
                message: "Student not found",
            });
            return;
        }

        res.status(200).json({
            success: true,
            message: "Student rejected and deleted successfully",
        });
    } catch (error: any) {
        res.status(500).json({
            success: false,
            message: "Failed to delete student",
            error: error.message,
        });
    }
};

// Get only verified students
const getVerifiedStudents = async (req: Request, res: Response): Promise<void> => {
    try {
        const students = await Student.find({ verified: true }).select("-password -refreshToken");
        res.status(200).json({ success: true, data: students });
    } catch (error: any) {
        res.status(500).json({
            success: false,
            message: "Failed to fetch verified students",
            error: error.message,
        });
    }
};

// Get only pending (not verified) students
const getPendingStudents = async (req: Request, res: Response): Promise<void> => {
    try {
        const students = await Student.find({ verified: false }).select("-password -refreshToken");
        res.status(200).json({ success: true, data: students });
    } catch (error: any) {
        res.status(500).json({
            success: false,
            message: "Failed to fetch pending students",
            error: error.message,
        });
    }
};

// Get students by class
const getStudentsByClass = async (req: Request<{ classNo: string }>, res: Response): Promise<void> => {
    try {
        const { classNo } = req.params;
        const classNumber = parseInt(classNo);

        if (classNumber !== 9 && classNumber !== 10 && classNumber !== 11 && classNumber !== 12) {
            res.status(400).json({
                success: false,
                message: "Invalid class number. Must be 9, 10, 11 or 12",
            });
            return;
        }

        const students = await Student.find({ 
            classNo: classNumber,
            verified: true 
        }).select("-password -refreshToken");

        res.status(200).json({
            success: true,
            data: students,
            count: students.length
        });
    } catch (error: any) {
        res.status(500).json({
            success: false,
            message: "Failed to fetch students by class",
            error: error.message,
        });
    }
};

// Get students by language preference
const getStudentsByLanguage = async (req: Request<{ language: string }>, res: Response): Promise<void> => {
    try {
        const { language } = req.params;

        if (language !== "Bengali" && language !== "English") {
            res.status(400).json({
                success: false,
                message: "Invalid language. Must be 'Bengali' or 'English'",
            });
            return;
        }

        const students = await Student.find({ 
            language: language,
            verified: true 
        }).select("-password -refreshToken");

        res.status(200).json({
            success: true,
            data: students,
            count: students.length
        });
    } catch (error: any) {
        res.status(500).json({
            success: false,
            message: "Failed to fetch students by language",
            error: error.message,
        });
    }
};

export {
    registerStudent,
    loginStudent,
    logoutStudent,
    getAllStudents,
    acceptStudent,
    rejectStudent,
    getVerifiedStudents,
    getPendingStudents,
};