import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing_user_app/features/area_safety/domain/models/area_safety_model.dart';
import 'package:ride_sharing_user_app/features/area_safety/domain/services/area_safety_service_interface.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';

/// Area pause, no-go areas and danger reports: the banner near the rider and "Report danger".
class AreaSafetyController extends GetxController implements GetxService {
  final AreaSafetyServiceInterface areaSafetyServiceInterface;
  AreaSafetyController({required this.areaSafetyServiceInterface});

  bool enabled = false;
  List<String> types = const ['gunshots', 'roadblock', 'protest', 'accident', 'flooding', 'other'];
  SafetyNearby nearby = const SafetyNearby();
  bool reporting = false;

  Future<void> loadMeta() async {
    final Response response = await areaSafetyServiceInterface.getMeta();
    if (response.statusCode == 200) {
      enabled = response.body['data']?['enabled'] == true;
      final t = response.body['data']?['types'];
      if (t is List && t.isNotEmpty) types = t.map((e) => '$e').toList();
      update();
    }
  }

  /// Around the rider's saved place (home and booking use it), or a given point.
  Future<void> loadNearby({double? latitude, double? longitude}) async {
    if (!enabled) await loadMeta();
    if (!enabled) {
      nearby = const SafetyNearby();
      update();
      return;
    }
    final saved = Get.find<LocationController>().getUserAddress();
    final double? lat = latitude ?? saved?.latitude;
    final double? lng = longitude ?? saved?.longitude;
    if (lat == null || lng == null) return;
    final Response response = await areaSafetyServiceInterface.getNearby(lat, lng);
    if (response.statusCode == 200 && response.body['data'] is Map) {
      nearby = SafetyNearby.fromJson(Map<String, dynamic>.from(response.body['data']));
      update();
    }
  }

  /// Reports what the rider sees, at their position now.
  Future<bool> report(String type, String note, {String? tripId}) async {
    if (reporting) return false;
    reporting = true;
    update();
    final LocationController location = Get.find<LocationController>();
    final LatLng? here = await location.getCurrentPosition();
    final saved = location.getUserAddress();
    final double? lat = here?.latitude ?? saved?.latitude;
    final double? lng = here?.longitude ?? saved?.longitude;
    if (lat == null || lng == null) {
      reporting = false;
      update();
      showCustomSnackBar('danger_no_location'.tr);
      return false;
    }
    String? place;
    try {
      place = await location.getAddressFromGeocode(LatLng(lat, lng));
    } catch (_) {}
    final Response response = await areaSafetyServiceInterface.report({
      'type': type,
      'latitude': lat,
      'longitude': lng,
      if (place != null && place.isNotEmpty) 'place': place,
      if (note.trim().isNotEmpty) 'note': note.trim(),
      if (tripId != null) 'trip_request_id': tripId,
    });
    reporting = false;
    update();
    if (response.statusCode == 200) {
      showCustomSnackBar('danger_report_sent'.tr, isError: false);
      loadNearby();
      return true;
    }
    final body = response.body;
    final errors = body is Map ? body['errors'] : null;
    showCustomSnackBar(errors is List && errors.isNotEmpty ? '${errors.first['message']}' : 'something_went_wrong'.tr);
    return false;
  }
}
