import axios, { AxiosResponse } from 'axios';
import FormData from 'form-data';
import * as fs from 'fs';
import { Request, Response } from 'express';

// Import all the fixed functions
import {
    extractQuestionsFromMathpix,
    debugMathpixExtraction,
} from '../utils/mmdHandling.ts';

// Updated Type definitions to match new structure
interface UploadedFile {
    fieldname: string;
    originalname: string;
    encoding: string;
    mimetype: string;
    path?: string;  // FIXED: Made optional for buffer support
    size: number;
    buffer?: Buffer;
}

interface MathpixPDFResponse {
    pdf_id: string;
    status?: string;
}

interface MathpixStatusResponse {
    status: string;
}

interface MathpixResponse {
    text?: string;
    html?: string;
    latex?: string;
    data?: Array<{
        type: string;
        value: string;
    }>;
    confidence?: number;
    is_printed?: boolean;
    is_handwritten?: boolean;
    line_data?: Array<any>;
    error?: string;  // ADDED: Error handling
    error_id?: string;
}

interface ProcessResult {
    mathpixResponse: MathpixResponse;
    id: string;
    processingTime: string;
    attempts?: number;
    confidence?: number;
}

interface ExtractedQuestion {
    questionNumber: number;
    question: string;
    diagram: null;
    options: string[] | null;
    type: string;
    metadata: {
        hasTabular: boolean;
        hasColumnMatching: boolean;
        hasFillInBlank: boolean;
        optionCount: number;
        rawSectionLength: number;
        confidence?: number;
    };
}

interface ExtractionStats {
    total_questions: number;
    question_types: { [key: string]: number };
    questions_with_options: number;
    questions_without_options: number;
    average_options_per_question: string | number;
    problematic_questions: Array<{
        questionNumber: number;
        issue: string;
        optionCount?: number;
        length?: number;
    }>;
}

// Helper function to determine if file is an image
function isImageFile(mimetype: string): boolean {
    const imageTypes: string[] = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
    return imageTypes.includes(mimetype);
}

// Helper function to get file data (handles both buffer and path)
function getFileData(file: UploadedFile): Buffer | fs.ReadStream {
    console.log('📁 Getting file data:', {
        hasBuffer: !!file.buffer,
        bufferSize: file.buffer?.length || 0,
        hasPath: !!file.path,
        pathExists: file.path ? fs.existsSync(file.path) : false
    });

    // Priority 1: Use buffer if available (memory storage)
    if (file.buffer && file.buffer.length > 0) {
        console.log('✅ Using file buffer');
        return file.buffer;
    } 
    
    // Priority 2: Use file path if available (disk storage)
    if (file.path && fs.existsSync(file.path)) {
        console.log('✅ Using file path (disk storage):', file.path);
        return fs.readFileSync(file.path); // Read as buffer for consistency
    }
    
    throw new Error('No valid file data found. File must have either buffer or path.');
}

// Process PDF file - Updated to return MathpixResponse
const processPDF = async (file: UploadedFile): Promise<ProcessResult> => {
    const form = new FormData();
    
    try {
        const fileData = getFileData(file);
        form.append('file', fileData, file.originalname);
    } catch (fileError: any) {
        throw new Error(`Cannot read PDF file: ${fileError.message}`);
    }
    
    // FIXED: Simplified PDF options - removed problematic options
    form.append('options_json', JSON.stringify({
        math_inline_delimiters: ["$", "$"],
        rm_spaces: true,
        formats: ["text", "html"] // Simplified formats
    }));
    
    try {
        // Upload PDF to Mathpix
        const postResponse: AxiosResponse<MathpixPDFResponse> = await axios.post(
            'https://api.mathpix.com/v3/pdf',
            form,
            {
                headers: {
                    ...form.getHeaders(),
                    'app_id': process.env.MATHPIX_API_ID as string,
                    'app_key': process.env.MATHPIX_API_KEY as string
                }
            }
        );
        
        const pdf_id: string = postResponse.data.pdf_id;
        console.log(`PDF uploaded successfully. PDF ID: ${pdf_id}`);
        
        // Poll for completion with exponential backoff
        const maxAttempts: number = 6;
        const baseInterval: number = 5000; // Start with 5 seconds
        let attempts: number = 0;
        let totalWaitTime: number = 0;
        
        while (attempts < maxAttempts) {
            attempts++;
            const waitTime: number = Math.min(baseInterval * Math.pow(1.5, attempts - 1), 15000); // Max 15 seconds
            
            console.log(`Checking PDF processing status... Attempt ${attempts}`);
            
            const statusResponse: AxiosResponse<MathpixStatusResponse> = await axios.get(
                `https://api.mathpix.com/v3/pdf/${pdf_id}`,
                {
                    headers: {
                        'app_id': process.env.MATHPIX_API_ID as string,
                        'app_key': process.env.MATHPIX_API_KEY as string
                    }
                }
            );
            
            const status: string = statusResponse.data.status;
            console.log(`PDF Status: ${status}`);
            
            if (status === 'completed') {
                // Get the processed data - try multiple endpoints for best results
                let mathpixResponse: MathpixResponse = {};
                
                try {
                    // Get text format
                    const textResponse: AxiosResponse<string> = await axios.get(
                        `https://api.mathpix.com/v3/pdf/${pdf_id}.mmd`,
                        {
                            headers: {
                                'app_id': process.env.MATHPIX_API_ID as string,
                                'app_key': process.env.MATHPIX_API_KEY as string
                            }
                        }
                    );
                    
                    mathpixResponse.text = textResponse.data;
                } catch (e) {
                    console.log('MMD format not available');
                }
                
                try {
                    // Get HTML format if available
                    const htmlResponse: AxiosResponse<string> = await axios.get(
                        `https://api.mathpix.com/v3/pdf/${pdf_id}.html`,
                        {
                            headers: {
                                'app_id': process.env.MATHPIX_API_ID as string,
                                'app_key': process.env.MATHPIX_API_KEY as string
                            }
                        }
                    );
                    
                    mathpixResponse.html = htmlResponse.data;
                } catch (e) {
                    console.log('HTML format not available');
                }
                
                // Set additional metadata
                mathpixResponse.is_printed = true;
                mathpixResponse.confidence = 0.95; // PDFs generally have high confidence
                
                return {
                    mathpixResponse: mathpixResponse,
                    id: pdf_id,
                    processingTime: `${totalWaitTime / 1000} seconds`,
                    attempts: attempts,
                    confidence: mathpixResponse.confidence
                };
                
            } else if (status === 'error' || status === 'failed') {
                throw new Error(`PDF processing failed with status: ${status}`);
            }
            
            // Wait before next attempt (except on last attempt)
            if (attempts < maxAttempts) {
                console.log(`Waiting ${waitTime / 1000} seconds before next check...`);
                await new Promise(resolve => setTimeout(resolve, waitTime));
                totalWaitTime += waitTime;
            }
        }
        
        throw new Error(`PDF processing timeout after ${totalWaitTime / 1000} seconds and ${maxAttempts} attempts`);
        
    } catch (error: any) {
        if (error.response) {
            console.error('Mathpix API Error:', error.response.status, error.response.data);
            throw new Error(`Mathpix API Error: ${error.response.status} - ${error.response.data?.error || error.message}`);
        }
        throw error;
    }
};

// CRITICAL FIX: Process Image file - SIMPLIFIED COMPATIBLE OPTIONS
const processImage = async (file: UploadedFile): Promise<ProcessResult> => {
    console.log('\n🖼️ === PROCESSING IMAGE ===');
    console.log('File details:', {
        name: file.originalname,
        type: file.mimetype,
        size: `${(file.size / 1024).toFixed(1)}KB`,
        encoding: file.encoding,
        hasBuffer: !!file.buffer,
        hasPath: !!file.path,
        fieldname: file.fieldname
    });

    const startTime = Date.now();

    try {
        // STEP 1: Validate file
        if (file.size === 0) {
            throw new Error('Empty image file');
        }

        if (file.size > 32 * 1024 * 1024) { // 32MB limit
            throw new Error(`Image too large: ${(file.size / (1024 * 1024)).toFixed(1)}MB`);
        }

        // STEP 2: Check API credentials
        if (!process.env.MATHPIX_API_ID || !process.env.MATHPIX_API_KEY) {
            throw new Error('Missing Mathpix API credentials');
        }

        console.log('✅ API credentials validated');

        // STEP 3: Prepare FormData
        const form = new FormData();
        
        try {
            const fileData = getFileData(file);
            
            // FIXED: Proper file attachment with metadata
            form.append('file', fileData, {
                filename: file.originalname,
                contentType: file.mimetype,
                knownLength: file.size
            });
            
            console.log('✅ File successfully added to FormData');
            
        } catch (fileError: any) {
            console.error('❌ File preparation failed:', fileError.message);
            throw new Error(`Cannot read file: ${fileError.message}`);
        }

        // STEP 4: CRITICAL FIX - Use only BASIC compatible options
        const basicOptions = {
            "formats": ["text", "html"],  // Only basic formats
            "math_inline_delimiters": ["$", "$"],
            "rm_spaces": true
            // REMOVED all data_options that were causing the error
        };

        form.append('options_json', JSON.stringify(basicOptions));
        console.log('✅ Basic compatible options added');

        // STEP 5: Make API request
        console.log('📡 Making Mathpix API request...');
        console.log('API URL: https://api.mathpix.com/v3/text');

        const response: AxiosResponse<MathpixResponse> = await axios.post(
            'https://api.mathpix.com/v3/text',
            form,
            {
                headers: {
                    ...form.getHeaders(),
                    'app_id': process.env.MATHPIX_API_ID as string,
                    'app_key': process.env.MATHPIX_API_KEY as string,
                },
                timeout: 60000,  // 60 second timeout
                maxContentLength: Infinity,
                maxBodyLength: Infinity,
                validateStatus: function (status) {
                    return status < 500; // Handle 4xx errors manually
                }
            }
        );

        const processingTime = Date.now() - startTime;

        console.log('📊 Mathpix API Response:', {
            status: response.status,
            statusText: response.statusText,
            hasText: !!response.data?.text,
            textLength: response.data?.text?.length || 0,
            hasHtml: !!response.data?.html,
            confidence: response.data?.confidence,
            hasError: !!response.data?.error,
            processingTime: `${processingTime}ms`
        });

        // STEP 6: Handle API errors
        if (response.status >= 400) {
            let errorMsg = `Mathpix API Error ${response.status}`;
            switch (response.status) {
                case 401: errorMsg += ': Invalid API credentials'; break;
                case 402: errorMsg += ': API quota exceeded'; break;
                case 429: errorMsg += ': Rate limit exceeded'; break;
                case 413: errorMsg += ': Image too large'; break;
                case 415: errorMsg += ': Unsupported format'; break;
                default: errorMsg += `: ${response.data?.error || 'Unknown error'}`;
            }
            throw new Error(errorMsg);
        }

        // STEP 7: Check for API-level errors in successful response
        const mathpixData = response.data;
        
        if (mathpixData.error) {
            console.error('❌ Mathpix returned API error:', mathpixData.error);
            throw new Error(`Mathpix API error: ${mathpixData.error}`);
        }

        // STEP 8: Validate extracted data
        if (!mathpixData.text && !mathpixData.html) {
            console.warn('⚠️ No text data extracted from image');
            console.log('Creating fallback response...');
            mathpixData.text = 'No clear text detected in this image. The image may be blank, blurry, or contain content that is difficult to recognize.';
            mathpixData.confidence = 0.1;
        } else {
            console.log('✅ Text extraction successful');
            if (mathpixData.text) {
                console.log('Text preview:', mathpixData.text.substring(0, 200) + '...');
            }
        }

        console.log('🎉 Image processing completed successfully!');

        return {
            mathpixResponse: mathpixData,
            id: `img_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            processingTime: `${(processingTime / 1000).toFixed(1)} seconds`,
            confidence: mathpixData.confidence
        };

    } catch (error: any) {
        const processingTime = Date.now() - startTime;
        
        console.error('❌ Image processing failed');
        console.error('Error type:', error.constructor?.name || 'Unknown');
        console.error('Error message:', error.message);
        console.error('Processing time:', `${processingTime}ms`);

        // Enhanced error logging for debugging
        if (error.response) {
            console.error('HTTP Error Details:', {
                status: error.response.status,
                statusText: error.response.statusText,
                data: error.response.data
            });
        }

        if (error.code) {
            console.error('Network error code:', error.code);
        }

        throw new Error(`Image processing failed: ${error.message}`);
    }
};

// Generate extraction statistics - Updated for new question structure
function generateExtractionStats(questions: ExtractedQuestion[]): ExtractionStats {
    const stats: ExtractionStats = {
        total_questions: questions.length,
        question_types: {},
        questions_with_options: 0,
        questions_without_options: 0,
        average_options_per_question: 0,
        problematic_questions: []
    };
    
    let totalOptions: number = 0;
    
    questions.forEach((q: ExtractedQuestion, index: number) => {
        const type: string = q.type || 'unknown';
        stats.question_types[type] = (stats.question_types[type] || 0) + 1;
        
        if (q.options && q.options.length > 0) {
            const nonEmptyOptions = q.options.filter(opt => opt.trim().length > 0);
            if (nonEmptyOptions.length > 0) {
                stats.questions_with_options++;
                totalOptions += nonEmptyOptions.length;
                
                // Check for incomplete multiple choice
                if (q.type === 'multiple_choice' && nonEmptyOptions.length < 4) {
                    stats.problematic_questions.push({
                        questionNumber: q.questionNumber || index + 1,
                        issue: 'incomplete_options',
                        optionCount: nonEmptyOptions.length
                    });
                }
            } else {
                stats.questions_without_options++;
            }
        } else {
            stats.questions_without_options++;
        }
        
        // Check for other potential issues
        if (q.question.length < 20) {
            stats.problematic_questions.push({
                questionNumber: q.questionNumber || index + 1,
                issue: 'very_short_question',
                length: q.question.length
            });
        }
        
        // Check for mathematical symbols preservation
        if ((q.question.includes('<') || q.question.includes('>')) && q.metadata.confidence) {
            console.log(`✓ Mathematical symbols preserved in question ${q.questionNumber}`);
        }
    });
    
    stats.average_options_per_question = stats.questions_with_options > 0 
        ? (totalOptions / stats.questions_with_options).toFixed(1)
        : 0;
    
    return stats;
}

const upload = async (req: Request & { file?: UploadedFile }, res: Response): Promise<Response | void> => {
    const uploadedFile: UploadedFile | undefined = req.file;
    const startTime: number = Date.now();
    
    console.log('\n🚀 === UPLOAD PROCESSING STARTED ===');
    console.log(`Timestamp: ${new Date().toISOString()}`);
    
    if (!uploadedFile) {
        return res.status(400).json({
            success: false,
            message: "No file uploaded"
        });
    }
    
    console.log('📁 File received:', {
        originalname: uploadedFile.originalname,
        mimetype: uploadedFile.mimetype,
        size: `${(uploadedFile.size / 1024).toFixed(1)} KB`,
        fieldname: uploadedFile.fieldname,
        encoding: uploadedFile.encoding,
        hasBuffer: !!uploadedFile.buffer,
        bufferSize: uploadedFile.buffer?.length || 0,
        hasPath: !!uploadedFile.path,
        pathExists: uploadedFile.path ? fs.existsSync(uploadedFile.path) : 'N/A'
    });
    
    try {
        let result: ProcessResult;
        let fileType: string;
        
        // Validate file size (optional - adjust as needed)
        const maxSizeBytes: number = 50 * 1024 * 1024; // 50MB
        if (uploadedFile.size > maxSizeBytes) {
            throw new Error(`File too large. Maximum size is ${maxSizeBytes / (1024 * 1024)}MB`);
        }
        
        if (uploadedFile.size === 0) {
            throw new Error('Empty file uploaded');
        }

        // Check API credentials early
        if (!process.env.MATHPIX_API_ID || !process.env.MATHPIX_API_KEY) {
            throw new Error('Mathpix API credentials not configured');
        }
        
        console.log('✅ Initial validation passed');
        console.log('✅ API credentials found');
        
        // Determine file type and process accordingly
        if (uploadedFile.mimetype === 'application/pdf') {
            fileType = 'pdf';
            console.log('📄 Processing as PDF...');
            result = await processPDF(uploadedFile);
        } else if (isImageFile(uploadedFile.mimetype)) {
            fileType = 'image';
            console.log('🖼️ Processing as image...');
            result = await processImage(uploadedFile);
        } else {
            throw new Error(`Unsupported file type: ${uploadedFile.mimetype}`);
        }
        
        console.log('✅ Mathpix processing completed');
        console.log('Processing result:', {
            id: result.id,
            processingTime: result.processingTime,
            confidence: result.confidence,
            hasText: !!result.mathpixResponse.text,
            textLength: result.mathpixResponse.text?.length || 0
        });
        
        // Clean up uploaded file immediately after processing
        if (uploadedFile.path && fs.existsSync(uploadedFile.path)) {
            try {
                fs.rmSync(uploadedFile.path);
                console.log('🧹 Temporary file cleaned up');
            } catch (cleanupError: any) {
                console.warn('⚠️ Could not clean up uploaded file:', cleanupError.message);
            }
        }
        
        // DEBUG: Log Mathpix response details
        console.log('\n🔍 === MATHPIX RESPONSE DEBUG ===');
        console.log('Response validation:', {
            hasText: !!result.mathpixResponse.text,
            textLength: result.mathpixResponse.text?.length || 0,
            hasHtml: !!result.mathpixResponse.html,
            confidence: result.mathpixResponse.confidence,
            hasError: !!result.mathpixResponse.error
        });
        
        if (result.mathpixResponse.text) {
            console.log('Text preview:', result.mathpixResponse.text.substring(0, 200) + '...');
        }
        
        if (result.mathpixResponse.error) {
            console.warn('⚠️ Mathpix returned error:', result.mathpixResponse.error);
        }
        
        debugMathpixExtraction(result.mathpixResponse);
        console.log('===============================\n');
        
        // Extract questions using the enhanced functions
        console.log('🔧 === EXTRACTING QUESTIONS ===');
        let extractedQuestions: ExtractedQuestion[] = [];
        
        try {
            extractedQuestions = extractQuestionsFromMathpix(
                result.mathpixResponse, 
                true // Enable debug mode
            );
            console.log(`✅ Question extraction completed: ${extractedQuestions.length} questions found`);
            
            if (extractedQuestions.length === 0) {
                console.warn('⚠️ No questions extracted - this could indicate:');
                console.warn('   - Image quality issues');
                console.warn('   - Unsupported question format');
                console.warn('   - Text recognition problems');
                console.warn('   - Missing question numbering (1., 2., etc.)');
            }
            
        } catch (extractionError: any) {
            console.error('❌ Question extraction failed:', extractionError.message);
            console.error('Stack trace:', extractionError.stack);
            
            // Continue processing with empty questions array
            extractedQuestions = [];
        }
        
        // Generate comprehensive statistics
        const extractionStats: ExtractionStats = generateExtractionStats(extractedQuestions);
        
        // Enhanced logging
        console.log('\n📈 === EXTRACTION SUMMARY ===');
        console.log(`File: ${uploadedFile.originalname} (${fileType})`);
        console.log(`Processing time: ${result.processingTime}`);
        console.log(`Mathpix confidence: ${result.confidence || 'N/A'}`);
        console.log(`Questions extracted: ${extractedQuestions.length}`);
        console.log(`Question types: ${Object.keys(extractionStats.question_types).join(', ')}`);
        console.log(`With options: ${extractionStats.questions_with_options}, Without: ${extractionStats.questions_without_options}`);
        console.log(`Average options per question: ${extractionStats.average_options_per_question}`);
        console.log(`Success rate: ${extractedQuestions.length > 0 ? '✅ SUCCESS' : '❌ NO QUESTIONS FOUND'}`);
        
        if (extractionStats.problematic_questions.length > 0) {
            console.log(`⚠️ ${extractionStats.problematic_questions.length} questions may need review`);
            extractionStats.problematic_questions.slice(0, 3).forEach(issue => {
                console.log(`   - Question ${issue.questionNumber}: ${issue.issue}`);
            });
        }
        
        // Check for mathematical symbols preservation
        const questionsWithMathSymbols = extractedQuestions.filter(q => 
            q.question.includes('<') || q.question.includes('>')
        ).length;
        if (questionsWithMathSymbols > 0) {
            console.log(`✅ Mathematical symbols preserved in ${questionsWithMathSymbols} questions`);
        }
        
        console.log(`=========================\n`);
        
        // Calculate total processing time
        const totalTime: number = Date.now() - startTime;
        
        // Transform questions to match your existing frontend interface
        const transformedQuestions = extractedQuestions.map(q => ({
            question: q.question,
            diagram: q.diagram,
            options: q.options || []
        }));
        
        console.log(`🎉 Processing completed successfully in ${(totalTime / 1000).toFixed(1)} seconds!`);
        
        // Send comprehensive JSON response
        res.status(200).json({
            success: true,
            message: `${fileType.toUpperCase()} processed and ${extractedQuestions.length} questions extracted successfully`,
            data: {
                // File info
                file_type: fileType,
                pdf_id: result.id,
                total_questions: extractedQuestions.length,
                questions: transformedQuestions, // Use transformed questions for frontend compatibility
                processing_time: `${(totalTime / 1000).toFixed(1)} seconds`,
                original_filename: uploadedFile.originalname,
                
                // Additional detailed info (optional - can be used for debugging)
                detailed_info: {
                    // File info
                    file_info: {
                        type: fileType,
                        original_filename: uploadedFile.originalname,
                        file_size: uploadedFile.size,
                        mime_type: uploadedFile.mimetype
                    },
                    
                    // Processing info
                    processing_info: {
                        mathpix_id: result.id,
                        mathpix_processing_time: result.processingTime,
                        total_processing_time: `${(totalTime / 1000).toFixed(1)} seconds`,
                        attempts: result.attempts || 1,
                        confidence: result.confidence || null
                    },
                    
                    // Enhanced questions data with metadata
                    enhanced_questions: extractedQuestions,
                    
                    // Statistics
                    extraction_stats: extractionStats,
                    
                    // Quality indicators
                    quality_indicators: {
                        has_mathematical_symbols: questionsWithMathSymbols > 0,
                        questions_with_math_symbols: questionsWithMathSymbols,
                        average_confidence: result.confidence || null,
                        extraction_method_used: 'mathpix_basic_compatible'
                    }
                }
            }
        });
        
    } catch (error: any) {
        const totalTime = Date.now() - startTime;
        
        console.error('\n❌ === PROCESSING FAILED ===');
        console.error('Error type:', error.constructor?.name || 'Unknown');
        console.error('Error message:', error.message);
        console.error('Processing time:', `${(totalTime / 1000).toFixed(1)}s`);
        
        if (error.response) {
            console.error('HTTP Response Error:', {
                status: error.response.status,
                statusText: error.response.statusText,
                data: error.response.data
            });
        }
        
        if (error.code) {
            console.error('Error code:', error.code);
        }
        
        // Clean up file if it still exists
        if (uploadedFile && uploadedFile.path && fs.existsSync(uploadedFile.path)) {
            try {
                fs.rmSync(uploadedFile.path);
                console.log('🧹 Cleaned up file after error');
            } catch (cleanupError: any) {
                console.error('❌ Cleanup failed:', cleanupError.message);
            }
        }
        
        // Return detailed error information
        res.status(500).json({
            success: false,
            message: "Failed to process file",
            error: {
                type: error.constructor?.name || 'UnknownError',
                message: error.message,
                details: error.response?.data || null
            },
            data: {
                total_questions: 0,
                questions: [],
                processing_time: `${(totalTime / 1000).toFixed(1)} seconds`
            },
            file_info: uploadedFile ? {
                original_filename: uploadedFile.originalname,
                mime_type: uploadedFile.mimetype,
                file_size: uploadedFile.size
            } : null
        });
    }
};

export { upload };