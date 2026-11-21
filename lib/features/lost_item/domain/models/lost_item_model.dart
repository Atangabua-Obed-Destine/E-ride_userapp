/// A lost item case, as one side (rider or driver) sees it. The server decides
/// what the person can do now (actions) and says where things stand (message).
class LostItem {
  final String id;
  final String tripRequestId;
  final String? tripRefId;
  final String? tripDate;
  final String? pickupAddress;
  final String? destinationAddress;
  final String description;
  final String? photo;
  final String status; // reported | found | not_found | returned | cancelled | closed
  final bool isOpen;
  final bool needsSupport;
  final String? returnMethod; // collect | deliver
  final double returnFee;
  final double deliverFee;
  final String? driverNote;
  final String message;
  final String otherName;
  final String? otherPhone;
  final String? otherVehicle;
  final List<String> actions;
  final String? createdAt;
  /// While E-Ride support has the case: the desk's name, number and hours.
  final String? supportName;
  final String? supportPhone;
  final String? supportHours;
  final bool supportOpenNow;

  const LostItem({
    required this.id, required this.tripRequestId, this.tripRefId, this.tripDate, this.pickupAddress, this.destinationAddress,
    required this.description, this.photo, required this.status, this.isOpen = false, this.needsSupport = false,
    this.returnMethod, this.returnFee = 0, this.deliverFee = 0, this.driverNote, this.message = '', this.otherName = '',
    this.otherPhone, this.otherVehicle, this.actions = const [], this.createdAt,
    this.supportName, this.supportPhone, this.supportHours, this.supportOpenNow = false,
  });

  factory LostItem.fromJson(Map<String, dynamic> json) {
    final Map other = json['other'] is Map ? json['other'] as Map : const {};
    final Map support = json['support'] is Map ? json['support'] as Map : const {};
    String? text(dynamic v) => v == null || '$v'.trim().isEmpty ? null : '$v'.trim();
    return LostItem(
      id: '${json['id']}',
      tripRequestId: '${json['trip_request_id']}',
      tripRefId: text(json['trip_ref_id']),
      tripDate: text(json['trip_date']),
      pickupAddress: text(json['pickup_address']),
      destinationAddress: text(json['destination_address']),
      description: '${json['description'] ?? ''}',
      photo: text(json['photo']),
      status: '${json['status'] ?? 'reported'}',
      isOpen: json['is_open'] == true,
      needsSupport: json['needs_support'] == true,
      returnMethod: text(json['return_method']),
      returnFee: double.tryParse('${json['return_fee']}') ?? 0,
      deliverFee: double.tryParse('${json['deliver_fee']}') ?? 0,
      driverNote: text(json['driver_note']),
      message: '${json['message'] ?? ''}',
      otherName: '${other['name'] ?? ''}'.trim(),
      otherPhone: text(other['phone']),
      otherVehicle: text(other['vehicle']),
      actions: [for (final a in (json['actions'] is List ? json['actions'] as List : const [])) '$a'],
      createdAt: text(json['created_at']),
      supportName: text(support['name']),
      supportPhone: text(support['phone']),
      supportHours: text(support['hours']),
      supportOpenNow: support['open_now'] == true,
    );
  }

  bool can(String action) => actions.contains(action);
}
