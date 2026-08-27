// lib/services/attendance_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:attendance_app/modals/cumulative_attendance_model.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:attendance_app/modals/mark_attendance_data.dart';

class AttendanceService {
  final String baseUrl;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AttendanceService({
    required this.baseUrl,
  });

  // -------------------------------
  // TOKEN MANAGEMENT
  // -------------------------------
  Future<String?> _getToken() async {
    return await _storage.read(key: "jwt_token");
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  // -------------------------------
  // RESPONSE HANDLER
  // -------------------------------
  dynamic _handleResponse(http.Response response) {
    final decoded = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    } else {
      final String errorMessage = decoded["reason"] ?? 
                                  decoded["message"] ?? 
                                  decoded["error"] ?? 
                                  "API Error (${response.statusCode})";
      throw Exception(errorMessage);
    }
  }

  String extractErrorMessage(dynamic response) {
    try {
      final body = jsonDecode(response.body);
      return body["reason"] ?? body["message"] ?? body["error"] ?? "Submission rejected by server context.";
    } catch (_) {
      return "Submission rejected by server context.";
    }
  }

  // -------------------------------
  // CREATE Attendance Master
  // -------------------------------
  Future<MarkAttendanceData> createAttendance({
    required MarkAttendanceData data,
  }) async {
    final url = Uri.parse("$baseUrl/api/v1/attendance-masters");

    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode(data.toJson()),
    );

    final decoded = _handleResponse(response);
    return MarkAttendanceData.fromJson(decoded);
  }

  // -------------------------------
  // MARK Attendance (Site Check-In / Check-Out)
  // -------------------------------
  Future<MarkAttendanceData> markAttendance({
    required MarkAttendanceData data,
  }) async {
    final url = Uri.parse("$baseUrl/api/v1/attendance-masters/mark");

    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode(data.toJson()),
    );

    final decoded = _handleResponse(response);
    return MarkAttendanceData.fromJson(decoded);
  }

  // -------------------------------
  // GET BY ID
  // -------------------------------
  Future<MarkAttendanceData> getById(int id) async {
    final url = Uri.parse("$baseUrl/api/v1/attendance-masters/$id");

    final response = await http.get(
      url,
      headers: await _headers(),
    );

    final decoded = _handleResponse(response);
    return MarkAttendanceData.fromJson(decoded);
  }

  // -------------------------------
  // GET TODAY ATTENDANCE
  // -------------------------------
  Future<MarkAttendanceData> getTodayAttendance(String employeeName) async {
    final url = Uri.parse("$baseUrl/api/v1/attendance-masters/today/$employeeName");

    final response = await http.get(
      url,
      headers: await _headers(),
    );

    final decoded = _handleResponse(response);
    return MarkAttendanceData.fromJson(decoded);
  }

  // -------------------------------
  // SEARCH BY MOBILE AND DATE
  // -------------------------------
  Future<MarkAttendanceData?> getAttendanceByMobileAndDate({
    required String mobileNumber,
    required String date,
  }) async {
    final url = Uri.parse(
      "$baseUrl/api/v1/attendance-masters/search-by-mobile-number-and-date",
    ).replace(queryParameters: {
      'mobileNumber': mobileNumber,
      'attendanceDate': date,
    });

    final response = await http.get(
      url,
      headers: await _headers(),
    );

    if (response.statusCode == 404) {
      return null;
    }

    final decoded = _handleResponse(response);
    return MarkAttendanceData.fromJson(decoded);
  }

  // -------------------------------
  // GET ALL
  // -------------------------------
  Future<List<MarkAttendanceData>> getAllAttendance() async {
    final url = Uri.parse("$baseUrl/api/v1/attendance-masters");

    final response = await http.get(
      url,
      headers: await _headers(),
    );

    final decoded = _handleResponse(response);
    final List<dynamic> attendanceList = decoded["Data"] ?? [];

    return attendanceList.map((e) => MarkAttendanceData.fromJson(e)).toList();
  }

  // -------------------------------
  // UPDATE
  // -------------------------------
  Future<MarkAttendanceData> updateAttendance({
    required int id,
    required MarkAttendanceData data,
  }) async {
    final url = Uri.parse("$baseUrl/api/v1/attendance-masters/$id");

    final response = await http.put(
      url,
      headers: await _headers(),
      body: jsonEncode(data.toJson()),
    );

    final decoded = _handleResponse(response);
    return MarkAttendanceData.fromJson(decoded);
  }

  // -------------------------------
  // UPDATE BY MOBILE AND DATE
  // -------------------------------
  Future<MarkAttendanceData> updateAttendanceByMobileAndDate({
    required String mobileNumber,
    required String date,
    required MarkAttendanceData data,
  }) async {
    final url = Uri.parse(
      "$baseUrl/api/v1/attendance-masters/update-attendance-by-mobile-number-and-date",
    ).replace(queryParameters: {
      'mobileNumber': mobileNumber,
      'selectedDate': date,
    });

    final response = await http.put(
      url,
      headers: await _headers(),
      body: jsonEncode(data.toJson()),
    );

    final decoded = _handleResponse(response);
    return MarkAttendanceData.fromJson(decoded);
  }

  // -------------------------------
  // DELETE
  // -------------------------------
  Future<void> deleteAttendance(int id) async {
    final url = Uri.parse("$baseUrl/api/v1/attendance-masters/$id");

    final response = await http.delete(
      url,
      headers: await _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _handleResponse(response);
    }
  }

  // -------------------------------
  // SITE NAME MASTERS
  // -------------------------------
  Future<List<Map<String, dynamic>>> fetchSiteNames() async {
    final url = Uri.parse("$baseUrl/api/v1/site-name-masters");

    final response = await http.get(
      url,
      headers: await _headers(),
    ).timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch site names');
    }

    final List data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data);
  }

  // -------------------------------
  // LEGACY SUPPORT METHODS (for backward compatibility)
  // -------------------------------
  
  // This method converts the legacy payload format to MarkAttendanceData
  Future<dynamic> markAttendanceLegacy(Map<String, dynamic> payload) async {
    // Convert payload to MarkAttendanceData if needed
    // Or handle it as is
    final url = Uri.parse("$baseUrl/api/v1/attendance-masters/mark");
    
    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(extractErrorMessage(response));
    }
  }

    // Legacy method for fetching today attendance (returns Map, not MarkAttendanceData)
  Future<Map<String, dynamic>> fetchTodayAttendanceLegacy(String employeeName) async {
    final url = Uri.parse("$baseUrl/api/v1/attendance-masters/today/$employeeName");
    
    final response = await http.get(
      url,
      headers: await _headers(),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200 || response.body.trim().isEmpty) {
      throw Exception('Failed to fetch attendance data');
    }

    return jsonDecode(response.body);
  }

  // Legacy method for fetching site names (returns List<Map>)
  Future<List<Map<String, dynamic>>> fetchSiteNamesLegacy() async {
    final url = Uri.parse("$baseUrl/api/v1/site-name-masters");
    
    final response = await http.get(
      url,
      headers: await _headers(),
    ).timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch site names');
    }

    final List data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data);
  }

  // -------------------------------
  // GET CUMULATIVE ALL ATTENDANCE
  // -------------------------------
  Future<List<CumulativeAttendanceModel>>
      getCumulativeAttendance({
    required int year,
    required int month,
  }) async {
    final url = Uri.parse(
      "$baseUrl/api/v1/attendance-masters/cumulative/all",
    ).replace(
      queryParameters: {
        'year': year.toString(),
        'month': month.toString(),
      },
    );

    final response = await http.get(
      url,
      headers: await _headers(),
    ).timeout(
      const Duration(seconds: 15),
    );

    final decoded = _handleResponse(response);

    if (decoded is! List) {
      throw Exception(
        'Invalid cumulative attendance response from server',
      );
    }

    return decoded
        .map(
          (e) => CumulativeAttendanceModel.fromJson(
            e as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}