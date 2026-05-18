import { Router } from "express";
import { upload as uploadControl } from "../controllers/upload.controller";
import { upload as uploadMiddleware } from "../middlewares/multer.middleware";

const router = Router();

router.post("/", uploadMiddleware.single("pdf"), uploadControl);

export default router;
