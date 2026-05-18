import mongoose, { Schema, Document } from "mongoose";

// Language union type
type Language = "Bengali" | "English";

// Interface for Question Document
interface IQuestion extends Document {
  language: Language;
  chapter: string;
  classNo: number;
  correctAnswer: string;
  options: string[];
  question: string;
  diagram?: string; // optional Cloudinary image URL
}

const questionSchema = new Schema<IQuestion>(
  {
    language: {
      type: String,
      enum: ["Bengali", "English"],
      required: [true, "Preferred language is required"],
    },
    chapter: {
      type: String,
      required: true,
    },
    classNo: {
      type: Number,
      required: true,
    },
    correctAnswer: {
      type: String,
      required: true,
    },
    options: {
      type: [String],
      validate: {
        validator: function (val: string[]) {
          return Array.isArray(val) && val.length === 4;
        },
        message: "Exactly 4 options are required",
      },
      required: true,
    },
    question: {
      type: String,
      required: true,
    },
    diagram: {
      type: String,
      default: null,
      validate: {
        validator: function (url: string) {
          return url === null || /^https:\/\/res\.cloudinary\.com\/.+/i.test(url);
        },
        message: "Invalid Cloudinary URL format",
      },
    },
  },
  { timestamps: true }
);

export const Question = mongoose.model<IQuestion>("Question", questionSchema);
