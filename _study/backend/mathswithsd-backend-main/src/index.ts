import dotenv from "dotenv";
dotenv.config();

import connectDB from "./db/index.db";
import { app } from "./app";

import https from "https";
import http from "http";
import fs from "fs";

// SSL options
const options = {
  key: fs.readFileSync(process.env.SSL_KEY as string),
  cert: fs.readFileSync(process.env.SSL_CERT as string),
  ca: fs.readFileSync(process.env.SSL_CA as string),
};

// Connect DB and then start server
connectDB()
  .then(() => {
    app.on("error", (error) => {
      console.error("ERROR: ", error);
      throw error;
    });

    // HTTPS server
    https.createServer(options, app).listen(443, () => {
      console.log("✅ Server running securely on https://api.mathswithsd.in");
    });

    // (Optional) Redirect HTTP → HTTPS
    http.createServer((req, res) => {
      res.writeHead(301, { Location: "https://" + req.headers.host + req.url });
      res.end();
    }).listen(80, () => {
      console.log("🌍 Redirecting all HTTP -> HTTPS");
    });
  })
  .catch((err) => {
    console.log("MONGO db connection failed !!!", err);
  });
