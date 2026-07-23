import 'package:hive_flutter/hive_flutter.dart';

class AttendanceQueueService {
  static const String _boxName = 'offline_attendance_box';

  // Initialize Hive box once at app startup
  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  // Save the record locally when offline or remote
  Future<void> queueOfflineAction(Map<String, dynamic> payload) async {
    final box = Hive.box(_boxName);
    
    // Attach an immutable client-side creation stamp
    payload['clientTimestamp'] = DateTime.now().toIso8601String();
    
    await box.add(payload);
  }

  // Retrieve all records waiting for server sync
  List<Map<String, dynamic>> getPendingQueue() {
    final box = Hive.box(_boxName);
    return box.values.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  // Clear specific item out of storage after server responds 200 OK
  Future<void> dequeueAction(int index) async {
    final box = Hive.box(_boxName);
    await box.deleteAt(index);
  }
}