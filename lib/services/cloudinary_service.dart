import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<String?> uploadImageToCloudinary(
  FilePickerResult? filePickerResult,
) async {
  if (filePickerResult == null || filePickerResult.files.isEmpty) {
    return null; // No file selected
  }

  const String cloudName = "dl6d48nzy";
  const String uploadPreset = "mapakaon-preset";

  try {
    final uri = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
    );
    final request = http.MultipartRequest('POST', uri);

    Uint8List fileBytes;
    String fileName = filePickerResult.files.single.name;

    if (kIsWeb) {
      // ✅ Web: file picker already provides bytes
      fileBytes = filePickerResult.files.single.bytes!;
    } else {
      // ✅ Mobile/Desktop: need to read from path
      final path = filePickerResult.files.single.path;
      if (path == null) return null; // safety check
      File file = File(path);
      fileBytes = await file.readAsBytes();
    }

    // Attach file
    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
    );
    request.files.add(multipartFile);

    // Add required preset
    request.fields['upload_preset'] = uploadPreset;

    // Send request
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      return data['secure_url'] as String;
    } else {
      debugPrint(
        "❌ Cloudinary upload failed: ${response.statusCode} - $responseBody",
      );
      return null;
    }
  } catch (e, stack) {
    debugPrint("⚠️ Exception during upload: $e\n$stack");
    return null;
  }
}
