import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/authentication/auth_provider.dart';

class MarkAttendanceHelper {
  static String getOverallAttendanceStatus({
    required bool isAwaitingApproval,
    required DateTime? officeTimeIn,
    required DateTime? officeTimeOut,
  }) {
    if (isAwaitingApproval) return 'Pending Approval';
    if (officeTimeIn == null) return 'Absent';
    if (officeTimeOut == null) return 'In Progress';
    return 'Present';
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'pending approval':
        return Colors.amber.shade800;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static bool isPastGracePeriod() {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day, 9, 30);
    return now.isAfter(cutoff);
  }
}

class ProfileHeaderWidget extends StatelessWidget {
  final AuthProvider authProvider;
  final String status;
  final Color statusColor;

  const ProfileHeaderWidget({
    super.key,
    required this.authProvider,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${authProvider.employeeId ?? ''} ${authProvider.username ?? ''}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Multi-Route Allocation Logs',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        Chip(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          label: Text(
            status,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class HeaderDashboardWidget extends StatelessWidget {
  final AuthProvider authProvider;
  final double width;
  final bool isAwaitingApproval;

  const HeaderDashboardWidget({
    super.key,
    required this.authProvider,
    required this.width,
    required this.isAwaitingApproval,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.blueGrey.shade700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: width * 0.44,
          height: width * 0.44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isAwaitingApproval ? Colors.amber.shade700 : Colors.blue.shade700,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: authProvider.employeeImageBytes != null
                ? Image.memory(
                    authProvider.employeeImageBytes!,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Colors.grey.shade100,
                    child: const Icon(
                      Icons.person,
                      size: 75,
                      color: Colors.grey,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class ApprovalWarningWidget extends StatelessWidget {
  const ApprovalWarningWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade400, width: 1.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty, color: Colors.amber.shade900, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Late Punch Detected! Your check-in has been routed to the Admin Approval Queue. Subsequent actions remain locked until an admin resolves this entry.',
              style: TextStyle(
                color: Color(0xFF7F5F00),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActionCardWidget extends StatelessWidget {
  String get currentShift {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    const dayShiftStart = 9 * 60;  // 09:00 AM
    const nightShiftStart = 21 * 60; // 09:00 PM

    return currentMinutes >= dayShiftStart &&
            currentMinutes < nightShiftStart
        ? 'Day Shift'
        : 'Night Shift';
  }

  final bool isSubmitted;
  final bool isAwaitingApproval;
  final bool hasActiveVisitSession;
  final String? activeSiteName;
  final bool isCustomSite;
  final bool isOptimisticUpdating;
  final DateTime? officeTimeIn;
  final VoidCallback onSiteOut;
  final VoidCallback onSiteIn;
  final VoidCallback onDayOut;
  final ValueChanged<bool?> onCustomSiteChanged;
  final Widget dropdownWidget;
  final TextEditingController remarksController;

  const ActionCardWidget({
    super.key,
    required this.isSubmitted,
    required this.isAwaitingApproval,
    required this.hasActiveVisitSession,
    required this.activeSiteName,
    required this.isCustomSite,
    required this.isOptimisticUpdating,
    required this.officeTimeIn,
    required this.onSiteOut,
    required this.onSiteIn,
    required this.onDayOut,
    required this.onCustomSiteChanged,
    required this.dropdownWidget,
    required this.remarksController,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isSubmitted
                        ? 'Shift Ended'
                        : hasActiveVisitSession
                            ? 'Active Site Session'
                            : isAwaitingApproval
                                ? 'Late Check-In (Pending Approval)'
                                : 'Ready to Check-In',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: currentShift == 'Day Shift'
                        ? Colors.orange.shade50
                        : Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: currentShift == 'Day Shift'
                          ? Colors.orange
                          : Colors.indigo,
                    ),
                  ),
                  child: Text(
                    currentShift,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: currentShift == 'Day Shift'
                          ? Colors.deepOrange.shade700
                          : Colors.indigo.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),

            // PRIORITIZE ACTIVE VISIT: Always let user check out of a site even if approval is pending!
            if (hasActiveVisitSession) ...[
              _buildActiveSessionState(),
            ] else if (!isSubmitted && !isAwaitingApproval) ...[
              _buildCheckInState(),
            ],

            if (officeTimeIn != null &&
                !hasActiveVisitSession &&
                !isSubmitted) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(),
              ),
              _buildDayOutButton(),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "Currently checked into:\n» $activeSiteName",
            style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[800],
            minimumSize: const Size(double.infinity, 48),
          ),
          icon: isOptimisticUpdating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.no_meeting_room, color: Colors.white),
          onPressed: isOptimisticUpdating ? null : onSiteOut,
          label: const Text(
            'Check Out of Current Site',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckInState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: isCustomSite,
              onChanged: onCustomSiteChanged,
            ),
            const Expanded(
              child: Text(
                "Out of Boundary / Custom Work (Bypass Geofence)",
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (!isCustomSite) ...[
          const Text('Select Baseline Fixed Worksite', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          dropdownWidget,
        ] else ...[
          const Text('Purpose / Assignment Custom Label', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextFormField(
            controller: remarksController,
            decoration: const InputDecoration(
              hintText: 'e.g., Procurement or out-of-boundary purchase task runs',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[800],
            minimumSize: const Size(double.infinity, 48),
          ),
          icon: isOptimisticUpdating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.meeting_room, color: Colors.white),
          onPressed: isOptimisticUpdating ? null : onSiteIn,
          label: const Text(
            'Mark Site Check-In',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildDayOutButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red[800],
        minimumSize: const Size(double.infinity, 48),
      ),
      icon: isOptimisticUpdating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : const Icon(Icons.assignment_turned_in, color: Colors.white),
      onPressed: isOptimisticUpdating ? null : onDayOut,
      label: const Text(
        'Finish Workday (Final Day Out)',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class SiteDropdownWidget extends StatelessWidget {
  final List<Map<String, dynamic>> siteMasterList;
  final Map<String, dynamic>? selectedSiteObject;
  final ValueChanged<Map<String, dynamic>?> onChanged;

  const SiteDropdownWidget({
    super.key,
    required this.siteMasterList,
    required this.selectedSiteObject,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? matchedValue;
    if (selectedSiteObject != null) {
      matchedValue = siteMasterList.firstWhere(
        (element) => element['siteId'] == selectedSiteObject!['siteId'],
        orElse: () => siteMasterList.isNotEmpty ? siteMasterList.first : {},
      );
      if (matchedValue.isEmpty) matchedValue = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        // Overall outer border for the dropdown box
        border: Border.all(color: Colors.grey.shade400, width: 1.0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: matchedValue,
          hint: const Text('Select Target Workspace Location'),
          isExpanded: true,
          itemHeight: 48.0, // Reduced item height for a thin, compact row
          items: siteMasterList.map((siteMap) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: siteMap,
              child: Container(
                width: double.infinity,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                // Single bottom border line per site to avoid double-thick borders
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1.0),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '[${siteMap['siteId']}] ${siteMap['siteName']}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis, // Cleanly truncate long text with ...
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class LogStatusCardWidget extends StatelessWidget {
  final String title;
  final DateTime? timestamp;
  final bool isAwaitingApproval;

  const LogStatusCardWidget({
    super.key,
    required this.title,
    required this.timestamp,
    required this.isAwaitingApproval,
  });

  @override
  Widget build(BuildContext context) {
    final isStartCard = title.contains('Start');
    final isAwaiting = isAwaitingApproval && isStartCard;

    return Card(
      color: Colors.white,
      child: ListTile(
        leading: Icon(
          Icons.access_time,
          color: isAwaiting
              ? Colors.amber.shade700
              : (timestamp != null ? Colors.green : Colors.grey),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        trailing: Text(
          isAwaiting
              ? 'Awaiting Approval'
              : (timestamp != null ? DateFormat('hh:mm a').format(timestamp!) : 'Pending'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isAwaiting
                ? Colors.amber.shade800
                : (timestamp != null ? Colors.black : Colors.grey),
          ),
        ),
      ),
    );
  }
}