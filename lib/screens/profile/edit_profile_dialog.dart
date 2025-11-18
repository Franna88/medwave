import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../services/firebase/audit_service.dart';

class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({super.key});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _specializationController = TextEditingController();
  final _yearsExpController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  void _loadCurrentData() {
    final userProfileProvider = context.read<UserProfileProvider>();
    final profile = userProfileProvider.userProfile;
    
    if (profile != null) {
      _phoneController.text = profile.phoneNumber;
      _specializationController.text = profile.specialization;
      _yearsExpController.text = profile.yearsOfExperience.toString();
      _addressController.text = profile.address ?? '';
      _cityController.text = profile.city ?? '';
      _postalCodeController.text = profile.postalCode ?? '';
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _specializationController.dispose();
    _yearsExpController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final userProfileProvider = context.read<UserProfileProvider>();
      final userId = authProvider.user?.uid;
      final profile = userProfileProvider.userProfile;

      if (userId == null || profile == null) {
        throw Exception('User not logged in');
      }

      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'phoneNumber': _phoneController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'yearsOfExperience': int.tryParse(_yearsExpController.text.trim()) ?? 0,
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'postalCode': _postalCodeController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Log audit event
      final auditService = AuditService();
      await auditService.logEvent(
        userId: userId,
        userEmail: profile.email,
        userName: profile.fullName,
        action: AuditAction.profileUpdated,
        actionDescription: 'Updated practice information',
        details: {
          'phoneNumber': _phoneController.text.trim(),
          'specialization': _specializationController.text.trim(),
          'yearsOfExperience': int.tryParse(_yearsExpController.text.trim()) ?? 0,
        },
      );

      // Reload profile
      await userProfileProvider.loadProfileFromFirebase(userId);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile updated successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
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
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: AppTheme.primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Update your practice information',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Phone Number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Specialization
                TextFormField(
                  controller: _specializationController,
                  decoration: InputDecoration(
                    labelText: 'Specialization',
                    prefixIcon: const Icon(Icons.medical_services),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your specialization';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Years of Experience
                TextFormField(
                  controller: _yearsExpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Years of Experience',
                    prefixIcon: const Icon(Icons.work),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter years of experience';
                    }
                    final years = int.tryParse(value.trim());
                    if (years == null || years < 0) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Address
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Practice Address',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your practice address';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // City
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: 'City',
                    prefixIcon: const Icon(Icons.location_city),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your city';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Postal Code
                TextFormField(
                  controller: _postalCodeController,
                  decoration: InputDecoration(
                    labelText: 'Postal Code',
                    prefixIcon: const Icon(Icons.markunread_mailbox),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your postal code';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

