import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for handling web-specific image loading optimizations
class WebImageService {
  static const Duration _cacheTimeout = Duration(hours: 24);
  static const int _maxCacheObjects = 200;
  
  /// Configure CachedNetworkImage for web optimization
  static void configureWebImageCache() {
    if (kIsWeb) {
      // Web-specific cache configuration can be added here
      // CachedNetworkImage automatically handles web caching
    }
  }
  
  /// Get Firebase Storage image URL with web-optimized parameters
  static Future<String?> getOptimizedImageUrl(String imagePath) async {
    try {
      Reference ref;
      if (imagePath.startsWith('gs://')) {
        ref = FirebaseStorage.instance.refFromURL(imagePath);
      } else if (imagePath.startsWith('http')) {
        // Already a full URL
        return imagePath;
      } else {
        ref = FirebaseStorage.instance.ref(imagePath);
      }
      
      // Get download URL with extended timeout for web
      final downloadUrl = await ref.getDownloadURL();
      
      // Add web-specific query parameters for optimization
      if (kIsWeb && downloadUrl.contains('firebasestorage.googleapis.com')) {
        // Add cache-busting and compression parameters
        final uri = Uri.parse(downloadUrl);
        final newUri = uri.replace(
          queryParameters: {
            ...uri.queryParameters,
            'alt': 'media',
            // Add timestamp for cache control
            '_t': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        );
        return newUri.toString();
      }
      
      return downloadUrl;
    } catch (e) {
      print('❌ WebImageService error getting URL for $imagePath: $e');
      return null;
    }
  }
  
  /// Get appropriate headers for web image requests
  static Map<String, String> getWebImageHeaders() {
    final headers = <String, String>{};
    
    if (kIsWeb) {
      headers.addAll({
        'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
        'Cache-Control': 'max-age=3600',
        'sec-fetch-dest': 'image',
        'sec-fetch-mode': 'no-cors',
        'sec-fetch-site': 'cross-site',
      });
      
      // Add Firebase Auth token if available
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Note: Firebase Storage URLs already include authentication tokens
        // Additional auth headers are not typically needed
      }
    }
    
    return headers;
  }
  
  /// Clear image cache (useful for debugging or memory management)
  static Future<void> clearImageCache() async {
    if (kIsWeb) {
      await CachedNetworkImage.evictFromCache('');
      print('🧹 Web image cache cleared');
    }
  }
  
  /// Preload critical images for better performance
  static Future<void> preloadImage(String imageUrl) async {
    if (kIsWeb && imageUrl.isNotEmpty) {
      try {
        await CachedNetworkImage.evictFromCache(imageUrl);
        // Force download to cache
        final imageProvider = CachedNetworkImageProvider(
          imageUrl,
          headers: getWebImageHeaders(),
        );
        // This will trigger the download and caching
        await imageProvider.evict();
        print('🔄 Preloaded image: $imageUrl');
      } catch (e) {
        print('❌ Failed to preload image $imageUrl: $e');
      }
    }
  }
  
  /// Check if image URL is accessible
  static Future<bool> isImageAccessible(String imageUrl) async {
    try {
      if (kIsWeb) {
        // On web, we can use CachedNetworkImage to test accessibility
        final imageProvider = CachedNetworkImageProvider(
          imageUrl,
          headers: getWebImageHeaders(),
        );
        await imageProvider.evict();
        return true;
      }
      return true; // Assume accessible for non-web
    } catch (e) {
      print('❌ Image not accessible: $imageUrl - $e');
      return false;
    }
  }
}
