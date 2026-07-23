import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/authentication/auth_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ShiftLapTrackerView extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final String initialAttendanceDate;

  const ShiftLapTrackerView({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.initialAttendanceDate,
  });

  @override
  State<ShiftLapTrackerView> createState() => _ShiftLapTrackerViewState();
}

class _ShiftLapTrackerViewState extends State<ShiftLapTrackerView> {
  late DateTime _selectedDate;
  final MapController _mapController = MapController();
  
  // High-fidelity map structures
  List<LatLng> _routeCoordinates = [];
  List<Marker> _mapMarkers = [];
  List<dynamic> _siteVisitsList = [];
  
  bool _isLoading = false;
  String? _timeInStr;
  String? _timeOutStr;
  String? _totalHoursStr;
  String? _attendanceStatus;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateFormat('yyyy-MM-dd').parse(widget.initialAttendanceDate);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchHistoricalLap();
    });
  }

  Future<void> _fetchHistoricalLap() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final String baseUrl = dotenv.env['API_BASE_URL'] ?? "http://165.99.213.125:8082";

    final String url = "$baseUrl/api/v1/attendance-masters/date/$formattedDate";

    try {
      debugPrint("Fetching comprehensive lap logs from: $url");
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> records = jsonDecode(response.body);
        
        List<LatLng> calculatedPoints = [];
        List<Marker> markersGenerated = [];
        List<dynamic> localizedVisits = [];
        
        String? checkInTime;
        String? checkOutTime;
        String? totalHours;
        String? statusLabel;

        final log = records.firstWhere(
          (element) => element['employeeId']?.toString().trim() == widget.employeeId.trim(),
          orElse: () => null,
        );

        if (log != null) {
          checkInTime = log['officeTimeIn'];
          checkOutTime = log['officeTimeOut'];
          totalHours = log['totalAttendanceHours'];
          statusLabel = log['status'];

          // 1. Process Shift Start Anchor Location
          if (log['officeTimeInLocation'] != null) {
            final double? lat = double.tryParse(log['officeTimeInLocation']['latitude']?.toString() ?? '');
            final double? lng = double.tryParse(log['officeTimeInLocation']['longitude']?.toString() ?? '');
            if (lat != null && lng != null) {
              final startLatLng = LatLng(lat, lng);
              calculatedPoints.add(startLatLng);
              
              markersGenerated.add(
                Marker(
                  point: startLatLng,
                  width: 45,
                  height: 45,
                  child: Tooltip(
                    message: "Shift Started ($checkInTime)",
                    child: const Icon(Icons.play_circle_fill, color: Colors.green, size: 38),
                  ),
                ),
              );
            }
          }

          // 2. Process multi-site sequential intermediate stops
          if (log['visits'] != null && (log['visits'] as List).isNotEmpty) {
            localizedVisits = log['visits'] as List;
            
            for (var index = 0; index < localizedVisits.length; index++) {
              final visit = localizedVisits[index];
              final String siteTitle = visit['siteName'] ?? "Unknown Workspace";
              final String timeIn = visit['timeIn'] ?? '--:--';
              final String timeOut = visit['timeOut'] ?? 'In Progress';

              // Extract point where worker checked into intermediate site
              if (visit['timeInLocation'] != null) {
                final double? vLat = double.tryParse(visit['timeInLocation']['latitude']?.toString() ?? '');
                final double? vLng = double.tryParse(visit['timeInLocation']['longitude']?.toString() ?? '');
                if (vLat != null && vLng != null) {
                  final siteInPoint = LatLng(vLat, vLng);
                  calculatedPoints.add(siteInPoint);

                  markersGenerated.add(
                    Marker(
                      point: siteInPoint,
                      width: 40,
                      height: 40,
                      child: Tooltip(
                        message: "$siteTitle\nIn: $timeIn\nOut: $timeOut",
                        child: CircleAvatar(
                          backgroundColor: Colors.blue.shade900,
                          radius: 14,
                          child: Text(
                            "${index + 1}",
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              }

              // Extract point where worker checked out of intermediate site
              if (visit['timeOutLocation'] != null) {
                final double? voLat = double.tryParse(visit['timeOutLocation']['latitude']?.toString() ?? '');
                final double? voLng = double.tryParse(visit['timeOutLocation']['longitude']?.toString() ?? '');
                if (voLat != null && voLng != null) {
                  calculatedPoints.add(LatLng(voLat, voLng));
                }
              }
            }
          }

          // 3. Process Shift End Anchor Location
          if (log['officeTimeOutLocation'] != null) {
            final double? outLat = double.tryParse(log['officeTimeOutLocation']['latitude']?.toString() ?? '');
            final double? outLng = double.tryParse(log['officeTimeOutLocation']['longitude']?.toString() ?? '');
            if (outLat != null && outLng != null) {
              final endLatLng = LatLng(outLat, outLng);
              calculatedPoints.add(endLatLng);
              
              markersGenerated.add(
                Marker(
                  point: endLatLng,
                  width: 45,
                  height: 45,
                  child: Tooltip(
                    message: "Shift Ended ($checkOutTime)",
                    child: const Icon(Icons.flag_circle, color: Colors.red, size: 38),
                  ),
                ),
              );
            }
          }
        }

        setState(() {
          _routeCoordinates = calculatedPoints;
          _mapMarkers = markersGenerated;
          _siteVisitsList = localizedVisits;
          _timeInStr = checkInTime;
          _timeOutStr = checkOutTime;
          _totalHoursStr = totalHours;
          _attendanceStatus = statusLabel;
          _isLoading = false;
        });

        // Smart map reframing to target the route center
        if (calculatedPoints.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 200), () {
            _mapController.move(calculatedPoints.first, 13.5);
          });
        }

      } else {
        throw Exception("Server failed with code: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _routeCoordinates = [];
        _mapMarkers = [];
        _siteVisitsList = [];
        _isLoading = false;
      });
      debugPrint("Parsing/Network Failure Trace: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error parsing historical maps: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF273F4F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${widget.employeeName} (${widget.employeeId})",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              "Route Logs: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}",
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            )
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _fetchHistoricalLap();
              }
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF273F4F)))
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _routeCoordinates.isNotEmpty 
                        ? _routeCoordinates.first 
                        : const LatLng(12.9489, 78.8704),
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.attendance.app',
                    ),
                    if (_routeCoordinates.isNotEmpty) ...[
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routeCoordinates,
                            strokeWidth: 4.5,
                            color: Colors.indigo.shade700,
                          ),
                        ],
                      ),
                      MarkerLayer(markers: _mapMarkers),
                    ],
                  ],
                ),
                
                if (_routeCoordinates.isEmpty)
                  Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(24),
                    child: const Center(
                      child: Text(
                        "No tracking coordinates logs found for this date.\nPick a different date inside the Calendar window above.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),

                // Top Floating Status Analytics Board
                if (_routeCoordinates.isNotEmpty)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Card(
                      color: const Color(0xFF273F4F).withOpacity(0.95),
                      elevation: 6,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Shift In: ${_timeInStr ?? '--:--'}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text("Shift Out: ${_timeOutStr ?? 'Active'}", style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const Divider(color: Colors.white24, height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Hours Active: ${_totalHoursStr ?? '00:00'}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                                Text("Status: ${_attendanceStatus ?? 'N/A'}", style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Bottom Drawer View tracking historical entries sequentially
                if (_siteVisitsList.isNotEmpty)
                  _buildVisitsCollapsibleDrawer(),
              ],
            ),
    );
  }

  Widget _buildVisitsCollapsibleDrawer() {
    return DraggableScrollableSheet(
      initialChildSize: 0.12,
      minChildSize: 0.12,
      maxChildSize: 0.45,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, spreadRadius: 1)
            ],
          ),
          child: ListView.builder(
            controller: scrollController,
            itemCount: _siteVisitsList.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }

              final visit = _siteVisitsList[index - 1];
              return Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.shade900,
                      radius: 12,
                      child: Text("$index", style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                    title: Text(
                      visit['siteName'] ?? 'Unknown Site Location',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF273F4F)),
                    ),
                    subtitle: Text(
                      "Timeline: ${visit['timeIn'] ?? '--'} to ${visit['timeOut'] ?? 'Active'} (${visit['visitType']})",
                      style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                    ),
                    trailing: Icon(
                      visit['geofenceVerified'] == true ? Icons.verified : Icons.gpp_maybe,
                      color: visit['geofenceVerified'] == true ? Colors.green : Colors.amber,
                      size: 20,
                    ),
                  ),
                  const Divider(height: 1, indent: 50, endIndent: 16),
                ],
              );
            },
          ),
        );
      },
    );
  }
}