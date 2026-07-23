import 'package:flutter/material.dart';
import '../utils/attendance_report_constants.dart';

class ColumnSelector extends StatelessWidget {
  final List<String> selectedColumns;
  final ValueChanged<List<String>> onColumnsChanged;

  const ColumnSelector({
    super.key,
    required this.selectedColumns,
    required this.onColumnsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_column, size: 18),
            SizedBox(width: 4),
            Text('Columns', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      // We pass a copy of the current selections into the popup items
      itemBuilder: (context) {
        // Create a local list inside the itemBuilder scope that StatefulBuilder can modify safely
        final List<String> localSelections = List<String>.from(selectedColumns);

        return [
          const PopupMenuItem<String>(
            value: 'header',
            enabled: false,
            child: Text(
              'Select Columns',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ...AttendanceReportConstants.allAvailableColumns.map((column) {
            return PopupMenuItem<String>(
              value: column,
              enabled: false, // Prevents the menu from closing when clicked
              child: StatefulBuilder(
                builder: (context, setStatePopup) {
                  final isSelected = localSelections.contains(column);

                  return InkWell(
                    onTap: () {
                      setStatePopup(() {
                        if (!isSelected) {
                          localSelections.add(column);
                        } else {
                          localSelections.remove(column);
                        }
                      });
                      // Instantly update the parent widget
                      onColumnsChanged(List<String>.from(localSelections));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Checkbox(
                            activeColor: Colors.orange.shade700,
                            value: isSelected,
                            onChanged: (bool? selected) {
                              setStatePopup(() {
                                if (selected == true) {
                                  localSelections.add(column);
                                } else {
                                  localSelections.remove(column);
                                }
                              });
                              // Instantly update the parent widget
                              onColumnsChanged(List<String>.from(localSelections));
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              column,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ];
      },
    );
  }
}