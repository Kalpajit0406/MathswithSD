import { Router } from "express";
import { createTestConfig, getAllStudentTests, deleteTestConfig, getTestsByClassAndLanguage } from "../controllers/testConfig.controller";

const router = Router();

// POST /api/tests → create a test
// GET  /api/tests → get all student tests
router.route("/")
  .post(createTestConfig)
  .get(getAllStudentTests);

// GET /api/tests/:classNo/:language → get tests by class and language  
router.route("/:classNo/:language")
  .get(getTestsByClassAndLanguage);


// DELETE /api/tests/delete → delete a test by ID
router.route("/delete/:id").delete(deleteTestConfig); 


export default router;
