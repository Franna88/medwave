import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class ProfilePhotoService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery or camera
  Future<XFile?> pickImage({bool fromCamera = false}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  /// Compress and resize image for profile photo
  Future<Uint8List?> compressImage(Uint8List imageBytes) async {
    try {
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Resize to max 512x512 while maintaining aspect ratio
      img.Image resized = img.copyResize(
        image,
        width: image.width > image.height ? 512 : null,
        height: image.height >= image.width ? 512 : null,
      );

      // Compress as JPEG with 85% quality
      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  /// Upload profile photo to Firebase Storage
  Future<String?> uploadProfilePhoto(String userId, XFile imageFile) async {
    try {
      // Read image bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Compress image
      final Uint8List? compressedBytes = await compressImage(imageBytes);
      if (compressedBytes == null) {
        throw Exception('Failed to compress image');
      }

      // Create storage reference
      final String fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = _storage.ref().child('practitioners/$userId/$fileName');

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

      print('✅ Profile photo uploaded: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading profile photo: $e');
      return null;
    }
  }

  /// Update user profile with new photo URL
  Future<bool> updateProfilePhoto(String userId, String photoUrl) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'photoUrl': photoUrl,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('✅ Profile photo URL updated in Firestore');
      return true;
    } catch (e) {
      print('❌ Error updating profile photo URL: $e');
      return false;
    }
  }

  /// Delete old profile photo from storage
  Future<void> deleteOldProfilePhoto(String photoUrl) async {
    try {
      if (photoUrl.isEmpty) return;

      // Extract storage path from URL
      final Uri uri = Uri.parse(photoUrl);
      final String path = uri.pathSegments.last;

      // Delete from storage
      final Reference ref = _storage.refFromURL(photoUrl);
      await ref.delete();

      print('✅ Old profile photo deleted');
    } catch (e) {
      print('⚠️ Could not delete old profile photo: $e');
      // Don't throw error - it's okay if old photo can't be deleted
    }
  }

  /// Complete workflow: pick, upload, and update profile photo
  Future<String?> updateUserProfilePhoto(
    String userId, {
    bool fromCamera = false,
    String? oldPhotoUrl,
  }) async {
    try {
      // Pick image
      final XFile? imageFile = await pickImage(fromCamera: fromCamera);
      if (imageFile == null) {
        print('No image selected');
        return null;
      }

      // Upload to Firebase Storage
      final String? photoUrl = await uploadProfilePhoto(userId, imageFile);
      if (photoUrl == null) {
        throw Exception('Failed to upload photo');
      }

      // Update Firestore
      final bool updated = await updateProfilePhoto(userId, photoUrl);
      if (!updated) {
        throw Exception('Failed to update profile');
      }

      // Delete old photo if exists
      if (oldPhotoUrl != null && oldPhotoUrl.isNotEmpty) {
        await deleteOldProfilePhoto(oldPhotoUrl);
      }

      return photoUrl;
    } catch (e) {
      print('❌ Error in updateUserProfilePhoto: $e');
      return null;
    }
  }
}

