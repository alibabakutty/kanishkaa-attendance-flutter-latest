import 'dart:io';
import 'package:attendance_app/modals/mark_attendance_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class DayEndExcelExportService {
  static const _borderColor = '#808080';
  static const _headerColor = '#FF8C00';
  static const _bannerColor = '#FFFF00';
  static const _evenRowColor = '#F5F5F5';
  static const _statusPresentColor = '#C6EFCE';
  static const _statusHalfDayColor = '#FFC7CE';
  static const _statusAbsentColor = '#FFC7CE';

  static Future<String> exportToExcel(
    List<MarkAttendanceData> attendanceList, {
    required String? startDate,
    required String? endDate,
    required String searchType,
    String? employeeName,
    String? employeeId,
    String? mobileNumber,
    bool includeLocationData = false,
  }) async {
    try {
      // Sort attendance list by date
      final sortedList = List<MarkAttendanceData>.from(attendanceList)
        ..sort((a, b) {
          if (a.attendanceDate == null && b.attendanceDate == null) return 0;
          if (a.attendanceDate == null) return 1;
          if (b.attendanceDate == null) return -1;
          return a.attendanceDate!.compareTo(b.attendanceDate!);
        });

      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];
      sheet.showGridlines = true;

      // Set sheet name with date
      final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
      sheet.name = 'Attendance_Report_$dateStr';

      _addDataTable(sheet, sortedList);
      _applyFormatting(sheet, sortedList.length + 4);

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      return await _saveFile(bytes, sortedList.length);
    } catch (e) {
      throw Exception('Failed to export Excel: $e');
    }
  }

  static void _addDataTable(
    xlsio.Worksheet sheet,
    List<MarkAttendanceData> attendanceList,
  ) {
    const int startRow = 1;

    // 1. Title Banner Row - LARGER FONT
    final bannerRange = sheet.getRangeByIndex(startRow, 1, startRow, 15);
    bannerRange.merge();
    
    String title = 'KANISHKAA ATTENDANCE REPORT - DAY END';
    if (attendanceList.isNotEmpty && attendanceList.first.attendanceDate != null) {
      final firstDate = attendanceList.first.attendanceDate!;
      final lastDate = attendanceList.last.attendanceDate!;
      
      if (firstDate.year == lastDate.year &&
          firstDate.month == lastDate.month &&
          firstDate.day == lastDate.day) {
        title = 'KANISHKAA ATTENDANCE - ${DateFormat('dd.MM.yyyy').format(firstDate)}';
      } else {
        title = 'KANISHKAA ATTENDANCE - ${DateFormat('dd.MM.yyyy').format(firstDate)} to ${DateFormat('dd.MM.yyyy').format(lastDate)}';
      }
    }
    
    bannerRange.setText(title);
    bannerRange.cellStyle.bold = true;
    bannerRange.cellStyle.fontSize = 16;
    bannerRange.cellStyle.backColor = _bannerColor;
    bannerRange.cellStyle.hAlign = xlsio.HAlignType.center;
    bannerRange.cellStyle.vAlign = xlsio.VAlignType.center;
    _addBorders(bannerRange);

    // 2. Header Row - LARGER FONT
    final headerRow = startRow + 1;
    final headers = [
      'S.No',
      'Date',
      'Employee ID',
      'Employee Name',
      'Site Name',
      'Time In',
      'Status In',
      'Time Out',
      'Status Out',
      'Total Hours',
      'Attendance Status',
      'Permission Time In',
      'Permission Time Out',
      'Permission Hours',
      'Permission Status',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(headerRow, i + 1);
      cell.setText(headers[i]);
      _styleHeaderCell(cell);
    }

    // 3. Data Rows - LARGER FONT
    for (int i = 0; i < attendanceList.length; i++) {
      final record = attendanceList[i];
      final row = headerRow + i + 1;

      // Extract and safely combine all unique site names from the visits array list
      String sitesText = '-';
      if (record.visits.isNotEmpty) {
        final siteNames = record.visits
            .map((v) => v.siteName)
            .where((name) => name.trim().isNotEmpty)
            .toSet() // Removes duplicates if they visited the same site twice
            .toList();
        if (siteNames.isNotEmpty) {
          sitesText = siteNames.join(', ');
        }
      }

      // S.No
      final snoCell = sheet.getRangeByIndex(row, 1);
      snoCell.setNumber(i + 1);
      snoCell.cellStyle.hAlign = xlsio.HAlignType.center;
      snoCell.cellStyle.fontSize = 12;

      // Date
      final dateCell = sheet.getRangeByIndex(row, 2);
      dateCell.setText(
        record.attendanceDate != null
            ? DateFormat('dd-MM-yyyy').format(record.attendanceDate!)
            : '-',
      );
      dateCell.cellStyle.hAlign = xlsio.HAlignType.center;
      dateCell.cellStyle.fontSize = 12;

      // Employee ID
      final empIdCell = sheet.getRangeByIndex(row, 3);
      empIdCell.setText(record.employeeId);
      empIdCell.cellStyle.hAlign = xlsio.HAlignType.center;
      empIdCell.cellStyle.fontSize = 12;

      // Employee Name
      final empNameCell = sheet.getRangeByIndex(row, 4);
      empNameCell.setText(record.employeeName);
      empNameCell.cellStyle.fontSize = 12;

      // Site Name (FIXED: Uses the formatted multi-site string variable)
      final siteCell = sheet.getRangeByIndex(row, 5);
      siteCell.setText(sitesText);
      siteCell.cellStyle.fontSize = 12;

      // Time In
      final timeInCell = sheet.getRangeByIndex(row, 6);
      timeInCell.setText(
        record.officeTimeIn != null ? _formatTime(record.officeTimeIn!) : '-',
      );
      timeInCell.cellStyle.hAlign = xlsio.HAlignType.center;
      timeInCell.cellStyle.fontSize = 12;

      // Status In
      final statusInCell = sheet.getRangeByIndex(row, 7);
      final statusInText = record.officeTimeIn != null ? 'Marked' : 'Not-Marked';
      statusInCell.setText(statusInText);
      statusInCell.cellStyle.hAlign = xlsio.HAlignType.center;
      statusInCell.cellStyle.fontSize = 12;
      statusInCell.cellStyle.bold = true;
      
      if (record.officeTimeIn != null) {
        statusInCell.cellStyle.fontColor = '#006400';
      } else {
        statusInCell.cellStyle.fontColor = '#8B0000';
      }

      // Time Out
      final timeOutCell = sheet.getRangeByIndex(row, 8);
      timeOutCell.setText(
        record.officeTimeOut != null ? _formatTime(record.officeTimeOut!) : '-',
      );
      timeOutCell.cellStyle.hAlign = xlsio.HAlignType.center;
      timeOutCell.cellStyle.fontSize = 12;

      // Status Out
      final statusOutCell = sheet.getRangeByIndex(row, 9);
      final statusOutText = record.officeTimeOut != null ? 'Marked' : 'Not-Marked';
      statusOutCell.setText(statusOutText);
      statusOutCell.cellStyle.hAlign = xlsio.HAlignType.center;
      statusOutCell.cellStyle.fontSize = 12;
      statusOutCell.cellStyle.bold = true;
      
      if (record.officeTimeOut != null) {
        statusOutCell.cellStyle.fontColor = '#006400';
      } else {
        statusOutCell.cellStyle.fontColor = '#8B0000';
      }

      // Total Hours
      final totalHoursCell = sheet.getRangeByIndex(row, 10);
      totalHoursCell.setText(record.totalAttendanceHours ?? '-');
      totalHoursCell.cellStyle.hAlign = xlsio.HAlignType.center;
      totalHoursCell.cellStyle.fontSize = 12;
      totalHoursCell.cellStyle.bold = true;

      // Attendance Status
      final statusCell = sheet.getRangeByIndex(row, 11);
      final status = record.status.toUpperCase();
      statusCell.setText(status);
      statusCell.cellStyle.hAlign = xlsio.HAlignType.center;
      statusCell.cellStyle.fontSize = 12;
      statusCell.cellStyle.bold = true;
      
      if (status == 'PRESENT') {
        statusCell.cellStyle.fontColor = '#006400';
        statusCell.cellStyle.backColor = _statusPresentColor;
      } else if (status == 'HALF_DAY') {
        statusCell.cellStyle.fontColor = '#8B0000';
        statusCell.cellStyle.backColor = _statusHalfDayColor;
      } else if (status == 'ABSENT') {
        statusCell.cellStyle.fontColor = '#8B0000';
        statusCell.cellStyle.backColor = _statusAbsentColor;
      }

      // Permission Time In
      final permTimeInCell = sheet.getRangeByIndex(row, 12);
      permTimeInCell.setText(
        record.permissionTimeIn != null
            ? _formatTime(record.permissionTimeIn!)
            : '-',
      );
      permTimeInCell.cellStyle.hAlign = xlsio.HAlignType.center;
      permTimeInCell.cellStyle.fontSize = 12;

      // Permission Time Out
      final permTimeOutCell = sheet.getRangeByIndex(row, 13);
      permTimeOutCell.setText(
        record.permissionTimeOut != null
            ? _formatTime(record.permissionTimeOut!)
            : '-',
      );
      permTimeOutCell.cellStyle.hAlign = xlsio.HAlignType.center;
      permTimeOutCell.cellStyle.fontSize = 12;

      // Permission Hours
      final permHoursCell = sheet.getRangeByIndex(row, 14);
      permHoursCell.setText(record.totalPermissionHours ?? '-');
      permHoursCell.cellStyle.hAlign = xlsio.HAlignType.center;
      permHoursCell.cellStyle.fontSize = 12;
      permHoursCell.cellStyle.bold = true;

      // Permission Status
      final permStatusCell = sheet.getRangeByIndex(row, 15);
      if (record.permissionTimeIn != null && record.permissionTimeOut != null) {
        permStatusCell.setText('Approved');
        permStatusCell.cellStyle.fontColor = '#006400';
        permStatusCell.cellStyle.bold = true;
      } else if (record.permissionTimeIn != null || record.permissionTimeOut != null) {
        permStatusCell.setText('Pending');
        permStatusCell.cellStyle.fontColor = '#FF8C00';
        permStatusCell.cellStyle.bold = true;
      } else {
        permStatusCell.setText('-');
      }
      permStatusCell.cellStyle.hAlign = xlsio.HAlignType.center;
      permStatusCell.cellStyle.fontSize = 12;

      // Alternate row color
      if (i % 2 == 1) {
        final rowRange = sheet.getRangeByIndex(row, 1, row, headers.length);
        rowRange.cellStyle.backColor = _evenRowColor;
      }

      // Add borders to the row
      _addBorders(sheet.getRangeByIndex(row, 1, row, headers.length));
      
      // Set vertical alignment for all cells in the row
      sheet.getRangeByIndex(row, 1, row, headers.length)
          .cellStyle.vAlign = xlsio.VAlignType.center;
    }

    // 4. Summary Section - LARGER FONT
    final summaryRow = attendanceList.length + headerRow + 2;
    
    // Total Records
    final totalCell = sheet.getRangeByIndex(summaryRow, 1, summaryRow, 4);
    totalCell.merge();
    totalCell.setText('Total Records : ${attendanceList.length}');
    totalCell.cellStyle.bold = true;
    totalCell.cellStyle.fontSize = 14;
    totalCell.cellStyle.backColor = '#FFF2CC';
    totalCell.cellStyle.hAlign = xlsio.HAlignType.left;
    _addBorders(totalCell);

    // Summary stats
    final presentCount = attendanceList.where((r) => r.status.toUpperCase() == 'PRESENT').length;
    final halfDayCount = attendanceList.where((r) => r.status.toUpperCase() == 'HALF_DAY').length;
    final absentCount = attendanceList.where((r) => r.status.toUpperCase() == 'ABSENT').length;
    final permissionCount = attendanceList.where((r) => 
      r.permissionTimeIn != null || r.permissionTimeOut != null
    ).length;

    final summaryRow2 = summaryRow + 1;
    final summaryData = [
      'Present: $presentCount',
      'Half Day: $halfDayCount',
      'Absent: $absentCount',
      'Permission: $permissionCount',
    ];

    for (int i = 0; i < summaryData.length; i++) {
      final cell = sheet.getRangeByIndex(summaryRow2, i + 1);
      cell.setText(summaryData[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 13;
      
      if (i == 0) {
        cell.cellStyle.fontColor = '#006400';
        cell.cellStyle.backColor = _statusPresentColor;
      } else if (i == 1 || i == 2) {
        cell.cellStyle.fontColor = '#8B0000';
        cell.cellStyle.backColor = _statusHalfDayColor;
      } else {
        cell.cellStyle.fontColor = '#00008B';
        cell.cellStyle.backColor = '#E6E6FA';
      }
      cell.cellStyle.hAlign = xlsio.HAlignType.center;
      _addBorders(cell);
    }
  }

  static void _styleHeaderCell(xlsio.Range cell) {
    cell.cellStyle.bold = true;
    cell.cellStyle.fontSize = 13;
    cell.cellStyle.backColor = _headerColor;
    cell.cellStyle.fontColor = '#FFFFFF';
    cell.cellStyle.hAlign = xlsio.HAlignType.center;
    cell.cellStyle.vAlign = xlsio.VAlignType.center;
    cell.cellStyle.wrapText = true;
    _addBorders(cell);
  }

  static void _applyFormatting(
    xlsio.Worksheet sheet,
    int totalRows,
  ) {
    // Auto-fit all columns
    for (int i = 1; i <= 15; i++) {
      sheet.autoFitColumn(i);
    }
    
    // Set minimum column widths (in characters)
    sheet.getRangeByIndex(1, 4, totalRows, 4).columnWidth = 25; // Employee Name
    sheet.getRangeByIndex(1, 5, totalRows, 5).columnWidth = 32; // Site Name (Expanded layout for comma separation list)
    sheet.getRangeByIndex(1, 7, totalRows, 7).columnWidth = 14; // Status In
    sheet.getRangeByIndex(1, 9, totalRows, 9).columnWidth = 14; // Status Out
    sheet.getRangeByIndex(1, 11, totalRows, 11).columnWidth = 16; // Attendance Status
    sheet.getRangeByIndex(1, 15, totalRows, 15).columnWidth = 14; // Permission Status
    
    // Set smaller columns
    sheet.getRangeByIndex(1, 1, totalRows, 1).columnWidth = 8; // S.No
    sheet.getRangeByIndex(1, 2, totalRows, 2).columnWidth = 12; // Date
    sheet.getRangeByIndex(1, 3, totalRows, 3).columnWidth = 14; // Employee ID
    sheet.getRangeByIndex(1, 6, totalRows, 6).columnWidth = 12; // Time In
    sheet.getRangeByIndex(1, 8, totalRows, 8).columnWidth = 12; // Time Out
    sheet.getRangeByIndex(1, 10, totalRows, 10).columnWidth = 12; // Total Hours
    sheet.getRangeByIndex(1, 12, totalRows, 12).columnWidth = 14; // Permission Time In
    sheet.getRangeByIndex(1, 13, totalRows, 13).columnWidth = 14; // Permission Time Out
    sheet.getRangeByIndex(1, 14, totalRows, 14).columnWidth = 14; // Permission Hours
  }

  static void _addBorders(xlsio.Range range) {
    range.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    range.cellStyle.borders.all.color = _borderColor;
  }

  static String _formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  static Future<String> _saveFile(List<int> bytes, int recordCount) async {
    final directory = await getTemporaryDirectory();

    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    final file = File(
      '${directory.path}/attendance_report_${recordCount}_$dateStr.xlsx',
    );

    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Attendance Report',
        subject: 'Attendance Report',
      ),
    );

    return file.path;
  }

  static Future<String> exportToCSV(List<MarkAttendanceData> attendanceList) async {
    final sortedList = List<MarkAttendanceData>.from(attendanceList)
      ..sort((a, b) {
        if (a.attendanceDate == null && b.attendanceDate == null) return 0;
        if (a.attendanceDate == null) return 1;
        if (b.attendanceDate == null) return -1;
        return a.attendanceDate!.compareTo(b.attendanceDate!);
      });

    final buffer = StringBuffer();
    
    buffer.writeln(
      'S.No,Date,Employee ID,Employee Name,Site Name,Time In,Status In,Time Out,Status Out,Total Hours,Attendance Status,Permission Time In,Permission Time Out,Permission Hours,Permission Status'
    );

    for (int i = 0; i < sortedList.length; i++) {
      final record = sortedList[i];
      
      final statusIn = record.officeTimeIn != null ? 'Marked' : 'Not-Marked';
      final statusOut = record.officeTimeOut != null ? 'Marked' : 'Not-Marked';
      
      // FIX: Extract multi-visit site details safely for CSV rendering
      String sitesText = '-';
      if (record.visits.isNotEmpty) {
        final siteNames = record.visits
            .map((v) => v.siteName)
            .where((name) => name.trim().isNotEmpty)
            .toSet()
            .toList();
        if (siteNames.isNotEmpty) {
          sitesText = siteNames.join(', ');
        }
      }

      String permStatus = '-';
      if (record.permissionTimeIn != null && record.permissionTimeOut != null) {
        permStatus = 'Approved';
      } else if (record.permissionTimeIn != null || record.permissionTimeOut != null) {
        permStatus = 'Pending';
      }
      
      buffer.writeln(
        '${i + 1},'
        '"${record.attendanceDate != null ? DateFormat('dd-MM-yyyy').format(record.attendanceDate!) : '-'}",'
        '"${record.employeeId}",'
        '"${record.employeeName}",'
        '"$sitesText",' // Enclosing within quotes prevents commas from breaking CSV columns
        '"${record.officeTimeIn != null ? _formatTime(record.officeTimeIn!) : '-'}",'
        '"$statusIn",'
        '"${record.officeTimeOut != null ? _formatTime(record.officeTimeOut!) : '-'}",'
        '"$statusOut",'
        '"${record.totalAttendanceHours ?? '-'}",'
        '"${record.status}",'
        '"${record.permissionTimeIn != null ? _formatTime(record.permissionTimeIn!) : '-'}",'
        '"${record.permissionTimeOut != null ? _formatTime(record.permissionTimeOut!) : '-'}",'
        '"${record.totalPermissionHours ?? '-'}",'
        '"$permStatus"'
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'attendance_report_${DateTime.now().millisecondsSinceEpoch}.csv';
    final filePath = '${directory.path}/$fileName';
    
    final file = File(filePath);
    await file.writeAsString(buffer.toString());
    
    return filePath;
  }
}