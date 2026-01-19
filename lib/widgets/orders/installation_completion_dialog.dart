import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/streams/order.dart' as models;
import '../../services/firebase/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/role_manager.dart';

/// Dialog for completing installation by uploading proof and signature images
class InstallationCompletionDialog extends StatefulWidget {
  final models.Order order;
  final Function(List<String> proofUrls, String signatureUrl, String? note)
  onComplete;

  const InstallationCompletionDialog({
    super.key,
    required this.order,
    required this.onComplete,
  });

  @override
  State<InstallationCompletionDialog> createState() =>
      _InstallationCompletionDialogState();
}

class _InstallationCompletionDialogState
    extends State<InstallationCompletionDialog> {
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _noteController = TextEditingController();

  // Proof images - support multiple
  final List<XFile> _proofImages = [];
  final List<String> _proofUrls = [];
  final Map<int, bool> _proofUploading = {}; // Track which image is uploading

  // Signature - single image
  XFile? _signatureImage;
  bool _isUploadingSignature = false;
  String? _signatureUrl;

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _adminOverride = false;

  bool get _isAdmin {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final role = authProvider.userRole;
      return role == UserRole.superAdmin ||
          role == UserRole.countryAdmin ||
          role == UserRole.operationsAdmin;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickProofImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final index = _proofImages.length;
        setState(() {
          _proofImages.add(image);
          _proofUrls.add(''); // Placeholder for URL
          _proofUploading[index] = true;
          _errorMessage = null;
        });

        // Automatically upload the image after selection
        await _uploadProofImage(index);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: $e';
      });
    }
  }

  Future<void> _uploadProofImage(int index) async {
    if (index >= _proofImages.length) return;

    setState(() {
      _proofUploading[index] = true;
      _errorMessage = null;
    });

    try {
      final url = await _storageService.uploadInstallationPhoto(
        orderId: widget.order.id,
        imageFile: _proofImages[index],
      );

      setState(() {
        _proofUrls[index] = url;
        _proofUploading[index] = false;
      });
    } catch (e) {
      setState(() {
        _proofUploading[index] = false;
        _errorMessage = 'Error uploading proof image: $e';
      });
    }
  }

  void _removeProofImage(int index) {
    setState(() {
      _proofImages.removeAt(index);
      _proofUrls.removeAt(index);
      _proofUploading.remove(index);
      // Reindex remaining upload states
      final newUploading = <int, bool>{};
      _proofUploading.forEach((key, value) {
        if (key > index) {
          newUploading[key - 1] = value;
        } else if (key < index) {
          newUploading[key] = value;
        }
      });
      _proofUploading.clear();
      _proofUploading.addAll(newUploading);
    });
  }

  Future<void> _pickSignatureImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _signatureImage = image;
          _signatureUrl = null; // Reset URL when new image is selected
          _isUploadingSignature = true;
          _errorMessage = null;
        });

        // Automatically upload the image after selection
        await _uploadSignatureImage();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: $e';
        _isUploadingSignature = false;
      });
    }
  }

  Future<void> _uploadSignatureImage() async {
    if (_signatureImage == null) return;

    setState(() {
      _isUploadingSignature = true;
      _errorMessage = null;
    });

    try {
      final url = await _storageService.uploadCustomerSignature(
        orderId: widget.order.id,
        imageFile: _signatureImage!,
      );

      setState(() {
        _signatureUrl = url;
        _isUploadingSignature = false;
      });
    } catch (e) {
      setState(() {
        _isUploadingSignature = false;
        _errorMessage = 'Error uploading signature image: $e';
      });
    }
  }

  bool get _canSubmit {
    // Admin override: allow submission without images if admin and override is enabled
    if (_isAdmin && _adminOverride) {
      return !_isSubmitting;
    }
    // Standard validation: require proof images and signature
    final allProofsUploaded =
        _proofUrls.isNotEmpty &&
        _proofUrls.every((url) => url.isNotEmpty) &&
        _proofUploading.values.every((uploading) => !uploading);
    return allProofsUploaded && _signatureUrl != null && !_isSubmitting;
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit) {
      setState(() {
        if (_isAdmin && !_adminOverride) {
          _errorMessage =
              'Please upload at least one proof image and the signature before completing installation, or enable admin override';
        } else {
          _errorMessage =
              'Please upload at least one proof image and the signature before completing installation';
        }
      });
      return;
    }

    // All images should already be uploaded at this point (unless admin override)
    final proofUrls = _proofUrls.where((url) => url.isNotEmpty).toList();
    final signatureUrl = _signatureUrl;
    
    // Admin override: allow empty proofUrls and signatureUrl
    if (!(_isAdmin && _adminOverride)) {
      if (proofUrls.isEmpty || signatureUrl == null) {
        setState(() {
          _errorMessage =
              'Please upload at least one proof image and the signature before completing installation';
        });
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      widget.onComplete(
        proofUrls,
        signatureUrl ?? '',
        _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Error completing installation: $e';
      });
    }
  }

  Widget _buildProofImagesSection() {
    final hasImages =
        _proofImages.isNotEmpty || _proofUrls.any((url) => url.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasImages
              ? AppTheme.successColor.withOpacity(0.3)
              : AppTheme.borderColor,
          width: hasImages ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.photo_camera,
                color: hasImages
                    ? AppTheme.successColor
                    : AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Proof of Installation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Photos showing completed installation(s)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasImages)
                Icon(
                  Icons.check_circle,
                  color: AppTheme.successColor,
                  size: 24,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasImages) ...[
            // Show images in a row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...List.generate(_proofImages.length, (index) {
                    final image = _proofImages[index];
                    final url = index < _proofUrls.length
                        ? _proofUrls[index]
                        : '';
                    final isUploading = _proofUploading[index] ?? false;
                    final isUploaded = url.isNotEmpty;

                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 150,
                      child: Column(
                        children: [
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (isUploading)
                                    const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  else if (isUploaded)
                                    Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value:
                                                    loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                              .cumulativeBytesLoaded /
                                                          loadingProgress
                                                              .expectedTotalBytes!
                                                    : null,
                                              ),
                                            );
                                          },
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                color: Colors.grey.shade200,
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.broken_image,
                                                    size: 32,
                                                  ),
                                                ),
                                              ),
                                    )
                                  else
                                    FutureBuilder<Uint8List>(
                                      future: image.readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        }
                                        if (snapshot.hasData) {
                                          return Image.memory(
                                            snapshot.data!,
                                            fit: BoxFit.cover,
                                          );
                                        }
                                        return Container(
                                          color: Colors.grey.shade200,
                                          child: const Center(
                                            child: Icon(Icons.image, size: 32),
                                          ),
                                        );
                                      },
                                    ),
                                  // Remove button
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Material(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => _removeProofImage(index),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (isUploading)
                            Text(
                              'Uploading...',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.secondaryColor.withOpacity(0.7),
                              ),
                            )
                          else if (isUploaded)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: AppTheme.successColor,
                                  size: 12,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Uploaded',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.successColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  }),
                  // Add more button
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        style: BorderStyle.solid,
                        width: 2,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _pickProofImage,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              color: AppTheme.primaryColor,
                              size: 32,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add Image',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Show select button - directly opens gallery and auto-uploads
            ElevatedButton.icon(
              onPressed: _pickProofImage,
              icon: const Icon(Icons.photo_library, size: 18),
              label: const Text('Select from Gallery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignatureSection() {
    final hasImage = _signatureImage != null || _signatureUrl != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasImage
              ? AppTheme.successColor.withOpacity(0.3)
              : AppTheme.borderColor,
          width: hasImage ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.draw,
                color: hasImage ? AppTheme.successColor : AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Signature',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Photo of customer signature',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasImage)
                Icon(
                  Icons.check_circle,
                  color: AppTheme.successColor,
                  size: 24,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasImage) ...[
            // Show image preview
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _signatureImage != null
                    ? FutureBuilder<Uint8List>(
                        future: _signatureImage!.readAsBytes(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasData) {
                            return Image.memory(
                              snapshot.data!,
                              fit: BoxFit.cover,
                            );
                          }
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.image, size: 48),
                            ),
                          );
                        },
                      )
                    : _signatureUrl != null
                    ? Image.network(
                        _signatureUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 48),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
            if (_isUploadingSignature)
              Column(
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    'Uploading image...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.secondaryColor.withOpacity(0.7),
                    ),
                  ),
                ],
              )
            else if (_signatureUrl != null)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppTheme.successColor,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Uploaded',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pickSignatureImage,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Replace'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
          ] else ...[
            // Show select button - directly opens gallery and auto-uploads
            ElevatedButton.icon(
              onPressed: _pickSignatureImage,
              icon: const Icon(Icons.photo_library, size: 18),
              label: const Text('Select from Gallery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.install_desktop,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Complete Installation',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.order.customerName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upload the following images to complete the installation:',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Proof of Installation (multiple images)
                    _buildProofImagesSection(),
                    const SizedBox(height: 16),
                    // Customer Signature
                    _buildSignatureSection(),
                    const SizedBox(height: 20),
                    // Note field
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                        hintText: 'Add any additional notes...',
                      ),
                      maxLines: 3,
                    ),
                    // Admin override checkbox
                    if (_isAdmin) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: CheckboxListTile(
                          title: const Text(
                            'Complete without images (Admin only)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'As an admin, you can complete installation without uploading proof images or signature',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: _adminOverride,
                          onChanged: (value) {
                            setState(() {
                              _adminOverride = value ?? false;
                              _errorMessage = null; // Clear error when toggling
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _canSubmit ? _handleSubmit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Complete Installation'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
