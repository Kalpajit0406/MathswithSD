import mongoose, { Schema, Document } from "mongoose";

// Interface for individual response
interface IResponse {
  questionNumber: number;
  questionId: string;
  selectedOption: string | null;
}

// Interface for TestResponse Document
interface ITestResponse extends Document {
  date: string;
  time: string;
  studentMobile: string;
  testId: mongoose.Types.ObjectId;
  responses: IResponse[];
}

const responseSchema = new Schema<IResponse>(
  {
    questionNumber: {
      type: Number,
      required: [true, "Question number is required"],
    },
    questionId: {
      type: String,
      required: [true, "Question ID is required"],
    },
    selectedOption: {
      type: String,
      default: null,
    },
  }
);

const testResponseSchema = new Schema<ITestResponse>(
  {
    date: {
      type: String,
      required: [true, "Date is required"],
    },
    time: {
      type: String,
      required: [true, "Time is required"],
    },
    studentMobile: {
      type: String,
      required: [true, "Student mobile number is required"],
    },
    testId: {
      type: Schema.Types.ObjectId,
      ref: 'TestConfig',
      required: [true, "Test ID is required"],
    },
    responses: {
      type: [responseSchema],
      required: [true, "Test responses are required"],
      validate: {
        validator: function (val: IResponse[]) {
          return Array.isArray(val) && val.length > 0;
        },
        message: "At least one response is required",
      },
    },
  },
  { timestamps: true }
);

export const TestResponse = mongoose.model<ITestResponse>("TestResponse", testResponseSchema);