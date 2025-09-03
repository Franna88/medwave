import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../theme/app_theme.dart';

class SignaturePopupDialog extends StatefulWidget {
  final String title;
  final String? initialSignature;
  final Function(Uint8List? signatureBytes) onSignatureComplete;

  const SignaturePopupDialog({
    super.key,
    required this.title,
    this.initialSignature,
    required this.onSignatureComplete,
  });

  @override
  State<SignaturePopupDialog> createState() => _SignaturePopupDialogState();

  static Future<void> show({
    required BuildContext context,
    required String title,
    String? initialSignature,
    required Function(Uint8List? signatureBytes) onSignatureComplete,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return SignaturePopupDialog(
          title: title,
          initialSignature: initialSignature,
          onSignatureComplete: onSignatureComplete,
        );
      },
    );
  }
}

class _SignaturePopupDialogState extends State<SignaturePopupDialog> {
  final List<Offset?> _points = [];
  bool _hasSignature = false;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    // If there's an initial signature, show that we have one
    if (widget.initialSignature != null) {
      setState(() {
        _hasSignature = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width * 0.9;
    final dialogHeight = screenSize.height * 0.8;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Use your finger or stylus to sign in the area below. Your signature will be saved when you tap "Done".',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.secondaryColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Signature Area
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Stack(
                  children: [
                    // Signature canvas
                    Positioned.fill(
                      child: GestureDetector(
                        onPanStart: (details) {
                          if (_isClearing) return;
                          
                          setState(() {
                            _points.add(details.localPosition);
                            _hasSignature = true;
                          });
                          HapticFeedback.lightImpact();
                        },
                        onPanUpdate: (details) {
                          if (_isClearing) return;
                          
                          setState(() {
                            _points.add(details.localPosition);
                          });
                        },
                        onPanEnd: (details) {
                          if (_isClearing) return;
                          
                          setState(() {
                            _points.add(null); // Separate strokes
                          });
                        },
                        child: CustomPaint(
                          painter: SignaturePopupPainter(
                            points: _points,
                            strokeColor: AppTheme.textColor,
                            strokeWidth: 3.0,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                    
                    // Placeholder text
                    if (!_hasSignature)
                      Positioned.fill(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.gesture,
                                size: 48,
                                color: AppTheme.secondaryColor.withOpacity(0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tap and drag to sign here',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: AppTheme.secondaryColor.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Clear button
                    if (_hasSignature)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _clearSignature,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.clear,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Clear',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                        foregroundColor: AppTheme.secondaryColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _hasSignature ? _saveSignature : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _hasSignature ? 'Save Signature' : 'Sign First',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearSignature() {
    setState(() {
      _isClearing = true;
      _points.clear();
      _hasSignature = false;
    });
    
    HapticFeedback.mediumImpact();
    
    // Reset clearing flag after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
      }
    });
  }

  Future<void> _saveSignature() async {
    if (!_hasSignature || _points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a signature first'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    try {
      final signatureBytes = await _getSignatureBytes();
      widget.onSignatureComplete(signatureBytes);
      
      if (mounted) {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving signature: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<Uint8List?> _getSignatureBytes() async {
    if (!_hasSignature || _points.isEmpty) return null;
    
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Get the signature area size
      final signatureArea = context.findRenderObject() as RenderBox?;
      final size = signatureArea?.size ?? const Size(400, 300);
      
      // Fill background with white
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white,
      );
      
      // Draw the signature
      final painter = SignaturePopupPainter(
        points: _points,
        strokeColor: AppTheme.textColor,
        strokeWidth: 3.0,
      );
      painter.paint(canvas, size);
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      
      print('✅ Signature popup captured: ${bytes?.length ?? 0} bytes');
      return bytes;
    } catch (e) {
      print('❌ Error capturing signature in popup: $e');
      return null;
    }
  }
}

class SignaturePopupPainter extends CustomPainter {
  final List<Offset?> points;
  final Color strokeColor;
  final double strokeWidth;

  SignaturePopupPainter({
    required this.points,
    required this.strokeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
