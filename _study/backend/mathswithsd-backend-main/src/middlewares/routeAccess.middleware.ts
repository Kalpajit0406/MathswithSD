import jwt from "jsonwebtoken";
import { Student } from "../models/student.models";
import { Request, Response, NextFunction } from "express";
import { asyncHandler } from "../utils/asyncHandler";
import { ApiError } from "../utils/ApiError";

interface AuthenticatedRequest extends Request {
  student?: {
    _id: string;
  };
}

export const verifyToken = asyncHandler(async(req : Request, res : Response, next : NextFunction) => {
  const authHeader = req.headers["authorization"];
  if (!authHeader) return res.status(401).json({ message: "No token provided" });

  const token = authHeader.split(" ")[1];
  try {
    const decoded = jwt.verify(token, process.env.ACCESS_TOKEN_SECRET as string);
    const student = await Student.findById(decoded?._id).select("-password -refreshToken");
            if (!student) {
                throw new ApiError(401, "Unauthorized: Invalid token");
            }
    (req as AuthenticatedRequest).student = { _id: String(student._id) };
    next();
  } catch (err) {
    return res.status(403).json({ message: "Invalid or expired token" });
  }
});
