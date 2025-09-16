import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/enhanced_storage_service.dart';

/// A widget that properly loads images from Firebase Storage with robust error handling
class FirebaseImage extends StatefulWidget {
  final String imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;
  final Widget? loadingWidget;

  const FirebaseImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
    this.loadingWidget,
  });

  @override
  State<FirebaseImage> createState() => _FirebaseImageState();
}

class _FirebaseImageState extends State<FirebaseImage> {
  String? _downloadUrl;
  Uint8List? _imageData;
  bool _isLoading = true;
  String? _error;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Try different loading strategies
      await _tryLoadingStrategies();
    } catch (e) {
      print('❌ FirebaseImage error loading ${widget.imagePath}: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _tryLoadingStrategies() async {
    // Strategy 1: Direct URL (if already a full URL)
    if (widget.imagePath.startsWith('http')) {
      await _loadFromDirectUrl();
      return;
    }

    // Strategy 2: Firebase Storage path
    try {
      await _loadFromFirebaseStorage();
    } catch (e) {
      print('🔄 Firebase Storage failed, trying fallback strategy: $e');
      
      // Strategy 3: Retry with fresh authentication
      if (_retryCount < _maxRetries) {
        _retryCount++;
        await _refreshAuthAndRetry();
      } else {
        throw e;
      }
    }
  }

  Future<void> _loadFromDirectUrl() async {
    setState(() {
      _downloadUrl = widget.imagePath;
      _isLoading = false;
    });
  }

  Future<void> _loadFromFirebaseStorage() async {
    // Use enhanced storage service with multiple fallback strategies
    try {
      final downloadUrl = await EnhancedStorageService.getImageUrlWithFallback(widget.imagePath);
      if (downloadUrl != null) {
        setState(() {
          _downloadUrl = downloadUrl;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      print('🔄 Enhanced URL loading failed, trying direct data: $e');
    }
    
    // Fallback to direct data download
    Reference ref;
    if (widget.imagePath.startsWith('gs://')) {
      ref = FirebaseStorage.instance.refFromURL(widget.imagePath);
    } else {
      ref = FirebaseStorage.instance.ref(widget.imagePath);
    }

    try {
      final data = await ref.getData();
      if (data != null) {
        setState(() {
          _imageData = data;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load image data');
      }
    } catch (e) {
      throw Exception('All loading strategies failed: $e');
    }
  }

  Future<void> _refreshAuthAndRetry() async {
    try {
      // Force refresh the authentication token
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.getIdToken(true); // Force refresh
        print('🔄 Refreshed auth token, retrying...');
        
        // Wait a bit before retrying
        await Future.delayed(Duration(milliseconds: 500 * _retryCount));
        
        await _loadFromFirebaseStorage();
      } else {
        throw Exception('User not authenticated');
      }
    } catch (e) {
      print('❌ Auth refresh failed: $e');
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryColor,
              ),
            ),
          );
    }

    if (_error != null || (_downloadUrl == null && _imageData == null)) {
      return widget.errorWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.broken_image,
                  color: AppTheme.errorColor,
                  size: 40,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.errorColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          );
    }

    // If we have direct image data, use it
    if (_imageData != null) {
      return Image.memory(
        _imageData!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Memory image error: $error');
          return _buildErrorWidget();
        },
      );
    }

    // Check if it's a local file or network image
    if (_downloadUrl != null && !_downloadUrl!.startsWith('http')) {
      return Image.file(
        File(_downloadUrl!),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget();
        },
      );
    }

    // Network image with robust error handling
    return Image.network(
      _downloadUrl!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      headers: _buildHeaders(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return widget.loadingWidget ??
            Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        print('❌ Network image error for $_downloadUrl: $error');
        
        // If this is an HTTP 412 error and we haven't retried too much, try again
        if (error.toString().contains('412') && _retryCount < _maxRetries) {
          _retryCount++;
          print('🔄 HTTP 412 detected, retrying in ${_retryCount}s...');
          Future.delayed(Duration(seconds: _retryCount), () {
            if (mounted) {
              _loadImage();
            }
          });
        }
        
        return _buildErrorWidget();
      },
    );
  }

  Map<String, String> _buildHeaders() {
    return {
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0',
    };
  }

  Widget _buildErrorWidget() {
    return widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.broken_image,
                color: AppTheme.errorColor,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                _retryCount > 0 ? 'Retrying...' : 'Network error',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.errorColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
  }
}