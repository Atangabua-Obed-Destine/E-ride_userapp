/// A place of care near the rider: a hospital or clinic, or a pharmacy.
class HealthPlace {
  final String id;
  final String kind; // hospital | pharmacy
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double? distanceKm;
  final String? phone;
  final bool? openNow;
  final bool onDuty;
  final bool verified;

  const HealthPlace({
    required this.id, required this.kind, required this.name, required this.address, required this.latitude,
    required this.longitude, this.distanceKm, this.phone, this.openNow, this.onDuty = false, this.verified = false,
  });

  factory HealthPlace.fromJson(Map<String, dynamic> json) => HealthPlace(
    id: '${json['id']}',
    kind: '${json['kind'] ?? 'hospital'}',
    name: '${json['name'] ?? ''}',
    address: '${json['address'] ?? ''}',
    latitude: double.tryParse('${json['latitude']}') ?? 0,
    longitude: double.tryParse('${json['longitude']}') ?? 0,
    distanceKm: double.tryParse('${json['distance_km']}'),
    phone: (json['phone'] as String?)?.trim().isEmpty ?? true ? null : (json['phone'] as String).trim(),
    openNow: json['open_now'] is bool ? json['open_now'] as bool : null,
    onDuty: json['on_duty'] == true,
    verified: json['verified'] == true,
  );

  bool get isPharmacy => kind == 'pharmacy';
}

/// What the health ride screen shows: places, the numbers to call and the rides left today.
class HealthPlacesResult {
  final List<HealthPlace> hospitals;
  final List<HealthPlace> pharmacies;
  final int ridesLeft;
  final int dailyLimit;

  const HealthPlacesResult({this.hospitals = const [], this.pharmacies = const [], this.ridesLeft = 0, this.dailyLimit = 0});

  factory HealthPlacesResult.fromJson(Map<String, dynamic> json) {
    List<HealthPlace> list(dynamic v) => [
      for (final p in (v is List ? v : const [])) if (p is Map) HealthPlace.fromJson(Map<String, dynamic>.from(p)),
    ];
    return HealthPlacesResult(
      hospitals: list(json['hospitals']),
      pharmacies: list(json['pharmacies']),
      ridesLeft: int.tryParse('${json['rides_left']}') ?? 0,
      dailyLimit: int.tryParse('${json['daily_limit']}') ?? 0,
    );
  }
}
