import 'package:firebase_database/firebase_database.dart';

class IncubatorStatusService {
  final String incubatorId;
  final DatabaseReference _statusRef;

  IncubatorStatusService(this.incubatorId)
      : _statusRef = FirebaseDatabase.instance.ref('HatchTech/$incubatorId/lastOnline');

  Stream<bool> get onlineStatusStream {
    // Listen for changes to the lastOnline timestamp
    return _statusRef.onValue.map((event) {
      final int? timestampMillis = event.snapshot.value as int?;
      
      if (timestampMillis == null) {
        // If the node doesn't exist, it's considered off
        return false;
      }

      final DateTime lastOnline =
          DateTime.fromMillisecondsSinceEpoch(timestampMillis);
      final DateTime now = DateTime.now();

      // Define the offline threshold (e.g., 60 seconds)
      const Duration offlineThreshold = Duration(seconds: 60);

      // If the last update was less than the threshold ago, it's ON
      return now.difference(lastOnline) < offlineThreshold;
    });
  }
}