import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Processes image and extracts math text with high accuracy
  Future<String> recognizeMathText(String imagePath) async {
    // 1. Preprocess image for better OCR
    final File preprocessedFile = await _preprocessImage(imagePath);
    
    // 2. Perform OCR
    final InputImage inputImage = InputImage.fromFile(preprocessedFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    // 3. Clean up and structure the text
    String cleanedText = _cleanText(recognizedText.text);
    
    // 4. Handle multiple questions
    cleanedText = _handleMultiQuestions(cleanedText);

    return cleanedText;
  }

  /// Image Preprocessing: Grayscale, Contrast, Thresholding
  Future<File> _preprocessImage(String path) async {
    final Uint8List bytes = await File(path).readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (image == null) return File(path);

    // Convert to Grayscale
    image = img.grayscale(image);

    // Increase Contrast
    image = img.contrast(image, contrast: 150);

    // Apply simple binary thresholding
    // We iterate through pixels and set to black or white
    for (var pixel in image) {
      final luminance = img.getLuminance(pixel);
      if (luminance < 128) {
        pixel.r = pixel.g = pixel.b = 0;
      } else {
        pixel.r = pixel.g = pixel.b = 255;
      }
    }

    // Save preprocessed image to temp directory
    final tempDir = await getTemporaryDirectory();
    final preprocessedPath = '${tempDir.path}/preprocessed_ocr.png';
    final preprocessedFile = File(preprocessedPath);
    await preprocessedFile.writeAsBytes(img.encodePng(image));

    return preprocessedFile;
  }

  /// Fixes common OCR mistakes while preserving math variables
  String _cleanText(String text) {
    // Basic cleaning without destroying variables like 'x'
    return text
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll('—', '-') // Long dash
        .replaceAll('·', '*') // Middle dot
        .replaceAll('O', '0')
        .replaceAll('l', '1')
        .replaceAll('|', '1')
        .replaceAll('\r', '')
        .trim();
  }

  /// Detects question patterns (1), 2), etc.) and ensures they are readable
  String _handleMultiQuestions(String text) {
    // Simple regex to add newlines before question numbers like "1)" or "2."
    final RegExp questionPattern = RegExp(r'(\d+[\)\.])');
    return text.replaceAllMapped(questionPattern, (match) => '\n${match.group(0)} ');
  }

  void dispose() {
    _textRecognizer.close();
  }
}
