import 'package:attendance_app/screen/public_holiday_marker/public_holiday_marker.dart';
import 'package:flutter/material.dart';
import 'package:attendance_app/screen/admin_approval/admin_approval_page.dart';
// Import your Public Holiday Marker page when created
// import 'package:attendance_app/screen/public_holiday_marker/public_holiday_marker.dart';

const Color backgroundColor = Color(0xFF273F4F);
const Color textPrimary = Color(0xFFF1F2F6);
const Color textSecondary = Color(0xFFB0BEC5);

class AdminManagementSubmenu extends StatelessWidget {
  const AdminManagementSubmenu({super.key});

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Widget _buildSubmenuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: Colors.white),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.cyanAccent),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Admin Management',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.cyanAccent,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Admin Control Panel',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a category to manage administrative tasks.',
                style: TextStyle(color: textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 1.0,
                  children: [
                    // Submenu 1: Admin Late Approval
                    _buildSubmenuCard(
                      context: context,
                      icon: Icons.assignment_turned_in,
                      title: 'Late Approval',
                      description: 'Review and approve employee late entries',
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBDA61), Color(0xFFFF5ACD)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      onTap: () => _navigateTo(context, const AdminApprovalPage()),
                    ),

                    // Submenu 2: Public Holiday Marker
                    _buildSubmenuCard(
                      context: context,
                      icon: Icons.calendar_today,
                      title: 'Public Holidays',
                      description: 'Mark or update company public holidays',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () {
                        // Navigate to your Public Holiday screen when created:
                        _navigateTo(context, const PublicHolidayMarker());
                      },
                    ),

                    // Add future submenus here simply by adding more _buildSubmenuCard items!
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}