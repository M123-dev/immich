import 'dart:async';

/// Service to track person merges and provide forwarding information
/// when navigating to person pages after a merge operation
class PersonMergeTrackerService {
  static final PersonMergeTrackerService _instance = PersonMergeTrackerService._internal();
  factory PersonMergeTrackerService() => _instance;
  PersonMergeTrackerService._internal();

  // Map of merged person ID -> target person ID
  final Map<String, String> _mergeForwardingMap = {};

  final Set<String> _handledMergeRecords = {};

  // Stream controller to notify listeners of merge events
  final StreamController<PersonMergeEvent> _mergeEventController = StreamController<PersonMergeEvent>.broadcast();

  /// Record a person merge operation
  void recordMerge({required String mergedPersonId, required String targetPersonId}) {
    _mergeForwardingMap[mergedPersonId] = targetPersonId;
    _mergeEventController.add(PersonMergeEvent(mergedPersonId: mergedPersonId, targetPersonId: targetPersonId));
  }

  /// Record multiple person merges (when merging multiple people into one)
  void recordMultipleMerges({required List<String> mergedPersonIds, required String targetPersonId}) {
    for (final mergedId in mergedPersonIds) {
      _mergeForwardingMap[mergedId] = targetPersonId;
    }

    _mergeEventController.add(
      PersonMergeEvent(
        mergedPersonId: mergedPersonIds.first, // Use first as representative
        targetPersonId: targetPersonId,
        additionalMergedIds: mergedPersonIds.skip(1).toList(),
      ),
    );
  }

  /// Get the target person ID for a merged person
  String? getTargetPersonId(String personId) {
    return _mergeForwardingMap[personId];
  }

  /// Check if a person ID has been merged
  bool isPersonMerged(String personId) {
    return _mergeForwardingMap.containsKey(personId);
  }

  /// Check if a merge record has been handled (redirected)
  bool isMergeRecordHandled(String personId) {
    return _handledMergeRecords.contains(personId);
  }

  /// Check if we should redirect for this person (merged but not yet handled)
  bool shouldRedirectForPerson(String personId) {
    return isPersonMerged(personId) && !isMergeRecordHandled(personId);
  }

  /// Stream of merge events
  Stream<PersonMergeEvent> get mergeEvents => _mergeEventController.stream;

  /// Clear a specific merge record (useful for cleanup)
  void clearMergeRecord(String personId) {
    _mergeForwardingMap.remove(personId);
  }

  /// Clear merge records older than specified duration (useful for cleanup)
  void clearOldMergeRecords({Duration maxAge = const Duration(hours: 24)}) {
    // For now, just clear all records since we don't track timestamps
    // In a real implementation, you might want to add timestamps
    _mergeForwardingMap.clear();
  }

  /// Mark a merge record as handled (for tracking purposes)
  void markMergeRecordHandled(String personId) {
    _handledMergeRecords.add(personId);
  }

  /// Clear all merge records (useful for fresh starts or testing)
  void clearAllMergeRecords() {
    _mergeForwardingMap.clear();
    _handledMergeRecords.clear();
  }

  /// Dispose resources
  void dispose() {
    _mergeEventController.close();
  }
}

/// Event representing a person merge operation
class PersonMergeEvent {
  final String mergedPersonId;
  final String targetPersonId;
  final List<String>? additionalMergedIds;

  PersonMergeEvent({required this.mergedPersonId, required this.targetPersonId, this.additionalMergedIds});

  /// Get all merged person IDs including the main one and additional ones
  List<String> get allMergedIds => [mergedPersonId, ...(additionalMergedIds ?? [])];
}
