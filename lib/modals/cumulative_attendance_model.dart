class CumulativeAttendanceModel {
  final String employeeId;
  final String employeeName;
  final String mobileNumber;
  final String month;
  final String financialYear;
  final int totalPresentDays;
  final int totalHalfDayDays;
  final int totalAbsentDays;
  final String totalMonthEndWorkedHours;
  final String totalSundayHours;
  final String totalMonthEndPermissionHours;
  final String totalMonthEndNetHours;
  final String overTimeHours;
  final String totalGrossHours;

  CumulativeAttendanceModel({
    required this.employeeId,
    required this.employeeName,
    required this.mobileNumber,
    required this.month,
    required this.financialYear,
    required this.totalPresentDays,
    required this.totalHalfDayDays,
    required this.totalAbsentDays,
    required this.totalMonthEndWorkedHours,
    required this.totalSundayHours,
    required this.totalMonthEndPermissionHours,
    required this.totalMonthEndNetHours,
    required this.overTimeHours,
    required this.totalGrossHours
  });

  factory CumulativeAttendanceModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return CumulativeAttendanceModel(
      employeeId: json['employeeId']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? '',
      mobileNumber: json['mobileNumber']?.toString() ?? '',
      month: json['month']?.toString() ?? '',
      financialYear: json['financialYear']?.toString() ?? '',
      totalPresentDays:
        int.tryParse(json['totalMonthEndPresentDays']?.toString() ?? '0') ?? 0,
      totalHalfDayDays:
        int.tryParse(json['totalMonthEndHalfDayDays']?.toString() ?? '0') ?? 0,
      totalAbsentDays:
        int.tryParse(json['totalMonthEndAbsentDays']?.toString() ?? '0') ?? 0,
      totalMonthEndWorkedHours:
          json['totalMonthEndWorkedHours']?.toString() ?? '0 hrs 0 mins',
      totalSundayHours:
          json['totalMonthEndSundayHours']?.toString() ?? '32 hrs',
      totalMonthEndPermissionHours:
          json['totalMonthEndPermissionHours']?.toString() ?? '0 hrs 0 mins',
      totalMonthEndNetHours:
          json['totalMonthEndNetHours']?.toString() ?? '0 hrs 0 mins',
      overTimeHours:
          json['totalMonthEndOvertimeHours']?.toString() ?? '0 hrs 0 mins',
      totalGrossHours: 
          json['totalMonthEndGrossHours']?.toString() ?? '0 hrs 0 mins'
    );
  }
}