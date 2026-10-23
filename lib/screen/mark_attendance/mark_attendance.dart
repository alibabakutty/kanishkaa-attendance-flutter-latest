import 'dart:async';
import 'package:attendance_app/screen/mark_attendance/mark_attendance_helper.dart';
import 'package:attendance_app/service/mark_attendance/attendance_service.dart';
import 'package:attendance_app/service/mark_attendance/location_service.dart';
import 'package:attendance_app/service/mark_attendance/network_quality_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:attendance_app/authentication/auth_provider.dart';
import 'package:attendance_app/modals/geopoint.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MarkAttendance extends StatefulWidget {
  final bool isSunday;
  const MarkAttendance({super.key, this.isSunday = false});

  @override
  State<MarkAttendance> createState() => _MarkAttendanceState();
}

class _MarkAttendanceState extends State<MarkAttendance> with WidgetsBindingObserver {
  late AttendanceService _attendanceService;
  final LocationService _locationService = LocationService();

  // State variables
  DateTime? _officeTimeIn;
  DateTime? _officeTimeOut;
  bool _isSubmitted = false;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isAwaitingApproval = false;
  bool _isPoorNetwork = false;

  List<Map<String, dynamic>> _siteMasterList = [];
  Map<String, dynamic>? _selectedSiteObject;
  bool _isCustomSite = false;
  final TextEditingController _remarksController = TextEditingController();
  bool _hasActiveVisitSession = false;
  String? _activeSiteName;

  DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(minutes: 5);

  bool _isOptimisticUpdating = false;
  int _networkRetryCount = 0;
  static const int _maxNetworkRetries = 3;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();

    final baseUrl = dotenv.get(
      'API_BASE_URL',
      fallback: 'http://192.232.33.53:8080',
    );

    _attendanceService = AttendanceService(baseUrl: baseUrl);

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeConnectivity();
      _loadScreenData();
      _initializeLocationTracking();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();

    _locationService.dispose();

    WidgetsBinding.instance.removeObserver(this);

    _remarksController.dispose();

    super.dispose();
  }

  Future<void> _initializeConnectivity() async {
    final connectivity = Connectivity();

    // Check current state immediately
    final result = await connectivity.checkConnectivity();

    if (!mounted) return;

    _updateConnectivityStatus(result);

    // Listen for changes
    _connectivitySubscription =
        connectivity.onConnectivityChanged.listen((result) {
      if (!mounted) return;

      _updateConnectivityStatus(result);
    });
  }

  // 2. Modify _updateConnectivityStatus method
  void _updateConnectivityStatus(List<ConnectivityResult> result) async {
    final bool offline = result.isEmpty ||
        result.every((connection) => connection == ConnectivityResult.none);

    if (offline) {
      if (!mounted) return;
      setState(() {
        _isOffline = true;
        _isPoorNetwork = false;
      });
      _showOfflineSnackBar();
      return;
    }

    // Set transient state while probing network
    final String checkEndpoint = '${_attendanceService.baseUrl}/actuator/health';
    final quality = await NetworkQualityService.checkNetworkQuality(checkEndpoint);

    if (!mounted) return;

    final bool wasPoor = _isPoorNetwork;
    final bool wasOffline = _isOffline;

    setState(() {
      _isOffline = (quality == NetworkQuality.offline);
      _isPoorNetwork = (quality == NetworkQuality.poor);
    });

    if (_isOffline) {
      _showOfflineSnackBar();
    } else if (_isPoorNetwork) {
      // Only show SnackBar if transitioning into poor network state
      if (!wasPoor) {
        _showPoorNetworkSnackBar();
      }
    } else {
      // Connection is strong
      if (wasOffline || wasPoor) {
        _showOnlineSnackBar();
      }
      _lastFetchTime = null;
      _fetchTodayAttendance(forceRefresh: true);
    }
  }

  // 3. Add Poor Network SnackBar helper
  void _showPoorNetworkSnackBar() {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange.shade800,
          content: const Row(
            children: [
              Icon(
                Icons.network_check,
                color: Colors.white,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Poor network connection detected. Operations may take longer or fail. Please check your network or retry.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _showOfflineSnackBar() {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          duration: Duration(days: 1),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          content: Row(
            children: [
              Icon(
                Icons.wifi_off,
                color: Colors.white,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No internet connection. Please check your network.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _showOnlineSnackBar() {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          content: Row(
            children: [
              Icon(
                Icons.wifi,
                color: Colors.white,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Internet connection restored.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _checkConnectivityOnResume() async {
    final result = await Connectivity().checkConnectivity();

    if (!mounted) return;

    _updateConnectivityStatus(result);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastFetchTime = null;

      _checkConnectivityOnResume();

      _fetchTodayAttendance(forceRefresh: true);

      _initializeLocationTracking();
    } else if (
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {

      _locationService.dispose();
    }
  }

  // --- LOCATION TRACKING ---
  Future<void> _initializeLocationTracking() async {
    bool serviceEnabled = await _locationService.checkLocationServices();
    if (!serviceEnabled) return;

    LocationPermission permission = await _locationService.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

    _locationService.startLocationTracking((Position position) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  // --- DATA LOADING ---
  Future<void> _loadScreenData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      await _fetchTodayAttendance(forceRefresh: true);
      await _fetchSiteNames();
    } catch (e) {
      debugPrint("Initialization failure: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchTodayAttendance({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration &&
        _officeTimeIn != null) {
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final String username = authProvider.username ?? '';
      if (username.isEmpty) {
        debugPrint("Username is empty, cannot fetch attendance");
        return;
      }
      
      final data = await _attendanceService.fetchTodayAttendanceLegacy(username);

      if (!mounted) return;

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      setState(() {
        _isAwaitingApproval = data['status'] == 'PENDING_APPROVAL';
        
        // Parse office time in (handles both full timestamp strings and time-only strings)
        if (data['officeTimeIn'] != null) {
          String inStr = data['officeTimeIn'].toString();
          _officeTimeIn = inStr.contains('T') 
              ? DateTime.parse(inStr) 
              : DateTime.parse('$todayStr $inStr');
        } else {
          _officeTimeIn = null;
        }

        // Parse office time out
        if (data['officeTimeOut'] != null) {
          String outStr = data['officeTimeOut'].toString();
          _officeTimeOut = outStr.contains('T') 
              ? DateTime.parse(outStr) 
              : DateTime.parse('$todayStr $outStr');
        } else {
          _officeTimeOut = null;
        }

        _isSubmitted = _officeTimeOut != null;

        // Extract visits safely from shiftSessions if root 'visits' is missing/null
        List<dynamic> visits = [];
        if (data['visits'] != null && (data['visits'] as List).isNotEmpty) {
          visits = data['visits'];
        } else if (data['shiftSessions'] != null && (data['shiftSessions'] as List).isNotEmpty) {
          // Gather visits from all shift sessions
          for (var session in data['shiftSessions']) {
            if (session['visits'] != null && (session['visits'] as List).isNotEmpty) {
              visits.addAll(session['visits']);
            }
          }
        }

        if (!_isAwaitingApproval && visits.isNotEmpty) {
          // 1. Check if ANY visit is currently open (timeOut is null or empty)
          final activeVisit = visits.firstWhere(
            (v) => v['timeOut'] == null || v['timeOut'].toString().trim().isEmpty,
            orElse: () => null,
          );

          if (activeVisit != null) {
            _hasActiveVisitSession = true;
            _activeSiteName = activeVisit['siteName'];
          } else {
            // 2. All visits are closed -> Clear active session so Finish Workday appears
            _hasActiveVisitSession = false;
            _activeSiteName = null; 
          }
        } else {
          _hasActiveVisitSession = false;
          _activeSiteName = null;
        }

        _lastFetchTime = DateTime.now();
      });
    } catch (e) {
      debugPrint("Silent Background Sync Error: $e");
    }
  }

  Future<void> _fetchSiteNames() async {
    if (_siteMasterList.isNotEmpty) return;
    try {
      final sites = await _attendanceService.fetchSiteNamesLegacy();
      if (mounted) {
        setState(() {
          _siteMasterList = sites;
        });
      }
    } catch (e) {
      debugPrint('Site Routing Network Isolation Warn: $e');
    }
  }

  // --- HELPER METHODS ---
  bool _siteNamesContainsActiveVisit() {
    if (_activeSiteName == null) return false;
    return _siteMasterList.any((s) => 
      s['siteName'].toString().toLowerCase() == _activeSiteName!.toLowerCase()
    );
  }

  // --- ATTENDANCE ACTION ---
  Future<void> _executeAttendanceAction(String actionType) async {
    if (_isProcessing || _isOptimisticUpdating) return;
    // Capture the mobile's local time when the action starts.
    final DateTime actionTapTime = DateTime.now();

    if (!['sitein', 'siteout', 'dayout'].contains(actionType)) {
      _showErrorSnackBar('Invalid attendance action.');
      return;
    }
    if (_isOffline) {
      _showErrorSnackBar(
        'No internet connection. Please reconnect before marking attendance.',
      );
      return;
    }
    final authProvider = Provider.of<AuthProvider>(context, listen: false,);

    final String employeeId = authProvider.employeeId?.toString().trim() ?? '';
    final String employeeName = authProvider.username?.trim() ?? '';
    final String mobileNumber = authProvider.mobileNumber?.toString().trim() ?? '';
    // Validate employee identity before making the request.
    // if (employeeId.isEmpty) {
    //   _showErrorSnackBar(
    //     'Employee ID is missing. Please log in again or refresh your profile.',
    //   );
    //   return;
    // }

    if (employeeName.isEmpty) {
      _showErrorSnackBar(
        'Employee name is missing. Please log in again.',
      );
      return;
    }

    // Validate the requested action.
    if (actionType == 'sitein') {
      if (_hasActiveVisitSession) {
        _showErrorSnackBar(
          'Please check out from "$_activeSiteName" before checking in again.',
        );
        return;
      }

      if (_isCustomSite) {
        if (_remarksController.text.trim().isEmpty) {
          _showErrorSnackBar(
            'Please enter remarks for the custom site.',
          );
          return;
        }
      } else if (_selectedSiteObject == null) {
        _showErrorSnackBar('Please select an official site.');
        return;
      }
    }

    if (actionType == 'siteout' && !_hasActiveVisitSession) {
      _showErrorSnackBar('There is no active site visit to check out.');
      return;
    }

    if (actionType == 'dayout' && _hasActiveVisitSession) {
      _showErrorSnackBar(
        'Please check out from your active site before finishing your workday.',
      );
      return;
    }

    // Save the current UI state for rollback if the API request fails.
    final Map<String, dynamic> rollbackData = {
      'hasActiveVisitSession': _hasActiveVisitSession,
      'activeSiteName': _activeSiteName,
      'remarksText': _remarksController.text,
      'selectedSiteObject': _selectedSiteObject,
      'isCustomSite': _isCustomSite,
      'isAwaitingApproval': _isAwaitingApproval,
      'isSubmitted': _isSubmitted,
    };

    setState(() {
      _isProcessing = true;
    });

    try {
      // Capture the current location.
      final GeoPoint? currentGpsLocation =
          await _locationService.determinePosition();

      if (!mounted) return;

      if (currentGpsLocation == null) {
        _showErrorSnackBar(
          'Unable to capture GPS coordinates. Please retry.',
        );
        return;
      }

      // final DateTime now = DateTime.now();
      final String attendanceDate = DateFormat('yyyy-MM-dd').format(actionTapTime);
      final String currentTime = DateFormat('HH:mm:ss').format(actionTapTime);
      // Select shift using the mobile's local system time.
      // 21:00:00 and later means NIGHT_SHIFT.
      final String shiftType = actionTapTime.hour >= 21 ? 'NIGHT_SHIFT' : 'DAY_SHIFT';
      debugPrint('Mobile action time: $actionTapTime');
      debugPrint('Selected shift type: $shiftType');

      final bool runningAsCustomSite = actionType == 'sitein'
          ? _isCustomSite
          : (_activeSiteName != null &&
              !_siteNamesContainsActiveVisit());

      final String siteLabel = actionType == 'sitein'
          ? (runningAsCustomSite
              ? _remarksController.text.trim()
              : (_selectedSiteObject?['siteName']?.toString().trim() ?? ''))
          : (_activeSiteName?.trim() ?? '');

      // Declare chosenSiteId before using it in visitPayload.
      final dynamic chosenSiteId =
          actionType == 'sitein' && !runningAsCustomSite
              ? _selectedSiteObject != null ? _selectedSiteObject!['siteId'] : null
              : null;

      if (actionType != 'dayout' && siteLabel.isEmpty) {
        _showErrorSnackBar(
          'Site name is missing. Please refresh attendance and retry.',
        );
        return;
      }

      // Construct the visit record.
      final Map<String, dynamic> visitPayload = {
        'siteId': chosenSiteId,
        'siteName': siteLabel,
        'visitType': runningAsCustomSite ? 'OTHER' : 'REGULAR_SITE',
        'customSite': runningAsCustomSite,
        'remarks': runningAsCustomSite
            ? _remarksController.text.trim()
            : null,
        'timeIn': actionType == 'sitein' ? currentTime : null,
        'timeInLocation': actionType == 'sitein'
            ? currentGpsLocation.toJson()
            : null,
        'timeOut': actionType == 'siteout' ? currentTime : null,
        'timeOutLocation': actionType == 'siteout'
            ? currentGpsLocation.toJson()
            : null,
      };
      // A shift session is required by the backend.
      // NOTE:
      // GENERAL and IN_PROGRESS must match your backend's actual enum values.
      // If your backend requires shiftMaster, its real ID must be supplied too.
      final Map<String, dynamic> sessionPayload = {
        'shiftType': shiftType,
        'workDate': attendanceDate,
        'timeIn': actionType == 'sitein' ? currentTime : null,
        'timeInLocation': actionType == 'sitein'
            ? currentGpsLocation.toJson()
            : null,
        'timeOut': actionType == 'dayout' ? currentTime : null,
        'timeOutLocation': actionType == 'dayout'
            ? currentGpsLocation.toJson()
            : null,
        'sessionStatus': actionType == 'dayout'
            ? 'COMPLETED'
            : 'IN_PROGRESS',
        'remarks': runningAsCustomSite
            ? _remarksController.text.trim()
            : null,
        'visits': actionType == 'dayout' ? [] : [visitPayload],
      };

      final Map<String, dynamic> bodyPayload = {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'mobileNumber': mobileNumber.isEmpty ? null : mobileNumber,
        'attendanceDate': attendanceDate,
        'status': actionType,
        'tallyAttendanceStatus': 'PENDING',
        'officeTimeOut': actionType == 'dayout' ? currentTime : null,
        'officeTimeOutLocation': actionType == 'dayout' ? currentGpsLocation.toJson() : null,
        'shiftSessions': [sessionPayload],
      };

      debugPrint('========== MARK ATTENDANCE REQUEST ==========');
      debugPrint('Action: $actionType');
      debugPrint('Employee ID: $employeeId');
      debugPrint('Payload: $bodyPayload');
      debugPrint('=============================================');

      // Apply optimistic UI changes.
      setState(() {
        _isOptimisticUpdating = true;
        _networkRetryCount = 0;

        if (actionType == 'sitein') {
          _hasActiveVisitSession = true;
          _activeSiteName = siteLabel;
        } else if (actionType == 'siteout') {
          _hasActiveVisitSession = false;
          _activeSiteName = null;
        } else if (actionType == 'dayout') {
          _isSubmitted = true;
          _hasActiveVisitSession = false;
          _activeSiteName = null;
        }

        _remarksController.clear();
        _selectedSiteObject = null;
        _isCustomSite = false;
      });

      await _sendAttendanceNetworkPayload(
        payload: bodyPayload,
        actionType: actionType,
        rollbackData: rollbackData,
      );
    } catch (e, stackTrace) {
      debugPrint('Attendance action error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _performRollback(
        rollbackData,
        'Unable to mark attendance: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _sendAttendanceNetworkPayload({
    required Map<String, dynamic> payload,
    required String actionType,
    required Map<String, dynamic> rollbackData,
  }) async {
    try {
      await _attendanceService.markAttendanceLegacy(payload);

      if (!mounted) return;

      setState(() => _isOptimisticUpdating = false);
      _lastFetchTime = null;
      await _fetchTodayAttendance(forceRefresh: true);
      
      String dialogMessage = _isAwaitingApproval 
          ? "Late arrival sent to Admin approval queue." 
          : "${actionType.toUpperCase()} marked successfully.";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _isAwaitingApproval ? Colors.amber.shade800 : Colors.green.shade600,
          content: Text(dialogMessage),
        ),
      );
    } catch (exception) {
      if (_networkRetryCount < _maxNetworkRetries) {
        _networkRetryCount++;
        int backoffDuration = _networkRetryCount * 1500;
        await Future.delayed(Duration(milliseconds: backoffDuration));
        await _sendAttendanceNetworkPayload(
          payload: payload,
          actionType: actionType,
          rollbackData: rollbackData
        );
      } else {
        // 👇 UPDATE THIS ERROR HANDLING BLOCK 👇
        String technicalMessage = "Connection lost. Check signal and try again.";
        
        if (exception is TimeoutException) {
          technicalMessage = "Server response threshold timeout exceeded.";
        } else if (exception.toString().contains("400")) {
          // If your service throws clean error string formats, extract it here
          technicalMessage = exception.toString().replaceAll("Exception:", "").trim();
        } else {
          technicalMessage = exception.toString();
        }
        
        _performRollback(rollbackData, technicalMessage);
      }
    }
  }

  void _performRollback(Map<String, dynamic> rollbackData, String errorMessage) {
    if (!mounted) return;
    setState(() {
      _isOptimisticUpdating = false;
      _hasActiveVisitSession = rollbackData['hasActiveVisitSession'];
      _activeSiteName = rollbackData['activeSiteName'];
      _remarksController.text = rollbackData['remarksText'];
      _selectedSiteObject = rollbackData['selectedSiteObject'];
      _isCustomSite = rollbackData['isCustomSite'];
      _isAwaitingApproval = rollbackData['isAwaitingApproval'];
      _isSubmitted = rollbackData['isSubmitted'];
    });
    _showErrorSnackBar(errorMessage);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
  }

  void _onLogout(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.logout();
    Navigator.of(context).pushReplacementNamed('/employeeLogin');
  }

  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    final status = MarkAttendanceHelper.getOverallAttendanceStatus(
      isAwaitingApproval: _isAwaitingApproval,
      officeTimeIn: _officeTimeIn,
      officeTimeOut: _officeTimeOut,
    );
    final statusColor = MarkAttendanceHelper.getStatusColor(status);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue[800],
        centerTitle: true,
        title: Text(
          widget.isSunday ? 'Sunday Attendance' :
          'Week Day Attendance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => _onLogout(context),
            icon: const Icon(Icons.logout, color: Colors.white),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  // --- Professional Outer Container Border & Framing ---
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: Colors.blueGrey.shade300,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14.0),
                    child: RefreshIndicator(
                      onRefresh: () async {
                        _lastFetchTime = null;
                        await _loadScreenData();
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            if (_isOffline)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.wifi_off, color: Colors.white),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Offline mode\nInternet connection unavailable.',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_isPoorNetwork)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade800,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                        Icons.signal_cellular_connected_no_internet_4_bar,
                                        color: Colors.white),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'Unstable or Poor Network Connection.\nPlease retry or move to a stronger signal area.',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          _checkConnectivityOnResume(),
                                      child: const Text('RETRY',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),

                            ProfileHeaderWidget(
                              authProvider: authProvider,
                              status: status,
                              statusColor: statusColor,
                            ),
                            const SizedBox(height: 20),

                            HeaderDashboardWidget(
                              authProvider: authProvider,
                              width: screenWidth,
                              isAwaitingApproval: _isAwaitingApproval,
                            ),
                            const SizedBox(height: 20),

                            if (_isAwaitingApproval)
                              const ApprovalWarningWidget(),

                            ActionCardWidget(
                              isSubmitted: _isSubmitted,
                              isAwaitingApproval: _isAwaitingApproval,
                              hasActiveVisitSession: _hasActiveVisitSession,
                              activeSiteName: _activeSiteName,
                              isCustomSite: _isCustomSite,
                              isOptimisticUpdating: _isOptimisticUpdating,
                              officeTimeIn: _officeTimeIn,
                              onSiteOut: () =>
                                  _executeAttendanceAction('siteout'),
                              onSiteIn: () =>
                                  _executeAttendanceAction('sitein'),
                              onDayOut: () =>
                                  _executeAttendanceAction('dayout'),
                              onCustomSiteChanged: (val) {
                                setState(() {
                                  _isCustomSite = val ?? false;
                                  _selectedSiteObject = null;
                                });
                              },
                              dropdownWidget: SiteDropdownWidget(
                                siteMasterList: _siteMasterList,
                                selectedSiteObject: _selectedSiteObject,
                                onChanged: (Map<String, dynamic>? selectedMap) {
                                  setState(() {
                                    _selectedSiteObject = selectedMap;
                                  });
                                },
                              ),
                              remarksController: _remarksController,
                            ),

                            const SizedBox(height: 20),

                            LogStatusCardWidget(
                              title: 'First Check-In (Shift Start)',
                              timestamp: _officeTimeIn,
                              isAwaitingApproval: _isAwaitingApproval,
                            ),
                            const SizedBox(height: 10),

                            LogStatusCardWidget(
                              title: 'Final Check-Out (Shift Closed)',
                              timestamp: _officeTimeOut,
                              isAwaitingApproval: _isAwaitingApproval,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }}