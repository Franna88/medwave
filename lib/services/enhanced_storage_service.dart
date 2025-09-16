import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Enhanced Firebase Storage service with comprehensive HTTP 412 error handling
class EnhancedStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Test Firebase Storage connectivity with enhanced diagnostics
  static Future<Map<String, dynamic>> runComprehensiveStorageTest() async {
    final results = <String, dynamic>{};
    
    try {
      print('🔍 === ENHANCED FIREBASE STORAGE DIAGNOSTIC ===');
      
      // 1. Authentication Check
      final authResult = await _testAuthentication();
      results['authentication'] = authResult;
      print('📋 Authentication: ${authResult['status']}');
      
      // 2. Token Freshness Check
      final tokenResult = await _testTokenFreshness();
      results['token_freshness'] = tokenResult;
      print('📋 Token Freshness: ${tokenResult['status']}');
      
      // 3. Bucket Access Test
      final bucketResult = await _testBucketAccess();
      results['bucket_access'] = bucketResult;
      print('📋 Bucket Access: ${bucketResult['status']}');
      
      // 4. CORS Test
      final corsResult = await _testCorsConfiguration();
      results['cors_config'] = corsResult;
      print('📋 CORS Config: ${corsResult['status']}');
      
      // 5. Service Account Test
      final serviceAccountResult = await _testServiceAccountPermissions();
      results['service_account'] = serviceAccountResult;
      print('📋 Service Account: ${serviceAccountResult['status']}');
      
      // 6. Direct Upload Test with Multiple Strategies
      final uploadResult = await _testMultipleUploadStrategies();
      results['upload_strategies'] = uploadResult;
      print('📋 Upload Strategies: ${uploadResult['status']}');
      
      print('🔍 === END ENHANCED DIAGNOSTIC ===');
      
    } catch (e) {
      print('❌ Enhanced diagnostic failed: $e');
      results['error'] = e.toString();
    }
    
    return results;
  }
  
  static Future<Map<String, dynamic>> _testAuthentication() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'status': 'FAILED', 'error': 'No authenticated user'};
      }
      
      return {
        'status': 'SUCCESS',
        'uid': user.uid,
        'email': user.email,
        'isAnonymous': user.isAnonymous,
        'emailVerified': user.emailVerified,
      };
    } catch (e) {
      return {'status': 'FAILED', 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _testTokenFreshness() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'status': 'FAILED', 'error': 'No user to test token'};
      }
      
      // Get current token
      final oldToken = await user.getIdToken();
      print('🔑 Current token length: ${oldToken?.length ?? 0}');
      
      // Force refresh token
      final newToken = await user.getIdToken(true);
      print('🔑 Refreshed token length: ${newToken?.length ?? 0}');
      
      if (oldToken == null || newToken == null) {
        return {'status': 'FAILED', 'error': 'Failed to get tokens'};
      }
      
      final tokenChanged = oldToken != newToken;
      
      return {
        'status': 'SUCCESS',
        'token_refreshed': tokenChanged,
        'old_token_preview': oldToken.length > 20 ? oldToken.substring(0, 20) + '...' : oldToken,
        'new_token_preview': newToken.length > 20 ? newToken.substring(0, 20) + '...' : newToken,
      };
    } catch (e) {
      return {'status': 'FAILED', 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _testBucketAccess() async {
    try {
      // Test basic bucket listing
      final ref = _storage.ref();
      final listResult = await ref.listAll();
      
      return {
        'status': 'SUCCESS',
        'items_found': listResult.items.length,
        'prefixes_found': listResult.prefixes.length,
        'bucket_name': _storage.bucket,
      };
    } catch (e) {
      return {'status': 'FAILED', 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _testCorsConfiguration() async {
    try {
      // Test CORS by making a direct HTTP request to the bucket
      final bucketUrl = 'https://firebasestorage.googleapis.com/v0/b/${_storage.bucket}/o';
      
      final response = await http.get(
        Uri.parse(bucketUrl),
        headers: {
          'Origin': 'https://localhost',
          'Access-Control-Request-Method': 'GET',
        },
      );
      
      final corsHeaders = response.headers.keys
          .where((key) => key.toLowerCase().startsWith('access-control'))
          .toList();
      
      return {
        'status': response.statusCode == 200 ? 'SUCCESS' : 'FAILED',
        'status_code': response.statusCode,
        'cors_headers': corsHeaders,
        'has_cors_headers': corsHeaders.isNotEmpty,
      };
    } catch (e) {
      return {'status': 'FAILED', 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _testServiceAccountPermissions() async {
    try {
      // Test creating a reference to a test path
      final testRef = _storage.ref('test-permissions/${DateTime.now().millisecondsSinceEpoch}');
      
      // Try to get metadata (this tests read permissions)
      try {
        await testRef.getMetadata();
      } catch (e) {
        // File doesn't exist, which is expected
        if (!e.toString().contains('object-not-found')) {
          return {'status': 'FAILED', 'error': 'Read permission denied: $e'};
        }
      }
      
      // Try to create a small test file (this tests write permissions)
      try {
        final testData = Uint8List.fromList('test'.codeUnits);
        await testRef.putData(testData);
        
        // Clean up test file
        await testRef.delete();
        
        return {'status': 'SUCCESS', 'permissions': 'read_write'};
      } catch (e) {
        if (e.toString().contains('412')) {
          return {
            'status': 'FAILED',
            'error': 'HTTP 412 - Service account lacks permissions',
            'suggested_action': 'Check IAM roles for service account',
          };
        }
        return {'status': 'FAILED', 'error': e.toString()};
      }
    } catch (e) {
      return {'status': 'FAILED', 'error': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> _testMultipleUploadStrategies() async {
    final strategies = <String, dynamic>{};
    final testData = Uint8List.fromList('test-upload-${DateTime.now().millisecondsSinceEpoch}'.codeUnits);
    
    // Strategy 1: Standard putData
    try {
      final ref1 = _storage.ref('test-strategies/standard-${DateTime.now().millisecondsSinceEpoch}');
      await ref1.putData(testData);
      await ref1.delete();
      strategies['standard_upload'] = {'status': 'SUCCESS'};
    } catch (e) {
      strategies['standard_upload'] = {'status': 'FAILED', 'error': e.toString()};
    }
    
    // Strategy 2: Upload with metadata
    try {
      final ref2 = _storage.ref('test-strategies/metadata-${DateTime.now().millisecondsSinceEpoch}');
      final metadata = SettableMetadata(
        contentType: 'text/plain',
        customMetadata: {
          'test': 'true',
          'strategy': 'metadata',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      await ref2.putData(testData, metadata);
      await ref2.delete();
      strategies['metadata_upload'] = {'status': 'SUCCESS'};
    } catch (e) {
      strategies['metadata_upload'] = {'status': 'FAILED', 'error': e.toString()};
    }
    
    // Strategy 3: Upload with cache control
    try {
      final ref3 = _storage.ref('test-strategies/cache-${DateTime.now().millisecondsSinceEpoch}');
      final metadata = SettableMetadata(
        cacheControl: 'no-cache, no-store, must-revalidate',
        contentType: 'text/plain',
      );
      await ref3.putData(testData, metadata);
      await ref3.delete();
      strategies['cache_control_upload'] = {'status': 'SUCCESS'};
    } catch (e) {
      strategies['cache_control_upload'] = {'status': 'FAILED', 'error': e.toString()};
    }
    
    final successCount = strategies.values.where((s) => s['status'] == 'SUCCESS').length;
    final totalCount = strategies.length;
    
    return {
      'status': successCount > 0 ? 'PARTIAL_SUCCESS' : 'FAILED',
      'successful_strategies': '$successCount/$totalCount',
      'strategies': strategies,
    };
  }
  
  /// Enhanced image loading with multiple fallback strategies
  static Future<String?> getImageUrlWithFallback(String imagePath) async {
    final strategies = [
      () => _getUrlDirectly(imagePath),
      () => _getUrlWithFreshToken(imagePath),
      () => _getUrlWithMetadata(imagePath),
      () => _getUrlWithCacheBypass(imagePath),
    ];
    
    for (int i = 0; i < strategies.length; i++) {
      try {
        print('🔄 Trying image URL strategy ${i + 1}/${strategies.length}');
        final url = await strategies[i]();
        if (url != null) {
          print('✅ Strategy ${i + 1} succeeded');
          return url;
        }
      } catch (e) {
        print('❌ Strategy ${i + 1} failed: $e');
        if (i == strategies.length - 1) {
          // Last strategy failed
          rethrow;
        }
      }
    }
    
    return null;
  }
  
  static Future<String?> _getUrlDirectly(String imagePath) async {
    final ref = _storage.refFromURL(imagePath);
    return await ref.getDownloadURL();
  }
  
  static Future<String?> _getUrlWithFreshToken(String imagePath) async {
    // Force refresh authentication token
    final user = _auth.currentUser;
    if (user != null) {
      await user.getIdToken(true);
    }
    
    final ref = _storage.refFromURL(imagePath);
    return await ref.getDownloadURL();
  }
  
  static Future<String?> _getUrlWithMetadata(String imagePath) async {
    final ref = _storage.refFromURL(imagePath);
    
    // First get metadata to ensure file exists
    await ref.getMetadata();
    
    // Then get download URL
    return await ref.getDownloadURL();
  }
  
  static Future<String?> _getUrlWithCacheBypass(String imagePath) async {
    final ref = _storage.refFromURL(imagePath);
    final url = await ref.getDownloadURL();
    
    // Add cache-busting parameter
    final uri = Uri.parse(url);
    final newUri = uri.replace(queryParameters: {
      ...uri.queryParameters,
      'cache_bust': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    
    return newUri.toString();
  }
}

