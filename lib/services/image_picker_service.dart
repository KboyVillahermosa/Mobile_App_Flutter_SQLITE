import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  // Method to pick image from gallery or camera
  static Future<File?> pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  // Method to show image source selection dialog
  static Future<File?> showImageSourceDialog(BuildContext context) async {
    ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      return await pickImage(source);
    }
    return null;
  }

  // Method to save image to app's documents directory
  static Future<String> saveImagePermanently(File image) async {
    final directory = await getApplicationDocumentsDirectory();
    final name = path.basename(image.path);
    final savedImage = await image.copy('${directory.path}/$name');
    
    return savedImage.path;
  }
}