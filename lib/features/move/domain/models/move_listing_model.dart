/// A truck owner from the E-Ride Move directory: customers call them when no
/// truck is available in the app.
class MoveListing {
  final String id;
  final String ownerName;
  final String phone;
  final String whatsapp;
  final String? areas;
  final String? note;
  final String? photo;
  final bool onEride;
  final String? vehicleCategoryId;
  final String? vehicleName;
  final String? vehicleType;

  const MoveListing({
    required this.id,
    required this.ownerName,
    required this.phone,
    required this.whatsapp,
    this.areas,
    this.note,
    this.photo,
    this.onEride = false,
    this.vehicleCategoryId,
    this.vehicleName,
    this.vehicleType,
  });

  factory MoveListing.fromJson(Map<String, dynamic> json) {
    final Map? vehicle = json['vehicle_category'] is Map ? json['vehicle_category'] as Map : null;
    final String phone = '${json['phone'] ?? ''}';
    return MoveListing(
      id: '${json['id']}',
      ownerName: '${json['owner_name'] ?? ''}',
      phone: phone,
      whatsapp: '${json['whatsapp'] ?? phone}',
      areas: (json['areas'] ?? '').toString().isEmpty ? null : '${json['areas']}',
      note: (json['note'] ?? '').toString().isEmpty ? null : '${json['note']}',
      photo: json['photo']?.toString(),
      onEride: json['on_eride'] == true,
      vehicleCategoryId: vehicle?['id']?.toString(),
      vehicleName: vehicle?['name']?.toString(),
      vehicleType: vehicle?['type']?.toString(),
    );
  }
}
