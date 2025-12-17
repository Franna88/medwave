import 'package:flutter/material.dart';
import '../../models/streams/appointment.dart';

/// Badge that indicates an appointment is ready to move to operations
/// Shows when contract is signed, deposit paid, and confirmation received
class ReadyForOpsBadge extends StatelessWidget {
  final SalesAppointment appointment;
  final bool isCompact; // For card vs dialog display

  const ReadyForOpsBadge({
    super.key,
    required this.appointment,
    this.isCompact = false,
  });

  bool get _isReady {
    return appointment.depositPaid == true &&
        appointment.depositConfirmationStatus == 'confirmed';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[600]!, Colors.green[400]!],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified,
            size: isCompact ? 14 : 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            'Ready For Ops',
            style: TextStyle(
              fontSize: isCompact ? 11 : 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

