class CumulativeAttendanceModel {
  final String employeeId;
  final String employeeName;
  final String mobileNumber;
  final String month;
  final String financialYear;
  final String totalMonthEndWorkedHours;
  final String totalMonthEndPermissionHours;
  final String totalMonthEndNetHours;

  CumulativeAttendanceModel({
    required this.employeeId,
    required this.employeeName,
    required this.mobileNumber,
    required this.month,
    required this.financialYear,
    required this.totalMonthEndWorkedHours,
    required this.totalMonthEndPermissionHours,
    required this.totalMonthEndNetHours,
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
      totalMonthEndWorkedHours:
          json['totalMonthEndWorkedHours']?.toString() ?? '0 hrs 0 mins',
      totalMonthEndPermissionHours:
          json['totalMonthEndPermissionHours']?.toString() ?? '0 hrs 0 mins',
      totalMonthEndNetHours:
          json['totalMonthEndNetHours']?.toString() ?? '0 hrs 0 mins',
    );
  }
}