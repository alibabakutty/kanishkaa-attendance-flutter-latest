import 'dart:io';
import 'package:attendance_app/modals/mark_attendance_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class MonthEndExcelExportService {
  static const _borderColor = '#808080';
  static const _headerColor = '#92D050'; // Bright light green header
  static const _bannerColor = '#FFFF00'; // Bright Yellow banner
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
      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];
      sheet.showGridlines = true;

      final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
      sheet.name = 'Attendance_Report_$dateStr';

      // Group data by date to create stacked day-wise tables
      final Map<String, List<MarkAttendanceData>> groupedData = {};
      for (var record in attendanceList) {
        if (record.attendanceDate != null) {
          final dayStr = DateFormat('dd.MM.yyyy').format(record.attendanceDate!);
          groupedData.putIfAbsent(dayStr, () => []).add(record);
        }
      }

      // Sort dates chronologically
      final sortedDates = groupedData.keys.toList()
        ..sort((a, b) {
          final dateA = DateFormat('dd.MM.yyyy').parse(a);
          final dateB = DateFormat('dd.MM.yyyy').parse(b);
          return dateA.compareTo(dateB);
        });

      int currentRow = 1;

      // Build tables for each day sequentially
      for (var date in sortedDates) {
        currentRow = _generateDayTable(sheet, currentRow, date, groupedData[date]!);
        currentRow += 2; // Space between daily tables
      }

      _applyFormatting(sheet, currentRow);

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      return await _saveFile(bytes, attendanceList.length);
    } catch (e) {
      throw Exception('Failed to export Excel: $e');
    }
  }

  static int _generateDayTable(
    xlsio.Worksheet sheet,
    int startRow,
    String dateLabel,
    List<MarkAttendanceData> dailyList,
  ) {
    // 1. Full-width Section Banner Row (Spans all 14 columns)
    final bannerRange = sheet.getRangeByIndex(startRow, 1, startRow, 14);
    bannerRange.merge();
    bannerRange.setText('KANISHKAA ATTENDANCE - $dateLabel');
    bannerRange.cellStyle.bold = true;
    bannerRange.cellStyle.fontSize = 16;
    bannerRange.cellStyle.backColor = _bannerColor;
    bannerRange.cellStyle.hAlign = xlsio.HAlignType.center;
    bannerRange.cellStyle.vAlign = xlsio.VAlignType.center;
    _addBorders(bannerRange);

    // 2. Double-Row Header Structure (Row 1: Main Headers / Merges)
    final hRow1 = startRow + 1;
    final hRow2 = startRow + 2;

    // Standard columns vertically merged across both header rows
    final standardHeaders = [
      'S.No', 
      'Employee ID', 
      'Employee Name', 
      'Site Name', 
      'Device Name',
      'Time In', 
      'Status In', 
      'Time Out', 
      'Status Out', 
      'Attendance Hours', 
      'Attendance Status'
    ];

    for (int i = 0; i < standardHeaders.length; i++) {
      final cellRange = sheet.getRangeByIndex(hRow1, i + 1, hRow2, i + 1);
      cellRange.merge();
      cellRange.setText(standardHeaders[i]);
      _styleHeaderCell(cellRange);
    }

    // "Permission" Master Header spanning columns 12, 13, and 14
    final permissionMaster = sheet.getRangeByIndex(hRow1, 12, hRow1, 14);
    permissionMaster.merge();
    permissionMaster.setText('Permission');
    _styleHeaderCell(permissionMaster);

    // Permission Sub-headers on Row 2
    final permSubs = ['Permission Time In', 'Permission Time Out', 'Permission Hours'];
    for (int i = 0; i < permSubs.length; i++) {
      final cell = sheet.getRangeByIndex(hRow2, 12 + i);
      cell.setText(permSubs[i]);
      _styleHeaderCell(cell);
    }

    // 3. Populate Data Rows
    int dataStartRow = hRow2 + 1;
    for (int i = 0; i < dailyList.length; i++) {
      final record = dailyList[i];
      final row = dataStartRow + i;

      // Extract unique site names from the visits array
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

      sheet.getRangeByIndex(row, 1).setNumber(i + 1);
      sheet.getRangeByIndex(row, 1).cellStyle.fontSize = 12;
      
      sheet.getRangeByIndex(row, 2).setText(record.employeeId);
      sheet.getRangeByIndex(row, 2).cellStyle.fontSize = 12;
      
      sheet.getRangeByIndex(row, 3).setText(record.employeeName);
      sheet.getRangeByIndex(row, 3).cellStyle.fontSize = 12;
      
      sheet.getRangeByIndex(row, 4).setText(sitesText);
      sheet.getRangeByIndex(row, 4).cellStyle.fontSize = 12;
      
      sheet.getRangeByIndex(row, 5).setText(record.mobileNumber != null ? 'Android' : 'iPhone');
      sheet.getRangeByIndex(row, 5).cellStyle.fontSize = 12;
      
      // Time In
      sheet.getRangeByIndex(row, 6).setText(record.officeTimeIn != null ? _formatTime(record.officeTimeIn!) : '-');
      sheet.getRangeByIndex(row, 6).cellStyle.fontSize = 12;
      
      // Status In
      final statusInCell = sheet.getRangeByIndex(row, 7);
      statusInCell.setText(record.officeTimeIn != null ? 'Marked' : 'Not-Marked');
      statusInCell.cellStyle.fontSize = 12;
      statusInCell.cellStyle.bold = true;
      statusInCell.cellStyle.fontColor = record.officeTimeIn != null ? '#006400' : '#8B0000';
      
      // Time Out
      sheet.getRangeByIndex(row, 8).setText(record.officeTimeOut != null ? _formatTime(record.officeTimeOut!) : '-');
      sheet.getRangeByIndex(row, 8).cellStyle.fontSize = 12;
      
      // Status Out
      final statusOutCell = sheet.getRangeByIndex(row, 9);
      statusOutCell.setText(record.officeTimeOut != null ? 'Marked' : 'Not-Marked');
      statusOutCell.cellStyle.fontSize = 12;
      statusOutCell.cellStyle.bold = true;
      statusOutCell.cellStyle.fontColor = record.officeTimeOut != null ? '#006400' : '#8B0000';
      
      // Single Attendance Hours Column
      final hoursCell = sheet.getRangeByIndex(row, 10);
      hoursCell.setText(record.totalAttendanceHours ?? '-');
      hoursCell.cellStyle.fontSize = 12;
      hoursCell.cellStyle.bold = true;
      
      // Attendance Status Colors
      final statusCell = sheet.getRangeByIndex(row, 11);
      final status = record.status.toUpperCase();
      statusCell.setText(status);
      statusCell.cellStyle.fontSize = 12;
      statusCell.cellStyle.bold = true;
      if (status == 'PRESENT') {
        statusCell.cellStyle.fontColor = '#006400';
        statusCell.cellStyle.backColor = _statusPresentColor;
      } else if (status == 'HALF_DAY' || status == 'ABSENT') {
        statusCell.cellStyle.fontColor = '#8B0000';
        statusCell.cellStyle.backColor = status == 'HALF_DAY' ? _statusHalfDayColor : _statusAbsentColor;
      }

      // Permission Columns (Shifted to 12, 13, 14)
      sheet.getRangeByIndex(row, 12).setText(record.permissionTimeIn != null ? _formatTime(record.permissionTimeIn!) : '-');
      sheet.getRangeByIndex(row, 12).cellStyle.fontSize = 12;
      
      sheet.getRangeByIndex(row, 13).setText(record.permissionTimeOut != null ? _formatTime(record.permissionTimeOut!) : '-');
      sheet.getRangeByIndex(row, 13).cellStyle.fontSize = 12;
      
      final permHoursCell = sheet.getRangeByIndex(row, 14);
      permHoursCell.setText(record.totalPermissionHours ?? '-');
      permHoursCell.cellStyle.fontSize = 12;
      permHoursCell.cellStyle.bold = true;

      // Row styling & bounds formatting updates
      final rowRange = sheet.getRangeByIndex(row, 1, row, 14);
      _addBorders(rowRange);
      rowRange.cellStyle.vAlign = xlsio.VAlignType.center;
      
      if (i % 2 == 1) {
        rowRange.cellStyle.backColor = _evenRowColor;
      }
      
      // Alignment settings
      sheet.getRangeByIndex(row, 1).cellStyle.hAlign = xlsio.HAlignType.center;
      sheet.getRangeByIndex(row, 2).cellStyle.hAlign = xlsio.HAlignType.center;
      sheet.getRangeByIndex(row, 5).cellStyle.hAlign = xlsio.HAlignType.center;
      sheet.getRangeByIndex(row, 6).cellStyle.hAlign = xlsio.HAlignType.center;
      sheet.getRangeByIndex(row, 7).cellStyle.hAlign = xlsio.HAlignType.center;
      sheet.getRangeByIndex(row, 8).cellStyle.hAlign = xlsio.HAlignType.center;
      sheet.getRangeByIndex(row, 9).cellStyle.hAlign = xlsio.HAlignType.center;
      sheet.getRangeByIndex(row, 10).cellStyle.hAlign = xlsio.HAlignType.center;
      sheet.getRangeByIndex(row, 11).cellStyle.hAlign = xlsio.HAlignType.center;
      sheet.getRangeByIndex(row, 12).cellStyle.hAlign = xlsio.HAlignType.center;
      sheet.getRangeByIndex(row, 13).cellStyle.hAlign = xlsio.HAlignType.center;
      sheet.getRangeByIndex(row, 14).cellStyle.hAlign = xlsio.HAlignType.center;
    }

    return dataStartRow + dailyList.length - 1;
  }

  static void _styleHeaderCell(xlsio.Range range) {
    range.cellStyle.bold = true;
    range.cellStyle.fontSize = 13;
    range.cellStyle.backColor = _headerColor;
    range.cellStyle.fontColor = '#000000';
    range.cellStyle.hAlign = xlsio.HAlignType.center;
    range.cellStyle.vAlign = xlsio.VAlignType.center;
    range.cellStyle.wrapText = true;
    _addBorders(range);
  }

  static void _applyFormatting(xlsio.Worksheet sheet, int totalRows) {
    for (int i = 1; i <= 14; i++) {
      sheet.autoFitColumn(i);
    }
    
    sheet.getRangeByIndex(1, 1, totalRows, 1).columnWidth = 8;   // S.No
    sheet.getRangeByIndex(1, 2, totalRows, 2).columnWidth = 14;  // Employee ID
    sheet.getRangeByIndex(1, 3, totalRows, 3).columnWidth = 25;  // Employee Name
    sheet.getRangeByIndex(1, 4, totalRows, 4).columnWidth = 32;  // Site Name
    sheet.getRangeByIndex(1, 5, totalRows, 5).columnWidth = 15;  // Device Name
    sheet.getRangeByIndex(1, 6, totalRows, 6).columnWidth = 12;  // Time In
    sheet.getRangeByIndex(1, 7, totalRows, 7).columnWidth = 14;  // Status In
    sheet.getRangeByIndex(1, 8, totalRows, 8).columnWidth = 12;  // Time Out
    sheet.getRangeByIndex(1, 9, totalRows, 9).columnWidth = 14;  // Status Out
    sheet.getRangeByIndex(1, 10, totalRows, 10).columnWidth = 18; // Attendance Hours
    sheet.getRangeByIndex(1, 11, totalRows, 11).columnWidth = 18; // Attendance Status
    sheet.getRangeByIndex(1, 12, totalRows, 12).columnWidth = 18; // Permission Time In
    sheet.getRangeByIndex(1, 13, totalRows, 13).columnWidth = 18; // Permission Time Out
    sheet.getRangeByIndex(1, 14, totalRows, 14).columnWidth = 18; // Permission Hours
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
    final file = File('${directory.path}/attendance_report_${recordCount}_$dateStr.xlsx');

    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Attendance Month End Report',
        subject: 'Attendance Report',
      ),
    );
    return file.path;
  }
}