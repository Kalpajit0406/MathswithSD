import e, { Router } from "express";
import { saveStudentTest, checkTestResponse, getStudentTestResponse,  getAllTestResponses, deleteAllTestResponsesById } from "../controllers/testRespose.controller";

const router = Router();

router.route("/")
  .post(saveStudentTest);

router.route("/:studentMobile")   
  .get(getStudentTestResponse);

router.route("/check/:studentMobile/:testId")
  .get(checkTestResponse);
  
router.route("/res/all")
    .get(getAllTestResponses);

router.route("/delete/:testId")
  .delete(deleteAllTestResponsesById);    

export default router;  

