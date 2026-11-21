import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/estimated_fare_model.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/nearest_driver_model.dart';
import 'package:ride_sharing_user_app/features/ride/domain/services/ride_service_interface.dart';
import 'package:ride_sharing_user_app/helper/vehicle_type_helper.dart';

/// One available driver around the pickup, with its straight-line distance
/// and an approximate ETA.
class NearbyDriver {
  final Nearest driver;
  final LatLng position;
  final double distanceMeters;

  const NearbyDriver({required this.driver, required this.position, required this.distanceMeters});

  /// Average urban driving speed used for the estimate. The figure is shown
  /// with a "~" so the rider reads it as approximate.
  static const double _speedKmh = 22;

  int get etaMinutes => math.max(1, ((distanceMeters / 1000) / _speedKmh * 60).ceil() + 1);

  /// Within GPS precision of the pickup: the driver is already there.
  static const double _hereMeters = 100;
  bool get isHere => distanceMeters <= _hereMeters;

  /// "~3 min", or "Here now" when the driver is at the pickup already.
  String get etaLabel => isHere ? 'here_now'.tr : '~$etaMinutes ${'min_short'.tr}';

  /// The same, to follow "nearest" / "closest" in a sentence.
  String get etaInline => isHere ? 'at_your_pickup'.tr : '~$etaMinutes ${'min_short'.tr}';

  bool get isBike => driver.category == 'motor_bike';

  /// Map marker art: car, bike or truck.
  String get artAsset => VehicleTypeHelper.topArt(driver.category);
}

/// Live drivers around the pickup on the "Choose a vehicle" and "Finding your
/// driver" stages.
///
/// Kept apart from RideController.nearestDriverList on purpose: that list
/// feeds the home-screen map, and this one follows the trip's pickup point
/// instead of the saved address. Uses the same drivers-near-me endpoint, which
/// already returns only drivers who are online, available, on schedule and in
/// the zone. There is no realtime channel for customers, so "live" is a poll.
class NearbyDriversController extends GetxController implements GetxService {
  final RideServiceInterface rideServiceInterface;
  NearbyDriversController({required this.rideServiceInterface});

  static const Duration refreshEvery = Duration(seconds: 15);

  List<NearbyDriver> _drivers = [];
  bool _loaded = false;
  LatLng? _pickup;
  Timer? _timer;
  bool _fetching = false;
  // Bumped on every start/stop so a request still in flight from an earlier
  // session can't write into the current one.
  int _session = 0;

  /// Sorted nearest first.
  List<NearbyDriver> get drivers => _drivers;
  bool get loaded => _loaded;
  bool get isActive => _timer != null;
  LatLng? get pickup => _pickup;

  void start(LatLng pickup) {
    if (_timer != null && _pickup == pickup) return;
    _timer?.cancel();
    _session++;
    _pickup = pickup;
    _drivers = [];
    _loaded = false;
    _timer = Timer.periodic(refreshEvery, (_) => _fetch());
    _fetch();
    update();
  }

  void stop() {
    if (_timer == null && _drivers.isEmpty && _pickup == null) return;
    _timer?.cancel();
    _timer = null;
    _session++;
    _pickup = null;
    _drivers = [];
    _loaded = false;
    update();
  }

  Future<void> _fetch() async {
    final LatLng? pickup = _pickup;
    if (_fetching || pickup == null) return;
    final int session = _session;
    _fetching = true;
    try {
      final dynamic response = await rideServiceInterface.nearestDriverList(
        pickup.latitude.toString(), pickup.longitude.toString(),
      );
      if (session != _session) return;
      if (response?.statusCode == 200 && response.body is Map) {
        final List<Nearest> list = NearestDriverModel.fromJson(Map<String, dynamic>.from(response.body)).data ?? [];
        final List<NearbyDriver> parsed = [];
        for (final Nearest n in list) {
          final double? lat = double.tryParse(n.latitude ?? '');
          final double? lng = double.tryParse(n.longitude ?? '');
          if (lat == null || lng == null) continue;
          parsed.add(NearbyDriver(
            driver: n,
            position: LatLng(lat, lng),
            distanceMeters: Geolocator.distanceBetween(pickup.latitude, pickup.longitude, lat, lng),
          ));
        }
        parsed.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
        _drivers = parsed;
        _loaded = true;
        update();
        Get.find<MapController>().refreshNearbyDriverMarkers();
      }
    } catch (_) {
      // A background poll failing keeps the last good list; no snackbar.
    } finally {
      _fetching = false;
    }
  }

  /// Whether [d] drives the category of [fare]: by exact category id when the
  /// backend sends it, otherwise by vehicle type (car / motor_bike).
  bool matches(NearbyDriver d, FareModel fare) {
    final String? driverCategory = d.driver.vehicleCategoryId;
    if (driverCategory != null && driverCategory.isNotEmpty && fare.vehicleCategoryId != null) {
      return driverCategory == fare.vehicleCategoryId;
    }
    final String driverType = _normalizeType(d.driver.category);
    return driverType.isNotEmpty && driverType == _normalizeType(fare.vehicleCategoryType);
  }

  /// The two endpoints spell the type differently: drivers-near-me sends
  /// "car" / "motor_bike", the fare estimate sends "Car" / "Motorbike".
  static String _normalizeType(String? type) =>
      (type ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  List<NearbyDriver> driversFor(FareModel? fare) =>
      fare == null ? _drivers : _drivers.where((d) => matches(d, fare)).toList();

  NearbyDriver? nearestFor(FareModel? fare) {
    final List<NearbyDriver> list = driversFor(fare);
    return list.isEmpty ? null : list.first;
  }

  /// The category whose nearest driver is closest overall, for the "Closest"
  /// badge. Null when there is only one category or no drivers at all.
  String? closestCategoryId(List<FareModel> fares) {
    if (fares.length < 2) return null;
    String? best;
    double bestDistance = double.infinity;
    for (final FareModel fare in fares) {
      final NearbyDriver? n = nearestFor(fare);
      if (n != null && n.distanceMeters < bestDistance) {
        bestDistance = n.distanceMeters;
        best = fare.vehicleCategoryId;
      }
    }
    return best;
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
