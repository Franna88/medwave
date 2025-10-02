import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ValidationUtils {
  /// Shows a validation popup dialog when required fields are missing
  static Future<void> showValidationDialog(
    BuildContext context, {
    required String title,
    required List<String> missingFields,
    String? additionalMessage,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.warningColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please complete the following required fields:',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.secondaryColor,
                ),
              ),
              const SizedBox(height: 12),
              ...missingFields.map((field) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.warningColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            field,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              if (additionalMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.infoColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    additionalMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.infoColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Validates required text fields and returns missing field names
  static List<String> validateRequiredFields(Map<String, TextEditingController> fields) {
    List<String> missingFields = [];
    
    fields.forEach((fieldName, controller) {
      if (controller.text.trim().isEmpty) {
        missingFields.add(fieldName);
      }
    });
    
    return missingFields;
  }

  /// Validates form and shows dialog if validation fails
  static Future<bool> validateFormWithDialog(
    BuildContext context,
    GlobalKey<FormState> formKey, {
    Map<String, TextEditingController>? requiredFields,
    List<String>? customMissingFields,
    String title = 'Incomplete Form',
    String? additionalMessage,
  }) async {
    // First check form validation
    if (!formKey.currentState!.validate()) {
      List<String> missingFields = [];
      
      if (customMissingFields != null) {
        missingFields = customMissingFields;
      } else if (requiredFields != null) {
        missingFields = validateRequiredFields(requiredFields);
      } else {
        missingFields = ['Please check all required fields'];
      }
      
      await showValidationDialog(
        context,
        title: title,
        missingFields: missingFields,
        additionalMessage: additionalMessage,
      );
      return false;
    }
    
    return true;
  }

  /// Shows a success confirmation dialog
  static Future<void> showSuccessDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.successColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.secondaryColor,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: onPressed ?? () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(buttonText),
            ),
          ],
        );
      },
    );
  }
}
