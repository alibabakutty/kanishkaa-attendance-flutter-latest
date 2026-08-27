import 'package:attendance_app/modals/geopoint.dart';

class AttendanceVisitData {
  final int? id;
  final String? siteId;
  final String siteName;
  final String visitType;
  final DateTime? timeIn;
  final GeoPoint? timeInLocation;
  final DateTime? timeOut;
  final GeoPoint? timeOutLocation;
  final String? visitDuration;
  final bool isCustomSite;
  final bool? geofenceVerified;
  final String? remarks;

  AttendanceVisitData({
    this.id,
    this.siteId,
    required this.siteName,
    required this.visitType,
    this.timeIn,
    this.timeInLocation,
    this.timeOut,
    this.timeOutLocation,
    this.visitDuration,
    required this.isCustomSite,
    this.geofenceVerified,
    this.remarks,
  });

  factory AttendanceVisitData.fromJson(Map<String, dynamic> json, String? baseDate) {
    return AttendanceVisitData(
      id: json['id'],
      siteId: json['siteId'],
      siteName: json['siteName'] ?? '',
      visitType: json['visitType'] ?? 'REGULAR_SITE',
      timeIn: json['timeIn'] != null && baseDate != null
          ? DateTime.parse('${baseDate}T${json['timeIn']}')
          : null,
      timeInLocation: json['timeInLocation'] != null
          ? GeoPoint.fromJson(json['timeInLocation'])
          : null,
      timeOut: json['timeOut'] != null && baseDate != null
          ? DateTime.parse('${baseDate}T${json['timeOut']}')
          : null,
      timeOutLocation: json['timeOutLocation'] != null
          ? GeoPoint.fromJson(json['timeOutLocation'])
          : null,
      visitDuration: json['visitDuration'],
      isCustomSite: json['isCustomSite'] ?? false,
      geofenceVerified: json['geofenceVerified'],
      remarks: json['remarks'],
    );
  }

  Map<String, dynamic> toJson() {
    String? formatTimeString(DateTime? dt) {
      if (dt == null) return null;
      return "${dt.hour.toString().padLeft(2, '0')}:"
             "${dt.minute.toString().padLeft(2, '0')}:"
             "${dt.second.toString().padLeft(2, '0')}";
    }

    return {
      if (id != null) "id": id,
      if (siteId != null) "siteId": siteId,
      "siteName": siteName,
      "visitType": visitType,
      "timeIn": formatTimeString(timeIn),
      "timeInLocation": timeInLocation?.toJson(),
      "timeOut": formatTimeString(timeOut),
      "timeOutLocation": timeOutLocation?.toJson(),
      "isCustomSite": isCustomSite,
      if (remarks != null) "remarks": remarks,
    };
  }
}