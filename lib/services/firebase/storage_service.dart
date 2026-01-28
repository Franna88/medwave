import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Firebase Storage service for file uploads
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload waybill photo to Firebase Storage
  /// Returns the download URL of the uploaded image
  Future<String> uploadWaybillPhoto({
    required String orderId,
    required XFile imageFile,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'waybill_$timestamp.jpg';
      final storagePath = 'waybills/$orderId/$fileName';

      final ref = _storage.ref(storagePath);

      // Set metadata for the image
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'orderId': orderId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'waybill',
        },
      );

      // Upload based on platform
      UploadTask uploadTask;
      if (kIsWeb) {
        // For web, read as bytes
        final bytes = await imageFile.readAsBytes();
        uploadTask = ref.putData(bytes, metadata);
      } else {
        // For mobile, use file
        final file = File(imageFile.path);
        uploadTask = ref.putFile(file, metadata);
      }

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        if (kDebugMode) {
          debugPrint('Upload progress: ${progress.toStringAsFixed(1)}%');
        }
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (kDebugMode) {
        debugPrint('Waybill photo uploaded: $downloadUrl');
      }

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error uploading waybill photo: $e');
      }
      rethrow;
    }
  }

  /// Upload proof of installation photo to Firebase Storage
  /// Returns the download URL of the uploaded image
  Future<String> uploadInstallationPhoto({
    required String orderId,
    required XFile imageFile,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'proof_$timestamp.jpg';
      final storagePath = 'installations/$orderId/$fileName';

      final ref = _storage.ref(storagePath);

      // Set metadata for the image
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'orderId': orderId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'installation_proof',
        },
      );

      // Upload based on platform
      UploadTask uploadTask;
      if (kIsWeb) {
        // For web, read as bytes
        final bytes = await imageFile.readAsBytes();
        uploadTask = ref.putData(bytes, metadata);
      } else {
        // For mobile, use file
        final file = File(imageFile.path);
        uploadTask = ref.putFile(file, metadata);
      }

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        if (kDebugMode) {
          debugPrint(
            'Installation photo upload progress: ${progress.toStringAsFixed(1)}%',
          );
        }
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (kDebugMode) {
        debugPrint('Installation photo uploaded: $downloadUrl');
      }

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error uploading installation photo: $e');
      }
      rethrow;
    }
  }

  /// Upload deposit proof of payment to Firebase Storage
  /// Returns the download URL of the uploaded file (image or PDF)
  Future<String> uploadDepositProof({
    required String appointmentId,
    required XFile imageFile,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Determine file extension and content type
      final String fileExtension;
      final String contentType;
      final fileName = imageFile.name.toLowerCase();
      
      if (fileName.endsWith('.pdf')) {
        fileExtension = 'pdf';
        contentType = 'application/pdf';
      } else if (fileName.endsWith('.png')) {
        fileExtension = 'png';
        contentType = 'image/png';
      } else if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
        fileExtension = 'jpg';
        contentType = 'image/jpeg';
      } else {
        // Default to jpeg for images
        fileExtension = 'jpg';
        contentType = 'image/jpeg';
      }
      
      final storageFileName = 'proof_$timestamp.$fileExtension';
      final storagePath = 'deposit_proofs/$appointmentId/$storageFileName';

      final ref = _storage.ref(storagePath);

      // Set metadata for the file
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'appointmentId': appointmentId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'deposit_proof',
        },
      );

      // Upload based on platform
      UploadTask uploadTask;
      if (kIsWeb) {
        // For web, read as bytes
        final bytes = await imageFile.readAsBytes();
        uploadTask = ref.putData(bytes, metadata);
      } else {
        // For mobile, use file
        final file = File(imageFile.path);
        uploadTask = ref.putFile(file, metadata);
      }

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        if (kDebugMode) {
          debugPrint(
            'Deposit proof upload progress: ${progress.toStringAsFixed(1)}%',
          );
        }
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (kDebugMode) {
        debugPrint('Deposit proof uploaded: $downloadUrl');
      }

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error uploading deposit proof: $e');
      }
      rethrow;
    }
  }

  /// Upload customer-submitted deposit proof to Firebase Storage
  /// Stores in separate folder to distinguish from sales-uploaded proofs
  Future<String> uploadCustomerDepositProof({
    required String appointmentId,
    required Uint8List fileData,
    required String fileName,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Determine file extension and content type
      final String fileExtension;
      final String contentType;
      final lowerFileName = fileName.toLowerCase();
      
      if (lowerFileName.endsWith('.pdf')) {
        fileExtension = 'pdf';
        contentType = 'application/pdf';
      } else if (lowerFileName.endsWith('.png')) {
        fileExtension = 'png';
        contentType = 'image/png';
      } else if (lowerFileName.endsWith('.jpg') || lowerFileName.endsWith('.jpeg')) {
        fileExtension = 'jpg';
        contentType = 'image/jpeg';
      } else {
        // Default to jpeg for images
        fileExtension = 'jpg';
        contentType = 'image/jpeg';
      }
      
      final storageFileName = 'proof_$timestamp.$fileExtension';
      final storagePath = 'customer_deposit_proofs/$appointmentId/$storageFileName';

      final ref = _storage.ref(storagePath);

      // Set metadata for the file
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'appointmentId': appointmentId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'customer_deposit_proof',
        },
      );

      // Upload bytes (works for both web and mobile)
      final uploadTask = ref.putData(fileData, metadata);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        if (kDebugMode) {
          debugPrint(
            'Customer deposit proof upload progress: ${progress.toStringAsFixed(1)}%',
          );
        }
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (kDebugMode) {
        debugPrint('Customer deposit proof uploaded: $downloadUrl');
      }

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error uploading customer deposit proof: $e');
      }
      rethrow;
    }
  }

  /// Upload customer-submitted final payment proof to Firebase Storage
  /// Stores in separate folder to distinguish from operations-uploaded proofs
  Future<String> uploadCustomerFinalPaymentProof({
    required String orderId,
    required Uint8List fileData,
    required String fileName,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Determine file extension and content type
      final String fileExtension;
      final String contentType;
      final lowerFileName = fileName.toLowerCase();
      
      if (lowerFileName.endsWith('.pdf')) {
        fileExtension = 'pdf';
        contentType = 'application/pdf';
      } else if (lowerFileName.endsWith('.png')) {
        fileExtension = 'png';
        contentType = 'image/png';
      } else if (lowerFileName.endsWith('.jpg') || lowerFileName.endsWith('.jpeg')) {
        fileExtension = 'jpg';
        contentType = 'image/jpeg';
      } else {
        // Default to jpeg for images
        fileExtension = 'jpg';
        contentType = 'image/jpeg';
      }
      
      final storageFileName = 'proof_$timestamp.$fileExtension';
      final storagePath = 'customer_final_payment_proofs/$orderId/$storageFileName';

      final ref = _storage.ref(storagePath);

      // Set metadata for the file
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'orderId': orderId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'customer_final_payment_proof',
        },
      );

      // Upload bytes (works for both web and mobile)
      final uploadTask = ref.putData(fileData, metadata);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        if (kDebugMode) {
          debugPrint(
            'Customer final payment proof upload progress: ${progress.toStringAsFixed(1)}%',
          );
        }
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (kDebugMode) {
        debugPrint('Customer final payment proof uploaded: $downloadUrl');
      }

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error uploading customer final payment proof: $e');
      }
      rethrow;
    }
  }

  /// Upload final payment proof by operations team to Firebase Storage
  /// Returns the download URL of the uploaded file
  Future<String> uploadFinalPaymentProof({
    required String orderId,
    required Uint8List fileData,
    required String fileName,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Determine file extension and content type
      final String fileExtension;
      final String contentType;
      final lowerFileName = fileName.toLowerCase();
      
      if (lowerFileName.endsWith('.pdf')) {
        fileExtension = 'pdf';
        contentType = 'application/pdf';
      } else if (lowerFileName.endsWith('.png')) {
        fileExtension = 'png';
        contentType = 'image/png';
      } else if (lowerFileName.endsWith('.jpg') || lowerFileName.endsWith('.jpeg')) {
        fileExtension = 'jpg';
        contentType = 'image/jpeg';
      } else {
        // Default to jpeg for images
        fileExtension = 'jpg';
        contentType = 'image/jpeg';
      }
      
      final storageFileName = 'proof_$timestamp.$fileExtension';
      final storagePath = 'final_payment_proofs/$orderId/$storageFileName';

      final ref = _storage.ref(storagePath);

      // Set metadata for the file
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'orderId': orderId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'final_payment_proof',
        },
      );

      // Upload bytes (works for both web and mobile)
      final uploadTask = ref.putData(fileData, metadata);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        if (kDebugMode) {
          debugPrint(
            'Final payment proof upload progress: ${progress.toStringAsFixed(1)}%',
          );
        }
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (kDebugMode) {
        debugPrint('Final payment proof uploaded: $downloadUrl');
      }

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error uploading final payment proof: $e');
      }
      rethrow;
    }
  }

  /// Upload customer signature photo to Firebase Storage
  /// Returns the download URL of the uploaded image
  Future<String> uploadCustomerSignature({
    required String orderId,
    required XFile imageFile,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'signature_$timestamp.jpg';
      final storagePath = 'installations/$orderId/$fileName';

      final ref = _storage.ref(storagePath);

      // Set metadata for the image
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'orderId': orderId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'customer_signature',
        },
      );

      // Upload based on platform
      UploadTask uploadTask;
      if (kIsWeb) {
        // For web, read as bytes
        final bytes = await imageFile.readAsBytes();
        uploadTask = ref.putData(bytes, metadata);
      } else {
        // For mobile, use file
        final file = File(imageFile.path);
        uploadTask = ref.putFile(file, metadata);
      }

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        if (kDebugMode) {
          debugPrint(
            'Customer signature upload progress: ${progress.toStringAsFixed(1)}%',
          );
        }
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (kDebugMode) {
        debugPrint('Customer signature uploaded: $downloadUrl');
      }

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error uploading customer signature: $e');
      }
      rethrow;
    }
  }

  /// Upload any image to Firebase Storage
  Future<String> uploadImage({
    required String path,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
    Map<String, String>? customMetadata,
  }) async {
    try {
      final ref = _storage.ref(path);

      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: customMetadata,
      );

      final snapshot = await ref.putData(bytes, metadata);
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (kDebugMode) {
        debugPrint('Image uploaded to: $path');
      }

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error uploading image: $e');
      }
      rethrow;
    }
  }

  /// Delete a file from Firebase Storage
  Future<void> deleteFile(String path) async {
    try {
      final ref = _storage.ref(path);
      await ref.delete();

      if (kDebugMode) {
        debugPrint('File deleted: $path');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting file: $e');
      }
      rethrow;
    }
  }

  /// Get download URL for a file
  Future<String?> getDownloadUrl(String path) async {
    try {
      final ref = _storage.ref(path);
      return await ref.getDownloadURL();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting download URL: $e');
      }
      return null;
    }
  }

  /// Check if a file exists
  Future<bool> fileExists(String path) async {
    try {
      final ref = _storage.ref(path);
      await ref.getMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }
}
