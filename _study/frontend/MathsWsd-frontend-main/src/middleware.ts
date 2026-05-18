import { defineMiddleware } from "astro:middleware";

type ClassChapters = string[];

const classNo9Chaps: ClassChapters = [
  "Real Numbers",
  "Laws of Indices",
  "Graph",
  "Co-ordinate Geometry: Distance Formula",
  "Linear Simultaneous Equations",
  "Properties of Parallelogram",
  "Polynomial",
  "Factorisation",
  "Transversal & Mid-Point Theorem",
  "Profit and Loss",
  "Statistics",
  "Theorems on Area",
  "Construction: Construction of a Parallelogram whose measurement of one angle is given and equal in area of a Triangle",
  "Construction: Construction of a Triangle equal in area of a Quadrilateral",
  "Area & Perimeter of Triangle & Quadrilateral shaped region",
  "Circumference of Circle",
  "Theorems on Concurrence",
  "Area of Circular Region",
  "Co-ordinate Geometry: Internal and External Division of Straight Line Segment",
  "Co-ordinate Geometry: Area of Triangular Region",
  "Logarithm",
  "Set Theory",
  "Probability Theory"
];

const classNo10Chaps: ClassChapters = [
  "Quadratic equation in one variable",
  "Simple Interest",
  "Theorems related to circle",
  "Rectangular Parallelopiped or Cuboid",
  "Ratio and proportion",
  "Compound Interest and uniform rate of increase or decrease",
  "Theorems related to angles in a circle",
  "Right Circular Cylinder",
  "Quadratic Surd",
  "Theorems related to cyclic quadrilateral",
  "Construction: Circumcircle and Incircle of a triangle",
  "Sphere",
  "Variation",
  "Partnership Business",
  "Theorems related to Tangent to a circle",
  "Right circular cone",
  "Construction: Construction of tangent to a circle",
  "Similarity",
  "Problems on different solid objects",
  "Trigonometry: Measurement of angle",
  "Trigonometric Ratios & Identities",
  "Trigonometric Ratios of complementary angles",
  "Application of Trigonometric Ratios: Heights & Distances",
  "Statistics: Mean, Median, Mode, Ogive"
];

const classNo11Chaps: ClassChapters = [
    "Set Theory",
    "Relation and Function",
    "Trigonometry: Compund Angle",
    "Trigonometry: Multiple Angle",
    "Trigonometry: Sub Multiple Angle",
    "Trigonometry: Sums & Products",
    "Trigonometry: General Solution",
    "Laws of Indices",
    "Logarithm",
    "Mathematical Induction",
    "Complex Numbers",
    "Quadratic Equations",
    "Linear Inequations",
    "Permutation and Combination",
    "Binomial Theorem",
    "Sequence and Series",
    "Two Dimensional Coordinate Geometry",
    "Straight Line",
    "Circle",
    "Parabola",
    "Ellipse",
    "Hyperbola",
    "Three Dimensional Coordinate Geometry",
    "Real Numbers",
    "Limit",
    "Differentiation",
    "Significance of Derivative",
    "Mathematical Reasoning",
    "Statistics",
    "Probability"
];

const classNo12Chaps: ClassChapters = [
    "Relation",
    "Function",
    "Binary Operation",
    "Inverse Trigonometric Function",
    "Types of Matrices and Matrix Algebra",
    "Determinant",
    "Adjoint and Inverse of a Matrix and Solution of Simultaneous Linear Equations",
    "Limit",
    "Continuity and Differentiability",
    "Differentiation",
    "Second Order Derivative",
    "Indefinite Integral",
    "Definite Integral",
    "Differential Equation",
    "Tangent and Normal",
    "Increasing and Decreasing Function",
    "Maxima and Minima",
    "Definite Integral as an Area",
    "Vector Algebra",
    "Product of Two Vectors",
    "Direction Cosines and Direction Ratios",
    "Straight Line in Three Dimensional Space",
    "Plane",
    "Linear Programming",
    "Probability"
];


export const onRequest = defineMiddleware(async (context , next) => {
    context.locals.chapters = {classNo9Chaps, classNo10Chaps, classNo11Chaps, classNo12Chaps}
    next();
});
