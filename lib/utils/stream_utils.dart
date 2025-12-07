import '../models/streams/stream_stage.dart';

// Utility functions for stream drag-and-drop validation and stage management
class StreamUtils {
  // Only allows forward movement to the next immediate stage (position + 1)
  static bool canMoveToStage(
    String currentStageId,
    String targetStageId,
    List<StreamStage> stages,
  ) {
    // Don't allow moving to the same stage
    if (currentStageId == targetStageId) {
      return false;
    }

    // Find current and target stages
    final currentStage = stages.firstWhere(
      (s) => s.id == currentStageId,
      orElse: () => throw Exception('Current stage not found: $currentStageId'),
    );

    final targetStage = stages.firstWhere(
      (s) => s.id == targetStageId,
      orElse: () => throw Exception('Target stage not found: $targetStageId'),
    );

    // Only allow forward movement to the next immediate stage
    return targetStage.position == currentStage.position + 1;
  }

  // Checks if a stage is the final stage (using isFinalStage property)
  static bool isFinalStage(String stageId, List<StreamStage> stages) {
    final stage = stages.firstWhere(
      (s) => s.id == stageId,
      orElse: () => throw Exception('Stage not found: $stageId'),
    );
    return stage.isFinalStage;
  }

  // Gets the next stage in sequence for a given current stage
  static StreamStage? getNextStage(
    String currentStageId,
    List<StreamStage> stages,
  ) {
    final currentStage = stages.firstWhere(
      (s) => s.id == currentStageId,
      orElse: () => throw Exception('Current stage not found: $currentStageId'),
    );

    final nextPosition = currentStage.position + 1;
    try {
      return stages.firstWhere((s) => s.position == nextPosition);
    } catch (e) {
      return null; // No next stage
    }
  }

  // Gets the position of a stage by ID
  static int getCurrentStagePosition(String stageId, List<StreamStage> stages) {
    final stage = stages.firstWhere(
      (s) => s.id == stageId,
      orElse: () => throw Exception('Stage not found: $stageId'),
    );
    return stage.position;
  }
}
