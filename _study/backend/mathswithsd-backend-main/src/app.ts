import express, { Application } from "express";
import cors from "cors";
import cookieParser from "cookie-parser";

// Create Express app with Application type
const app: Application = express();

// app.use(
//   cors({
//     origin: process.env.CORS_ORIGIN,
//     credentials: true, 
//   })
// );

app.set("trust proxy", true);

app.use((req, res, next) => {
  const start = process.hrtime.bigint();
  
  res.on("finish", () => {
    const duration = Number(process.hrtime.bigint() - start) / 1000000;
    
    console.log(
      `[${res.statusCode}] ${new Date().toLocaleString()} ${req.ip}  - ${req.method.padEnd(6)}  ${req.originalUrl} ${duration.toFixed(2)}ms`
    );
  });

  next();
});


app.use(cors({
  origin: ["http://localhost:4432", "https://mathswithsd.in", "https://preview.mathswithsd.in"], 
  methods: ["GET", "POST", "PUT", "DELETE"],
  credentials: true
}));


app.use(
  express.json({
    limit: "16kb",
  })
);

app.use(
  express.urlencoded({
    extended: true,
    limit: "16kb",
  })
);

app.use(express.static("public"));
app.use(cookieParser());

// Routes import
import uploadRouter from "./routes/upload.route.ts";
app.use("/api/v1/scan", uploadRouter);

import questionRouter from "./routes/question.route.ts";
app.use("/api/v1/question", questionRouter);

import testConfigRoutes from "./routes/testConfig.route.ts";
app.use("/api/v1/tests", testConfigRoutes)

import studentRouter from "./routes/student.route.ts";
app.use("/api/v1/student", studentRouter);

import timeRouter from "./routes/time.route.ts";
app.use("/api/v1/time", timeRouter);

import testResponseRouter from "./routes/testResponse.route.ts";
app.use("/api/v1/testResponse", testResponseRouter);

export { app };
