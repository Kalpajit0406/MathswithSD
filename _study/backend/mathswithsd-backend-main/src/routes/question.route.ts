import { upload } from "../middlewares/multer.middleware.ts";
import { addQuestion, deleteQuestion, updateQuestion, getAllQuestions, getFilteredQuestions } from "../controllers/question.controller.ts";
import { Router } from "express";

const router = Router();
// Add a new question  
router.post(
  "/addQuestion",
  upload.fields([{ name: "diagram", maxCount: 1 }]),
  addQuestion
);
// Delete a question by ID
router.route("/questions/:id").delete(deleteQuestion);

// Update a question by ID
router.route("/questions/:id").put(updateQuestion);

import { verifyToken } from "../middlewares/routeAccess.middleware.ts";
// Apply the verifyToken middleware to all routes defined after this line
// Get all questions
router.route("/questions").get(verifyToken, getAllQuestions);

router.route("/filtered-questions/:classNo/:language").get(verifyToken, getFilteredQuestions);

export default router;
