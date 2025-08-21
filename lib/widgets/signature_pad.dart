import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

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
}

class _SignaturePadState extends State<SignaturePad> {
  final List<Offset?> _points = [];
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
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Stack(
            children: [
              // Signature area
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _points.add(details.localPosition);
                      _hasSignature = true;
                    });
                    HapticFeedback.lightImpact();
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _points.add(details.localPosition);
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _points.add(null); // Add null to separate strokes
                    });
                    _notifySignatureChanged();
                  },
                  child: CustomPaint(
                    painter: SignaturePainter(
                      points: _points,
                      strokeColor: widget.strokeColor,
                      strokeWidth: widget.strokeWidth,
                    ),
                    size: Size(widget.width, widget.height),
                  ),
                ),
              ),
              // Placeholder text when empty
              if (!_hasSignature)
                const Positioned.fill(
                  child: Center(
                    child: Text(
                      'Sign here',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              // Clear button
              if (_hasSignature)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _clearSignature,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.clear,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _clearSignature() {
    setState(() {
      _points.clear();
      _hasSignature = false;
    });
    HapticFeedback.lightImpact();
    _notifySignatureChanged();
  }

  void _notifySignatureChanged() {
    if (widget.onSignatureChanged != null) {
      if (_hasSignature) {
        _getSignatureBytes().then((bytes) {
          widget.onSignatureChanged!(bytes);
        });
      } else {
        widget.onSignatureChanged!(null);
      }
    }
  }

  Future<Uint8List?> _getSignatureBytes() async {
    if (!_hasSignature) return null;
    
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Fill background with white
    canvas.drawRect(
      Rect.fromLTWH(0, 0, widget.width, widget.height),
      Paint()..color = Colors.white,
    );
    
    // Draw the signature
    final painter = SignaturePainter(
      points: _points,
      strokeColor: widget.strokeColor,
      strokeWidth: widget.strokeWidth,
    );
    painter.paint(canvas, Size(widget.width, widget.height));
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      widget.width.toInt(),
      widget.height.toInt(),
    );
    
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<Uint8List?> getSignature() => _getSignatureBytes();
  
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
