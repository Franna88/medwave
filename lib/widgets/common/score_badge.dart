import 'package:flutter/material.dart';

import '../../utils/stream_utils.dart';

/// Reusable badge to display a form score with tier-based color.
class ScoreBadge extends StatelessWidget {
  final double? score;

  const ScoreBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        'Score ${score?.toStringAsFixed(0) ?? '-'}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _scoreColor(double? value) {
    switch (StreamUtils.getFormScoreTier(value)) {
      case FormScoreTier.high:
        return Colors.green;
      case FormScoreTier.mid:
        return Colors.orange;
      case FormScoreTier.low:
        return Colors.red;
      case FormScoreTier.none:
        return Colors.grey;
    }
  }
}
