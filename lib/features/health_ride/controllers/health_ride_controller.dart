import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/health_ride/domain/models/health_place_model.dart';
import 'package:ride_sharing_user_app/features/health_ride/domain/services/health_ride_service_interface.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/set_destination/screens/set_destination_screen.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:url_launcher/url_launcher.dart';

/// Health ride: an urgent ride to a hospital, clinic or pharmacy. Not an ambulance.
/// The rider picks a place near them (nearest first), then books as usual; the
/// server gives the normal fare with no surge and sends it to drivers further away.
class HealthRideController extends GetxController implements GetxService {
  final HealthRideServiceInterface healthRideServiceInterface;
  HealthRideController({required this.healthRideServiceInterface});

  bool loading = false;
  HealthPlacesResult? result;
  int tab = 0; // 0: hospitals and clinics, 1: pharmacies
  String? openingId;

  bool get enabled => Get.find<ConfigController>().config?.healthRideStatus ?? false;
  List<HealthPlace> get places => tab == 0 ? (result?.hospitals ?? const []) : (result?.pharmacies ?? const []);
  bool get noRidesLeft => result != null && result!.dailyLimit > 0 && result!.ridesLeft <= 0;

  void setTab(int value) {
    tab = value;
    update();
  }

  /// Places around the rider now (or their saved place when the phone cannot tell).
  Future<void> load() async {
    loading = true;
    update();
    final LocationController location = Get.find<LocationController>();
    LatLng? here;
    try {
      here = await location.getCurrentPosition();
    } catch (_) {}
    final saved = location.getUserAddress();
    final double? lat = here?.latitude ?? saved?.latitude;
    final double? lng = here?.longitude ?? saved?.longitude;
    if (lat == null || lng == null) {
      loading = false;
      result = const HealthPlacesResult();
      update();
      return;
    }
    final Response response = await healthRideServiceInterface.getPlaces(lat, lng);
    if (response.statusCode == 200 && response.body['data'] is Map) {
      result = HealthPlacesResult.fromJson(Map<String, dynamic>.from(response.body['data']));
    } else {
      result ??= const HealthPlacesResult();
      ApiChecker.checkApi(response);
    }
    loading = false;
    update();
  }

  /// Booking with this place as the destination, after checking that E-Ride serves it.
  Future<void> rideTo(HealthPlace place) async {
    if (openingId != null) return;
    if (noRidesLeft) {
      showCustomSnackBar('health_ride_none_left'.tr);
      return;
    }
    openingId = place.id;
    update();
    final zone = await Get.find<LocationController>().getZone(place.latitude.toString(), place.longitude.toString());
    openingId = null;
    update();
    if (!zone.isSuccess) {
      showCustomSnackBar('service_not_available_in_this_area'.tr);
      return;
    }
    Get.to(() => SetDestinationScreen(health: true, address: Address(
      latitude: place.latitude,
      longitude: place.longitude,
      address: place.address.isNotEmpty ? '${place.name}, ${place.address}' : place.name,
      addressLabel: 'others',
    )));
  }

  /// A place not in the list: the rider searches it like any destination.
  void rideElsewhere() {
    if (noRidesLeft) {
      showCustomSnackBar('health_ride_none_left'.tr);
      return;
    }
    Get.to(() => const SetDestinationScreen(health: true));
  }

  static Future<void> call(String number) async {
    final String digits = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return;
    await launchUrl(Uri.parse('tel:$digits'));
  }
}
