// lib/screens/attendance_history/utils/attendance_helpers.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/modals/mark_attendance_data.dart';

class AttendanceReportHelpers {
  static String formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd-MM-yyyy').format(date);
  }

  static String formatTime(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('hh:mm a').format(date);
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'half-day':
      case 'half_day': // Handle both standard variations safely
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Extracts and safely joins all unique site names from the multi-visit collection list
  static String getAggregatedSiteNames(MarkAttendanceData attendance) {
    if (attendance.visits.isEmpty) return 'N/A';
    final siteNames = attendance.visits
        .map((v) => v.siteName)
        .where((name) => name.trim().isNotEmpty)
        .toSet() // deduplicates items if they visited the same site multiple times
        .toList();
    return siteNames.isNotEmpty ? siteNames.join(', ') : 'N/A';
  }

  /// NEW: Extracts and joins site IDs from visits
  static String getAggregatedSiteIds(MarkAttendanceData attendance) {
    if (attendance.visits.isEmpty) return 'N/A';
    final siteIds = attendance.visits
        .map((v) => v.siteId)
        .where((id) => id != null && id.trim().isNotEmpty)
        .toSet()
        .toList();
    return siteIds.isNotEmpty ? siteIds.join(', ') : 'N/A';
  }

  /// NEW: Combines site ID and name for display (e.g., "S001 - Main Office")
  static String getCombinedSiteInfo(MarkAttendanceData attendance) {
    if (attendance.visits.isEmpty) return 'N/A';
    
    final uniqueVisits = <String, String>{};
    for (var visit in attendance.visits) {
      final id = visit.siteId ?? 'N/A';
      final name = visit.siteName;
      uniqueVisits[id] = name; // This will keep unique by ID
    }
    
    final List<String> combined = [];
    uniqueVisits.forEach((id, name) {
      if (id == 'N/A') {
        combined.add(name);
      } else {
        combined.add('$id - $name');
      }
    });
    
    return combined.join(', ');
  }

  static int compareAttendanceData(
    MarkAttendanceData a,
    MarkAttendanceData b,
    String column,
  ) {
    switch (column) {
      case 'Date':
        return (a.attendanceDate ?? DateTime(0))
            .compareTo(b.attendanceDate ?? DateTime(0));
      case 'Name':
        return a.employeeName.compareTo(b.employeeName);
      case 'ID':
        return a.employeeId.compareTo(b.employeeId);
      case 'Status':
        return a.status.compareTo(b.status);
      case 'Time In':
        return (a.officeTimeIn ?? DateTime(0))
            .compareTo(b.officeTimeIn ?? DateTime(0));
      case 'Time Out':
        return (a.officeTimeOut ?? DateTime(0))
            .compareTo(b.officeTimeOut ?? DateTime(0));
      case 'Mobile':
        return (a.mobileNumber ?? '').compareTo(b.mobileNumber ?? '');
      case 'Site ID':  // NEW: Add sorting for Site ID
        return getAggregatedSiteIds(a).compareTo(getAggregatedSiteIds(b));
      case 'Site Name':
        // FIXED: Sorts based on parsed multi-visit site string aggregations
        return getAggregatedSiteNames(a).compareTo(getAggregatedSiteNames(b));
      case 'Total Hours':
        return (a.totalAttendanceHours ?? '')
            .compareTo(b.totalAttendanceHours ?? '');
      case 'Total Permission Hours':
        return (a.totalPermissionHours ?? '')
            .compareTo(b.totalPermissionHours ?? '');
      case 'Permission Time In':
        // FIXED: Corrected reference pairing bug (was checking b vs b)
        return (a.permissionTimeIn ?? DateTime(0))
            .compareTo(b.permissionTimeIn ?? DateTime(0));
      case 'Permission Time Out':
        return (a.permissionTimeOut ?? DateTime(0))
            .compareTo(b.permissionTimeOut ?? DateTime(0));
      default:
        return 0;
    }
  }

  static Widget buildCellContent(String column, MarkAttendanceData attendance) {
    switch (column) {
      case 'Date':
        return Text(
          formatDate(attendance.attendanceDate),
          style: const TextStyle(fontSize: 12, height: 1.1),
        );
      case 'Name':
        return Text(
          attendance.employeeName,
          style: const TextStyle(fontSize: 12, height: 1.1),
        );
      case 'ID':
        return Text(
          attendance.employeeId,
          style: const TextStyle(fontSize: 12, height: 1.1),
        );
      case 'Status':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: getStatusColor(attendance.status).withAlpha(51),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: getStatusColor(attendance.status),
              width: 1,
            ),
          ),
          child: Text(
            attendance.status.toUpperCase(),
            style: TextStyle(
              color: getStatusColor(attendance.status),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
        );
      case 'Time In':
        return Text(
          formatTime(attendance.officeTimeIn),
          style: const TextStyle(fontSize: 12, height: 1.1),
        );
      case 'Time Out':
        return Text(
          formatTime(attendance.officeTimeOut),
          style: const TextStyle(fontSize: 12, height: 1.1),
        );
      case 'Mobile':
        return Text(
          attendance.mobileNumber ?? 'N/A',
          style: const TextStyle(fontSize: 12, height: 1.1),
        );
      case 'Site ID':  // NEW: Display site IDs
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue.shade200, width: 0.5),
          ),
          child: Text(
            getAggregatedSiteIds(attendance),
            style: const TextStyle(
              fontSize: 11, 
              height: 1.1,
              fontWeight: FontWeight.w500,
              color: Colors.blue,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      case 'Site Name':
        // FIXED: Renders joined multi-site list dynamically inside ui tables
        return Text(
          getAggregatedSiteNames(attendance),
          style: const TextStyle(fontSize: 12, height: 1.1),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      case 'Total Hours':
        return Text(
          attendance.totalAttendanceHours ?? 'N/A',
          style: const TextStyle(fontSize: 12, height: 1.1),
        );
      case 'Total Permission Hours':
        return Text(
          attendance.totalPermissionHours ?? 'N/A',
          style: const TextStyle(fontSize: 12, height: 1.1),
        );
      case 'Permission Time In':
        return Text(
          formatTime(attendance.permissionTimeIn),
          style: const TextStyle(fontSize: 12, height: 1.1),
        );
      case 'Permission Time Out':
        return Text(
          formatTime(attendance.permissionTimeOut),
          style: const TextStyle(fontSize: 12, height: 1.1),
        );
      default:
        return const Text('N/A', style: TextStyle(fontSize: 12, height: 1.1));
    }
  }
}