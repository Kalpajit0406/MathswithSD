import mongoose, { Document, Schema } from "mongoose";
import jwt from "jsonwebtoken";
import bcrypt from "bcrypt";

interface IStudent extends Document {
  fullName: string;
  studentMobile: string;
  classNo: 9 | 10 | 11 | 12;
  guardianName?: string;
  guardianMobile: string;
  password: string;
  refreshToken?: string;
  verified: boolean;
  language: String;
  createdAt: Date;
  updatedAt: Date;

  isPasswordCorrect(inputPassword: string): Promise<boolean>;
  generateAccessToken(): string;
  generateRefreshToken(): string;
}

const studentSchema = new Schema<IStudent>(
  {
    fullName: {
      type: String,
      required: [true, "Full Name is required"],
      trim: true,
      index: true,
    },
    studentMobile: {
      type: String,
      required: [true, "Mobile number is required"],
      unique: true,
      trim: true,
      index: true,
      validate: {
        validator: function (v: string) {
          return /^[6-9]\d{9}$/.test(v);
        },
        message: (props: any) => `${props.value} is not a valid mobile number!`,
      },
    },
    classNo: {
      type: Number,
      enum: [9, 10, 11, 12],
      required: [true, "Class is required"],
    },
    guardianName: {
      type: String,
      trim: true,
      index: true,
    },
    guardianMobile: {
      type: String,
      required: [true, "Guardian mobile number is required"],
      unique: true,
      trim: true,
      index: true,
      validate: {
        validator: function (v: string) {
          return /^[6-9]\d{9}$/.test(v);
        },
        message: (props: any) =>
          `${props.value} is not a valid mobile number!`,
      },
    },
    password: {
      type: String,
      required: [true, "Password is required"],
      minlength: [6, "Password must be at least 6 characters long"],
    },
    refreshToken: {
      type: String,
    },
    verified: {
      type: Boolean,
      default: false,
    },
    language: {
      type: String,
      enum: ["Bengali", "English"],
      required: [true, "Preferred language is required"],
      //default: "Bengali",
    },
  },
  {
    timestamps: true,
  }
);

// Hash password before saving
studentSchema.pre<IStudent>("save", async function (next) {
  if (!this.isModified("password")) return next();

  this.password = await bcrypt.hash(this.password, 10);
  next();
});

// Compare password method
studentSchema.methods.isPasswordCorrect = async function (
  this: IStudent,
  inputPassword: string
): Promise<boolean> {
  return await bcrypt.compare(inputPassword, this.password);
};

// Generate access token
studentSchema.methods.generateAccessToken = function (this: IStudent): string {
  return jwt.sign(
    {
      _id: this._id,
      studentMobile: this.studentMobile,
      fullName: this.fullName,
    },
    process.env.ACCESS_TOKEN_SECRET as string,
    {
      expiresIn: process.env.ACCESS_TOKEN_EXPIRY,
    }
  );
};

// Generate refresh token
studentSchema.methods.generateRefreshToken = function (this: IStudent): string {
  return jwt.sign(
    {
      _id: this._id,
    },
    process.env.REFRESH_TOKEN_SECRET as string,
    {
      expiresIn: process.env.REFRESH_TOKEN_EXPIRY,
    }
  );
};

export const Student = mongoose.model<IStudent>("Student", studentSchema);
