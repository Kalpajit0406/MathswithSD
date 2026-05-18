import { Request, Response } from 'express';
import { asyncHandler } from '../utils/asyncHandler';
import { TestResponse } from '../models/testResponse.models';

// Interface for individual response
interface IResponse {   
    questionNumber: number;
    questionId: string;
    selectedOption: string | null;
    }
// Interface for TestResponse Document
interface ITestResponse {   
    date: string;
    time: string;
    studentMobile: string;
    testId: string;
    responses: IResponse[];
}

const findByStudentThenCheckTest = async (studentMobile: string, testId: string) => {
    try {
        // Step 1: Find all responses by studentMobile
        const studentResponses = await TestResponse.find({ studentMobile });
        
        if (studentResponses.length === 0) {
            return {
                found: false,
                studentHasResponses: false,
                hasTestResponse: false,
                responses: []
            };
        }
        
        // Step 2: Check if testId exists in those responses
        const testResponse = studentResponses.find(response => 
            response.testId.toString() === testId
        );
        
        return {
            found: testResponse !== undefined,
            studentHasResponses: true,
            hasTestResponse: testResponse !== undefined,
            responses: studentResponses,
            testResponse: testResponse || null
        };
    } catch (error) {
        console.error("Error in findByStudentThenCheckTest:", error);
        throw error;
    }
};

const saveStudentTest = asyncHandler(async (req: Request, res: Response) => {
    const {
        date,
        time,
        studentMobile,
        testId,
        responses
    } = req.body as ITestResponse;

    // Basic validation
    if (!date || !time || !studentMobile || !testId || !responses) {
        return res.status(400).json({ 
            success: false,
            message: "All fields are required" 
        });
    }

    try {
        // Delete existing response for the same student 
        await TestResponse.findOneAndDelete({ studentMobile});

        // Save new Submission
        const newTestResponse = await TestResponse.create({
            date,
            time,
            studentMobile,
            testId,
            responses
        });

        res.status(201).json({ 
            success: true,
            message: "Test responses saved successfully", 
            data: newTestResponse 
        });
    } catch (error) {
        res.status(500).json({ 
            success: false,
            message: "Server error while saving test responses", 
            error: (error as Error).message 
        });
    }   
});

// Additional controller to check test response existence
const checkTestResponse = asyncHandler(async (req: Request, res: Response) => {
    const { studentMobile, testId } = req.params;

    if (!studentMobile || !testId) {
        return res.status(400).json({
            success: false,
            message: "Student mobile and test ID are required"
        });
    }

    try {
        const result = await findByStudentThenCheckTest(studentMobile, testId);
        
        res.status(200).json({
            success: true,
            message: "Test response check completed",
            data: {
                found: result.found,
                studentHasResponses: result.studentHasResponses,
                hasTestResponse: result.hasTestResponse,
                totalResponses: result.responses.length,
                testResponse: result.testResponse
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Server error while checking test response",
            error: (error as Error).message
        });
    }
});

// Get Student Test Response by studentMobile and testId
const getStudentTestResponse = asyncHandler(async (req: Request, res: Response) => {
    const { studentMobile} = req.params;
    if (!studentMobile) {
        return res.status(400).json({
            success: false,
            message: "Student mobile is required"
        });
    }
    try {
        const testResponse = await TestResponse.findOne({ studentMobile});
        if (!testResponse) {
            return res.status(404).json({
                success: false,
                message: "No test response found for the given student mobile"
            });
        }
        res.status(200).json({
            success: true,
            message: "Test response retrieved successfully",
            data: testResponse
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Server error while retrieving test response",
            error: (error as Error).message
        });
    }
});

// Get all test responses (for admin purposes)
const getAllTestResponses = asyncHandler(async (req: Request, res: Response) => {
    try {       
        const allResponses = await TestResponse.find();
        res.status(200).json({
            success: true,
            message: "All test responses retrieved successfully",
            data: allResponses
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Server error while retrieving all test responses",
            error: (error as Error).message
        });
    }
});

// Delete all responses by testId
const deleteAllTestResponsesById = asyncHandler(async (req: Request, res: Response) => {
  try {
    const { testId } = req.params;

    const deleteResult = await TestResponse.deleteMany({ testId });

    if (deleteResult.deletedCount === 0) {
      return res.status(404).json({
        success: false,
        message: "No test responses found for this testId",
      });
    }

    res.status(200).json({
      success: true,
      message: `${deleteResult.deletedCount} test response(s) deleted successfully`,
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      message: "Failed to delete test responses",
      error: error.message,
    });
  }
});

export { saveStudentTest, checkTestResponse, getStudentTestResponse, getAllTestResponses, deleteAllTestResponsesById };