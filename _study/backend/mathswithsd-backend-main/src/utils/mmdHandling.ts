// Enhanced Mathpix Question Extraction - Complete Implementation
// Type definitions
interface ParsedQuestionOptions {
    question: string;
    options: string[];
}

interface QuestionMetadata {
    hasTabular: boolean;
    hasColumnMatching: boolean;
    hasFillInBlank: boolean;
    optionCount: number;
    rawSectionLength: number;
    confidence?: number;
}

interface ExtractedQuestion {
    questionNumber: number;
    question: string;
    diagram: null;
    options: string[] | null;
    type: string;
    metadata: QuestionMetadata;
}

interface MathpixResponse {
    text?: string;
    html?: string;
    data?: Array<{
        type: string;
        value: string;
    }>;
    confidence?: number;
    is_printed?: boolean;
    is_handwritten?: boolean;
    line_data?: Array<any>;
}

// Helper function to escape special regex characters
function escapeRegExp(string: string): string {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// Process Mathpix API response to get the best text format
function processMathpixResponse(response: MathpixResponse): string {
    let textToProcess = '';
    
    if (response.data && response.data.length > 0) {
        // Prefer structured data if available
        textToProcess = response.data
            .map(item => item.value)
            .join(' ');
        console.log("Using Mathpix structured data format");
    } else if (response.text) {
        // Fall back to text format
        textToProcess = response.text;
        console.log("Using Mathpix text format");
    } else if (response.html) {
        // Last resort: HTML format
        textToProcess = response.html;
        console.log("Using Mathpix HTML format");
    }
    
    console.log("Mathpix confidence:", response.confidence);
    console.log("Is printed:", response.is_printed);
    console.log("Processing text preview:", textToProcess.substring(0, 200) + "...");
    
    return textToProcess;
}

// Fixed cleanMathpixContent function - preserves mathematical symbols
function cleanMathpixContent(text: string): string {
    return text
        // Remove specific Mathpix HTML artifacts while preserving math content
        .replace(/<span[^>]*class="katex[^"]*"[^>]*>(.*?)<\/span>/gs, '$1')
        .replace(/<math[^>]*>(.*?)<\/math>/gs, '$1')
        .replace(/<asciimath[^>]*>(.*?)<\/asciimath>/gs, '$1')
        .replace(/<latex[^>]*>(.*?)<\/latex>/gs, '$1')
        .replace(/=<span.*?<\/span>/gs, '')
        .replace(/=<spanclass="katex−display">.*?<\/span>/gs, '')
        
        // Remove HTML attributes but preserve content
        .replace(/class="[^"]*"/g, '')
        .replace(/style="[^"]*"/g, '')
        .replace(/display:\s*none;?/g, '')
        .replace(/aria−hidden="true"/g, '')
        .replace(/mathbackground="[^"]*"/g, '')
        .replace(/width="[^"]*"/g, '')
        .replace(/height="[^"]*"/g, '')
        
        // CRITICAL FIX: Preserve mathematical inequalities before removing HTML
        // Protect common mathematical expressions with < and > symbols
        .replace(/(\$[^$]*)<([^$]*\$)/g, '$1LESS_THAN$2')  // Math expressions with <
        .replace(/(\$[^$]*)>([^$]*\$)/g, '$1GREATER_THAN$2')  // Math expressions with >
        .replace(/(\w+|\d+)\s*&lt;\s*(\w+|\d+)/g, '$1 LESS_THAN $2')  // HTML entities
        .replace(/(\w+|\d+)\s*&gt;\s*(\w+|\d+)/g, '$1 GREATER_THAN $2')  // HTML entities
        .replace(/(\w+|\d+)\s*<\s*(\w+|\d+)/g, '$1 LESS_THAN $2')  // Direct symbols
        .replace(/(\w+|\d+)\s*>\s*(\w+|\d+)/g, '$1 GREATER_THAN $2')  // Direct symbols
        .replace(/([a-zA-Z]+)\s*<\s*([a-zA-Z]+)/g, '$1 LESS_THAN $2')  // Variables
        .replace(/([a-zA-Z]+)\s*>\s*([a-zA-Z]+)/g, '$1 GREATER_THAN $2')  // Variables
        .replace(/\\\[(.*?)\\\]/gs, '\$$1\$')  // Convert \[...\] to $...$
        
        // Now safely remove HTML tags (selective removal)
        .replace(/<\/?(?:div|span|p|br|hr|table|tr|td|th)[^>]*>/gi, '')
        .replace(/<(?!\/?(b|i|u|strong|em|sub|sup)\b)[^>]*>/gi, '') // Keep basic formatting tags
        
        // Restore mathematical symbols after HTML removal
        .replace(/LESS_THAN/g, '<')
        .replace(/GREATER_THAN/g, '>')
        
        // Clean HTML entities
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&amp;/g, '&')
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
        .replace(/&[a-zA-Z0-9#]+;/g, '') // Remove remaining entities
        
        // Fix Mathpix-specific spacing and formatting issues
        .replace(/(\w)(\$\vec\{)/g, '$1 $2')  // Space before vectors
        .replace(/(\w)(\$[^$]*\$)/g, '$1 $2')  // Space before inline math
        .replace(/(\$[^$]*\$)(\w)/g, '$1 $2')  // Space after inline math
        .replace(/(\w)(\\\()/g, '$1 $2')  // Space before LaTeX inline math
        .replace(/(\\\))(\w)/g, '$1 $2')  // Space after LaTeX inline math
        .replace(/(\w)(\\\[)/g, '$1 $2')  // Space before LaTeX block math
        .replace(/(\\\])(\w)/g, '$1 $2')  // Space after LaTeX block math
        
        // Specific fixes for common Mathpix output issues
        .replace(/field\$\vec\{B\}\$/g, 'field $\vec{B}$')
        .replace(/element\$\vec\{I\}\$/g, 'element $\vec{I}$')
        .replace(/distance\$\vec\{r\}\$/g, 'distance $\vec{r}$')
        .replace(/current\$i\$/g, 'current $i$')
        
        // Clean up mathematical expressions
        .replace(/\$\s*\$\s*/g, ' ') // Remove empty math delimiters
        .replace(/\$([^$]*)\$/g, '$$$1$$') // Ensure proper math delimiters
        
        // Fix common OCR/parsing errors
        .replace(/−/g, '-') // Replace unicode minus with regular hyphen
        .replace(/\s+/g, ' ') // Normalize whitespace
        .replace(/\n\s*\n\s*\n+/g, '\n\n') // Remove excessive line breaks
        
        // Clean up table formatting if present
        .replace(/\hline\s*/g, '\hline\n')
        .replace(/\\\s*\hline/g, '\\\n\hline')
        
        // Final cleanup
        .trim();
}

// Enhanced MCQ options extraction optimized for Mathpix output
function extractMCQOptions(text: string): string[] {
    const options: string[] = [];
    
    console.log("=== Extracting Options ===");
    console.log("Input text:", text.substring(0, 300) + "...");
    
    // Pattern 1: Standard Mathpix MCQ format - (a) option (b) option (c) option (d) option
    const pattern1 = /\(([abcdABCD])\)\s*([^()]*?)(?=\s*\([abcdABCD]\)|$)/gs;
    let matches = [...text.matchAll(pattern1)];
    
    if (matches.length >= 4) {
        console.log("✓ Pattern 1 (standard) matched:", matches.length, "options");
        matches.slice(0, 4).forEach((match, index) => {
            if (match[2]?.trim()) {
                const cleanOption = match[2].trim()
                    .replace(/\s+/g, ' ')
                    .replace(/^\s*[।\.]\s*/, '') // Remove Bengali/Hindi punctuation
                    .trim();
                options.push(cleanOption);
                console.log(`  Option ${match[1]}:`, cleanOption);
            }
        });
        return options;
    }
    
    // Pattern 2: Line-separated options (common in Mathpix text output)
    const lines = text.split(/\n+/).map(line => line.trim()).filter(line => line.length > 0);
    const optionLines = lines.filter(line => 
        /^\s*\([abcdABCD]\)/i.test(line) || 
        /^\s*[abcdABCD][\.\)]/i.test(line)
    );
    
    if (optionLines.length >= 4) {
        console.log("✓ Pattern 2 (line-separated) matched:", optionLines.length, "options");
        optionLines.slice(0, 4).forEach((line, index) => {
            const cleaned = line
                .replace(/^\s*[\(]?[abcdABCD][\.\)]\s*/i, '')
                .replace(/\s+/g, ' ')
                .trim();
            if (cleaned) {
                options.push(cleaned);
                console.log(`  Option ${index + 1}:`, cleaned);
            }
        });
        return options;
    }
    
    // Pattern 3: Alternative delimiters (a. option b. option)
    const pattern3 = /(?:^|[^a-zA-Z])([abcdABCD])[\.\)]\s*([^.\n]+?)(?=\s*[abcdABCD][\.\)]|$)/gm;
    matches = [...text.matchAll(pattern3)];
    
    if (matches.length >= 4) {
        console.log("✓ Pattern 3 (alternative delimiters) matched:", matches.length, "options");
        matches.slice(0, 4).forEach((match, index) => {
            if (match[2]?.trim()) {
                const cleanOption = match[2].trim()
                    .replace(/\s+/g, ' ')
                    .replace(/[।\.]$/, '') // Remove trailing punctuation
                    .trim();
                options.push(cleanOption);
                console.log(`  Option ${match[1]}:`, cleanOption);
            }
        });
        return options;
    }
    
    // Pattern 4: Spaced options (a ) option b ) option)
    const pattern4 = /([abcdABCD])\s*\)\s*([^)]+?)(?=\s*[abcdABCD]\s*\)|$)/g;
    matches = [...text.matchAll(pattern4)];
    
    if (matches.length >= 4) {
        console.log("✓ Pattern 4 (spaced options) matched:", matches.length, "options");
        matches.slice(0, 4).forEach((match, index) => {
            if (match[2]?.trim()) {
                const cleanOption = match[2].trim()
                    .replace(/\s+/g, ' ')
                    .trim();
                options.push(cleanOption);
                console.log(`  Option ${match[1]}:`, cleanOption);
            }
        });
        return options;
    }
    
    // Pattern 5: Extract from Mathpix structured data if available
    if (text.includes('"type": "text"') || text.includes('"value":')) {
        try {
            const jsonMatch = text.match(/\{.*\}/s);
            if (jsonMatch) {
                const data = JSON.parse(jsonMatch[0]);
                if (data.choices || data.options) {
                    console.log("✓ Pattern 5 (JSON data) matched");
                    return (data.choices || data.options).slice(0, 4);
                }
            }
        } catch (e) {
            console.log("JSON parsing failed, continuing...");
        }
    }
    
    // Pattern 6: Fallback - any text that looks like options
    const allPossibleOptions = [];
    const fallbackPattern = /\(([abcdABCD])\)|([abcdABCD])\./g;
    let fallbackMatch;
    
    while ((fallbackMatch = fallbackPattern.exec(text)) !== null) {
        const startIndex = fallbackMatch.index + fallbackMatch[0].length;
        const nextMatch = text.substring(startIndex).match(/\(([abcdABCD])\)|([abcdABCD])\./);
        const endIndex = nextMatch && nextMatch.index ? startIndex + nextMatch.index : text.length;
        
        const optionText = text.substring(startIndex, endIndex).trim();
        if (optionText && optionText.length > 1) {
            allPossibleOptions.push(optionText);
        }
    }
    
    if (allPossibleOptions.length >= 4) {
        console.log("✓ Pattern 6 (fallback) matched:", allPossibleOptions.length, "options");
        return allPossibleOptions.slice(0, 4);
    }
    
    console.log("✗ No clear options found");
    return [];
}

// Enhanced question-option separation with multiple strategies
function separateQuestionFromOptions(text: string): ParsedQuestionOptions {
    const cleanedText = cleanMathpixContent(text);
    
    // Remove question number at the beginning
    const textWithoutNumber = cleanedText.replace(/^\s*\d+\.\s*/, '');
    
    console.log("=== Separating Question from Options ===");
    console.log("Text after number removal:", textWithoutNumber.substring(0, 200) + "...");
    
    // Multiple strategies to find where options start
    const optionStartPatterns = [
        { pattern: /\n\s*\([abcdABCD]\)/i, name: "(a) on new line" },
        { pattern: /\([abcdABCD]\)\s+/i, name: "(a) with space" },
        { pattern: /\n\s*[abcdABCD][\.\)]/i, name: "a. on new line" },
        { pattern: /[^a-zA-Z][abcdABCD][\.\)]\s/i, name: "a. mid-text" },
        { pattern: /\s[abcdABCD]\)\s/i, name: "a) with spaces" }
    ];
    
    let splitIndex = -1;
    let bestPattern = null;
    
    for (const { pattern, name } of optionStartPatterns) {
        const match = textWithoutNumber.match(pattern);
        if (match) {
            const index = textWithoutNumber.indexOf(match[0]);
            if (splitIndex === -1 || index < splitIndex) {
                splitIndex = index;
                bestPattern = name;
            }
        }
    }
    
    if (splitIndex > 0) {
        const questionPart = textWithoutNumber.substring(0, splitIndex).trim();
        const optionsPart = textWithoutNumber.substring(splitIndex).trim();
        
        console.log("✓ Split found using pattern:", bestPattern);
        console.log("Question part:", questionPart);
        console.log("Options part:", optionsPart.substring(0, 100) + "...");
        
        const options = extractMCQOptions(optionsPart);
        
        // Clean up question text
        const cleanQuestion = questionPart
            .replace(/\s+/g, ' ')
            .replace(/হলে\s*নীচের\s*কোন্টি/g, 'হলে নীচের কোনটি')
            .replace(/\s*।\s*/g, '।')
            .replace(/\s*=\s*/g, ' = ')
            .replace(/(\w)(\$)/g, '$1 $2')
            .replace(/(\$)(\w)/g, '$1 $2')
            .trim();
        
        return {
            question: cleanQuestion,
            options: options
        };
    }
    
    // Fallback: try to extract options from entire text and reconstruct question
    const options = extractMCQOptions(textWithoutNumber);
    if (options.length > 0) {
        console.log("✓ Using fallback method - reconstructing question");
        
        // Try to clean question by removing option text
        let questionText = textWithoutNumber;
        options.forEach((option, index) => {
            const letter = String.fromCharCode(97 + index); // a, b, c, d
            const patterns = [
                new RegExp(`\\(${letter}\\)\\s*${escapeRegExp(option)}`, 'gi'),
                new RegExp(`\\(${letter.toUpperCase()}\\)\\s*${escapeRegExp(option)}`, 'gi'),
                new RegExp(`${letter}[\\.\\)]\\s*${escapeRegExp(option)}`, 'gi'),
                new RegExp(`${letter.toUpperCase()}[\\.\\)]\\s*${escapeRegExp(option)}`, 'gi')
            ];
            
            patterns.forEach(pattern => {
                questionText = questionText.replace(pattern, '').trim();
            });
        });
        
        // Clean up reconstructed question
        const cleanQuestion = questionText
            .replace(/\s+/g, ' ')
            .replace(/^[।\.\,\s]+/, '') // Remove leading punctuation
            .replace(/[।\.\,\s]+$/, '') // Remove trailing punctuation  
            .trim();
        
        return {
            question: cleanQuestion,
            options: options
        };
    }
    
    console.log("✗ No options found, returning original text as question");
    return {
        question: textWithoutNumber,
        options: []
    };
}

// Determine question type based on content analysis
function determineQuestionType(questionText: string, options: string[], hasTabular: boolean, hasColumnMatching: boolean, hasFillInBlank: boolean): string {
    if (hasColumnMatching) {
        return 'column_matching';
    } else if (hasTabular && !hasColumnMatching) {
        return 'multiple_choice_with_table';
    } else if (hasFillInBlank || (options && options.length === 0)) {
        return 'fill_in_blank';
    } else if (options && options.length === 4) {
        return 'multiple_choice';
    } else if (options && options.length > 0 && options.length < 4) {
        return 'incomplete_multiple_choice';
    } else {
        return 'other';
    }
}

// Main extraction function optimized for Mathpix
function extractQuestionsFromMathpix(mathpixResponse: MathpixResponse, debug: boolean = false): ExtractedQuestion[] {
    const questions: ExtractedQuestion[] = [];
    
    console.log("=== Starting Mathpix Question Extraction ===");
    
    const processedText = processMathpixResponse(mathpixResponse);
    if (!processedText.trim()) {
        console.error("No text received from Mathpix response");
        return [];
    }
    
    const cleanedText = cleanMathpixContent(processedText);
    
    if (debug) {
        console.log("Cleaned text preview:", cleanedText.substring(0, 500));
    }
    
    // Pre-process text to handle edge cases
    const preprocessedText = cleanedText
        .replace(/\section*\{[^}]*\}/g, '') // Remove LaTeX sections
        .replace(/\r\n/g, '\n') // Normalize line endings
        .replace(/\s+(?=[।])/g, '') // Fix spacing before Bengali punctuation
        // Fix common OCR errors for Bengali text
        .replace(/यমি/g, 'যদি')
        .replace(/यदि/g, 'যদি')
        .replace(/तारে/g, 'তারে')
        .replace(/तबে/g, 'তবে');
    
    // Split by question numbers - more flexible pattern
    const sections = preprocessedText.split(/(?=\n?\s*\d+\.\s+)/);
    
    console.log(`Found ${sections.length} potential question sections`);
    
    for (let i = 0; i < sections.length; i++) {
        const section = sections[i];
        if (!section.trim()) continue;
        
        const lines = section.split('\n').map(l => l.trim()).filter(l => l.length > 0);
        if (lines.length === 0) continue;
        
        const firstLine = lines[0];
        const qMatch = firstLine.match(/^(\d+)\.\s*(.+)/);
        
        if (!qMatch) {
            if (debug) console.log(`Skipping section ${i}: No question number found`);
            continue;
        }
        
        const questionNumber = parseInt(qMatch[1]);
        
        // Build complete section text
        const fullSectionText = lines.join(' ');
        
        if (debug) {
            console.log(`\n--- Processing Question ${questionNumber} ---`);
            console.log("Full section:", fullSectionText.substring(0, 300) + "...");
        }
        
        // Detect special content types
        const hasTabular = section.includes('\\begin{tabular}') || section.includes('<table');
        const hasColumnMatching = section.includes('স্তম্ভ A') || section.includes('স্তম্ভ B') || 
                                  section.includes('Column A') || section.includes('Column B');
        const hasFillInBlank = section.includes('_____') || 
                              (questionText => questionText.includes('=') && questionText.includes('।'))(fullSectionText);
        
        // Use enhanced separation function
        const parsed = separateQuestionFromOptions(fullSectionText);
        
        // Ensure we have exactly 4 options for MCQ
        const finalOptions = [...parsed.options];
        while (finalOptions.length < 4) {
            finalOptions.push('');
        }
        const trimmedOptions = finalOptions.slice(0, 4);
        
        // Final cleaning of question text
        const finalQuestion = parsed.question
            .replace(/\s+/g, ' ')
            .replace(/হলে\s*নীচের\s*কোন্টি/g, 'হলে নীচের কোনটি')
            .replace(/\s*।\s*/g, '।')
            .replace(/\s*=\s*/g, ' = ')
            .replace(/\$\s+/g, '$')
            .replace(/\s+\$/g, '$')
            .replace(/(\w)(\$)/g, '$1 $2')
            .replace(/(\$)(\w)/g, '$1 $2')
            .trim();
        
        const questionType = determineQuestionType(finalQuestion, trimmedOptions, hasTabular, hasColumnMatching, hasFillInBlank);
        
        const questionObj: ExtractedQuestion = {
            questionNumber: questionNumber,
            question: finalQuestion,
            diagram: null,
            options: trimmedOptions.some(opt => opt.trim()) ? trimmedOptions : null,
            type: questionType,
            metadata: {
                hasTabular: hasTabular,
                hasColumnMatching: hasColumnMatching,
                hasFillInBlank: hasFillInBlank,
                optionCount: trimmedOptions.filter(opt => opt.trim().length > 0).length,
                rawSectionLength: section.length,
                confidence: mathpixResponse.confidence
            }
        };
        
        questions.push(questionObj);
        
        if (debug) {
            console.log("Extracted question:", finalQuestion);
            console.log("Extracted options:", trimmedOptions);
            console.log("Question type:", questionType);
        }
    }
    
    console.log(`=== Extraction Complete: ${questions.length} questions extracted ===`);
    return questions;
}

// Debug utility function
function debugMathpixExtraction(mathpixResponse: MathpixResponse): void {
    console.log("=== Mathpix Response Debug Info ===");
    console.log("Confidence:", mathpixResponse.confidence);
    console.log("Is printed:", mathpixResponse.is_printed);
    console.log("Is handwritten:", mathpixResponse.is_handwritten);
    console.log("Has text:", !!mathpixResponse.text);
    console.log("Has HTML:", !!mathpixResponse.html);
    console.log("Has data:", !!mathpixResponse.data);
    
    if (mathpixResponse.text) {
        console.log("Text preview:", mathpixResponse.text.substring(0, 500) + "...");
    }
    
    if (mathpixResponse.html) {
        console.log("HTML preview:", mathpixResponse.html.substring(0, 300) + "...");
    }
    
    if (mathpixResponse.data) {
        console.log("Data items:", mathpixResponse.data.length);
        mathpixResponse.data.slice(0, 3).forEach((item, i) => {
            console.log(`Data[${i}]:`, item.type, item.value.substring(0, 100) + "...");
        });
    }
    
    const extracted = extractQuestionsFromMathpix(mathpixResponse, true);
    console.log("=== Extraction Results ===");
    console.log("Total questions extracted:", extracted.length);
    
    extracted.forEach((q, i) => {
        console.log(`\n--- Question ${i + 1} ---`);
        console.log("Number:", q.questionNumber);
        console.log("Type:", q.type);
        console.log("Question:", q.question.substring(0, 100) + "...");
        console.log("Options:", q.options?.map(opt => opt.substring(0, 50) + "..."));
        console.log("Option count:", q.metadata.optionCount);
    });
}

// Export all functions
export {
    extractQuestionsFromMathpix,
    debugMathpixExtraction,
};