/// One thing the customer started and has not finished, or that needs them.
class ActivityItem {
  /// What it is, e.g. food_pay, bus_ticket, hotel_reply, food_cart, ride_ongoing.
  final String kind;
  /// What to open (an order, a booking, a chat).
  final String id;
  /// now = needs them (usually with a deadline), unfinished = they left it,
  /// progress = follow along, later = when they like.
  final String group;
  final DateTime? deadline;
  final DateTime? at;
  final Map<String, dynamic> params;

  const ActivityItem({required this.kind, required this.id, required this.group, this.deadline, this.at, this.params = const {}});

  static DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        kind: json['kind']?.toString() ?? '',
        id: json['id']?.toString() ?? '',
        group: json['group']?.toString() ?? 'progress',
        deadline: _date(json['deadline']),
        at: _date(json['at']),
        params: json['params'] is Map ? Map<String, dynamic>.from(json['params']) : const {},
      );

  static const List<String> groups = ['now', 'unfinished', 'progress', 'later'];
}
