import 'package:ride_sharing_user_app/features/hotel/controllers/hotel_controller.dart';
import 'dart:math';

import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/explore/domain/models/explore_place_model.dart';
import 'package:ride_sharing_user_app/features/explore/domain/services/explore_service_interface.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/set_destination/screens/set_destination_screen.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:url_launcher/url_launcher.dart';

enum ExploreFilter { all, openNow, hotels, guestHouses }

/// Explore Bamenda: the categories, and for each one E-Ride's verified places
/// first, then Google's top rated and nearest.
///
/// Every category load is a paid Google search on the server, so a result is
/// reused for [_reuseFor] while the customer stays within [_reuseWithinKm].
/// It lives in memory only (Google's terms don't allow storing its results).
class ExploreController extends GetxController implements GetxService {
  final ExploreServiceInterface exploreServiceInterface;
  ExploreController({required this.exploreServiceInterface});

  static const Duration _reuseFor = Duration(minutes: 15);
  static const double _reuseWithinKm = 1;

  // ---------------------------------------------------------------- categories
  List<ExploreCategory>? categories;
  String? _serverLabel;
  bool categoriesLoading = false;
  /// Categories the server groups under Things to do (the tour guide).
  List<String> thingKeys = const ['eat', 'swim', 'party', 'visit', 'market'];
  bool isThing(String? key) => key != null && thingKeys.contains(key);

  // ---------------------------------------------------------------- places of the open category
  String? categoryKey;
  ExploreResult? result;
  bool loading = false;
  bool failed = false;
  ExploreFilter filter = ExploreFilter.all;
  String? openingPlaceId;

  final Map<String, ({ExploreResult result, DateTime at, double? lat, double? lng})> _cache = {};

  String get label {
    final String? fromServer = _serverLabel ?? Get.find<ConfigController>().config?.exploreLabel;
    return (fromServer == null || fromServer.isEmpty) ? 'explore_bamenda'.tr : fromServer;
  }

  /// Every active category, Things to do kinds included (the tiles group them).
  List<ExploreCategory> _allCategories = [];
  ExploreCategory? categoryOf(String key) =>
      (categories ?? []).firstWhereOrNull((c) => c.key == key) ?? _allCategories.firstWhereOrNull((c) => c.key == key);
  Set<String> get categoryKeys => {...(categories ?? []).map((c) => c.key), ..._allCategories.map((c) => c.key)};

  Address? get _here => Get.find<LocationController>().getUserAddress();

  /// Short name of where results are measured from, e.g. "Commercial Avenue".
  String? get nearLabel {
    final String? address = _here?.address;
    if (address == null || address.trim().isEmpty) return null;
    return address.split(',').first.trim();
  }

  /// Categories are cheap (no Google call), so home loads them every time.
  Future<void> loadCategories() async {
    categoriesLoading = true;
    update();
    final Response response = await exploreServiceInterface.getCategories();
    if (response.statusCode == 200 && response.body['data'] is Map) {
      final Map data = response.body['data'];
      _serverLabel = data['label']?.toString();
      final List<ExploreCategory> all = ((data['categories'] as List?) ?? []).whereType<Map>().map((e) => ExploreCategory.fromJson(Map<String, dynamic>.from(e))).toList();
      if (data['things'] is List) {
        thingKeys = (data['things'] as List).map((e) => e.toString()).toList();
      }
      _allCategories = all;
      // Things to do: one tile, first, instead of one per kind.
      final bool hasThings = all.any((c) => isThing(c.key));
      categories = [
        if (hasThings) ExploreCategory(key: ExploreCategory.things, name: 'things_to_do'.tr, icon: 'things'),
        ...all.where((c) => !isThing(c.key)),
      ];
    } else {
      categories ??= [];
    }
    categoriesLoading = false;
    update();
  }

  /// Opens a category: shows its last result straight away when recent and
  /// near enough, otherwise loads it.
  Future<void> open(String key, {bool force = false}) async {
    if (categoryKey != key) {
      categoryKey = key;
      filter = ExploreFilter.all;
      result = _cache[key]?.result;
    }
    await load(force: force);
  }

  Future<void> load({bool force = false}) async {
    final String? key = categoryKey;
    if (key == null) return;
    final Address? here = _here;
    final double? lat = here?.latitude;
    final double? lng = here?.longitude;
    // Places to stay: partner hotels' free rooms depend on the dates.
    final Map<String, String>? extra = key == ExploreCategory.stay
        ? {'check_in': HotelController.ymd(Get.find<HotelController>().checkIn), 'check_out': HotelController.ymd(Get.find<HotelController>().checkOut)}
        : null;
    final String cacheKey = extra == null ? key : '$key|${extra['check_in']}|${extra['check_out']}';
    final cached = _cache[cacheKey];
    if (!force && cached != null && DateTime.now().difference(cached.at) < _reuseFor && _sameSpot(lat, lng, cached.lat, cached.lng)) {
      result = cached.result;
      update();
      return;
    }
    loading = true;
    failed = false;
    update();
    final Response response = await exploreServiceInterface.getPlaces(key, latitude: lat, longitude: lng, extra: extra);
    if (categoryKey != key) return; // the customer moved on to another category
    if (response.statusCode == 200 && response.body['data'] is Map) {
      result = ExploreResult.fromJson(Map<String, dynamic>.from(response.body['data']));
      _cache[cacheKey] = (result: result!, at: DateTime.now(), lat: lat, lng: lng);
    } else {
      failed = result == null;
      ApiChecker.checkApi(response);
    }
    loading = false;
    update();
  }

  bool _sameSpot(double? lat, double? lng, double? lat0, double? lng0) {
    if (lat == null || lng == null || lat0 == null || lng0 == null) return lat == lat0 && lng == lng0;
    return _distanceKm(lat, lng, lat0, lng0) < _reuseWithinKm;
  }

  static double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const double r = 6371;
    final double dLat = (lat2 - lat1) * pi / 180;
    final double dLng = (lng2 - lng1) * pi / 180;
    final double a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// Filters that make sense for the open category: hotel types for places
  /// to stay, "Open now" for everything else.
  List<ExploreFilter> get filters => categoryKey == ExploreCategory.stay
      ? const [ExploreFilter.all, ExploreFilter.hotels, ExploreFilter.guestHouses]
      : const [ExploreFilter.all, ExploreFilter.openNow];

  void setFilter(ExploreFilter value) {
    if (filter == value) return;
    filter = value;
    update();
  }

  bool _matches(ExplorePlace p) {
    switch (filter) {
      case ExploreFilter.all:
        return true;
      case ExploreFilter.openNow:
        return p.openNow == true || p.onDuty;
      case ExploreFilter.hotels:
        return p.category == ExplorePlace.hotel;
      case ExploreFilter.guestHouses:
        return p.category != ExplorePlace.hotel;
    }
  }

  List<ExplorePlace> get onDuty => result?.onDuty ?? [];
  /// Verified places, without the on-duty ones already shown above them.
  List<ExplorePlace> get verified => (result?.verified ?? []).where((p) => !p.onDuty).where(_matches).toList();
  List<ExplorePlace> get topRated => (result?.topRated ?? []).where(_matches).toList();
  List<ExplorePlace> get nearby => (result?.nearby ?? []).where(_matches).toList();
  bool get filteredEmpty => onDuty.isEmpty && verified.isEmpty && topRated.isEmpty && nearby.isEmpty;

  // ---------------------------------------------------------------- actions

  /// Opens ride booking with the place as the destination, after checking
  /// that E-Ride serves it (same check as a saved place on the home screen).
  Future<void> rideThere(ExplorePlace place) async {
    if (!place.hasLocation || openingPlaceId != null) return;
    openingPlaceId = place.id;
    update();
    final zone = await Get.find<LocationController>().getZone(place.latitude.toString(), place.longitude.toString());
    openingPlaceId = null;
    update();
    if (!zone.isSuccess) {
      showCustomSnackBar('service_not_available_in_this_area'.tr);
      return;
    }
    Get.to(() => SetDestinationScreen(address: Address(
      latitude: place.latitude,
      longitude: place.longitude,
      address: place.address.isNotEmpty ? '${place.name}, ${place.address}' : place.name,
      addressLabel: 'others',
    )));
  }

  /// WhatsApp chat with a ready-made first message suited to the place.
  Future<void> whatsApp(ExplorePlace place) async {
    final String digits = _digits(place.whatsapp ?? '');
    if (digits.isEmpty) return;
    final String key = place.exploreCategory == ExploreCategory.stay ? 'stay_whatsapp_message' : 'place_whatsapp_message';
    final String text = Uri.encodeComponent(key.trParams({'name': place.name}));
    await _open(Uri.parse('https://wa.me/$digits?text=$text'));
  }

  Future<void> directions(ExplorePlace place) async {
    if (place.mapsUrl != null) {
      await _open(Uri.parse(place.mapsUrl!));
    } else if (place.hasLocation) {
      await _open(Uri.parse('https://www.google.com/maps/search/?api=1&query=${place.latitude},${place.longitude}'));
    }
  }

  Future<void> website(ExplorePlace place) async {
    if (place.website != null) await _open(Uri.parse(place.website!));
  }

  Future<void> _open(Uri uri) async {
    try {
      final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) showCustomSnackBar('could_not_open_link'.tr);
    } catch (_) {
      showCustomSnackBar('could_not_open_link'.tr);
    }
  }

  /// International number without "+" or spaces, as wa.me expects. A local
  /// 9-digit Cameroon number gets the 237 country code.
  static String _digits(String number) {
    String d = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('00')) d = d.substring(2);
    if (d.length == 9 && d.startsWith('6')) d = '237$d';
    return d;
  }
}
