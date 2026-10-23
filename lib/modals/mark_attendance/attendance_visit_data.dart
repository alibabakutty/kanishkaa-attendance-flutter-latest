
import 'package:attendance_app/modals/geopoint.dart';
import 'package:attendance_app/modals/mark_attendance/attendance_duration.dart';

class AttendanceVisitData {
  final int? id;
  final String? siteId;
  final String? siteName;
  final String? visitType;

  final DateTime? timeIn;
  final GeoPoint? timeInLocation;

  final DateTime? timeOut;
  final GeoPoint? timeOutLocation;

  final bool? customSite;
  final bool? geofenceVerified;
  final Duration? visitDuration;
  final String? remarks;

  const AttendanceVisitData({
    this.id,
    this.siteId,
    this.siteName,
    this.visitType,
    this.timeIn,
    this.timeInLocation,
    this.timeOut,
    this.timeOutLocation,
    this.customSite,
    this.geofenceVerified,
    this.visitDuration,
    this.remarks,
  });

  factory AttendanceVisitData.fromJson(
    Map<String, dynamic> json, {
    DateTime? referenceDate,
  }) {
    return AttendanceVisitData(
      id: _toInt(json['id']),
      siteId: json['siteId']?.toString(),
      siteName: json['siteName']?.toString(),
      visitType: json['visitType']?.toString(),

      timeIn: _parseDateTime(json['timeIn'], referenceDate),
      timeInLocation: _parseGeoPoint(json['timeInLocation']),

      timeOut: _parseDateTime(json['timeOut'], referenceDate),
      timeOutLocation: _parseGeoPoint(json['timeOutLocation']),

      customSite: json['customSite'] as bool?,
      geofenceVerified: json['geofenceVerified'] as bool?,

      visitDuration: AttendanceDuration.parse(json['visitDuration']),
      remarks: json['remarks']?.toString(),
    );
  }

  /// Use this method when sending visit data to the backend.
  /// Server-generated fields are intentionally excluded.
  Map<String, dynamic> toRequestJson() {
    return {
      'siteId': siteId,
      'siteName': siteName,
      'visitType': visitType,
      'timeInLocation': timeInLocation?.toJson(),
      'timeOutLocation': timeOutLocation?.toJson(),
      'customSite': customSite,
      'remarks': remarks,
    };
  }

  /// Use this method when serializing the complete response model.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'siteId': siteId,
      'siteName': siteName,
      'visitType': visitType,
      'timeIn': timeIn?.toIso8601String(),
      'timeInLocation': timeInLocation?.toJson(),
      'timeOut': timeOut?.toIso8601String(),
      'timeOutLocation': timeOutLocation?.toJson(),
      'customSite': customSite,
      'geofenceVerified': geofenceVerified,
      'visitDuration': AttendanceDuration.toIso(visitDuration),
      'remarks': remarks,
    };
  }

  static DateTime? _parseDateTime(
    dynamic value,
    DateTime? referenceDate,
  ) {
    if (value == null) return null;

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    // Handles full ISO datetime, such as:
    // 2026-10-10T14:58:51.2092964
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    // Handles time-only values, such as 09:00:00.
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?$',
    ).firstMatch(text);

    if (match == null || referenceDate == null) {
      return null;
    }

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

  static GeoPoint? _parseGeoPoint(dynamic value) {
    if (value is Map) {
      return GeoPoint.fromJson(
        Map<String, dynamic>.from(value),
      );
    }
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}