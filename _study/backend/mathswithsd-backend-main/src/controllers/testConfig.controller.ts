import { Request, Response } from "express";
import { TestConfig } from "../models/testConfig.models"; // adjust path as needed

// Allowed classes
type ClassNo = 9| 10 | 11 | 12;

// Allowed languages
type Language = "Bengali" | "English";

// Interface for TestConfig Document
interface ITestConfig extends Document {
  date: string;
  time: string;
  classNo: ClassNo;
  language: Language;
  totalMarks: number;
  marksPQ: number;
  timePQ: number;
  negativeMarksPQ: number;
  chapters: string[];
}

// ✅ POST /api/tests  → Create new test configuration
const createTestConfig = async (req: Request, res: Response) => {
  try {
    const {
      date,
      time,
      classNo,
      language,
      totalMarks,
      marksPQ,
      timePQ,
      negativeMarksPQ,
      chapters,
    } = req.body as ITestConfig;

    // Basic validation
    if (
      !date ||
      !time ||
      !classNo ||
      !language ||
      !totalMarks ||
      marksPQ === undefined ||
      timePQ === undefined ||
      negativeMarksPQ === undefined ||
      !chapters
    ) {
      return res.status(400).json({ error: "All fields are required" });
    }

    const newTest = new TestConfig({
      date,
      time,
      classNo,
      language,
      totalMarks,
      marksPQ,
      timePQ,
      negativeMarksPQ,
      chapters,
    });

    const savedTest = await newTest.save();
    return res
      .status(201)
      .json({ message: "Test configuration saved", test: savedTest });
  } catch (error) {
    console.error("Error saving test config:", error);
    return res.status(500).json({ error: "Internal server error" });
  }
};

// ✅ GET /api/tests  → Fetch all student tests
const getAllStudentTests = async (req: Request, res: Response) => {
  try {
    const tests = await TestConfig.find().sort({ createdAt: -1 });
    return res.status(200).json(tests);
  } catch (error) {
    console.error("Error fetching tests:", error);
    return res.status(500).json({ error: "Server error" });
  }
};

// ✅ GET /api/tests/:classNo/:language  → Fetch tests by class and language
export const getTestsByClassAndLanguage = async (req: Request,  res: Response) => {
  try {
    const { classNo, language } = req.params;

    // Validate classNo and language
    const validClasses: ClassNo[] = [9, 10, 11, 12];
    const validLanguages: Language[] = ["Bengali", "English"];

    if (
      !validClasses.includes(Number(classNo) as ClassNo) ||
      !validLanguages.includes(language as Language)
    ) {
      return res.status(400).json({ error: "Invalid class number or language" });
    }

    const tests = await TestConfig.find({
      classNo: Number(classNo),
      language,
    }).sort({ createdAt: -1 });

    return res.status(200).json(tests);
  } catch (error) {
    console.error("Error fetching tests by class and language:", error);
    return res.status(500).json({ error: "Server error" });
  }
};

// ✅ DELETE /api/tests/delete  → delete existing test configuration
const deleteTestConfig = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const deletedTest = await TestConfig.findByIdAndDelete(id);
    if (!deletedTest) {
      return res.status(404).json({ error: "Test configuration not found" });
    }
    return res
      .status(200)
      .json({ message: "Test configuration deleted", test: deletedTest });
  } catch (error) {
    console.error("Error deleting test config:", error);  
    return res.status(500).json({ error: "Internal server error" });
  }
};

export {
  createTestConfig,
  getAllStudentTests,
  deleteTestConfig,
}
