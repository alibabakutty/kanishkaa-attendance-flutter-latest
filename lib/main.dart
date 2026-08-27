import 'package:attendance_app/authentication/auth_provider.dart';
import 'package:attendance_app/screen/attendance_report/attendance_report.dart';
import 'package:attendance_app/screen/employee_login_page.dart';
import 'package:attendance_app/screen/employee_master.dart';
import 'package:attendance_app/screen/employee_profiles.dart';
import 'package:attendance_app/screen/home_page.dart';
import 'package:attendance_app/screen/mark_attendance/mark_attendance.dart';
import 'package:attendance_app/service/mark_attendance/attendance_queue_service.dart';
import 'package:attendance_app/widget_tree.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the local storage instance
  final queueService = AttendanceQueueService();

  try {
    await dotenv.load(fileName: ".env");
    // Initialize Hive Local DB Engine securely
    await queueService.init();
  } catch (e) {
    debugPrint('Initialization warning: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        // Provide Auth State Management
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        // Provide the Offline Storage Queue Service to the entire application
        Provider<AttendanceQueueService>.value(value: queueService),
      ],
      child: const AttendanceApp(),
    ),
  );
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kanishkaa Attendance Management',
      theme: ThemeData(primarySwatch: Colors.blue),
      routes: {
        '/': (context) => const WidgetTree(),
        '/employeeLogin': (context) => const EmployeeLoginPage(),
        '/home': (context) => const HomePage(),
        '/employeeProfiles': (context) => const EmployeeProfiles(),
        '/employeeMaster': (context) => const EmployeeMaster(),
        '/markAttendance': (context) => const MarkAttendance(),
        '/attendanceHistory': (context) => const AttendanceReport()
      },
    );
  }
}