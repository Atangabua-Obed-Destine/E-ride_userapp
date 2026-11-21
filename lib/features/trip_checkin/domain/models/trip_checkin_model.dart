/// "Are you OK?" asked by E-Ride during a ride.
class TripCheckin {
  final String id;
  final String tripRequestId;
  /// stopped | off_route | too_long
  final String reason;
  /// asked | ok | help | no_answer | closed
  final String status;
  final int secondsLeft;

  const TripCheckin({required this.id, required this.tripRequestId, required this.reason, required this.status, required this.secondsLeft});

  factory TripCheckin.fromJson(Map<String, dynamic> json) => TripCheckin(
    id: '${json['id'] ?? ''}',
    tripRequestId: '${json['trip_request_id'] ?? ''}',
    reason: '${json['reason'] ?? ''}',
    status: '${json['status'] ?? ''}',
    secondsLeft: int.tryParse('${json['seconds_left'] ?? 0}') ?? 0,
  );
}

/// Whether check-ins are on, the night sharing hours, and the open question.
class TripCheckinInfo {
  final bool enabled;
  final bool isNight;
  final int nightFrom;
  final int nightTo;
  final TripCheckin? checkin;

  const TripCheckinInfo({required this.enabled, required this.isNight, required this.nightFrom, required this.nightTo, this.checkin});

  factory TripCheckinInfo.fromJson(Map<String, dynamic> json) => TripCheckinInfo(
    enabled: json['enabled'] == true || '${json['enabled']}' == '1',
    isNight: json['is_night'] == true || '${json['is_night']}' == '1',
    nightFrom: int.tryParse('${json['night_from'] ?? 19}') ?? 19,
    nightTo: int.tryParse('${json['night_to'] ?? 6}') ?? 6,
    checkin: json['checkin'] is Map<String, dynamic> ? TripCheckin.fromJson(json['checkin']) : null,
  );
}
