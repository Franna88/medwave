import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/leads/lead.dart';
import '../../models/leads/lead_channel.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase/lead_service.dart';
import '../../theme/app_theme.dart';

/// Dialog for adding or editing a lead
class AddLeadDialog extends StatefulWidget {
  final LeadChannel channel;
  final Lead? existingLead;
  /// When true and creating (not editing), pops with the new lead id instead of true.
  final bool returnLeadIdOnCreate;

  const AddLeadDialog({
    super.key,
    required this.channel,
    this.existingLead,
    this.returnLeadIdOnCreate = false,
  });

  @override
  State<AddLeadDialog> createState() => _AddLeadDialogState();
}

class _AddLeadDialogState extends State<AddLeadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _leadService = LeadService();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _sourceController;
  late String _selectedStage;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController(text: widget.existingLead?.firstName ?? '');
    _lastNameController =
        TextEditingController(text: widget.existingLead?.lastName ?? '');
    _emailController =
        TextEditingController(text: widget.existingLead?.email ?? '');
    _phoneController =
        TextEditingController(text: widget.existingLead?.phone ?? '');
    _sourceController =
        TextEditingController(text: widget.existingLead?.source ?? '');
    _selectedStage = widget.existingLead?.currentStage ??
        widget.channel.stages.first.id;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _saveLead() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.uid ?? '';
      final userName = authProvider.userName ?? '';

      final now = DateTime.now();
      final selectedStageObj = widget.channel.stages
          .firstWhere((s) => s.id == _selectedStage);

      if (widget.existingLead != null) {
        // Update existing lead
        final updatedLead = widget.existingLead!.copyWith(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          source: _sourceController.text.trim(),
          updatedAt: now,
        );
        await _leadService.updateLead(updatedLead);
      } else {
        // Create new lead
        final newLead = Lead(
          id: '',
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          source: _sourceController.text.trim(),
          channelId: widget.channel.id,
          currentStage: _selectedStage,
          followUpWeek: selectedStageObj.isFollowUpStage ? 1 : null,
          createdAt: now,
          updatedAt: now,
          stageEnteredAt: now,
          stageHistory: [
            StageHistoryEntry(
              stage: _selectedStage,
              enteredAt: now,
            ),
          ],
          createdBy: userId,
          createdByName: userName,
        );
        final leadId = await _leadService.createLead(newLead);
        if (mounted && widget.returnLeadIdOnCreate) {
          Navigator.of(context).pop(leadId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lead created successfully')),
          );
          return;
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingLead != null
                  ? 'Lead updated successfully'
                  : 'Lead created successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    widget.existingLead != null
                        ? Icons.edit
                        : Icons.person_add,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.existingLead != null ? 'Edit Lead' : 'Add New Lead',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Form fields
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  if (!value.contains('@')) {
                    return 'Invalid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _sourceController,
                decoration: const InputDecoration(
                  labelText: 'Source',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.source_outlined),
                  hintText: 'e.g., Facebook, Website, Referral',
                ),
              ),
              const SizedBox(height: 16),

              // Stage selection (only for new leads)
              if (widget.existingLead == null)
                DropdownButtonFormField<String>(
                  value: _selectedStage,
                  decoration: const InputDecoration(
                    labelText: 'Initial Stage',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: widget.channel.stages.map((stage) {
                    return DropdownMenuItem(
                      value: stage.id,
                      child: Text(stage.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedStage = value);
                    }
                  },
                ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveLead,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(widget.existingLead != null ? 'Update' : 'Create'),
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

