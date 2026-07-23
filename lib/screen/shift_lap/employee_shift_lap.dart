import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/modals/employee_master_data.dart';
import 'package:attendance_app/service/employee_api_service.dart';
import 'package:attendance_app/authentication/auth_provider.dart';
import 'package:attendance_app/screen/shift_lap/shift_lap_tracker_view.dart'; 

class EmployeeShiftLap extends StatefulWidget {
  const EmployeeShiftLap({super.key});

  @override
  State<EmployeeShiftLap> createState() => _EmployeeShiftLapState();
}

class _EmployeeShiftLapState extends State<EmployeeShiftLap> {
  final EmployeeApiService _employeeApiService = EmployeeApiService();
  final TextEditingController _searchController = TextEditingController();

  List<EmployeeMasterData> _allEmployees = [];
  List<EmployeeMasterData> _filteredEmployees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredEmployees = _allEmployees.where((employee) {
        return employee.employeeName.toLowerCase().contains(query) ||
            employee.employeeId.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _fetchEmployees() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await _employeeApiService.getAllEmployees();
      
      data.sort((a, b) => a.employeeName.toLowerCase().compareTo(b.employeeName.toLowerCase()));

      if (mounted) {
        setState(() {
          _allEmployees = data;
          _filteredEmployees = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load employees: $e')),
      );
    }
  }

  Future<void> _uploadExcel() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.token == null) {
        throw Exception("Authentication token is missing. Please log in again.");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading employees...'), duration: Duration(seconds: 2)),
      );

      final success = await _employeeApiService.bulkUploadEmployees(
        file,
        authProvider.token!,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Bulk employee upload successful'),
          ),
        );
        _fetchEmployees();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Bulk upload failed'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Employee Tracking System', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 2,
        actions: [
          IconButton(
            tooltip: 'Import Excel Template',
            onPressed: _uploadExcel,
            icon: const Icon(Icons.upload_file_rounded, size: 26),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by employee name or ID...',
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F3F6),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : _filteredEmployees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              _allEmployees.isEmpty ? 'No employees added yet' : 'No matching records found',
                              style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: Colors.blueAccent,
                        onRefresh: _fetchEmployees,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          itemCount: _filteredEmployees.length,
                          itemBuilder: (context, index) => _buildEmployeeCard(_filteredEmployees[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(EmployeeMasterData employee) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _handleEmployeeTap(employee),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: _SafeEmployeeAvatar(imageData: employee.employeeImageData),
            title: Text(
              employee.employeeName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
                fontSize: 17,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                "ID: ${employee.employeeId}",
                style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFF0D47A1),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleEmployeeTap(EmployeeMasterData employee) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: "Select Tracking Log Date",
    );

    if (selectedDate == null || !mounted) return;

    final String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);

    // Pass arguments down to the path mapping engine screen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShiftLapTrackerView(
          employeeId: employee.employeeId,
          employeeName: employee.employeeName,
          initialAttendanceDate: formattedDate,
        ),
      ),
    );

    _fetchEmployees();
  }
}

class _SafeEmployeeAvatar extends StatelessWidget {
  final String? imageData;
  const _SafeEmployeeAvatar({this.imageData});

  @override
  Widget build(BuildContext context) {
    if (imageData == null || imageData!.isEmpty) {
      return const CircleAvatar(
        radius: 26,
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.person, color: Colors.white, size: 26),
      );
    }

    return CircleAvatar(
      radius: 26,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: Image.memory(
          base64Decode(imageData!),
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.blueAccent,
              alignment: Alignment.center,
              child: const Icon(Icons.person, color: Colors.white, size: 26),
            );
          },
        ),
      ),
    );
  }
}