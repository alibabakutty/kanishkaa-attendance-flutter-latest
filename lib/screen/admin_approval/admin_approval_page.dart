import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/authentication/auth_provider.dart';

class AdminApprovalPage extends StatefulWidget {
  const AdminApprovalPage({super.key});

  @override
  State<AdminApprovalPage> createState() => _AdminApprovalPageState();
}

class _AdminApprovalPageState extends State<AdminApprovalPage> {
  final String baseUrl = dotenv.get('API_BASE_URL', fallback: 'http://192.168.1.4:8080');
  
  List<dynamic> _pendingRequests = [];
  bool _isLoading = true;
  int? _processingId; // Tracks individual item ID over a broad global boolean

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPendingApprovals();
    });
  }

  // --- API: FETCH QUEUE ---
  Future<void> _fetchPendingApprovals() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAdmin) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/attendance-masters/pending'),
        headers: authProvider.authHeaders,
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _pendingRequests = jsonDecode(response.body);
        });
      }
    } catch (e) {
      _showSnackBar('Error loading approval queue: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- API: RESOLVE REQUEST (APPROVE / REJECT WITH ADMIN TRACKING) ---
  Future<void> _resolveRequest(int id, bool approve) async {
    if (_processingId != null) return; 
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _processingId = id);

    // Get the logged-in admin's identity
    final String adminUsername = authProvider.username ?? 'UnknownAdmin';

    try {
      // Encodes spaces/special characters safely
      final String encodedAdmin = Uri.encodeComponent(adminUsername);
      
      // CHANGED: Query param key is now adminApprovedBy to match your backend exactly
      final url = Uri.parse(
        '$baseUrl/api/v1/attendance-masters/resolve/$id?approve=$approve&adminApprovedBy=$encodedAdmin'
      );

      final response = await http.put(
        url,
        headers: authProvider.authHeaders,
      ).timeout(const Duration(seconds: 8));

      if ((response.statusCode == 200 || response.statusCode == 201) && mounted) {
        _showSnackBar(
          approve ? 'Late check-in approved successfully.' : 'Check-in request rejected.',
          approve ? Colors.green : Colors.orange,
        );
        _fetchPendingApprovals();
      } else {
        _showSnackBar('Server rejected action execution.', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Network error resolving request: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  void _showSnackBar(String message, Color background) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isAdmin) {
      return const Scaffold(
        backgroundColor: Color(0xFF273F4F),
        body: Center(
          child: Text(
            'Access Denied: Admin Privileges Required',
            style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF273F4F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF273F4F),
        elevation: 1,
        title: const Text('Late Approval Queue', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.cyanAccent),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : RefreshIndicator(
              color: Colors.cyanAccent,
              onRefresh: _fetchPendingApprovals,
              child: _pendingRequests.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _pendingRequests.length,
                      itemBuilder: (context, index) {
                        return _buildApprovalCard(_pendingRequests[index]);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return const CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user, size: 64, color: Colors.cyanAccent),
                SizedBox(height: 16),
                Text('Queue Clean!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('No pending late check-in approvals found.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // FIXED: Accepts dynamic parameter type to prevent casting error from the JSON list mapping
  Widget _buildApprovalCard(dynamic requestItem) {
    final Map<String, dynamic> request = requestItem as Map<String, dynamic>;
    
    final int requestId = request['id'] ?? 0;
    final String employeeName = request['employeeName'] ?? 'Unknown';
    final String empId = request['employeeId'] ?? 'N/A';
    final String dateStr = request['attendanceDate'] ?? '';
    final String timeInStr = request['officeTimeIn'] ?? '--:--';
    final bool isThisCardCardProcessing = _processingId == requestId;

    String formattedDate = dateStr;
    try {
      DateTime parsedDate = DateTime.parse(dateStr);
      formattedDate = DateFormat('EEE, MMM d, yyyy').format(parsedDate);
    } catch (_) {}

    return Card(
      color: const Color(0xFF37474F),
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(employeeName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Text('LATE ARRIVAL', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 4),
            Text('ID: $empId', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const Divider(color: Colors.white24, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Shift Date', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(formattedDate, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Punch-In Time', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(timeInStr, style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isThisCardCardProcessing)
              const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.cyanAccent)))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                      onPressed: _processingId != null ? null : () => _resolveRequest(requestId, false),
                      label: const Text('Reject', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.check, color: Colors.white, size: 18),
                      onPressed: _processingId != null ? null : () => _resolveRequest(requestId, true),
                      label: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }
}