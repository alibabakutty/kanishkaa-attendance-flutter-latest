// lib/screens/attendance_history/utils/constants.dart

class AttendanceReportConstants {
  static const List<String> allAvailableColumns = [
    'Date',
    'Name',
    'ID',
    'Status',
    'Time In',
    'Time Out',
    'Mobile',
    'Site ID',
    'Site Name',
    'Total Hours',
    'Total Permission Hours',
    'Permission Time In',
    'Permission Time Out',
  ];

  static const List<String> defaultColumns = [
    'Date',
    'Name',
    'Status',
    'Time In',
    'Site ID',
    'Site Name',
    'Total Hours',
  ];

  static const List<String> searchTypes = [
    'date',
    'name',
    'id',
    'mobile',
  ];
}