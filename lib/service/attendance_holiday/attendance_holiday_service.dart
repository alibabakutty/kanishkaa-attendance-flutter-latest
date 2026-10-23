import 'dart:convert';
import 'package:attendance_app/modals/attendance_holiday.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AttendanceHolidayService {
  // ============================================================
  // CONFIGURATION
  // ============================================================

  final String baseUrl;

  static const String endpoint =
      '/api/v1/attendance/holidays';

  // ============================================================
  // SECURE STORAGE
  // ============================================================

  final FlutterSecureStorage _storage =
      const FlutterSecureStorage();

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  AttendanceHolidayService({
    required this.baseUrl,
  });

  // ============================================================
  // TOKEN MANAGEMENT
  // ============================================================

  Future<String?> _getToken() async {
    return await _storage.read(
      key: 'jwt_token',
    );
  }

  // ============================================================
  // AUTH HEADERS
  // ============================================================

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    return headers;
  }

  // ============================================================
  // GET ALL HOLIDAYS
  //
  // GET /api/v1/attendance/holidays
  // ============================================================

  Future<List<AttendanceHoliday>> getAll() async {
    final uri = _buildUri(endpoint);

    final response = await http.get(
      uri,
      headers: await _headers(),
    );

    _validateResponse(response);

    final decoded = _decodeJson(response);

    if (decoded is! List) {
      throw AttendanceHolidayApiException(
        'Invalid holiday list received from server.',
        response.statusCode,
      );
    }

    final holidays = decoded
        .map(
          (json) => AttendanceHoliday.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList();

    holidays.sort(
      (a, b) => a.holidayDate.compareTo(
        b.holidayDate,
      ),
    );

    return holidays;
  }

  // ============================================================
  // GET HOLIDAYS BY MONTH
  //
  // GET /api/v1/attendance/holidays/month
  // ?year=2026&month=10
  // ============================================================

  Future<List<AttendanceHoliday>> getByMonth({
    required int year,
    required int month,
  }) async {
    if (month < 1 || month > 12) {
      throw ArgumentError(
        'Month must be between 1 and 12.',
      );
    }

    final uri = _buildUri(
      '$endpoint/month',
      queryParameters: {
        'year': year.toString(),
        'month': month.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: await _headers(),
    );

    _validateResponse(response);

    final decoded = _decodeJson(response);

    if (decoded is! List) {
      throw AttendanceHolidayApiException(
        'Invalid holiday list received from server.',
        response.statusCode,
      );
    }

    final holidays = decoded
        .map(
          (json) => AttendanceHoliday.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList();

    holidays.sort(
      (a, b) => a.holidayDate.compareTo(
        b.holidayDate,
      ),
    );

    return holidays;
  }

  // ============================================================
  // GET HOLIDAY BY DATE
  //
  // GET /api/v1/attendance/holidays/date
  // ?date=2026-10-07
  // ============================================================

  Future<AttendanceHoliday?> getByDate(
    DateTime date,
  ) async {
    final uri = _buildUri(
      '$endpoint/date',
      queryParameters: {
        'date': _formatDate(date),
      },
    );

    final response = await http.get(
      uri,
      headers: await _headers(),
    );

    // Backend returns 404 when holiday doesn't exist.
    if (response.statusCode == 404) {
      return null;
    }

    _validateResponse(response);

    final decoded = _decodeJson(response);

    if (decoded is! Map<String, dynamic>) {
      throw AttendanceHolidayApiException(
        'Invalid holiday response received from server.',
        response.statusCode,
      );
    }

    return AttendanceHoliday.fromJson(decoded);
  }

  // ============================================================
  // CREATE HOLIDAY
  //
  // POST /api/v1/attendance/holidays
  // ============================================================

  Future<AttendanceHoliday> create(
    AttendanceHolidayRequest request,
  ) async {
    final uri = _buildUri(endpoint);

    final response = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(
        request.toJson(),
      ),
    );

    _validateResponse(response);

    final decoded = _decodeJson(response);

    if (decoded is! Map<String, dynamic>) {
      throw AttendanceHolidayApiException(
        'Invalid response received after creating holiday.',
        response.statusCode,
      );
    }

    return AttendanceHoliday.fromJson(decoded);
  }

  // ============================================================
  // DELETE / DEACTIVATE HOLIDAY
  //
  // DELETE /api/v1/attendance/holidays/{id}
  // ============================================================

  Future<void> delete(
    int id,
  ) async {
    if (id <= 0) {
      throw ArgumentError(
        'Invalid holiday ID.',
      );
    }

    final uri = _buildUri(
      '$endpoint/$id',
    );

    final response = await http.delete(
      uri,
      headers: await _headers(),
    );

    _validateResponse(response);
  }

  // ============================================================
  // URI BUILDER
  // ============================================================

  Uri _buildUri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final cleanBaseUrl = baseUrl.trim().replaceAll(
          RegExp(r'/$'),
          '',
        );

    final cleanPath = path.startsWith('/')
        ? path
        : '/$path';

    return Uri.parse(
      '$cleanBaseUrl$cleanPath',
    ).replace(
      queryParameters: queryParameters,
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // JSON DECODER
  // ============================================================

  dynamic _decodeJson(
    http.Response response,
  ) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw AttendanceHolidayApiException(
        'Invalid JSON response received from server.',
        response.statusCode,
      );
    }
  }

  // ============================================================
  // RESPONSE VALIDATION
  // ============================================================

  void _validateResponse(
    http.Response response,
  ) {
    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return;
    }

    throw AttendanceHolidayApiException(
      _extractErrorMessage(response),
      response.statusCode,
    );
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  String _extractErrorMessage(
    http.Response response,
  ) {
    // ----------------------------------------------------------
    // Duplicate holiday date
    // ----------------------------------------------------------

    if (response.statusCode == 409) {
      return 'A holiday already exists for this date.';
    }

    // ----------------------------------------------------------
    // Empty response
    // ----------------------------------------------------------

    if (response.body.trim().isEmpty) {
      return _defaultErrorMessage(
        response.statusCode,
      );
    }

    // ----------------------------------------------------------
    // Try JSON response
    // ----------------------------------------------------------

    try {
      final decoded = jsonDecode(
        response.body,
      );

      if (decoded is Map<String, dynamic>) {
        // Spring Boot:
        // {
        //   "message": "..."
        // }

        if (decoded['message'] != null) {
          return decoded['message'].toString();
        }

        // Spring validation:
        // {
        //   "errors": {
        //      "holidayName": "Holiday name is required"
        //   }
        // }

        if (decoded['errors'] != null) {
          final errors = decoded['errors'];

          if (errors is Map) {
            return errors.entries
                .map(
                  (entry) =>
                      '${entry.key}: ${entry.value}',
                )
                .join('\n');
          }

          if (errors is List) {
            return errors
                .map(
                  (error) => error.toString(),
                )
                .join('\n');
          }
        }

        // Spring Boot:
        // {
        //   "error": "..."
        // }

        if (decoded['error'] != null) {
          return decoded['error'].toString();
        }

        // RFC 7807 / ProblemDetail

        if (decoded['detail'] != null) {
          return decoded['detail'].toString();
        }

        if (decoded['title'] != null) {
          return decoded['title'].toString();
        }
      }

      if (decoded is String &&
          decoded.trim().isNotEmpty) {
        return decoded;
      }
    } catch (_) {
      // Not JSON.
    }

    // ----------------------------------------------------------
    // Plain text response
    // ----------------------------------------------------------

    if (response.body.trim().isNotEmpty) {
      return response.body.trim();
    }

    return _defaultErrorMessage(
      response.statusCode,
    );
  }

  // ============================================================
  // DEFAULT HTTP ERROR MESSAGES
  // ============================================================

  String _defaultErrorMessage(
    int statusCode,
  ) {
    switch (statusCode) {
      case 400:
        return 'Invalid holiday information.';

      case 401:
        return 'Your session has expired. Please login again.';

      case 403:
        return 'You are not authorized to perform this action.';

      case 404:
        return 'Holiday was not found.';

      case 409:
        return 'A holiday already exists for this date.';

      case 422:
        return 'The holiday information could not be processed.';

      case 500:
        return 'Internal server error.';

      case 502:
        return 'Bad gateway. Please try again later.';

      case 503:
        return 'Attendance server is currently unavailable.';

      default:
        return 'Request failed. HTTP $statusCode';
    }
  }
}

// ============================================================
// API EXCEPTION
// ============================================================

class AttendanceHolidayApiException
    implements Exception {
  final String message;
  final int statusCode;

  const AttendanceHolidayApiException(
    this.message,
    this.statusCode,
  );

  @override
  String toString() {
    return message;
  }
}