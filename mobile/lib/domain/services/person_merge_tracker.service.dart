/// Why do we need this?
/// Say we open the profile page (drift_person.page.dart) for Person A, and then nested above
/// a image viewer for an image that belongs to Person A.
///
/// When the users now merges user A into user B, we cant just listen to
/// the changes in the profile page, we have to keep track where the user A (now B)
/// can be found in the DB.
///
/// So when popping back to the profile page (and the user is missing) we check
/// which other person B we have to display instead.
class PersonMergeTrackerService {
  // Map of merged person ID -> target person ID
  final Map<String, String> _mergeForwardingMap = {};

  // We can't just remove the merge record, because in the drift person page
  // we grab the profile data from a provider, so in the 'loading' state
  // we need to know if we are waiting for the data, or if the user has been
  // merged thus we need to redirect.
  // So when we have redirected once, we mark the record as handled so that we
  // don't try to redirect infinite times.
  final Set<String> _handledMergeRecords = {};

  /// Record a person merge operation
  void recordMerge({required String mergedPersonId, required String targetPersonId}) {
    _mergeForwardingMap[mergedPersonId] = targetPersonId;
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

  /// Mark a merge record as handled (for tracking purposes)
  void markMergeRecordHandled(String personId) {
    _handledMergeRecords.add(personId);
  }
}
