
class AttendanceHoliday {
  final int id;
  final DateTime holidayDate;
  final HolidayType holidayType;
  final String holidayName;
  final String? description;
  final bool active;

  const AttendanceHoliday({
    required this.id,
    required this.holidayDate,
    required this.holidayType,
    required this.holidayName,
    this.description,
    required this.active,
  });

  factory AttendanceHoliday.fromJson(
    Map<String, dynamic> json,
  ) {
    return AttendanceHoliday(
      id: _parseInt(json['id']),
      holidayDate: DateTime.parse(
        json['holidayDate'].toString(),
      ),
      holidayType: HolidayType.fromJson(
        json['holidayType'],
      ),
      holidayName: json['holidayName']?.toString() ?? '',
      description: json['description']?.toString(),
      active: _parseBool(json['active']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'holidayDate': _formatDate(holidayDate),
      'holidayType': holidayType.value,
      'holidayName': holidayName,
      'description': description,
      'active': active,
    };
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value == null) {
      return false;
    }

    return value.toString().toLowerCase() == 'true';
  }

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

// ============================================================
// HOLIDAY TYPE
// Matches backend HolidayType.java exactly
// ============================================================

enum HolidayType {
  publicHoliday,
  companyHoliday,
  weeklyOff;

  // ==========================================================
  // Backend value
  // ==========================================================

  String get value {
    switch (this) {
      case HolidayType.publicHoliday:
        return 'PUBLIC_HOLIDAY';

      case HolidayType.companyHoliday:
        return 'COMPANY_HOLIDAY';

      case HolidayType.weeklyOff:
        return 'WEEKLY_OFF';
    }
  }

  // ==========================================================
  // Convert backend JSON -> Flutter enum
  // ==========================================================

  static HolidayType fromJson(dynamic value) {
    switch (value?.toString()) {
      case 'PUBLIC_HOLIDAY':
        return HolidayType.publicHoliday;

      case 'COMPANY_HOLIDAY':
        return HolidayType.companyHoliday;

      case 'WEEKLY_OFF':
        return HolidayType.weeklyOff;

      default:
        return HolidayType.publicHoliday;
    }
  }

  // ==========================================================
  // User-friendly display name
  // ==========================================================

  String get displayName {
    switch (this) {
      case HolidayType.publicHoliday:
        return 'Public Holiday';

      case HolidayType.companyHoliday:
        return 'Company Holiday';

      case HolidayType.weeklyOff:
        return 'Weekly Off';
    }
  }
}

// ============================================================
// CREATE REQUEST MODEL
// ============================================================

class AttendanceHolidayRequest {
  final DateTime holidayDate;
  final HolidayType holidayType;
  final String holidayName;
  final String? description;

  const AttendanceHolidayRequest({
    required this.holidayDate,
    required this.holidayType,
    required this.holidayName,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'holidayDate': _formatDate(holidayDate),
      'holidayType': holidayType.value,
      'holidayName': holidayName.trim(),
      'description': description?.trim().isEmpty == true
          ? null
          : description?.trim(),
    };
  }

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}