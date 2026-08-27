import 'package:attendance_app/screen/attendance_report/widgets/text_input_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceSearchInputFields extends StatelessWidget {
  final String searchType;
  final TextEditingController employeeNameController;
  final TextEditingController employeeIdController;
  final TextEditingController employeeMobileNumberController;
  final DateTime? specificDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onSearch;
  final Function(DateTime? specificDate, DateTime? startDate, DateTime? endDate) onDateRangeTypeChanged;
  final Function(bool isStartDate, bool isEndDate, bool isSpecificDate) onSelectDate;

  const AttendanceSearchInputFields({
    super.key,
    required this.searchType,
    required this.employeeNameController,
    required this.employeeIdController,
    required this.employeeMobileNumberController,
    required this.specificDate,
    required this.startDate,
    required this.endDate,
    required this.onSearch,
    required this.onDateRangeTypeChanged,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    switch (searchType) {
      case 'name':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextInputField(
              label: 'Employee Name',
              controller: employeeNameController,
            ),
            const SizedBox(height: 12),
            _buildSearchButton(
              label: 'Search by Name',
              isEnabled: employeeNameController.text.trim().isNotEmpty,
            ),
          ],
        );
      case 'id':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextInputField(
              label: 'Employee ID',
              controller: employeeIdController,
            ),
            const SizedBox(height: 12),
            _buildSearchButton(
              label: 'Search by ID',
              isEnabled: employeeIdController.text.trim().isNotEmpty,
            ),
          ],
        );
      case 'mobile':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextInputField(
              label: 'Mobile Number',
              controller: employeeMobileNumberController,
              keyboardType: TextInputType.phone,
              hintText: 'Enter mobile number',
            ),
            const SizedBox(height: 12),
            _buildSearchButton(
              label: 'Search by Mobile',
              isEnabled: employeeMobileNumberController.text.trim().isNotEmpty,
            ),
          ],
        );
      case 'date':
      default:
        return _buildDateSearchOptions(context);
    }
  }

  Widget _buildSearchButton({required String label, required bool isEnabled}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isEnabled ? onSearch : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildDateSearchOptions(BuildContext context) {
    final bool isSpecificSelected =
        specificDate != null || (startDate == null && endDate == null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Specific Date',
                        style: TextStyle(fontSize: 14),
                      ),
                      value: 'specific',
                      groupValue: isSpecificSelected ? 'specific' : 'range',
                      onChanged: (value) {
                        onDateRangeTypeChanged(
                          specificDate ?? DateTime.now(),
                          null,
                          null,
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Date Range',
                        style: TextStyle(fontSize: 14),
                      ),
                      value: 'range',
                      groupValue: !isSpecificSelected ? 'range' : 'specific',
                      onChanged: (value) {
                        onDateRangeTypeChanged(
                          null,
                          startDate ?? DateTime.now(),
                          endDate ?? DateTime.now(),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (specificDate != null) _buildSpecificDateSelector(context),
              if (startDate != null && endDate != null)
                _buildDateRangeSelector(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpecificDateSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onSelectDate(false, false, true),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Select Date',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            child: Text(
              DateFormat('dd-MM-yyyy').format(specificDate!),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildSearchButton(
          label: 'Search by Specific Date',
          isEnabled: true,
        ),
      ],
    );
  }

  Widget _buildDateRangeSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onSelectDate(true, false, false),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Start Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    DateFormat('dd-MM-yyyy').format(startDate!),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onSelectDate(false, true, false),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'End Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    DateFormat('dd-MM-yyyy').format(endDate!),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSearchButton(
          label: 'Search by Date Range',
          isEnabled: true,
        ),
      ],
    );
  }
}