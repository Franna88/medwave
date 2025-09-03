import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import '../theme/app_theme.dart';
import 'signature_popup_dialog.dart';

class SignaturePad extends StatefulWidget {
  final double width;
  final double height;
  final Color strokeColor;
  final double strokeWidth;
  final String? label;
  final Function(Uint8List?)? onSignatureChanged;
  
  const SignaturePad({
    super.key,
    this.width = 300,
    this.height = 150,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.0,
    this.label,
    this.onSignatureChanged,
  });

  @override
  State<SignaturePad> createState() => _SignaturePadState();

  // Static method to get signature from a GlobalKey
  static Future<Uint8List?> getSignatureFromKey(GlobalKey key) async {
    final signaturePad = key.currentState;
    if (signaturePad is _SignaturePadState) {
      return signaturePad._signatureBytes;
    }
    return null;
  }
  
  // Static method to check if signature exists from a GlobalKey
  static bool hasSignatureFromKey(GlobalKey key) {
    final signaturePad = key.currentState;
    if (signaturePad is _SignaturePadState) {
      return signaturePad._hasSignature;
    }
    return false;
  }
}

class _SignaturePadState extends State<SignaturePad> {
  Uint8List? _signatureBytes;
  bool _hasSignature = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openSignaturePopup,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _hasSignature ? AppTheme.primaryColor : Colors.grey.shade300,
                  width: _hasSignature ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: _hasSignature ? AppTheme.primaryColor.withOpacity(0.05) : Colors.grey.shade50,
              ),
              child: Stack(
                children: [
                  // Signature preview or placeholder
                  Positioned.fill(
                    child: _hasSignature ? _buildSignaturePreview() : _buildPlaceholder(),
                  ),
                  // Edit button
                  if (_hasSignature)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  // Tap indicator
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _hasSignature ? AppTheme.primaryColor : AppTheme.secondaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _hasSignature ? Icons.check_circle : Icons.touch_app,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _hasSignature ? 'Signed' : 'Tap to Sign',
                              style: const TextStyle(
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
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.gesture,
            size: 32,
            color: AppTheme.secondaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to add signature',
            style: TextStyle(
              color: AppTheme.secondaryColor.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignaturePreview() {
    if (_signatureBytes == null) return _buildPlaceholder();
    
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          _signatureBytes!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        ),
      ),
    );
  }

  Future<void> _openSignaturePopup() async {
    HapticFeedback.lightImpact();
    
    await SignaturePopupDialog.show(
      context: context,
      title: widget.label ?? 'Digital Signature',
      onSignatureComplete: (signatureBytes) {
        setState(() {
          _signatureBytes = signatureBytes;
          _hasSignature = signatureBytes != null;
        });
        _notifySignatureChanged();
      },
    );
  }

  void _clearSignature() {
    setState(() {
      _signatureBytes = null;
      _hasSignature = false;
    });
    HapticFeedback.lightImpact();
    _notifySignatureChanged();
  }

  void _notifySignatureChanged() {
    if (widget.onSignatureChanged != null) {
      widget.onSignatureChanged!(_signatureBytes);
    }
  }

  Future<Uint8List?> getSignature() async => _signatureBytes;
  
  bool get hasSignature => _hasSignature;
  
  void clear() => _clearSignature();
}

class SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  final Color strokeColor;
  final double strokeWidth;

  SignaturePainter({
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
