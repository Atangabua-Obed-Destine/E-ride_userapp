class NearestDriverModel {
  List<Nearest>? data;
  NearestDriverModel(
      {this.data,});

  NearestDriverModel.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <Nearest>[];
      json['data'].forEach((v) {
        data!.add(Nearest.fromJson(v));
      });
    }
  }
}

class Nearest {

  String? latitude;
  String? longitude;
  String? category;
  /// The driver's user id; stable across refreshes, so it keys the map marker.
  String? userId;
  /// The driver's exact vehicle category. Newer backends send it; older ones
  /// do not, and the app then falls back to matching on [category] (car/bike).
  String? vehicleCategoryId;


  Nearest(
      {
        this.latitude,
        this.longitude,
        this.category,
        this.userId,
        this.vehicleCategoryId,
       });

  Nearest.fromJson(Map<String, dynamic> json) {

    latitude = json['latitude'];
    longitude = json['longitude'];
    category = json['category'];
    userId = json['user_id']?.toString();
    vehicleCategoryId = json['vehicle_category_id']?.toString();

  }

}


