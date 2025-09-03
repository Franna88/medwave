import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';

class WoundAssessmentWidget extends StatefulWidget {
  final int woundIndex;
  final String woundId;
  final Function(WoundAssessmentData) onWoundDataChanged;
  final WoundAssessmentData? initialData;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;

  const WoundAssessmentWidget({
    super.key,
    required this.woundIndex,
    required this.woundId,
    required this.onWoundDataChanged,
    this.initialData,
    this.isExpanded = false,
    this.onToggleExpanded,
  });

  @override
  State<WoundAssessmentWidget> createState() => _WoundAssessmentWidgetState();
}

class _WoundAssessmentWidgetState extends State<WoundAssessmentWidget> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for wound data
  late TextEditingController _locationController;
  late TextEditingController _lengthController;
  late TextEditingController _widthController;
  late TextEditingController _depthController;
  late TextEditingController _descriptionController;
  
  String _selectedWoundType = 'Pressure Ulcer';
  WoundStage _selectedWoundStage = WoundStage.stage1;
  List<String> _woundPhotos = [];
  
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers
    _locationController = TextEditingController();
    _lengthController = TextEditingController();
    _widthController = TextEditingController();
    _depthController = TextEditingController();
    _descriptionController = TextEditingController();
    
    // Load initial data if provided
    if (widget.initialData != null) {
      _loadInitialData(widget.initialData!);
    }
    
    // Add listeners to notify parent of changes
    _setupListeners();
  }

  void _loadInitialData(WoundAssessmentData data) {
    _locationController.text = data.location;
    _lengthController.text = data.length.toString();
    _widthController.text = data.width.toString();
    _depthController.text = data.depth.toString();
    _descriptionController.text = data.description;
    _selectedWoundType = data.type;
    _selectedWoundStage = data.stage;
    _woundPhotos = List.from(data.photos);
  }

  void _setupListeners() {
    _locationController.addListener(_notifyDataChanged);
    _lengthController.addListener(_notifyDataChanged);
    _widthController.addListener(_notifyDataChanged);
    _depthController.addListener(_notifyDataChanged);
    _descriptionController.addListener(_notifyDataChanged);
  }

  void _notifyDataChanged() {
    if (!mounted) return;
    
    final data = WoundAssessmentData(
      id: widget.woundId,
      location: _locationController.text,
      type: _selectedWoundType,
      length: double.tryParse(_lengthController.text) ?? 0.0,
      width: double.tryParse(_widthController.text) ?? 0.0,
      depth: double.tryParse(_depthController.text) ?? 0.0,
      description: _descriptionController.text,
      stage: _selectedWoundStage,
      photos: List.from(_woundPhotos),
    );
    
    widget.onWoundDataChanged(data);
  }

  @override
  void dispose() {
    _locationController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _depthController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get isValid {
    return _locationController.text.isNotEmpty &&
           _lengthController.text.isNotEmpty &&
           _widthController.text.isNotEmpty &&
           _depthController.text.isNotEmpty &&
           _descriptionController.text.isNotEmpty &&
           double.tryParse(_lengthController.text) != null &&
           double.tryParse(_widthController.text) != null &&
           double.tryParse(_depthController.text) != null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isExpanded ? AppTheme.primaryColor : AppTheme.borderColor,
          width: widget.isExpanded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isExpanded 
                ? AppTheme.primaryColor.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            blurRadius: widget.isExpanded ? 12 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildWoundHeader(),
          if (widget.isExpanded) _buildWoundForm(),
        ],
      ),
    );
  }

  Widget _buildWoundHeader() {
    return GestureDetector(
      onTap: widget.onToggleExpanded,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.isExpanded 
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: widget.isExpanded ? Radius.zero : const Radius.circular(16),
            bottomRight: widget.isExpanded ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Row(
          children: [
            // Wound number indicator
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isExpanded 
                    ? AppTheme.primaryColor 
                    : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  '${widget.woundIndex + 1}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.isExpanded ? Colors.white : AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Wound info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _locationController.text.isEmpty 
                        ? 'Wound ${widget.woundIndex + 1}'
                        : 'Wound ${widget.woundIndex + 1}: ${_locationController.text}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.isExpanded ? AppTheme.primaryColor : AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedWoundType,
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.isExpanded 
                          ? AppTheme.primaryColor.withOpacity(0.8)
                          : AppTheme.secondaryColor,
                    ),
                  ),
                  if (!widget.isExpanded && isValid) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.successColor,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Assessment complete',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Status and expand icon
            Column(
              children: [
                if (isValid && !widget.isExpanded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Complete',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Icon(
                  widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: widget.isExpanded ? AppTheme.primaryColor : AppTheme.secondaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWoundForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location and Type
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Wound Location *',
                prefixIcon: Icon(Icons.location_on),
                helperText: 'Anatomical location of the wound',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the wound location';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _selectedWoundType,
              decoration: const InputDecoration(
                labelText: 'Wound Type *',
                prefixIcon: Icon(Icons.medical_information),
                helperText: 'Classification of wound type',
              ),
              isExpanded: true,
              items: [
                'Pressure Ulcer',
                'Diabetic Foot Ulcer',
                'Venous Leg Ulcer',
                'Arterial Ulcer',
                'Surgical Wound',
                'Traumatic Wound',
                'Burns',
                'Other',
              ].map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedWoundType = value!;
                });
                _notifyDataChanged();
              },
            ),
            const SizedBox(height: 24),
            
            // Measurements
            const Text(
              'Wound Measurements',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _lengthController,
                    decoration: const InputDecoration(
                      labelText: 'Length *',
                      suffixText: 'cm',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final length = double.tryParse(value);
                      if (length == null || length <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _widthController,
                    decoration: const InputDecoration(
                      labelText: 'Width *',
                      suffixText: 'cm',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final width = double.tryParse(value);
                      if (width == null || width <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _depthController,
                    decoration: const InputDecoration(
                      labelText: 'Depth *',
                      suffixText: 'cm',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final depth = double.tryParse(value);
                      if (depth == null || depth <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Wound Stage
            DropdownButtonFormField<WoundStage>(
              value: _selectedWoundStage,
              decoration: const InputDecoration(
                labelText: 'Wound Stage *',
                prefixIcon: Icon(Icons.layers),
                helperText: 'Clinical staging of wound severity',
              ),
              isExpanded: true,
              items: WoundStage.values.map((stage) {
                return DropdownMenuItem(
                  value: stage,
                  child: Text(stage.description),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedWoundStage = value!;
                });
                _notifyDataChanged();
              },
            ),
            const SizedBox(height: 16),
            
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Wound Description *',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
                helperText: 'Detailed description of wound appearance',
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a wound description';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // Photos Section
            const Text(
              'Wound Photos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Document this wound for progress tracking',
              style: TextStyle(
                color: AppTheme.secondaryColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            _buildPhotoSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      children: [
        if (_woundPhotos.isNotEmpty)
          Container(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _woundPhotos.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 120,
                  height: 120,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_woundPhotos[index]),
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: AppTheme.errorColor,
                                size: 40,
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _woundPhotos.removeAt(index);
                            });
                            _notifyDataChanged();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppTheme.errorColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _woundPhotos.add(image.path);
        });
        _notifyDataChanged();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }
}

// Data class to hold wound assessment information
class WoundAssessmentData {
  final String id;
  final String location;
  final String type;
  final double length;
  final double width;
  final double depth;
  final String description;
  final WoundStage stage;
  final List<String> photos;

  WoundAssessmentData({
    required this.id,
    required this.location,
    required this.type,
    required this.length,
    required this.width,
    required this.depth,
    required this.description,
    required this.stage,
    required this.photos,
  });

  bool get isValid {
    return location.isNotEmpty &&
           length > 0 &&
           width > 0 &&
           depth > 0 &&
           description.isNotEmpty;
  }

  Wound toWound() {
    return Wound(
      id: id,
      location: location,
      type: type,
      length: length,
      width: width,
      depth: depth,
      description: description,
      photos: photos,
      assessedAt: DateTime.now(),
      stage: stage,
    );
  }
}
