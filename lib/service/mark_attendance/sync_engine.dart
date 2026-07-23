import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:attendance_app/service/mark_attendance/attendance_service.dart';
import 'package:attendance_app/service/mark_attendance/attendance_queue_service.dart';
import 'package:flutter/material.dart';

class AttendanceSyncEngine {
  final AttendanceQueueService _queueService;
  final AttendanceService _attendanceService;
  bool _isSyncing = false;
  
  // 1. Fixed type signature to expect a List wrap
  StreamSubscription<List<ConnectivityResult>>? _subscription; 

  AttendanceSyncEngine(this._queueService, this._attendanceService);

  void startListening() {
    // 2. Fixed lambda parameter to intercept List<ConnectivityResult>
    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      
      // 3. Checked if ANY adapter in the active array is connected to a network
      if (results.any((element) => element != ConnectivityResult.none)) {
        processPendingOfflineQueue();
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
  }

  Future<void> processPendingOfflineQueue() async {
    if (_isSyncing) return;
    
    final pendingItems = _queueService.getPendingQueue();
    if (pendingItems.isEmpty) return;

    _isSyncing = true;
    debugPrint("🔄 Background Sync Engine triggered. Found ${pendingItems.length} logs.");

    for (int i = 0; i < pendingItems.length; i++) {
      try {
        final payload = pendingItems[i];
        await _attendanceService.markAttendanceLegacy(payload).timeout(const Duration(seconds: 15));
        await _queueService.dequeueAction(0); 
        debugPrint("✅ Sync index 0 successfully processed.");
      } catch (e) {
        debugPrint("⚠️ Background Sync temporarily halted: $e");
        break;
      }
    }
    _isSyncing = false;
  }
}