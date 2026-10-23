
class GeoPoint {
  final double latitude;
  final double longitude;

  const GeoPoint({
    required this.latitude,
    required this.longitude,
  });

  factory GeoPoint.fromJson(Map<String, dynamic> json) {
    return GeoPoint(
      latitude: _toDouble(json['latitude']) ?? 0.0,
      longitude: _toDouble(json['longitude']) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}