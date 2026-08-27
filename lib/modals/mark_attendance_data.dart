import 'package:attendance_app/modals/geopoint.dart';
import 'attendance_visit_data.dart';

class MarkAttendanceData {
  final String employeeId;
  final String employeeName;
  final String? mobileNumber;
  final DateTime? attendanceDate;
  
  // Shift bookends
  final DateTime? officeTimeIn;
  final GeoPoint? officeTimeInLocation;
  final DateTime? officeTimeOut;
  final GeoPoint? officeTimeOutLocation;
  final String? totalAttendanceHours;
  
  // Multi-visit collection list
  final List<AttendanceVisitData> visits;

  // Permissions
  final DateTime? permissionTimeIn;
  final GeoPoint? permissionTimeInLocation;
  final DateTime? permissionTimeOut;
  final GeoPoint? permissionTimeOutLocation;
  final String? totalPermissionHours;
  
  final String status;
  final String? tallyAttendanceStatus;
  final String? tallyPermissionStatus;

  MarkAttendanceData({
    required this.employeeId,
    required this.employeeName,
    this.mobileNumber,
    this.attendanceDate,
    this.officeTimeIn,
    this.officeTimeInLocation,
    this.officeTimeOut,
    this.officeTimeOutLocation,
    this.totalAttendanceHours,
    required this.visits,
    this.permissionTimeIn,
    this.permissionTimeInLocation,
    this.permissionTimeOut,
    this.permissionTimeOutLocation,
    this.totalPermissionHours,
    required this.status,
    this.tallyAttendanceStatus,
    this.tallyPermissionStatus,
  });

  factory MarkAttendanceData.fromJson(Map<String, dynamic> json) {
    final String? baseDateString = json['attendanceDate'];
    
    // Parse nested child visits list safely
    var visitsList = json['visits'] as List?;
    List<AttendanceVisitData> parsedVisits = visitsList != null
        ? visitsList.map((v) => AttendanceVisitData.fromJson(v, baseDateString)).toList()
        : [];

    return MarkAttendanceData(
      employeeId: json['employeeId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      mobileNumber: json['mobileNumber'],
      attendanceDate: baseDateString != null ? DateTime.parse(baseDateString) : null,
      
      officeTimeIn: json['officeTimeIn'] != null && baseDateString != null
          ? DateTime.parse('${baseDateString}T${json['officeTimeIn']}')
          : null,
      officeTimeInLocation: json['officeTimeInLocation'] != null
          ? GeoPoint.fromJson(json['officeTimeInLocation'])
          : null,
      officeTimeOut: json['officeTimeOut'] != null && baseDateString != null
          ? DateTime.parse('${baseDateString}T${json['officeTimeOut']}')
          : null,
      officeTimeOutLocation: json['officeTimeOutLocation'] != null
          ? GeoPoint.fromJson(json['officeTimeOutLocation'])
          : null,
      totalAttendanceHours: json['totalAttendanceHours'],
      
      visits: parsedVisits, // Assign the child objects array
      
      permissionTimeIn: json['permissionTimeIn'] != null && baseDateString != null
          ? DateTime.parse('${baseDateString}T${json['permissionTimeIn']}')
          : null,
      permissionTimeInLocation: json['permissionTimeInLocation'] != null
          ? GeoPoint.fromJson(json['permissionTimeInLocation'])
          : null,
      permissionTimeOut: json['permissionTimeOut'] != null && baseDateString != null
          ? DateTime.parse('${baseDateString}T${json['permissionTimeOut']}')
          : null,
      permissionTimeOutLocation: json['permissionTimeOutLocation'] != null
          ? GeoPoint.fromJson(json['permissionTimeOutLocation'])
          : null,
      totalPermissionHours: json['totalPermissionHours'],
      
      status: json['status'] ?? 'ABSENT',
      tallyAttendanceStatus: json['tallyAttendanceStatus'],
      tallyPermissionStatus: json['tallyPermissionStatus'],
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
      "employeeId": employeeId,
      "employeeName": employeeName,
      "mobileNumber": mobileNumber,
      "attendanceDate": attendanceDate?.toIso8601String().split('T')[0],
      
      "officeTimeIn": formatTimeString(officeTimeIn),
      "officeTimeInLocation": officeTimeInLocation?.toJson(),
      "officeTimeOut": formatTimeString(officeTimeOut),
      "officeTimeOutLocation": officeTimeOutLocation?.toJson(),
      "totalAttendanceHours": totalAttendanceHours,
      
      // Serialize lists out seamlessly to Spring Boot mapping layers
      "visits": visits.map((v) => v.toJson()).toList(),
      
      "permissionTimeIn": formatTimeString(permissionTimeIn),
      "permissionTimeInLocation": permissionTimeInLocation?.toJson(),
      "permissionTimeOut": formatTimeString(permissionTimeOut),
      "permissionTimeOutLocation": permissionTimeOutLocation?.toJson(),
      "totalPermissionHours": totalPermissionHours,
      
      "status": status,
      "tallyAttendanceStatus": tallyAttendanceStatus,
      "tallyPermissionStatus": tallyPermissionStatus
    };
  }
}