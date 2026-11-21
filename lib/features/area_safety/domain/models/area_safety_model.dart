// Area pause, no-go areas and danger reports (backend Modules/ZoneManagement, SafetyService).

double? _double(dynamic v) => v == null ? null : double.tryParse(v.toString());
int _int(dynamic v) => int.tryParse('$v') ?? 0;
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// An area where E-Ride takes no trips for now: a pause (a zone or a circle) or a no-go area.
class SafetyAreaInfo {
  final String id;
  final String kind; // pause | no_go
  final String title;
  final String reason;
  final bool wholeZone;
  final double? latitude;
  final double? longitude;
  final int? radiusM;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool confirmed;
  final bool inside;

  const SafetyAreaInfo({required this.id, required this.kind, required this.title, required this.reason, required this.wholeZone,
    this.latitude, this.longitude, this.radiusM, this.startsAt, this.endsAt, required this.confirmed, required this.inside});

  factory SafetyAreaInfo.fromJson(Map<String, dynamic> j) => SafetyAreaInfo(
        id: '${j['id']}', kind: '${j['kind']}', title: '${j['title'] ?? ''}', reason: '${j['reason'] ?? ''}',
        wholeZone: j['whole_zone'] == true, latitude: _double(j['latitude']), longitude: _double(j['longitude']),
        radiusM: j['radius_m'] == null ? null : _int(j['radius_m']), startsAt: _date(j['starts_at']), endsAt: _date(j['ends_at']),
        confirmed: j['confirmed'] != false, inside: j['inside'] == true,
      );
}

/// A fresh danger report near the person (drivers see every one; riders only confirmed ones).
class SafetyReportInfo {
  final String id;
  final String type;
  final String? place;
  final int distanceM;
  final int minutesAgo;
  const SafetyReportInfo({required this.id, required this.type, this.place, required this.distanceM, required this.minutesAgo});

  factory SafetyReportInfo.fromJson(Map<String, dynamic> j) => SafetyReportInfo(
        id: '${j['id']}', type: '${j['type']}', place: j['place']?.toString(), distanceM: _int(j['distance_m']), minutesAgo: _int(j['minutes_ago']));
}

class SafetyNearby {
  final List<SafetyAreaInfo> areas;
  final List<SafetyAreaInfo> upcoming;
  final List<SafetyReportInfo> reports;
  /// Pauses refuse trips to or from them (the admin's choice); otherwise trips go ahead with a warning.
  final bool blocksTrips;
  const SafetyNearby({this.areas = const [], this.upcoming = const [], this.reports = const [], this.blocksTrips = true});

  factory SafetyNearby.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        (j[key] is List ? j[key] as List : const []).map((e) => f(Map<String, dynamic>.from(e))).toList();
    return SafetyNearby(
      areas: list('areas', SafetyAreaInfo.fromJson),
      upcoming: list('upcoming', SafetyAreaInfo.fromJson),
      reports: list('reports', SafetyReportInfo.fromJson),
      blocksTrips: j['blocks_trips'] != false,
    );
  }

  bool get isEmpty => areas.isEmpty && upcoming.isEmpty && reports.isEmpty;
}
