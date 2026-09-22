import 'dart:io';
import 'package:attendance_app/modals/cumulative_attendance_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class MonthendCumulativeService {
  static const _borderColor = '#808080';
  static const _headerColor = '#FF8000'; // Orange header
  static const _bannerColor = '#FFFF00'; // Yellow title banner
  static const _evenRowColor = '#F5F5F5';

  static Future<String> exportToExcel(
    List<CumulativeAttendanceModel> attendanceList, {
    required String monthYearTitle,
    required int year,
    required int month,
  }) async {
    try {
      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];
      sheet.showGridlines = true;

      final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
      sheet.name = 'Cumulative_Report_$dateStr';

      _buildCumulativeTable(
        sheet,
        attendanceList,
        monthYearTitle,
        year: year,
        month: month,
      );

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      return await _saveFile(bytes, attendanceList.length);
    } catch (e) {
      throw Exception('Failed to export Cumulative Excel: $e');
    }
  }

  static void _buildCumulativeTable(
    xlsio.Worksheet sheet,
    List<CumulativeAttendanceModel> attendanceList,
    String monthYearTitle, {
    required int year,
    required int month,
  }) {
    const int startRow = 1;
    const int totalColumns = 13;

    // Calculate budget hours based on days in selected month (8 hrs/day)
    final totalDaysInMonth = DateTime(year, month + 1, 0).day;
    final budgetHoursFormatted = '${totalDaysInMonth * 8}:00:00';

    // 1. Title Banner Row (Merged across all 10 columns)
    final bannerRange = sheet.getRangeByIndex(startRow, 1, startRow, totalColumns);
    bannerRange.merge();
    bannerRange.setText('KANISHKAA ATTENDANCE - CUMULATIVE REPORT - ${monthYearTitle.toUpperCase()}');
    bannerRange.cellStyle.bold = true;
    bannerRange.cellStyle.fontSize = 14;
    bannerRange.cellStyle.backColor = _bannerColor;
    bannerRange.cellStyle.hAlign = xlsio.HAlignType.center;
    bannerRange.cellStyle.vAlign = xlsio.VAlignType.center;
    _addBorders(bannerRange);

    // 2. Header Row
    final headerRow = startRow + 1;
    final headers = [
      'S.No',
      'Employee ID',
      'Employee Name',
      'Present\nDays',
      'Half Day\nDays',
      'Absent\nDays',
      'Budget Hours\n(8 Hrs/Day)',
      'Actual Worked\nHours',
      'Total Sunday\nHours\n(Leave_With_Pay)',
      'Total Permission\nHours',
      'Net Hours',
      'Over_Time Hours',
      'Gross Hours',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(headerRow, i + 1);
      cell.setText(headers[i]);
      _styleHeaderCell(cell);
    }

    // 3. Data Rows
    for (int i = 0; i < attendanceList.length; i++) {
      final record = attendanceList[i];
      final row = headerRow + i + 1;

      final hasAttendance = record.totalMonthEndWorkedHours.trim().isNotEmpty &&
          record.totalMonthEndWorkedHours != '0 hrs 0 mins' &&
          record.totalMonthEndWorkedHours != '00 hrs 00 mins' &&
          record.totalMonthEndWorkedHours != '-';

      // Column 1: S.No
      final snoCell = sheet.getRangeByIndex(row, 1);
      snoCell.setNumber(i + 1);
      snoCell.cellStyle.hAlign = xlsio.HAlignType.center;
      snoCell.cellStyle.fontSize = 11;

      // Column 2: Employee ID
      final empIdCell = sheet.getRangeByIndex(row, 2);
      empIdCell.setText(record.employeeId.isEmpty ? '-' : record.employeeId);
      empIdCell.cellStyle.hAlign = xlsio.HAlignType.center;
      empIdCell.cellStyle.fontSize = 11;

      // Column 3: Employee Name
      final empNameCell = sheet.getRangeByIndex(row, 3);
      empNameCell.setText(record.employeeName.isEmpty ? '-' : record.employeeName);
      empNameCell.cellStyle.fontSize = 11;

      // ------------------------------------------------------------
      // Column 4: Present Days
      // ------------------------------------------------------------

      final presentDaysCell = sheet.getRangeByIndex(row, 4);

      presentDaysCell.setNumber(
        record.totalPresentDays.toDouble(),
      );

      presentDaysCell.cellStyle.hAlign =
          xlsio.HAlignType.center;

      presentDaysCell.cellStyle.bold = true;
      presentDaysCell.cellStyle.fontSize = 11;

      // ------------------------------------------------------------
      // Column 5: Half Day Days
      // ------------------------------------------------------------

      final halfDayCell = sheet.getRangeByIndex(row, 5);

      halfDayCell.setNumber(
        record.totalHalfDayDays.toDouble(),
      );

      halfDayCell.cellStyle.hAlign =
          xlsio.HAlignType.center;

      halfDayCell.cellStyle.bold = true;
      halfDayCell.cellStyle.fontSize = 11;

      // ------------------------------------------------------------
      // Column 6: Absent Days
      // ------------------------------------------------------------

      final absentDaysCell = sheet.getRangeByIndex(row, 6);

      absentDaysCell.setNumber(
        record.totalAbsentDays.toDouble(),
      );

      absentDaysCell.cellStyle.hAlign =
          xlsio.HAlignType.center;

      absentDaysCell.cellStyle.bold = true;
      absentDaysCell.cellStyle.fontSize = 11;

      // Column 4: Budget Hours
      final budgetCell = sheet.getRangeByIndex(row, 7);
      budgetCell.setText(hasAttendance ? budgetHoursFormatted : '-');
      budgetCell.cellStyle.hAlign = xlsio.HAlignType.center;
      budgetCell.cellStyle.bold = hasAttendance;
      budgetCell.cellStyle.fontSize = 11;

      // Column 5: Actual Worked Hours
      final actualCell = sheet.getRangeByIndex(row, 8);
      actualCell.setText(record.totalMonthEndWorkedHours);
      actualCell.cellStyle.hAlign = xlsio.HAlignType.center;
      actualCell.cellStyle.bold = hasAttendance;
      actualCell.cellStyle.fontSize = 11;

      // Column 6: Total Sunday Hours
      final sundayCell = sheet.getRangeByIndex(row, 9);
      sundayCell.setText(record.totalSundayHours);
      sundayCell.cellStyle.hAlign = xlsio.HAlignType.center;
      sundayCell.cellStyle.bold = true;
      sundayCell.cellStyle.fontSize = 11;

      // Column 7: Total Permission Hours
      final permCell = sheet.getRangeByIndex(row, 10);
      permCell.setText(record.totalMonthEndPermissionHours);
      permCell.cellStyle.hAlign = xlsio.HAlignType.center;
      permCell.cellStyle.bold = hasAttendance;
      permCell.cellStyle.fontSize = 11;

      // Column 8: Net Hours
      final netCell = sheet.getRangeByIndex(row, 11);
      netCell.setText(hasAttendance ? record.totalMonthEndNetHours : '-');
      netCell.cellStyle.hAlign = xlsio.HAlignType.center;
      netCell.cellStyle.bold = hasAttendance;
      netCell.cellStyle.fontSize = 11;

      // Column 9: Over_Time Hours
      final otCell = sheet.getRangeByIndex(row, 12);
      otCell.setText(record.overTimeHours);
      otCell.cellStyle.hAlign = xlsio.HAlignType.center;
      otCell.cellStyle.bold = true;
      otCell.cellStyle.fontSize = 11;

      // Column 10: Gross Hours
      final grossCell = sheet.getRangeByIndex(row, 13);
      grossCell.setText(record.totalGrossHours);
      grossCell.cellStyle.hAlign = xlsio.HAlignType.center;
      grossCell.cellStyle.bold = true;
      grossCell.cellStyle.fontSize = 11;

      // Apply row range styles and alternating background colors
      final rowRange = sheet.getRangeByIndex(row, 1, row, totalColumns);
      rowRange.cellStyle.vAlign = xlsio.VAlignType.center;
      _addBorders(rowRange);

      if (i % 2 == 1) {
        rowRange.cellStyle.backColor = _evenRowColor;
      }
    }

    _applyColumnWidths(sheet, headerRow + attendanceList.length);
  }

  static void _styleHeaderCell(xlsio.Range cell) {
    cell.cellStyle.bold = true;
    cell.cellStyle.fontSize = 11;
    cell.cellStyle.backColor = _headerColor;
    cell.cellStyle.fontColor = '#FFFFFF';
    cell.cellStyle.hAlign = xlsio.HAlignType.center;
    cell.cellStyle.vAlign = xlsio.VAlignType.center;
    cell.cellStyle.wrapText = true;
    _addBorders(cell);
  }

  static void _applyColumnWidths(xlsio.Worksheet sheet, int totalRows) {
    sheet.getRangeByIndex(1, 1, totalRows, 1).columnWidth = 8;   // S.No
    sheet.getRangeByIndex(1, 2, totalRows, 2).columnWidth = 15;  // Employee ID
    sheet.getRangeByIndex(1, 3, totalRows, 3).columnWidth = 28;  // Employee Name
    sheet.getRangeByIndex(1, 4, totalRows, 4).columnWidth = 13; 
    sheet.getRangeByIndex(1, 5, totalRows, 5).columnWidth = 13;
    sheet.getRangeByIndex(1, 6, totalRows, 6).columnWidth = 13;
    sheet.getRangeByIndex(1, 7, totalRows, 7).columnWidth = 18;
    sheet.getRangeByIndex(1, 8, totalRows, 8).columnWidth = 20;
    sheet.getRangeByIndex(1, 9, totalRows, 9).columnWidth = 22;
    sheet.getRangeByIndex(1, 10, totalRows, 10).columnWidth = 20;
    sheet.getRangeByIndex(1, 11, totalRows, 11).columnWidth = 18;
    sheet.getRangeByIndex(1, 12, totalRows, 12).columnWidth = 18;
    sheet.getRangeByIndex(1, 13, totalRows, 13).columnWidth = 18;
  }

  static void _addBorders(xlsio.Range range) {
    range.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    range.cellStyle.borders.all.color = _borderColor;
  }

  static Future<String> _saveFile(List<int> bytes, int recordCount) async {
    final directory = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${directory.path}/cumulative_attendance_$dateStr.xlsx');

    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'KANISHKAA Attendance Cumulative Report',
        subject: 'Cumulative Attendance Report',
      ),
    );

    return file.path;
  }
}