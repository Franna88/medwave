import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:emailjs/emailjs.dart' as emailjs;
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_profile_provider.dart';

class ContactSupportDialog extends StatefulWidget {
  const ContactSupportDialog({super.key});

  @override
  State<ContactSupportDialog> createState() => _ContactSupportDialogState();
}

class _ContactSupportDialogState extends State<ContactSupportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSending = false;
  String? _selectedCategory;

  final List<String> _categories = [
    'Technical Issue',
    'Account Problem',
    'Billing Question',
    'Feature Request',
    'General Inquiry',
    'Other',
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendSupportEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final userProfileProvider = context.read<UserProfileProvider>();
      final userProfile = userProfileProvider.userProfile;

      final String practitionerName = userProfile?.fullName ?? 'Unknown User';
      final String practitionerEmail = authProvider.userEmail ?? 'no-email@medwave.com';
      final String practitionerId = authProvider.user?.uid ?? 'unknown';

      // Note: EmailJS configuration should be set up in config/api_keys.dart
      // Replace these with your actual EmailJS credentials
      await emailjs.send(
        'service_medwave', // Service ID - replace with your actual service ID
        'template_support', // Template ID - replace with your actual template ID
        {
          'from_name': practitionerName,
          'from_email': practitionerEmail,
          'user_id': practitionerId,
          'category': _selectedCategory ?? 'General Inquiry',
          'subject': _subjectController.text.trim(),
          'message': _messageController.text.trim(),
          'license_number': userProfile?.licenseNumber ?? 'N/A',
          'specialization': userProfile?.specialization ?? 'N/A',
        },
        const emailjs.Options(
          publicKey: 'YOUR_EMAILJS_PUBLIC_KEY', // Replace with your actual public key
          privateKey: null,
        ),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Support request sent successfully! We\'ll get back to you soon.'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to send support request: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
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
                      color: AppTheme.infoColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.support_agent,
                      color: AppTheme.infoColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact Support',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'We\'re here to help!',
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

              // Form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Dropdown
                    const Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        hintText: 'Select a category',
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                        ),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Subject Field
                    const Text(
                      'Subject',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        hintText: 'Brief description of your issue',
                        prefixIcon: const Icon(Icons.subject),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a subject';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Message Field
                    const Text(
                      'Message',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _messageController,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'Describe your issue in detail...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                      ),
                      alignLabelWithHint: true,
                    ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a message';
                        }
                        if (value.trim().length < 10) {
                          return 'Message must be at least 10 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Info Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.infoColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppTheme.infoColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'We typically respond within 24-48 hours. For urgent issues, please call our support line.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSending ? null : () => Navigator.of(context).pop(),
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
                      onPressed: _isSending ? null : _sendSupportEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Send Message',
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
    );
  }
}

