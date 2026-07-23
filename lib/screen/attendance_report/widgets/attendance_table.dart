// lib/screens/attendance_history/widgets/attendance_table.dart
import 'package:flutter/material.dart';
import 'package:attendance_app/modals/mark_attendance_data.dart';
import '../utils/attendance_report_helpers.dart';

class AttendanceTable extends StatelessWidget {
  final List<MarkAttendanceData> attendanceList;
  final List<String> selectedColumns;
  final int sortColumnIndex;
  final bool sortAscending;
  final ValueChanged<int> onSort;

  const AttendanceTable({
    super.key,
    required this.attendanceList,
    required this.selectedColumns,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
  });

  List<DataColumn> _buildDataColumns() {
    return selectedColumns.asMap().entries.map((entry) {
      final index = entry.key;
      final column = entry.value;
      return DataColumn(
        label: Text(column, style: const TextStyle(fontSize: 12)),
        tooltip: column,
        onSort: (columnIndex, ascending) {
          onSort(index);
        },
      );
    }).toList();
  }

  List<DataRow> _buildDataRows() {
    return attendanceList.map((attendance) {
      final cells = selectedColumns.map((column) {
        return DataCell(
          AttendanceReportHelpers.buildCellContent(column, attendance),
        );
      }).toList();

      return DataRow(
        cells: cells,
        color: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            return attendanceList.indexOf(attendance) % 2 == 0
                ? Colors.white
                : Colors.grey.shade50;
          },
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: DataTable(
          headingRowHeight: 36,
          dataRowHeight: 40,
          sortColumnIndex: sortColumnIndex,
          sortAscending: sortAscending,
          headingRowColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) => Colors.orange.shade100,
          ),
          columns: _buildDataColumns(),
          rows: _buildDataRows(),
          dividerThickness: 1,
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 12,
            height: 1.1,
          ),
          dataTextStyle: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}