double calculateOverallHatchRate(List<Map<String, dynamic>> batchHistory) {
  if (batchHistory.isEmpty) return 0.0;
  double totalSuccessRate = 0.0;
  int completedBatches = 0;
  for (var batch in batchHistory) {
    if (batch['hatchedCount'] != null && batch['eggCount'] != null) {
      final double successRate = (batch['hatchedCount'] as num).toDouble() / (batch['eggCount'] as num).toDouble() * 100.0;
      totalSuccessRate += successRate;
      completedBatches++;
    } else if (batch['hatchRate'] != null) {
      totalSuccessRate += (batch['hatchRate'] as num).toDouble();
      completedBatches++;
    } else if (batch['eggsHatched'] != null && batch['totalEggs'] != null) {
      final double successRate = (batch['eggsHatched'] as num).toDouble() / (batch['totalEggs'] as num).toDouble() * 100.0;
      totalSuccessRate += successRate;
      completedBatches++;
    }
  }
  return completedBatches > 0 ? (totalSuccessRate / completedBatches) : 0.0;
}

int getTotalCompletedBatches(List<Map<String, dynamic>> batchHistory) {
  return batchHistory.length;
}

String getNextCandlingDate(Map<String, Map<String, dynamic>> incubatorData, List<Map<String, dynamic>> batchHistory) {
  DateTime? nextCandling;
  final now = DateTime.now();
  incubatorData.forEach((name, data) {
    final int startDateMs = data['startDate'] ?? DateTime.now().millisecondsSinceEpoch;
    final DateTime startDate = DateTime.fromMillisecondsSinceEpoch(startDateMs);
    final List<int> candlingDays = [7, 14, 18];
    final int daysElapsed = now.difference(startDate).inDays;

    bool isCompleted = false;
    if (batchHistory.isNotEmpty) {
      final batchName = data['batchName'] ?? '';
      isCompleted = batchHistory.any((batch) => batch['batchName'] == batchName && batch['reason'] != null || batch['completionReason'] != null);
    }

    for (int day in candlingDays) {
      final bool candlingDone = ((data['candlingDates'] ?? {})['$day'] == true);
      if (daysElapsed < day && !candlingDone && !isCompleted) {
        final DateTime candlingDate = startDate.add(Duration(days: day));
        if (nextCandling == null || candlingDate.isBefore(nextCandling!)) {
          nextCandling = candlingDate;
        }
        break;
      } else if (!candlingDone && !isCompleted) {
        final DateTime candlingDate = startDate.add(Duration(days: day));
        if (nextCandling == null || candlingDate.isBefore(nextCandling!)) {
          nextCandling = candlingDate;
        }
      }
    }
  });
  if (nextCandling != null) {
    final DateTime nd = nextCandling!;
    return '${nd.day}/${nd.month}/${nd.year}';
  }
  return 'Schedule';
}
