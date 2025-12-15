import '../models/streams/stream_stage.dart';

enum FormScoreTier { high, mid, low, none }

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

    // Sales exception: allow jumping directly from Appointments -> Opt In
    final isSalesDirectOptIn =
        currentStage.streamType == StreamType.sales &&
        currentStage.id == 'appointments' &&
        targetStage.id == 'opt_in';
    if (isSalesDirectOptIn) return true;

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

  // Classifies a form score into a tier.
  static FormScoreTier getFormScoreTier(double? score) {
    if (score == null) return FormScoreTier.none;
    if (score >= 20) return FormScoreTier.high;
    if (score >= 5 && score <= 19) return FormScoreTier.mid;
    return FormScoreTier.low;
  }

  // Sorts any list by form score tiers (high > mid > low > none) and
  static List<T> sortByFormScore<T>(
    List<T> items,
    double? Function(T item) getScore,
  ) {
    final indexed = items
        .asMap()
        .entries
        .map(
          (entry) => (
            item: entry.value,
            index: entry.key,
            score: getScore(entry.value),
          ),
        )
        .toList();

    int tierPriority(FormScoreTier tier) {
      switch (tier) {
        case FormScoreTier.high:
          return 0;
        case FormScoreTier.mid:
          return 1;
        case FormScoreTier.low:
          return 2;
        case FormScoreTier.none:
          return 3;
      }
    }

    indexed.sort((a, b) {
      final tierA = getFormScoreTier(a.score);
      final tierB = getFormScoreTier(b.score);

      final tierCompare = tierPriority(tierA).compareTo(tierPriority(tierB));
      if (tierCompare != 0) return tierCompare;

      if (a.score != null && b.score != null) {
        final scoreCompare = b.score!.compareTo(a.score!);
        if (scoreCompare != 0) return scoreCompare;
      }

      return a.index.compareTo(b.index);
    });

    return indexed.map((e) => e.item).toList();
  }

  // Adds light-weight tier separators for already sorted items.
  static List<({T? item, bool isDivider, FormScoreTier? tier})>
  withTierSeparators<T>(
    List<T> sortedItems,
    double? Function(T item) getScore,
  ) {
    final result = <({T? item, bool isDivider, FormScoreTier? tier})>[];
    FormScoreTier? lastTier;

    for (final item in sortedItems) {
      final tier = getFormScoreTier(getScore(item));
      if (lastTier != null && tier != lastTier) {
        result.add((item: null, isDivider: true, tier: tier));
      }
      result.add((item: item, isDivider: false, tier: tier));
      lastTier = tier;
    }

    return result;
  }
}
