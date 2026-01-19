import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/profile_photo_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_profile_provider.dart';

class ProfilePhotoUploadDialog extends StatefulWidget {
  const ProfilePhotoUploadDialog({super.key});

  @override
  State<ProfilePhotoUploadDialog> createState() =>
      _ProfilePhotoUploadDialogState();
}

class _ProfilePhotoUploadDialogState extends State<ProfilePhotoUploadDialog> {
  final ProfilePhotoService _photoService = ProfilePhotoService();
  bool _isUploading = false;

  Future<void> _uploadPhoto(bool fromCamera) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final userProfileProvider = context.read<UserProfileProvider>();
      final userId = authProvider.user?.uid;
      final oldPhotoUrl = userProfileProvider.userProfile?.photoUrl;

      if (userId == null) {
        throw Exception('User not logged in');
      }

      final String? photoUrl = await _photoService.updateUserProfilePhoto(
        userId,
        fromCamera: fromCamera,
        oldPhotoUrl: oldPhotoUrl,
      );

      if (photoUrl != null) {
        // Reload profile to get updated photo
        await userProfileProvider.loadProfileFromFirebase(userId);

        if (mounted) {
          Navigator.of(context).pop(true); // Return success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Profile photo updated successfully!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        throw Exception('Failed to upload photo');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_a_photo,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Update Profile Photo',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Choose a photo source',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),

            const SizedBox(height: 32),

            if (_isUploading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Uploading photo...',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  // Camera Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _uploadPhoto(true),
                      icon: const Icon(Icons.camera_alt, size: 24),
                      label: const Text(
                        'Take Photo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Gallery Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _uploadPhoto(false),
                      icon: const Icon(Icons.photo_library, size: 24),
                      label: const Text(
                        'Choose from Gallery',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Cancel Button
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
