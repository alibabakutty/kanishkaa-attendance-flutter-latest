import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

enum NetworkQuality { strong, poor, offline }

class NetworkQualityService {
  static const int _timeoutMs = 3000;
  static const int _poorThresholdMs = 1500; // Latency > 1.5s is considered poor

  static Future<NetworkQuality> checkNetworkQuality(String checkUrl) async {
    try {
      final stopwatch = Stopwatch()..start();

      // Send a lightweight HEAD request to minimize data overhead
      final response = await http
          .head(Uri.parse(checkUrl))
          .timeout(Duration(milliseconds: _timeoutMs));

      stopwatch.stop();

      // If status code is valid (2xx or 3xx)
      if (response.statusCode >= 200 && response.statusCode < 400) {
        if (stopwatch.elapsedMilliseconds > _poorThresholdMs) {
          return NetworkQuality.poor;
        }
        return NetworkQuality.strong;
      }

      // If endpoint returned 404/500, fallback to standard socket ping check
      return await _fallbackSocketCheck();
    } on TimeoutException {
      return NetworkQuality.poor;
    } on SocketException {
      return NetworkQuality.offline;
    } catch (_) {
      return await _fallbackSocketCheck();
    }
  }

  // Backup raw socket check if the HTTP endpoint fails or returns non-200
  static Future<NetworkQuality> _fallbackSocketCheck() async {
    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(milliseconds: 3000));
      stopwatch.stop();
      socket.destroy();

      if (stopwatch.elapsedMilliseconds > _poorThresholdMs) {
        return NetworkQuality.poor;
      }
      return NetworkQuality.strong;
    } on TimeoutException {
      return NetworkQuality.poor;
    } catch (_) {
      return NetworkQuality.offline;
    }
  }
}