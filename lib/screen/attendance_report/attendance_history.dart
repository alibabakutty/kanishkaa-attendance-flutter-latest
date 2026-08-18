import 'package:attendance_app/modals/mark_attendance_data.dart';
import 'package:attendance_app/service/mark_attendance/attendance_service.dart';
import 'package:attendance_app/service/reports/dayend_excel_export_service.dart';
import 'package:attendance_app/service/reports/monthend_excel_export_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/authentication/auth_provider.dart';
import 'widgets/search_type_selector.dart';
import 'widgets/text_input_field.dart';
import 'widgets/column_selector.dart';
import 'widgets/attendance_table.dart';
import 'utils/attendance_report_constants.dart';
import 'utils/attendance_report_helpers.dart';

class AttendanceHistory extends StatefulWidget {
  const AttendanceHistory({super.key});

  @override
  State<AttendanceHistory> createState() => _AttendanceHistoryState();
}

class _AttendanceHistoryState extends State<AttendanceHistory> {
  late AttendanceService _attendanceService;
  final _employeeNameController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _employeeMobileNumberController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _specificDate = DateTime.now();
  String _searchType = 'date';
  bool _isLoading = false;
  bool _hasSearched = false;
  List<MarkAttendanceData> _attendanceList = [];
  String _errorMessage = '';
  List<String> _selectedColumns = List.from(AttendanceReportConstants.defaultColumns);
  bool _sortAscending = true;
  int _sortColumnIndex = 0;
  
  // Add this for export state
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _attendanceService = AttendanceService(
      baseUrl: dotenv.get('API_BASE_URL', fallback: "http://192.168.1.3:8080"),
    );
    _employeeNameController.addListener(() => setState(() {}));
    _employeeIdController.addListener(() => setState(() {}));
    _employeeMobileNumberController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _employeeNameController.dispose();
    _employeeIdController.dispose();
    _employeeMobileNumberController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    BuildContext context, {
    bool isStartDate = false,
    bool isEndDate = false,
    bool isSpecificDate = false,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isSpecificDate
          ? _specificDate ?? DateTime.now()
          : isStartDate
              ? _startDate ?? DateTime.now()
              : _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isSpecificDate) {
          _specificDate = picked;
        } else if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _searchAttendanceHistories() async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = '';
      _attendanceList.clear();
    });

    try {
      List<MarkAttendanceData> results = [];

      if (_searchType == 'date') {
        if (_specificDate != null) {
          results = await _searchBySpecificDate(_specificDate!);
        } else if (_startDate != null && _endDate != null) {
          results = await _searchByDateRange(_startDate!, _endDate!);
        } else {
          // If no date selected, show all records
          results = await _attendanceService.getAllAttendance();
        }
      } else if (_searchType == 'name' &&
          _employeeNameController.text.isNotEmpty) {
        results = await _searchByEmployeeName(
          _employeeNameController.text.trim(),
        );
      } else if (_searchType == 'id' && _employeeIdController.text.isNotEmpty) {
        results = await _searchByEmployeeId(_employeeIdController.text.trim());
      } else if (_searchType == 'mobile' &&
          _employeeMobileNumberController.text.isNotEmpty) {
        results = await _searchByMobileNumber(
          _employeeMobileNumberController.text.trim(),
        );
      }

      final authProvider = Provider.of<AuthProvider>(
        context,
        listen: false,
      );

      List<MarkAttendanceData> filteredResults = results;

      // If employee → only show own attendance
      if (authProvider.isEmployee) {
        filteredResults = results.where((record) {
          return record.employeeId == authProvider.employeeId;
        }).toList();
      }

      // Sort records by date (oldest to newest)
      filteredResults.sort((a, b) {
        if (a.attendanceDate == null && b.attendanceDate == null) return 0;
        if (a.attendanceDate == null) return 1;
        if (b.attendanceDate == null) return -1;
        
        // Compare dates
        return a.attendanceDate!.compareTo(b.attendanceDate!);
      });
      
      // If admin → show all records automatically
      setState(() {
        _attendanceList = filteredResults;

        if (filteredResults.isEmpty) {
          _errorMessage = 'No attendance records found';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching attendance: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<MarkAttendanceData>> _searchBySpecificDate(DateTime date) async {
    try {
      final allRecords = await _attendanceService.getAllAttendance();

      // Filter records where attendanceDate matches the specific date
      return allRecords.where((record) {
        if (record.attendanceDate == null) return false;

        // Compare only year, month, and day
        return record.attendanceDate!.year == date.year &&
            record.attendanceDate!.month == date.month &&
            record.attendanceDate!.day == date.day;
      }).toList();
    } catch (e) {
      throw Exception('Failed to search by date: $e');
    }
  }

  Future<List<MarkAttendanceData>> _searchByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final allRecords = await _attendanceService.getAllAttendance();

      // Normalize dates
      final startDate = DateTime(start.year, start.month, start.day);
      final endDate = DateTime(end.year, end.month, end.day);

      return allRecords.where((record) {
        if (record.attendanceDate == null) return false;
        
        final recordDate = DateTime(
          record.attendanceDate!.year,
          record.attendanceDate!.month,
          record.attendanceDate!.day,
        );
        
        // Check if record date is within range (inclusive)
        return (recordDate.isAtSameMomentAs(startDate) || 
                recordDate.isAfter(startDate)) &&
              (recordDate.isAtSameMomentAs(endDate) || 
                recordDate.isBefore(endDate));
      }).toList();
    } catch (e) {
      throw Exception('Failed to search by date range: $e');
    }
  }

  Future<List<MarkAttendanceData>> _searchByEmployeeName(String name) async {
    try {
      final allRecords = await _attendanceService.getAllAttendance();
      return allRecords.where((record) {
        return record.employeeName.toLowerCase().contains(name.toLowerCase());
      }).toList();
    } catch (e) {
      throw Exception('Failed to search by name: $e');
    }
  }

  Future<List<MarkAttendanceData>> _searchByEmployeeId(String id) async {
    try {
      final allRecords = await _attendanceService.getAllAttendance();
      return allRecords.where((record) {
        return record.employeeId.toLowerCase().contains(id.toLowerCase());
      }).toList();
    } catch (e) {
      throw Exception('Failed to search by ID: $e');
    }
  }

  Future<List<MarkAttendanceData>> _searchByMobileNumber(String mobile) async {
    try {
      final allRecords = await _attendanceService.getAllAttendance();
      return allRecords.where((record) {
        return record.mobileNumber?.contains(mobile) ?? false;
      }).toList();
    } catch (e) {
      throw Exception('Failed to search by mobile: $e');
    }
  }

  Future<void> _exportToExcel({required String exportType}) async {
    if (_attendanceList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No attendance records to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      // Prepare parameters for export
      String? startDateStr;
      String? endDateStr;
      
      if (_searchType == 'date') {
        if (_specificDate != null) {
          startDateStr = DateFormat('dd-MM-yyyy').format(_specificDate!);
          endDateStr = startDateStr;
        } else if (_startDate != null && _endDate != null) {
          startDateStr = DateFormat('dd-MM-yyyy').format(_startDate!);
          endDateStr = DateFormat('dd-MM-yyyy').format(_endDate!);
        }
      }

      bool includeLocationData = true;
      String filePath;

      // Choose export service based on type
      if (exportType == 'dayend') {
        filePath = await DayEndExcelExportService.exportToExcel(
          _attendanceList,
          startDate: startDateStr,
          endDate: endDateStr,
          searchType: _searchType,
          employeeName: _employeeNameController.text.trim().isNotEmpty 
              ? _employeeNameController.text.trim() 
              : null,
          employeeId: _employeeIdController.text.trim().isNotEmpty 
              ? _employeeIdController.text.trim() 
              : null,
          mobileNumber: _employeeMobileNumberController.text.trim().isNotEmpty 
              ? _employeeMobileNumberController.text.trim() 
              : null,
          includeLocationData: includeLocationData,
        );
      } else {
        // MonthEnd export
        filePath = await MonthEndExcelExportService.exportToExcel(
          _attendanceList,
          startDate: startDateStr,
          endDate: endDateStr,
          searchType: _searchType,
          employeeName: _employeeNameController.text.trim().isNotEmpty 
              ? _employeeNameController.text.trim() 
              : null,
          employeeId: _employeeIdController.text.trim().isNotEmpty 
              ? _employeeIdController.text.trim() 
              : null,
          mobileNumber: _employeeMobileNumberController.text.trim().isNotEmpty 
              ? _employeeMobileNumberController.text.trim() 
              : null,
          includeLocationData: includeLocationData,
        );
      }

      // Show success message
      if (mounted) {
        final exportTypeName = exportType == 'dayend' ? 'Day End' : 'Month End';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✅ $exportTypeName Report Exported Successfully!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'File saved at: $filePath',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Failed to export: ${e.toString()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Widget _buildSearchInputFields() {
    switch (_searchType) {
      case 'name':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextInputField(
              label: 'Employee Name',
              controller: _employeeNameController,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _employeeNameController.text.trim().isNotEmpty
                    ? _searchAttendanceHistories
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Search by Name',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      case 'id':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextInputField(
              label: 'Employee ID',
              controller: _employeeIdController,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _employeeIdController.text.trim().isNotEmpty
                    ? _searchAttendanceHistories
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Search by ID',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      case 'mobile':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextInputField(
              label: 'Mobile Number',
              controller: _employeeMobileNumberController,
              keyboardType: TextInputType.phone,
              hintText: 'Enter mobile number',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _employeeMobileNumberController.text.trim().isNotEmpty
                    ? _searchAttendanceHistories
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Search by Mobile',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      case 'date':
      default:
        return _buildDateSearchOptions();
    }
  }

  Widget _buildDateSearchOptions() {
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
                      groupValue: _specificDate != null ||
                              (_startDate == null && _endDate == null)
                          ? 'specific'
                          : 'range',
                      onChanged: (value) {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                          if (_specificDate == null) {
                            _specificDate = DateTime.now();
                          }
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date Range',
                          style: TextStyle(fontSize: 14)),
                      value: 'range',
                      groupValue: _startDate != null || _endDate != null
                          ? 'range'
                          : 'specific',
                      onChanged: (value) {
                        setState(() {
                          _specificDate = null;
                          if (_startDate == null) _startDate = DateTime.now();
                          if (_endDate == null) _endDate = DateTime.now();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_specificDate != null) _buildSpecificDateSelector(),
              if (_startDate != null && _endDate != null)
                _buildDateRangeSelector(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _selectDate(context, isStartDate: true),
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
                    _startDate != null
                        ? DateFormat('dd-MM-yyyy').format(_startDate!)
                        : 'Select start date',
                    style: TextStyle(
                      fontSize: 14,
                      color: _startDate != null
                          ? Colors.black87
                          : Colors.grey[600],
                      fontWeight: _startDate != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _selectDate(context, isEndDate: true),
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
                    _endDate != null
                        ? DateFormat('dd-MM-yyyy').format(_endDate!)
                        : 'Select end date',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          _endDate != null ? Colors.black87 : Colors.grey[600],
                      fontWeight: _endDate != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_startDate != null && _endDate != null)
                ? _searchAttendanceHistories
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Search by Date Range',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecificDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _selectDate(context, isSpecificDate: true),
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
              _specificDate != null
                  ? DateFormat('dd-MM-yyyy').format(_specificDate!)
                  : 'Select a date',
              style: TextStyle(
                fontSize: 14,
                color:
                    _specificDate != null ? Colors.black87 : Colors.grey[600],
                fontWeight:
                    _specificDate != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                _specificDate != null ? _searchAttendanceHistories : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Search by Specific Date',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_errorMessage.isNotEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Text(
            _errorMessage,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (_attendanceList.isEmpty && _hasSearched) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              const Text(
                'No attendance records found',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Try adjusting your search criteria',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    } else if (_attendanceList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ColumnSelector(
              selectedColumns: _selectedColumns,
              onColumnsChanged: (newColumns) {
                setState(() {
                  _selectedColumns = newColumns;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        AttendanceTable(
          attendanceList: _attendanceList,
          selectedColumns: _selectedColumns,
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAscending,
          onSort: (columnIndex) {
            setState(() {
              _sortColumnIndex = columnIndex;
              _sortAscending = !_sortAscending;
              final column = _selectedColumns[columnIndex];
              _attendanceList.sort((a, b) {
                final result = AttendanceReportHelpers.compareAttendanceData(
                  a,
                  b,
                  column,
                );
                return _sortAscending ? result : -result;
              });
            });
          },
        ),
        // Removed the Row with Total Records and Export button from here
      ],
    );
  }

  // New method for export dropdown
  Widget _buildExportDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: _isExporting ? Colors.orange.shade300 : Colors.green,
      ),
      child: PopupMenuButton<String>(
        enabled: !_isExporting,
        offset: const Offset(0, 40),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isExporting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                const Icon(Icons.download, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                _isExporting ? 'Exporting...' : 'Export ▼',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        onSelected: (value) {
          _exportToExcel(exportType: value);
        },
        itemBuilder: (BuildContext context) => [
          PopupMenuItem<String>(
            value: 'dayend',
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.orange),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Day End Report',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      'Detailed daily format',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'monthend',
            child: Row(
              children: [
                const Icon(Icons.calendar_month, size: 16, color: Colors.blue),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Month End Report',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      'Grouped by date with permissions',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E5),
      appBar: AppBar(
        backgroundColor: Colors.orange.shade700,
        elevation: 2,
        titleSpacing: 8,
        title: Row(
          children: [
            const Text(
              'Attendance Report',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            // Total Records counter in header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _attendanceList.isNotEmpty 
                    ? '${_attendanceList.length} records' 
                    : '0 records',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Export dropdown in header
            _buildExportDropdown(),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchTypeSelector(
                selectedType: _searchType,
                onChanged: (value) {
                  setState(() {
                    _searchType = value;
                    _hasSearched = false;
                    _attendanceList.clear();
                    _errorMessage = '';
                    _employeeNameController.clear();
                    _employeeIdController.clear();
                    _employeeMobileNumberController.clear();
                    _specificDate = _searchType == 'date' ? DateTime.now() : null;
                    _startDate = null;
                    _endDate = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildSearchInputFields(),
              const SizedBox(height: 12),
              _buildAttendanceList(),
            ],
          ),
        ),
      ),
    );
  }
}