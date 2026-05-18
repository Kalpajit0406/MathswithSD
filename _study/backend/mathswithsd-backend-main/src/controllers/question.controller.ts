import { Request, Response } from "express";
import { asyncHandler } from "../utils/asyncHandler.ts";
import { Question } from "../models/question.models.ts";
import { uploadOnCloudinary } from "../utils/cloudinary.ts";

interface QuestionRequestBody {
  chapter: string;
  classNo: "9" | "10" | "11" | "12";
  correctAnswer: string;
  options: string[] | string;
  question: string;
  language: "Bengali" | "English";
}


interface QuestionUpdateBody {
  chapter?: string;
  classNo?: "9" | "10" | "11" | "12";
  correctAnswer?: string;
  options?: string[];
  question?: string;
  diagram?: string; // optional, for updating the diagram
}

const addQuestion = asyncHandler(async (req: Request, res: Response) => {
  const {
    chapter,
    classNo,
    correctAnswer,
    options,
    question,
    language
  } = req.body as QuestionRequestBody;
  console.log("BODY:", req.body);
  console.log("FILES:", req.files);


  // Parse options if sent as JSON string
  let parsedOptions = options;
  if (typeof options === "string") {
    try {
      parsedOptions = JSON.parse(options);
    } catch {
      return res.status(400).json({
        success: false,
        message: "Invalid options format. Must be JSON string or array."
      });
    }
  }

  // Basic validation
  if (!chapter || !classNo || !correctAnswer || !parsedOptions || !question || !language) {
    return res.status(400).json({ success: false, message: "All required fields must be provided" });
  }

  if (!Array.isArray(parsedOptions) || parsedOptions.length < 2) {
    return res.status(400).json({ success: false, message: "At least two options are required" });
  }

  if (!parsedOptions.includes(correctAnswer)) {
    return res.status(400).json({ success: false, message: "Correct answer must be one of the provided options" });
  }

  if (!["9", "10", "11", "12"].includes(String(classNo))) {
    return res.status(400).json({ success: false, message: "Class must be '9', '10', '11' or '12'" });
  }

  if (!["Bengali", "English"].includes(language)) {
    return res.status(400).json({ success: false, message: "Language must be either 'Bengali' or 'English'" });
  }

  // Handle diagram upload
  let diagramUrl: string | null = null;

  if (req.files && (req.files as any).diagram && (req.files as any).diagram.length > 0) {
    const diagramLocalPath = (req.files as any).diagram[0].path;
    const uploadResult = await uploadOnCloudinary(diagramLocalPath);
    console.log("Upload Result:", uploadResult);
    if (uploadResult?.secure_url) {
      diagramUrl = uploadResult.secure_url;
      console.log("Diagram uploaded to Cloudinary:", diagramUrl);
      
    }
  }

  // Save question in DB
  const newQuestion = await Question.create({
    chapter,
    classNo,
    correctAnswer,
    options: parsedOptions,
    question,
    language,
    diagram: diagramUrl ?? null
  });

  res.status(201).json({
    success: true,
    message: "Question added successfully",
    data: newQuestion
  });
});

const deleteQuestion = asyncHandler(async (req: Request, res: Response) => {
  const { id } = req.params;

  const question = await Question.findByIdAndDelete(id);

  if (!question) {
    return res.status(404).json({
      success: false,
      message: "Question not found",
    });
  }

  res.status(200).json({
    success: true,
    message: "Question deleted successfully",
  });
});

const updateQuestion = asyncHandler(async (req: Request, res: Response) => {
  const { id } = req.params;
  const {
    chapter,
    classNo,
    correctAnswer,
    options,
    question,
    diagram
  } = req.body as QuestionUpdateBody;

  const updated = await Question.findByIdAndUpdate(
    id,
    {
      chapter,
      classNo,
      correctAnswer,
      options,
      question,
      diagram: diagram || undefined // allow diagram to be optional
    },
    { new: true }
  );

  if (!updated) {
    return res.status(404).json({
      success: false,
      message: "Question not found",
    });
  }

  res.status(200).json({
    success: true,
    message: "Question updated successfully",
    data: updated,
  });
});

const getAllQuestions = asyncHandler(async (req: Request, res: Response) => {
  const questions = await Question.find(); // fetch all documents from MongoDB

  res.status(200).json({
    success: true,
    count: questions.length,
    data: questions,
  });
});

// Get questions with filters (class, language) 
const getFilteredQuestions = asyncHandler(async (req: Request, res: Response) => {
  const { classNo, language } = req.params;
  const filter: any = {};
  if (classNo) filter.classNo = classNo;
  if (language) filter.language = language;
  const questions = await Question.find(filter);
  res.status(200).json({
    success: true,
    count: questions.length,
    data: questions,
  });
});

export { addQuestion, deleteQuestion, updateQuestion, getAllQuestions, getFilteredQuestions };
