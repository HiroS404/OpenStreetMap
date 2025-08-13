import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<String?> uploadImageToCloudinary(
  FilePickerResult? filePickerResult,
) async {
  if (filePickerResult == null || filePickerResult.files.isEmpty) {
    print('No file selected');
    return null;
  }

  String cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  String uploadPreset = dotenv.env['CLOUDINARY_PRESET_NAME'] ?? '';

  var uri = Uri.parse(
    'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
  );
  var request = http.MultipartRequest('POST', uri);

  // Get bytes depending on platform
  Uint8List fileBytes;
  String fileName = filePickerResult.files.single.name;

  if (kIsWeb) {
    fileBytes = filePickerResult.files.single.bytes!;
  } else {
    File file = File(filePickerResult.files.single.path!);
    fileBytes = await file.readAsBytes();
  }

  var multipartFile = http.MultipartFile.fromBytes(
    'file',
    fileBytes,
    filename: fileName,
  );
  request.files.add(multipartFile);

  // Required fields
  request.fields['upload_preset'] = uploadPreset;

  // Send request
  var response = await request.send();
  var responseBody = await response.stream.bytesToString();

  if (response.statusCode == 200) {
    var data = jsonDecode(responseBody);
    String imageUrl = data['secure_url'];
    print('Uploaded image URL: $imageUrl');
    return imageUrl; // Save this to Firestore
  } else {
    print('Upload failed: ${response.statusCode} - $responseBody');
    return null;
  }
}
