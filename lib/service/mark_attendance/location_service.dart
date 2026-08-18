import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:attendance_app/modals/geopoint.dart';

class LocationService {
  StreamSubscription<Position>? _gpsStreamSubscription;
  GeoPoint? _cachedGeoPoint;
  
  bool get hasCachedLocation => _cachedGeoPoint != null;
  GeoPoint? get cachedGeoPoint => _cachedGeoPoint;

  Future<bool> checkLocationServices() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<LocationPermission> checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  Future<GeoPoint?> determinePosition() async {
    bool serviceEnabled = await checkLocationServices();
    if (!serviceEnabled) {
      return null;
    }

    if (_cachedGeoPoint != null) {
      return _cachedGeoPoint;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );
      _cachedGeoPoint = GeoPoint(latitude: position.latitude, longitude: position.longitude);
      return _cachedGeoPoint;
    } catch (e) {
      return null;
    }
  }

  void startLocationTracking(Function(Position) onLocationUpdate) {
    _stopLocationTracking();
    
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 10,
    );

    _gpsStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings
    ).listen(
      onLocationUpdate,
      onError: (error) {
        debugPrint("Background GPS Stream Exception: $error");
      },
    );
  }

  Future<void> _stopLocationTracking() async {
    if (_gpsStreamSubscription != null) {
      await _gpsStreamSubscription!.cancel();
      _gpsStreamSubscription = null;
    }
  }

  void stopTracking() {
    _gpsStreamSubscription?.cancel();
    _gpsStreamSubscription = null;
  }

  void dispose() {
    _stopLocationTracking();
  }
}