import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  Future<File?> pickAndCropImage(BuildContext context) async {
    final primaryColor = Theme.of(context).primaryColor;
    try {
      // 1. Pick Image from Camera
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );

      if (photo == null) return null;

      // 2. Open Crop Screen
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: photo.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Question',
            toolbarColor: primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Question',
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
        ],
      );

      if (croppedFile == null) return null;

      return File(croppedFile.path);
    } catch (e) {
      debugPrint("ImageService Error: $e");
      return null;
    }
  }
}
