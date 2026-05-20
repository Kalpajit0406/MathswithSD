const fs = require('fs');
const path = require('path');

const modelsPath = 'C:\\Users\\kalpa\\OneDrive\\Desktop\\MathswithSD\\mathswithsd-backend-main\\src\\models\\student.models.ts';
const controllerPath = 'C:\\Users\\kalpa\\OneDrive\\Desktop\\MathswithSD\\mathswithsd-backend-main\\src\\controllers\\student.controller.ts';

let modelsCode = fs.readFileSync(modelsPath, 'utf8');

// Update interface
modelsCode = modelsCode.replace(/fullName: string;/, 'firstName: string;\n  lastName: string;\n  dob: Date;\n  gender: string;');

// Update Schema
modelsCode = modelsCode.replace(
  /fullName:\s*\{[\s\S]*?\},/,
  `firstName: {
      type: String,
      required: [true, "First Name is required"],
      trim: true,
      index: true,
    },
    lastName: {
      type: String,
      required: [true, "Last Name is required"],
      trim: true,
      index: true,
    },
    dob: {
      type: Date,
      required: [true, "Date of birth is required"],
    },
    gender: {
      type: String,
      enum: ["Male", "Female", "Other"],
      required: [true, "Gender is required"],
    },`
);

// Update jwt.sign payload
modelsCode = modelsCode.replace(/fullName:\s*this\.fullName,/, 'firstName: this.firstName,\n      lastName: this.lastName,');

fs.writeFileSync(modelsPath, modelsCode);
console.log('Updated student.models.ts');

let controllerCode = fs.readFileSync(controllerPath, 'utf8');

// Update Interface
controllerCode = controllerCode.replace(/fullName: string;/, 'firstName: string;\n  lastName: string;\n  dob: Date;\n  gender: string;');

// Update destructuring
controllerCode = controllerCode.replace(/const { fullName, /, 'const { firstName, lastName, dob, gender, ');

// Update validation array
controllerCode = controllerCode.replace(/\[fullName, /, '[firstName, lastName, dob, gender, ');

// Update Student.create
controllerCode = controllerCode.replace(/fullName,/, 'firstName,\n        lastName,\n        dob,\n        gender,');

// Update admin role condition
controllerCode = controllerCode.replace(/if\s*\(studentMobile === '7278000101'\)\s*\{[\s\S]*?\}/, `if (studentMobile === '7278000101' || studentMobile === '6289855545') {
        role = process.env.SECRET_ROLE ? process.env.SECRET_ROLE : 'admin';
    }`);

fs.writeFileSync(controllerPath, controllerCode);
console.log('Updated student.controller.ts');
