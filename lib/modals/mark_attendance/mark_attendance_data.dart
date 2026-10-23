
import 'package:attendance_app/modals/geopoint.dart';
import 'package:attendance_app/modals/mark_attendance/attendance_duration.dart';
import 'package:attendance_app/modals/mark_attendance/attendance_shift_session_data.dart';

class MarkAttendanceData {
  final int? id;

  final String? employeeId;
  final String? employeeName;
  final String? mobileNumber;

  final DateTime? attendanceDate;
  final String? attendanceDayType;

  final DateTime? officeTimeIn;
  final GeoPoint? officeTimeInLocation;
  final DateTime? officeTimeOut;
  final GeoPoint? officeTimeOutLocation;

  final String? status;
  final String? approvalStatus;
  final String? attendanceState;

  final List<AttendanceShiftSessionData> shiftSessions;

  final Duration? totalAttendanceHours;
  final Duration? regularHours;
  final Duration? overtimeHours;

  final DateTime? permissionTimeIn;
  final GeoPoint? permissionTimeInLocation;
  final DateTime? permissionTimeOut;
  final GeoPoint? permissionTimeOutLocation;
  final Duration? totalPermissionHours;

  final String? adminApprovedBy;
  final DateTime? approvedAt;

  final String? tallyAttendanceStatus;
  final String? tallyPermissionStatus;

  final Duration? totalMonthEndWorkedHours;
  final Duration? totalMonthEndPermissionHours;
  final Duration? totalMonthEndNetHours;

  final String? formattedTotalMonthEndNetHours;
  final String? formattedTotalMonthEndPermissionHours;
  final String? formattedTotalMonthEndWorkedHours;

  const MarkAttendanceData({
    this.id,
    this.employeeId,
    this.employeeName,
    this.mobileNumber,
    this.attendanceDate,
    this.attendanceDayType,
    this.officeTimeIn,
    this.officeTimeInLocation,
    this.officeTimeOut,
    this.officeTimeOutLocation,
    this.status,
    this.approvalStatus,
    this.attendanceState,
    this.shiftSessions = const [],
    this.totalAttendanceHours,
    this.regularHours,
    this.overtimeHours,
    this.permissionTimeIn,
    this.permissionTimeInLocation,
    this.permissionTimeOut,
    this.permissionTimeOutLocation,
    this.totalPermissionHours,
    this.adminApprovedBy,
    this.approvedAt,
    this.tallyAttendanceStatus,
    this.tallyPermissionStatus,
    this.totalMonthEndWorkedHours,
    this.totalMonthEndPermissionHours,
    this.totalMonthEndNetHours,
    this.formattedTotalMonthEndNetHours,
    this.formattedTotalMonthEndPermissionHours,
    this.formattedTotalMonthEndWorkedHours,
  });

  factory MarkAttendanceData.fromJson(Map<String, dynamic> json) {
    final parsedAttendanceDate = _dateOnly(json['attendanceDate']);

    final sessionsJson = json['shiftSessions'];
    final sessionList = sessionsJson is List ? sessionsJson : const [];

    return MarkAttendanceData(
      id: _int(json['id']),
      employeeId: json['employeeId']?.toString(),
      employeeName: json['employeeName']?.toString(),
      mobileNumber: json['mobileNumber']?.toString(),
      attendanceDate: parsedAttendanceDate,
      attendanceDayType: json['attendanceDayType']?.toString(),

      officeTimeIn: _dateTime(json['officeTimeIn'], parsedAttendanceDate),
      officeTimeInLocation: _geoPoint(json['officeTimeInLocation']),
      officeTimeOut: _dateTime(json['officeTimeOut'], parsedAttendanceDate),
      officeTimeOutLocation: _geoPoint(json['officeTimeOutLocation']),

      status: json['status']?.toString(),
      approvalStatus: json['approvalStatus']?.toString(),
      attendanceState: json['attendanceState']?.toString(),

      shiftSessions: sessionList
          .whereType<Map>()
          .map(
            (item) => AttendanceShiftSessionData.fromJson(
              Map<String, dynamic>.from(item),
              referenceDate: parsedAttendanceDate,
            ),
          )
          .toList(),

      totalAttendanceHours:
          AttendanceDuration.parse(json['totalAttendanceHours']),
      regularHours: AttendanceDuration.parse(json['regularHours']),
      overtimeHours: AttendanceDuration.parse(json['overtimeHours']),

      permissionTimeIn:
          _dateTime(json['permissionTimeIn'], parsedAttendanceDate),
      permissionTimeInLocation: _geoPoint(json['permissionTimeInLocation']),
      permissionTimeOut:
          _dateTime(json['permissionTimeOut'], parsedAttendanceDate),
      permissionTimeOutLocation:
          _geoPoint(json['permissionTimeOutLocation']),
      totalPermissionHours:
          AttendanceDuration.parse(json['totalPermissionHours']),

      adminApprovedBy: json['adminApprovedBy']?.toString(),
      approvedAt: _dateTime(json['approvedAt'], parsedAttendanceDate),

      tallyAttendanceStatus: json['tallyAttendanceStatus']?.toString(),
      tallyPermissionStatus: json['tallyPermissionStatus']?.toString(),

      totalMonthEndWorkedHours:
          AttendanceDuration.parse(json['totalMonthEndWorkedHours']),
      totalMonthEndPermissionHours:
          AttendanceDuration.parse(json['totalMonthEndPermissionHours']),
      totalMonthEndNetHours:
          AttendanceDuration.parse(json['totalMonthEndNetHours']),

      formattedTotalMonthEndNetHours:
          json['formattedTotalMonthEndNetHours']?.toString(),
      formattedTotalMonthEndPermissionHours:
          json['formattedTotalMonthEndPermissionHours']?.toString(),
      formattedTotalMonthEndWorkedHours:
          json['formattedTotalMonthEndWorkedHours']?.toString(),
    );
  }

  /// Use this when sending an attendance request to the backend.
  /// Server-generated fields are intentionally excluded.
  Map<String, dynamic> toRequestJson() => {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'mobileNumber': mobileNumber,
        'attendanceDate': _dateOnlyString(attendanceDate),
        'status': status,
        'shiftSessions':
            shiftSessions.map((session) => session.toRequestJson()).toList(),
        'officeTimeInLocation': officeTimeInLocation?.toJson(),
        'officeTimeOutLocation': officeTimeOutLocation?.toJson(),
        'permissionTimeInLocation': permissionTimeInLocation?.toJson(),
        'permissionTimeOutLocation': permissionTimeOutLocation?.toJson(),
        'tallyAttendanceStatus': tallyAttendanceStatus,
        'tallyPermissionStatus': tallyPermissionStatus,
      };

  /// Serializes the full response model, including server-generated fields.
  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'mobileNumber': mobileNumber,
        'attendanceDate': _dateOnlyString(attendanceDate),
        'attendanceDayType': attendanceDayType,

        'officeTimeIn': officeTimeIn?.toIso8601String(),
        'officeTimeInLocation': officeTimeInLocation?.toJson(),
        'officeTimeOut': officeTimeOut?.toIso8601String(),
        'officeTimeOutLocation': officeTimeOutLocation?.toJson(),

        'status': status,
        'approvalStatus': approvalStatus,
        'attendanceState': attendanceState,

        'shiftSessions': shiftSessions.map((session) => session.toJson()).toList(),

        'totalAttendanceHours':
            AttendanceDuration.toIso(totalAttendanceHours),
        'regularHours': AttendanceDuration.toIso(regularHours),
        'overtimeHours': AttendanceDuration.toIso(overtimeHours),

        'permissionTimeIn': permissionTimeIn?.toIso8601String(),
        'permissionTimeInLocation': permissionTimeInLocation?.toJson(),
        'permissionTimeOut': permissionTimeOut?.toIso8601String(),
        'permissionTimeOutLocation': permissionTimeOutLocation?.toJson(),
        'totalPermissionHours': AttendanceDuration.toIso(totalPermissionHours),

        'adminApprovedBy': adminApprovedBy,
        'approvedAt': approvedAt?.toIso8601String(),

        'tallyAttendanceStatus': tallyAttendanceStatus,
        'tallyPermissionStatus': tallyPermissionStatus,

        'totalMonthEndWorkedHours':
            AttendanceDuration.toIso(totalMonthEndWorkedHours),
        'totalMonthEndPermissionHours':
            AttendanceDuration.toIso(totalMonthEndPermissionHours),
        'totalMonthEndNetHours':
            AttendanceDuration.toIso(totalMonthEndNetHours),

        'formattedTotalMonthEndNetHours': formattedTotalMonthEndNetHours,
        'formattedTotalMonthEndPermissionHours':
            formattedTotalMonthEndPermissionHours,
        'formattedTotalMonthEndWorkedHours':
            formattedTotalMonthEndWorkedHours,
      };

  static DateTime? _dateOnly(dynamic value) {
    if (value == null) return null;

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return null;

    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String? _dateOnlyString(DateTime? value) {
    if (value == null) return null;

    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _dateTime(dynamic value, DateTime? referenceDate) {
    if (value == null) return null;

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    // Full ISO datetime, e.g. 2026-10-10T14:58:51.2092964
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    // Time-only value, e.g. 09:00:00
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?$',
    ).firstMatch(text);

    if (match == null || referenceDate == null) return null;

    final fraction = match.group(4) ?? '';
    final milliseconds = int.tryParse(
          fraction.padRight(3, '0').substring(0, 3),
        ) ??
        0;

    return DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.tryParse(match.group(3) ?? '0') ?? 0,
      milliseconds,
    );
  }

  static GeoPoint? _geoPoint(dynamic value) {
    if (value is Map) {
      return GeoPoint.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}