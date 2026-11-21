import 'dart:convert';

import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/address/controllers/address_controller.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/explore/controllers/explore_controller.dart';
import 'package:ride_sharing_user_app/features/explore/domain/models/explore_place_model.dart';
import 'package:ride_sharing_user_app/features/explore/domain/services/explore_service_interface.dart';
import 'package:ride_sharing_user_app/features/guide/domain/models/guide_models.dart';
import 'package:ride_sharing_user_app/features/guide/domain/services/guide_service_interface.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/set_destination/screens/set_destination_screen.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThingSort { topPicks, bestRated, nearest, openNow }

/// E-Ride as a city and tour guide: Things to do (eat, swim, party, sights,
/// markets) rated by riders, a place's guide, the city's tours, and the tour
/// or one-place visit the person is taking.
///
/// A tour is self-guided and stop by stop: "Start" books a normal ride to the
/// first stop, "Next stop" the next one. The run lives on the phone only.
class GuideController extends GetxController implements GetxService {
  final GuideServiceInterface guideServiceInterface;
  GuideController({required this.guideServiceInterface});

  static const String _runKey = 'guide_tour_run';
  /// A run left open this long is over (the person forgot to end it).
  static const Duration _runExpiry = Duration(hours: 18);
  static const String all = 'all';

  SharedPreferences get _prefs => Get.find<SharedPreferences>();
  Address? get _here => Get.find<LocationController>().getUserAddress();

  // ---------------------------------------------------------------- things to do home
  ThingsHome? home;
  bool homeLoading = false;
  bool homeFailed = false;

  String kind = all;
  ThingSort sort = ThingSort.topPicks;
  final Map<String, List<ExplorePlace>> _kindPlaces = {};
  final Map<String, DateTime> _kindAt = {};
  bool kindLoading = false;
  bool kindGoogleMissing = false;

  // ---------------------------------------------------------------- places and tours
  final Map<String, PlaceGuideInfo> _guides = {};
  final Set<String> _guideLoading = {};
  final Map<String, TourDetail> _tours = {};
  bool tourLoading = false;
  bool rating = false;

  // ---------------------------------------------------------------- the run
  TourRun? run;
  String? ridingTo;

  @override
  void onInit() {
    super.onInit();
    _restoreRun();
  }

  Future<void> loadHome({bool force = false}) async {
    if (homeLoading || (!force && home != null)) return;
    homeLoading = true;
    homeFailed = false;
    update();
    final Response response = await guideServiceInterface.getThings(latitude: _here?.latitude, longitude: _here?.longitude);
    if (response.statusCode == 200 && response.body['data'] is Map) {
      home = ThingsHome.fromJson(Map<String, dynamic>.from(response.body['data']));
    } else {
      homeFailed = home == null;
      ApiChecker.checkApi(response);
    }
    homeLoading = false;
    update();
  }

  List<TourCard> get tours => home?.tours ?? [];
  String? get city => home?.city;

  // ---------------------------------------------------------------- kinds and sorting

  Future<void> setKind(String value) async {
    kind = value;
    update();
    if (value != all) await _loadKind(value);
  }

  void setSort(ThingSort value) {
    sort = value;
    update();
  }

  /// One kind's places: E-Ride's verified ones first, then Google's. A Google
  /// search is paid, so a result is reused for 15 minutes.
  Future<void> _loadKind(String key, {bool force = false}) async {
    final DateTime? at = _kindAt[key];
    if (!force && at != null && DateTime.now().difference(at) < const Duration(minutes: 15)) {
      update();
      return;
    }
    kindLoading = true;
    kindGoogleMissing = false;
    update();
    final Response response = await Get.find<ExploreServiceInterface>().getPlaces(key, latitude: _here?.latitude, longitude: _here?.longitude);
    if (kind != key) return;
    if (response.statusCode == 200 && response.body['data'] is Map) {
      final ExploreResult result = ExploreResult.fromJson(Map<String, dynamic>.from(response.body['data']));
      final Map<String, ExplorePlace> merged = {};
      for (final ExplorePlace p in [...result.verified, ...result.topRated, ...result.nearby]) {
        merged.putIfAbsent(p.id, () => p);
      }
      _kindPlaces[key] = merged.values.toList();
      _kindAt[key] = DateTime.now();
      kindGoogleMissing = !result.googleAvailable;
    } else {
      ApiChecker.checkApi(response);
    }
    kindLoading = false;
    update();
  }

  Future<void> refreshKind() async {
    if (kind == all) {
      await loadHome(force: true);
    } else {
      await _loadKind(kind, force: true);
    }
  }

  /// The places of the chosen kind, in the chosen order.
  List<ExplorePlace> get places {
    final List<ExplorePlace> list = List.of(kind == all ? (home?.picks ?? []) : (_kindPlaces[kind] ?? []));
    switch (sort) {
      case ThingSort.topPicks:
        // E-Ride's checked places first; within a group, the server's order (Google's prominence).
        int group(ExplorePlace p) => p.isVerified && p.hasGuide ? 0 : p.isVerified ? 1 : p.hasErideRating ? 2 : 3;
        final List<MapEntry<int, ExplorePlace>> indexed = list.asMap().entries.toList();
        indexed.sort((a, b) {
          final int g = group(a.value).compareTo(group(b.value));
          return g != 0 ? g : a.key.compareTo(b.key);
        });
        return indexed.map((e) => e.value).toList();
      case ThingSort.bestRated:
        list.sort((a, b) {
          final double ra = bestRating(a) ?? -1;
          final double rb = bestRating(b) ?? -1;
          if (ra != rb) return rb.compareTo(ra);
          return (b.erideRatings + b.reviews).compareTo(a.erideRatings + a.reviews);
        });
        return list;
      case ThingSort.nearest:
        list.sort((a, b) => (a.distanceKm ?? 9999).compareTo(b.distanceKm ?? 9999));
        return list;
      case ThingSort.openNow:
        return list.where((p) => p.openNow == true || p.reception24h).toList();
    }
  }

  /// Riders' rating once a few have rated, else Google's.
  static double? bestRating(ExplorePlace p) {
    if (p.hasErideRating && p.erideRatings >= 3) return p.erideRating;
    if (p.hasRating) return p.rating;
    return p.erideRating;
  }

  List<ExplorePlace>? placesOf(String key) => _kindPlaces[key];

  // ---------------------------------------------------------------- one place

  PlaceGuideInfo? guideOf(String id) => _guides[id];
  bool guideLoading(String id) => _guideLoading.contains(id);

  Future<void> loadGuide(ExplorePlace place, {bool force = false}) async {
    if (_guideLoading.contains(place.id) || (!force && _guides.containsKey(place.id))) return;
    _guideLoading.add(place.id);
    update();
    final Response response = await guideServiceInterface.getPlaceGuide(place.id, latitude: _here?.latitude, longitude: _here?.longitude);
    if (response.statusCode == 200 && response.body['data'] is Map) {
      _guides[place.id] = PlaceGuideInfo.fromJson(Map<String, dynamic>.from(response.body['data']));
    }
    _guideLoading.remove(place.id);
    update();
  }

  Future<bool> rate(ExplorePlace place, int stars, String? comment) async {
    if (rating) return false;
    rating = true;
    update();
    final Response response = await guideServiceInterface.ratePlace(place.id, stars: stars, comment: comment, name: place.name);
    rating = false;
    if (response.statusCode == 200 && response.body['data'] is Map) {
      _guides[place.id] = PlaceGuideInfo.fromJson(Map<String, dynamic>.from(response.body['data']));
      update();
      showCustomSnackBar('guide_rating_thanks'.tr, isError: false);
      return true;
    }
    update();
    ApiChecker.checkApi(response);
    return false;
  }

  // ---------------------------------------------------------------- tours

  TourDetail? tourOf(String id) => _tours[id];

  Future<TourDetail?> loadTour(String id, {bool force = false}) async {
    if (!force && _tours.containsKey(id)) return _tours[id];
    tourLoading = true;
    update();
    final Response response = await guideServiceInterface.getTour(id, latitude: _here?.latitude, longitude: _here?.longitude);
    tourLoading = false;
    if (response.statusCode == 200 && response.body['data'] is Map) {
      _tours[id] = TourDetail.fromJson(Map<String, dynamic>.from(response.body['data']));
    } else {
      ApiChecker.checkApi(response);
    }
    update();
    return _tours[id];
  }

  // ---------------------------------------------------------------- the run

  void _restoreRun() {
    final String? raw = _prefs.getString(_runKey);
    if (raw == null) return;
    try {
      final TourRun? saved = TourRun.fromJson(jsonDecode(raw));
      if (saved != null && DateTime.now().difference(saved.startedAt) < _runExpiry) {
        run = saved;
      } else {
        _prefs.remove(_runKey);
      }
    } catch (_) {
      _prefs.remove(_runKey);
    }
  }

  void _saveRun() {
    if (run == null) {
      _prefs.remove(_runKey);
    } else {
      _prefs.setString(_runKey, jsonEncode(run!.toJson()));
    }
    update();
  }

  /// Start tour: the run begins at stop 1 and a ride there is booked.
  Future<void> startTour(TourDetail tour, {int from = 0}) async {
    final List<ExplorePlace> stops = tour.stops.map((s) => s.place).where((p) => p.hasLocation).toList();
    if (stops.isEmpty) return;
    run = TourRun(tourId: tour.card.id, title: tour.card.title, stops: stops, index: from.clamp(0, stops.length - 1), startedAt: DateTime.now());
    _saveRun();
    await rideToCurrent();
  }

  /// Visit: a one-stop tour. Ride there, the guide on arrival, rate it, then
  /// somewhere nearby or home.
  Future<void> startVisit(ExplorePlace place) async {
    if (!place.hasLocation) return;
    run = TourRun(title: place.name, stops: [place], startedAt: DateTime.now());
    _saveRun();
    await rideToCurrent();
  }

  Future<void> rideToCurrent() async {
    final TourRun? r = run;
    if (r == null) return;
    ridingTo = r.current.id;
    update();
    await Get.find<ExploreController>().rideThere(r.current);
    ridingTo = null;
    update();
  }

  /// Next stop: move on and book the ride there.
  Future<void> nextStop() async {
    final TourRun? r = run;
    if (r == null || r.isLast) return;
    run = r.copyWith(index: r.index + 1);
    _saveRun();
    await rideToCurrent();
  }

  /// Skip a stop without riding there (e.g. it is closed).
  void skipStop() {
    final TourRun? r = run;
    if (r == null || r.isLast) return;
    run = r.copyWith(index: r.index + 1);
    _saveRun();
  }

  void endRun() {
    run = null;
    _saveRun();
  }

  /// Ride back home: the saved Home address, or the destination screen to pick one.
  Future<void> rideHome() async {
    final AddressController addresses = Get.find<AddressController>();
    if (addresses.addressList == null) {
      await addresses.getAddressList(1);
    }
    final Address? homeAddress = (addresses.addressList ?? []).firstWhereOrNull((a) => a.addressLabel == 'home');
    endRun();
    Get.to(() => SetDestinationScreen(address: homeAddress));
  }

  /// Somewhere else: a normal ride, the person picks where.
  void rideSomewhereElse() {
    endRun();
    Get.to(() => const SetDestinationScreen());
  }
}
