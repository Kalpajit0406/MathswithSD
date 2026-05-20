import jwt from "jsonwebtoken";
import { Request, Response, NextFunction } from "express";
import { asyncHandler } from "../utils/asyncHandler";
import { ApiError } from "../utils/ApiError";
import { Student } from "../models/student.models";

// Interface for authenticated request
interface AuthenticatedRequest extends Request {
  student?: {
    _id: string;
  };
}

export const verifyJWT = asyncHandler(async (req: Request, res: Response, next: NextFunction) => {
    
    const token = req.cookies?.accessToken || req.header("Authorization")?.replace("Bearer ", "");
    if (!token) {
        throw new ApiError(401, "Unauthorized: No token provided");
    }

    try {
        const decoded = jwt.verify(token, process.env.ACCESS_TOKEN_SECRET as string) as {
            _id(_id: any): unknown; id: string 
};
        const student = await Student.findById(decoded?._id).select("-password -refreshToken");
        if (!student) {
            throw new ApiError(401, "Unauthorized: Invalid token");
        }
        (req as AuthenticatedRequest).student = { _id: String(student._id) };
        next();
    } catch (error) {
        throw new ApiError(401, "Unauthorized: Invalid token");
    }
});
