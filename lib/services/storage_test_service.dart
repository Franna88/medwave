import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Test service to diagnose Firebase Storage connectivity and permissions
class StorageTestService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Test basic storage connectivity and authentication
  static Future<Map<String, dynamic>> runStorageConnectivityTest() async {
    final testResults = <String, dynamic>{};
    
    try {
      // Test 1: Check authentication
      final user = _auth.currentUser;
      testResults['authentication'] = {
        'status': user != null ? 'SUCCESS' : 'FAILED',
        'userId': user?.uid,
        'email': user?.email,
        'isAnonymous': user?.isAnonymous,
      };
      
      // Test 2: Check storage bucket configuration
      try {
        final bucket = _storage.bucket;
        testResults['bucket_config'] = {
          'status': 'SUCCESS',
          'bucket': bucket,
        };
      } catch (e) {
        testResults['bucket_config'] = {
          'status': 'FAILED',
          'error': e.toString(),
        };
      }
      
      // Test 3: Try to list files (read permission test)
      try {
        final listResult = await _storage.ref().list(const ListOptions(maxResults: 1));
        testResults['read_permission'] = {
          'status': 'SUCCESS',
          'items_found': listResult.items.length,
          'prefixes_found': listResult.prefixes.length,
        };
      } catch (e) {
        testResults['read_permission'] = {
          'status': 'FAILED',
          'error': e.toString(),
        };
      }
      
      // Test 4: Try a minimal upload (write permission test)
      if (user != null) {
        try {
          final testData = Uint8List.fromList('TEST'.codeUnits);
          final fileName = 'test_${DateTime.now().millisecondsSinceEpoch}.txt';
          final testRef = _storage.ref().child('connectivity_test/$fileName');
          
          final uploadTask = testRef.putData(testData);
          final snapshot = await uploadTask;
          final downloadUrl = await snapshot.ref.getDownloadURL();
          
          testResults['write_permission'] = {
            'status': 'SUCCESS',
            'download_url': downloadUrl,
            'file_path': 'connectivity_test/$fileName',
          };
          
          // Test 5: Try to download the uploaded file
          try {
            final downloadedData = await testRef.getData();
            final downloadedText = String.fromCharCodes(downloadedData!);
            
            testResults['download_test'] = {
              'status': downloadedText == 'TEST' ? 'SUCCESS' : 'FAILED',
              'downloaded_content': downloadedText,
            };
            
            // Clean up test file
            await testRef.delete();
          } catch (downloadError) {
            testResults['download_test'] = {
              'status': 'FAILED',
              'error': downloadError.toString(),
            };
          }
          
        } catch (uploadError) {
          testResults['write_permission'] = {
            'status': 'FAILED',
            'error': uploadError.toString(),
          };
        }
      } else {
        testResults['write_permission'] = {
          'status': 'SKIPPED',
          'reason': 'User not authenticated',
        };
      }
      
      // Test 6: Check specific paths used by the app
      final pathTests = ['patients', 'signatures', 'sessions'];
      final pathResults = <String, dynamic>{};
      
      for (final path in pathTests) {
        try {
          final listResult = await _storage.ref().child(path).list(const ListOptions(maxResults: 1));
          pathResults[path] = {
            'status': 'SUCCESS',
            'items': listResult.items.length,
            'prefixes': listResult.prefixes.length,
          };
        } catch (e) {
          pathResults[path] = {
            'status': 'FAILED',
            'error': e.toString(),
          };
        }
      }
      
      testResults['path_access'] = pathResults;
      
    } catch (e) {
      testResults['general_error'] = e.toString();
    }
    
    return testResults;
  }

  /// Test image upload specifically
  static Future<Map<String, dynamic>> testImageUpload(Uint8List imageBytes, String testPath) async {
    final testResults = <String, dynamic>{};
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        testResults['status'] = 'FAILED';
        testResults['error'] = 'User not authenticated';
        return testResults;
      }
      
      final fileName = 'test_image_${DateTime.now().millisecondsSinceEpoch}.png';
      final storageRef = _storage.ref().child('$testPath/$fileName');
      
      // Try upload with metadata
      try {
        final uploadTask = storageRef.putData(
          imageBytes,
          SettableMetadata(contentType: 'image/png'),
        );
        
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        
        testResults['status'] = 'SUCCESS';
        testResults['download_url'] = downloadUrl;
        testResults['file_path'] = '$testPath/$fileName';
        testResults['upload_method'] = 'with_metadata';
        
        // Clean up
        await storageRef.delete();
        
      } catch (metadataError) {
        // Try without metadata
        try {
          final uploadTask = storageRef.putData(imageBytes);
          
          final snapshot = await uploadTask;
          final downloadUrl = await snapshot.ref.getDownloadURL();
          
          testResults['status'] = 'SUCCESS';
          testResults['download_url'] = downloadUrl;
          testResults['file_path'] = '$testPath/$fileName';
          testResults['upload_method'] = 'no_metadata';
          testResults['metadata_error'] = metadataError.toString();
          
          // Clean up
          await storageRef.delete();
          
        } catch (fallbackError) {
          testResults['status'] = 'FAILED';
          testResults['metadata_error'] = metadataError.toString();
          testResults['fallback_error'] = fallbackError.toString();
        }
      }
      
    } catch (e) {
      testResults['status'] = 'FAILED';
      testResults['error'] = e.toString();
    }
    
    return testResults;
  }

  /// Print comprehensive test results
  static void printTestResults(Map<String, dynamic> results) {
    print('\n🔍 === FIREBASE STORAGE DIAGNOSTIC REPORT ===');
    
    results.forEach((key, value) {
      print('\n📋 $key:');
      if (value is Map) {
        value.forEach((subKey, subValue) {
          print('  $subKey: $subValue');
        });
      } else {
        print('  $value');
      }
    });
    
    print('\n🔍 === END DIAGNOSTIC REPORT ===\n');
  }
}

