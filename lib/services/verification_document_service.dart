import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

/// Service for handling verification document uploads (ID documents and practice images)
class VerificationDocumentService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery or camera
  Future<XFile?> pickImage({bool fromCamera = false}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  /// Pick multiple images from gallery (one by one)
  /// Note: ImagePicker doesn't support multiple selection on all platforms
  /// So we return a single image wrapped in a list for consistency
  Future<List<XFile>> pickMultipleImages({int maxImages = 10}) async {
    try {
      // Pick single image - user can call this multiple times
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      
      if (image != null) {
        return [image];
      }
      
      return [];
    } catch (e) {
      print('Error picking image: $e');
      return [];
    }
  }

  /// Compress and resize image for documents
  Future<Uint8List?> compressImage(Uint8List imageBytes) async {
    try {
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Resize to max 1024x1024 while maintaining aspect ratio
      // Documents need to be clear and readable, so we keep higher resolution
      img.Image resized = img.copyResize(
        image,
        width: image.width > image.height ? 1024 : null,
        height: image.height >= image.width ? 1024 : null,
      );

      // Compress as JPEG with 85% quality
      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  /// Upload ID documents to Firebase Storage
  Future<List<String>> uploadIdDocuments(String userId, List<XFile> imageFiles) async {
    List<String> uploadedUrls = [];
    
    try {
      for (int i = 0; i < imageFiles.length; i++) {
        final imageFile = imageFiles[i];
        
        // Read image bytes
        final Uint8List imageBytes = await imageFile.readAsBytes();

        // Compress image
        final Uint8List? compressedBytes = await compressImage(imageBytes);
        if (compressedBytes == null) {
          print('⚠️ Failed to compress image ${i + 1}, skipping');
          continue;
        }

        // Create storage reference
        final String fileName = 'id_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final Reference storageRef = _storage.ref().child('practitioners/$userId/verification/id/$fileName');

        // Upload file
        UploadTask uploadTask;
        if (kIsWeb) {
          uploadTask = storageRef.putData(
            compressedBytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
        } else {
          // For mobile/desktop, write to temporary file first
          final File tempFile = File('${imageFile.path}_compressed.jpg');
          await tempFile.writeAsBytes(compressedBytes);
          uploadTask = storageRef.putFile(
            tempFile,
            SettableMetadata(contentType: 'image/jpeg'),
          );
        }

        // Wait for upload to complete
        final TaskSnapshot snapshot = await uploadTask;

        // Get download URL
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        uploadedUrls.add(downloadUrl);
        
        print('✅ ID document ${i + 1} uploaded: $downloadUrl');
      }

      return uploadedUrls;
    } catch (e) {
      print('❌ Error uploading ID documents: $e');
      return uploadedUrls; // Return whatever we successfully uploaded
    }
  }

  /// Upload practice images to Firebase Storage
  Future<List<String>> uploadPracticeImages(String userId, List<XFile> imageFiles) async {
    List<String> uploadedUrls = [];
    
    try {
      for (int i = 0; i < imageFiles.length; i++) {
        final imageFile = imageFiles[i];
        
        // Read image bytes
        final Uint8List imageBytes = await imageFile.readAsBytes();

        // Compress image
        final Uint8List? compressedBytes = await compressImage(imageBytes);
        if (compressedBytes == null) {
          print('⚠️ Failed to compress image ${i + 1}, skipping');
          continue;
        }

        // Create storage reference
        final String fileName = 'practice_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final Reference storageRef = _storage.ref().child('practitioners/$userId/verification/practice/$fileName');

        // Upload file
        UploadTask uploadTask;
        if (kIsWeb) {
          uploadTask = storageRef.putData(
            compressedBytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
        } else {
          // For mobile/desktop, write to temporary file first
          final File tempFile = File('${imageFile.path}_compressed.jpg');
          await tempFile.writeAsBytes(compressedBytes);
          uploadTask = storageRef.putFile(
            tempFile,
            SettableMetadata(contentType: 'image/jpeg'),
          );
        }

        // Wait for upload to complete
        final TaskSnapshot snapshot = await uploadTask;

        // Get download URL
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        uploadedUrls.add(downloadUrl);
        
        print('✅ Practice image ${i + 1} uploaded: $downloadUrl');
      }

      return uploadedUrls;
    } catch (e) {
      print('❌ Error uploading practice images: $e');
      return uploadedUrls; // Return whatever we successfully uploaded
    }
  }

  /// Update user profile with verification document URLs
  Future<bool> updateVerificationDocuments(
    String userId,
    List<String> idDocumentUrls,
    List<String> practiceImageUrls,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'idDocumentUrls': idDocumentUrls,
        'practiceImageUrls': practiceImageUrls,
        'idDocumentUploadedAt': idDocumentUrls.isNotEmpty ? FieldValue.serverTimestamp() : null,
        'practiceImageUploadedAt': practiceImageUrls.isNotEmpty ? FieldValue.serverTimestamp() : null,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('✅ Verification documents updated in Firestore');
      return true;
    } catch (e) {
      print('❌ Error updating verification documents: $e');
      return false;
    }
  }

  /// Delete verification documents from storage
  Future<void> deleteDocuments(List<String> documentUrls) async {
    for (final url in documentUrls) {
      try {
        if (url.isEmpty) continue;

        // Delete from storage
        final Reference ref = _storage.refFromURL(url);
        await ref.delete();

        print('✅ Document deleted: $url');
      } catch (e) {
        print('⚠️ Could not delete document: $e');
        // Don't throw error - it's okay if document can't be deleted
      }
    }
  }
}

