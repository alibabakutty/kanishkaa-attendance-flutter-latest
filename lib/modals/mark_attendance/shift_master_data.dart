
import 'package:attendance_app/modals/mark_attendance/attendance_duration.dart';

class ShiftMasterData {
  final int? id;
  final String? shiftCode;
  final String? shiftName;
  final String? shiftType;
  final String? scheduledStartTime;
  final String? scheduledEndTime;
  final bool? crossesMidnight;
  final Duration? scheduledHours;
  final bool? active;

  const ShiftMasterData({
    this.id,
    this.shiftCode,
    this.shiftName,
    this.shiftType,
    this.scheduledStartTime,
    this.scheduledEndTime,
    this.crossesMidnight,
    this.scheduledHours,
    this.active,
  });

  factory ShiftMasterData.fromJson(Map<String, dynamic> json) {
    return ShiftMasterData(
      id: _int(json['id']),
      shiftCode: json['shiftCode']?.toString(),
      shiftName: json['shiftName']?.toString(),
      shiftType: json['shiftType']?.toString(),
      scheduledStartTime: json['scheduledStartTime']?.toString(),
      scheduledEndTime: json['scheduledEndTime']?.toString(),
      crossesMidnight: json['crossesMidnight'] as bool?,
      scheduledHours: AttendanceDuration.parse(json['scheduledHours']),
      active: json['active'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'shiftCode': shiftCode,
        'shiftName': shiftName,
        'shiftType': shiftType,
        'scheduledStartTime': scheduledStartTime,
        'scheduledEndTime': scheduledEndTime,
        'crossesMidnight': crossesMidnight,
        'scheduledHours': AttendanceDuration.toIso(scheduledHours),
        'active': active,
      };

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}