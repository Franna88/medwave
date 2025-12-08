import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
// Conditional import: dart:html only available on web, use stub for other platforms
import 'html_stub.dart' if (dart.library.html) 'dart:html' as html;
import '../../models/form/lead_form.dart';
import '../../models/form/form_submission.dart';
import '../../services/firebase/form_service.dart';
import '../../services/firebase/form_submission_service.dart';
import '../../services/firebase/lead_service.dart';
import '../../services/firebase/lead_channel_service.dart';
import '../../utils/utm_tracker.dart';
import '../../widgets/forms/dynamic_form_renderer.dart';
import '../../theme/app_theme.dart';

/// Public form screen accessible at /fb-form/:formId
/// Captures UTM parameters and creates leads automatically
class PublicFormScreen extends StatefulWidget {
  final String formId;

  const PublicFormScreen({super.key, required this.formId});

  @override
  State<PublicFormScreen> createState() => _PublicFormScreenState();
}

class _PublicFormScreenState extends State<PublicFormScreen> {
  final FormService _formService = FormService();
  final FormSubmissionService _submissionService = FormSubmissionService();
  final LeadService _leadService = LeadService();
  final LeadChannelService _channelService = LeadChannelService();

  LeadForm? _form;
  FormAttribution? _utmAttribution;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isSubmitted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    setState(() => _isLoading = true);

    try {
      Map<String, String> queryParams = {};
      String? fullUrl;

      if (kIsWeb) {
        try {
          fullUrl = html.window.location.href;
          final uri = Uri.parse(fullUrl);

          if (uri.fragment.isNotEmpty && uri.fragment.contains('?')) {
            final fragmentParts = uri.fragment.split('?');
            if (fragmentParts.length > 1) {
              final fragmentQuery = fragmentParts[1];
              final fragmentUri = Uri.parse('http://dummy.com?$fragmentQuery');
              queryParams = Map<String, String>.from(
                fragmentUri.queryParameters,
              );
            }
          } else {
            queryParams = Map<String, String>.from(uri.queryParameters);
          }

          if (queryParams.isEmpty) {
            queryParams = Map<String, String>.from(Uri.base.queryParameters);
          }
        } catch (e) {
          queryParams = Uri.base.queryParameters;
        }
      } else {
        queryParams = Uri.base.queryParameters;
      }

      _utmAttribution = UtmTracker.extractUtmParams(queryParams);

      // Fetch form
      final form = await _formService.getForm(widget.formId);

      if (form == null) {
        setState(() {
          _errorMessage = 'Form not found';
          _isLoading = false;
        });
        return;
      }

      // Validate form is active
      if (form.status != FormStatus.active) {
        setState(() {
          _errorMessage = 'This form is not currently active';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _form = form;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading form: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleFormSubmit(Map<String, dynamic> responses) async {
    if (_form == null) return;

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();

      final submission = FormSubmission(
        submissionId: '',
        formId: _form!.formId,
        responses: responses,
        submittedAt: now,
        attribution: _utmAttribution,
      );

      final submissionId = await _submissionService.saveSubmission(submission);

      // Get marketing channel
      final channel = await _channelService.initializeDefaultChannel();
      if (channel.stages.isEmpty) {
        throw Exception('Marketing channel has no stages');
      }

      final firstStage = channel.stages.first;

      // Create Lead from submission
      // Create a new submission object with the ID
      final submissionWithId = FormSubmission(
        submissionId: submissionId,
        formId: submission.formId,
        responses: submission.responses,
        submittedAt: submission.submittedAt,
        attribution: submission.attribution,
        userInfo: submission.userInfo,
      );

      await _leadService.createLeadFromFormSubmission(
        submission: submissionWithId,
        formAnswers: responses,
        channel: channel,
        firstStageId: firstStage.id,
      );

      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Error submitting form: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting form: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading form...',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Go to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isSubmitted) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  'Thank you!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your form has been submitted successfully.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_form == null) {
      return const Scaffold(body: Center(child: Text('Form not found')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _form!.formName,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Submitting form...'),
                ],
              ),
            )
          : DynamicFormRenderer(form: _form!, onSubmit: _handleFormSubmit),
    );
  }
}
