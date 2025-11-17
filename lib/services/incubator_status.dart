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
        return false;
      }

      final DateTime lastOnline =
          DateTime.fromMillisecondsSinceEpoch(timestampMillis);
      final DateTime now = DateTime.now();

      const Duration offlineThreshold = Duration(seconds: 60);

      return now.difference(lastOnline) < offlineThreshold;
    });
  }
}