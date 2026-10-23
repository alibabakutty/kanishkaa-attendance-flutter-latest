
import 'package:attendance_app/modals/geopoint.dart';
import 'package:attendance_app/modals/mark_attendance/attendance_duration.dart';
import 'package:attendance_app/modals/mark_attendance/attendance_visit_data.dart';
import 'package:attendance_app/modals/mark_attendance/shift_master_data.dart';

class AttendanceShiftSessionData {
  final int? id;
  final ShiftMasterData? shiftMaster;
  final String? shiftType;
  final DateTime? workDate;
  final DateTime? timeIn;
  final GeoPoint? timeInLocation;
  final DateTime? timeOut;
  final GeoPoint? timeOutLocation;
  final Duration? workedHours;
  final Duration? overtimeHours;
  final String? sessionStatus;
  final String? remarks;
  final List<AttendanceVisitData> visits;

  const AttendanceShiftSessionData({
    this.id,
    this.shiftMaster,
    this.shiftType,
    this.workDate,
    this.timeIn,
    this.timeInLocation,
    this.timeOut,
    this.timeOutLocation,
    this.workedHours,
    this.overtimeHours,
    this.sessionStatus,
    this.remarks,
    this.visits = const [],
  });

  factory AttendanceShiftSessionData.fromJson(
    Map<String, dynamic> json, {
    DateTime? referenceDate,
  }) {
    final parsedWorkDate =
        _dateOnly(json['workDate']) ?? referenceDate;

    final visitsJson = json['visits'];
    final visitList = visitsJson is List ? visitsJson : const [];

    return AttendanceShiftSessionData(
      id: _int(json['id']),
      shiftMaster: json['shiftMaster'] is Map
          ? ShiftMasterData.fromJson(
              Map<String, dynamic>.from(json['shiftMaster'] as Map),
            )
          : null,
      shiftType: json['shiftType']?.toString(),
      workDate: parsedWorkDate,
      timeIn: _dateTime(json['timeIn'], parsedWorkDate),
      timeInLocation: _geoPoint(json['timeInLocation']),
      timeOut: _dateTime(json['timeOut'], parsedWorkDate),
      timeOutLocation: _geoPoint(json['timeOutLocation']),
      workedHours: AttendanceDuration.parse(json['workedHours']),
      overtimeHours: AttendanceDuration.parse(json['overtimeHours']),
      sessionStatus: json['sessionStatus']?.toString(),
      remarks: json['remarks']?.toString(),
      visits: visitList
          .whereType<Map>()
          .map(
            (item) => AttendanceVisitData.fromJson(
              Map<String, dynamic>.from(item),
              referenceDate: parsedWorkDate,
            ),
          )
          .toList(),
    );
  }

  /// Request JSON: sends the fields from the attendance request.
  Map<String, dynamic> toRequestJson() => {
        'shiftType': shiftType,
        'timeIn': _timeOnly(timeIn),
        'timeInLocation': timeInLocation?.toJson(),
        'timeOut': _timeOnly(timeOut),
        'timeOutLocation': timeOutLocation?.toJson(),
        'visits': visits.map((visit) => visit.toRequestJson()).toList(),
        'remarks': remarks,
      };

  /// Response JSON: includes server-generated fields.
  Map<String, dynamic> toJson() => {
        'id': id,
        'shiftMaster': shiftMaster?.toJson(),
        'shiftType': shiftType,
        'workDate': _dateOnlyString(workDate),
        'timeIn': timeIn?.toIso8601String(),
        'timeInLocation': timeInLocation?.toJson(),
        'timeOut': timeOut?.toIso8601String(),
        'timeOutLocation': timeOutLocation?.toJson(),
        'workedHours': AttendanceDuration.toIso(workedHours),
        'overtimeHours': AttendanceDuration.toIso(overtimeHours),
        'sessionStatus': sessionStatus,
        'remarks': remarks,
        'visits': visits.map((visit) => visit.toJson()).toList(),
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

    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

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

  static String? _timeOnly(DateTime? value) {
    if (value == null) return null;
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}';
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