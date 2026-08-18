import 'dart:async';
import 'package:attendance_app/screen/mark_attendance/mark_attendance_helper.dart';
import 'package:attendance_app/service/mark_attendance/attendance_service.dart';
import 'package:attendance_app/service/mark_attendance/location_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:attendance_app/authentication/auth_provider.dart';
import 'package:attendance_app/modals/geopoint.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MarkAttendance extends StatefulWidget {
  const MarkAttendance({super.key});

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
      fallback: 'http://192.168.1.4:8080',
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

  void _updateConnectivityStatus(List<ConnectivityResult> result) {
    final bool offline = result.isEmpty ||
        result.every((connection) => connection == ConnectivityResult.none);

    if (_isOffline == offline) {
      return;
    }

    setState(() {
      _isOffline = offline;
    });

    if (offline) {
      _showOfflineSnackBar();
    } else {
      _showOnlineSnackBar();

      // Refresh attendance after reconnecting
      _lastFetchTime = null;
      _fetchTodayAttendance(forceRefresh: true);
    }
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
        _officeTimeIn = data['officeTimeIn'] != null
            ? DateTime.parse('$todayStr ${data['officeTimeIn']}')
            : null;
        _officeTimeOut = data['officeTimeOut'] != null
            ? DateTime.parse('$todayStr ${data['officeTimeOut']}')
            : null;
        _isSubmitted = _officeTimeOut != null;

        if (!_isAwaitingApproval && data['visits'] != null && (data['visits'] as List).isNotEmpty) {
          final lastVisit = (data['visits'] as List).last;
          if (lastVisit['timeOut'] == null) {
            _hasActiveVisitSession = true;
            _activeSiteName = lastVisit['siteName'];
          } else {
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

    if (_isOffline) {
      _showErrorSnackBar(
        'No internet connection. Please reconnect before marking attendance.',
      );
      return;
    }

    final String siteLabel = actionType == 'sitein'
        ? (_isCustomSite ? _remarksController.text.trim() : (_selectedSiteObject?['siteName'] ?? ""))
        : (_activeSiteName ?? "Default Site");

    final String? chosenSiteId = actionType == 'sitein' && !_isCustomSite
        ? _selectedSiteObject != null ? _selectedSiteObject!['siteId'] : null
        : null;

    // Validation
    if (actionType == 'sitein') {
      if (!_isCustomSite && _selectedSiteObject == null) {
        _showErrorSnackBar('Please select an official site.');
        return;
      }
      if (_isCustomSite && _remarksController.text.trim().isEmpty) {
        _showErrorSnackBar('Please enter remarks for custom work.');
        return;
      }
      if (_hasActiveVisitSession) {
        _showErrorSnackBar('Cannot Check-In: You must first Check-Out of your active session at "$_activeSiteName".');
        return;
      }
      if (_activeSiteName?.trim().toLowerCase() == siteLabel.trim().toLowerCase()) {
        _showErrorSnackBar('Duplicate Guard: You are already checked in at "$siteLabel" today.');
        return;
      }
    }

    if (actionType == 'dayout' && _hasActiveVisitSession) {
      _showErrorSnackBar('Please Check-Out of your current site session before finishing your workday.');
      return;
    }

    final GeoPoint? currentGpsLocation = await _locationService.determinePosition();
    if (currentGpsLocation == null) {
      _showErrorSnackBar('Unable to capture GPS coordinates. Stand under open sky and retry.');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final bool runningAsCustomSite = _hasActiveVisitSession
        ? (_activeSiteName != null && !_siteNamesContainsActiveVisit())
        : _isCustomSite;

    final bool previousHasActiveVisitSession = _hasActiveVisitSession;
    final String? previousActiveSiteName = _activeSiteName;
    final String previousRemarksText = _remarksController.text;
    final dynamic previousSelectedSiteObject = _selectedSiteObject;
    final bool previousIsCustomSite = _isCustomSite;
    final bool previousIsAwaitingApproval = _isAwaitingApproval;

    // Optimistic update
    setState(() {
      _isOptimisticUpdating = true;
      _networkRetryCount = 0;

      if (actionType == "sitein") {
        // Remove the check for MarkAttendanceHelper.isPastGracePeriod() here.
        // Let the backend decide if it's approved or pending.
        _hasActiveVisitSession = true;
        _activeSiteName = siteLabel;
      } else if (actionType == "siteout") {
        _hasActiveVisitSession = false;
        _activeSiteName = null;
      } else if (actionType == "dayout") {
        _isSubmitted = true;
        _hasActiveVisitSession = false;
        _activeSiteName = null;
      }

      _remarksController.clear();
      _selectedSiteObject = null;
      _isCustomSite = false;
    });

    // Prepare payload
    final Map<String, dynamic> bodyPayload = {
      "employeeId": authProvider.employeeId,
      "employeeName": authProvider.username,
      "mobileNumber": authProvider.mobileNumber,
      "status": actionType,
      "tallyAttendanceStatus": "PENDING",
      "visits": [
        {
          "siteId": chosenSiteId,
          "siteName": siteLabel,
          "visitType": runningAsCustomSite ? "OTHER" : "REGULAR_SITE",
          "isCustomSite": runningAsCustomSite,
          "remarks": (actionType == "sitein" && runningAsCustomSite) ? previousRemarksText.trim() : null,
          "timeInLocation": actionType == "sitein" ? currentGpsLocation.toJson() : null,
          "timeOutLocation": (actionType == "siteout" || actionType == "dayout") ? currentGpsLocation.toJson() : null,
        }
      ]
    };

    await _sendAttendanceNetworkPayload(
      payload: bodyPayload,
      actionType: actionType,
      rollbackData: {
        'hasActiveVisitSession': previousHasActiveVisitSession,
        'activeSiteName': previousActiveSiteName,
        'remarksText': previousRemarksText,
        'selectedSiteObject': previousSelectedSiteObject,
        'isCustomSite': previousIsCustomSite,
        'isAwaitingApproval': previousIsAwaitingApproval,
        'isSubmitted': _isSubmitted && actionType != 'dayout',
      }
    );
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
      backgroundColor: const Color(0xFFf4f7f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue[800],
        centerTitle: true,
        title: const Text(
          'Kanishkaa Attendance',
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
          : RefreshIndicator(
              onRefresh: () async {
                _lastFetchTime = null;
                await _loadScreenData();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_isOffline)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.wifi_off,
                            color: Colors.white,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Offline mode\nInternet connection unavailable.',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

                    if (_isAwaitingApproval) const ApprovalWarningWidget(),

                    ActionCardWidget(
                      isSubmitted: _isSubmitted,
                      isAwaitingApproval: _isAwaitingApproval,
                      hasActiveVisitSession: _hasActiveVisitSession,
                      activeSiteName: _activeSiteName,
                      isCustomSite: _isCustomSite,
                      isOptimisticUpdating: _isOptimisticUpdating,
                      officeTimeIn: _officeTimeIn,
                      onSiteOut: () => _executeAttendanceAction('siteout'),
                      onSiteIn: () => _executeAttendanceAction('sitein'),
                      onDayOut: () => _executeAttendanceAction('dayout'),
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
    );
  }
}