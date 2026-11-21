import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/listing/domain/models/listing_model.dart';
import 'package:ride_sharing_user_app/features/listing/domain/services/listing_service_interface.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/payment/controllers/payment_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/splash/domain/models/config_model.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_payment_screen.dart';
import 'package:ride_sharing_user_app/features/set_destination/screens/set_destination_screen.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';

/// Homes & spaces: searching, a listing's page, the owner's listings, visits
/// on both sides, and saved alerts. Each action reports its own error.
class ListingController extends GetxController implements GetxService {
  final ListingServiceInterface listingServiceInterface;
  ListingController({required this.listingServiceInterface});

  ListingServiceInterface get _service => listingServiceInterface;

  // ---------------------------------------------------------------- meta

  ListingMeta? meta;
  bool metaLoading = false;

  Future<ListingMeta?> loadMeta({bool force = false}) async {
    if (meta != null && !force) return meta;
    if (metaLoading) return meta;
    metaLoading = true;
    Response response = await _service.getMeta();
    metaLoading = false;
    if (response.statusCode == 200) {
      meta = ListingMeta.fromJson(Map<String, dynamic>.from(response.body['data']));
    }
    update();
    return meta;
  }

  // ---------------------------------------------------------------- search

  ListingFilters filters = const ListingFilters();
  List<Listing> items = [];
  int total = 0;
  int _page = 1;
  bool loading = false;
  bool loadingMore = false;
  bool failed = false;
  int _searchSeq = 0;

  Future<void> search() async {
    final int seq = ++_searchSeq;
    loading = true;
    failed = false;
    _page = 1;
    update();
    Response response = await _service.search(filters.toQuery(), 1);
    if (seq != _searchSeq) return; // a newer search replaced this one
    loading = false;
    if (response.statusCode == 200) {
      final data = response.body['data'];
      items = (data['items'] as List).map((j) => Listing.fromJson(Map<String, dynamic>.from(j))).toList();
      total = int.tryParse('${data['total']}') ?? items.length;
    } else {
      failed = true;
    }
    update();
  }

  bool get hasMore => items.length < total;

  Future<void> loadMore() async {
    if (loadingMore || loading || !hasMore) return;
    loadingMore = true;
    update();
    Response response = await _service.search(filters.toQuery(), _page + 1);
    loadingMore = false;
    if (response.statusCode == 200) {
      _page++;
      final data = response.body['data'];
      items.addAll((data['items'] as List).map((j) => Listing.fromJson(Map<String, dynamic>.from(j))));
    }
    update();
  }

  void setFilters(ListingFilters value) {
    filters = value;
    search();
  }

  // ---------------------------------------------------------------- one listing

  final Map<String, Listing> _byId = {};
  bool detailLoading = false;

  Listing? listing(String id) => _byId[id];

  Future<Listing?> loadListing(String id) async {
    detailLoading = _byId[id] == null;
    update();
    Response response = await _service.getListing(id);
    detailLoading = false;
    if (response.statusCode == 200) {
      _remember(Listing.fromJson(Map<String, dynamic>.from(response.body['data'])));
    } else {
      _error(response);
    }
    update();
    return _byId[id];
  }

  void _remember(Listing l) {
    _byId[l.id] = l;
    final int i = items.indexWhere((e) => e.id == l.id);
    if (i >= 0) items[i] = l;
    final int m = mine.indexWhere((e) => e.id == l.id);
    if (m >= 0) mine[m] = l;
  }

  // ---------------------------------------------------------------- owner

  List<Listing> mine = [];
  bool mineLoading = false;
  bool mineLoaded = false;
  String? busyId;
  bool saving = false;

  Future<void> loadMine() async {
    mineLoading = !mineLoaded;
    update();
    Response response = await _service.getMine();
    mineLoading = false;
    if (response.statusCode == 200) {
      mine = (response.body['data']['items'] as List).map((j) => Listing.fromJson(Map<String, dynamic>.from(j))).toList();
      mineLoaded = true;
      for (final l in mine) {
        _byId[l.id] = l;
      }
    }
    update();
  }

  /// Creates or edits a listing. Returns it when saved.
  Future<Listing?> save({String? id, required Map<String, String> fields, required List<XFile> photos, List<int> removePhotoIds = const []}) async {
    saving = true;
    update();
    Response response = id == null
        ? await _service.create(fields, photos)
        : await _service.edit(id, fields, photos, removePhotoIds);
    saving = false;
    Listing? saved;
    if (response.statusCode == 200) {
      saved = Listing.fromJson(Map<String, dynamic>.from(response.body['data']));
      _remember(saved);
      if (!mine.any((e) => e.id == saved!.id)) mine.insert(0, saved);
    } else {
      _error(response);
    }
    update();
    return saved;
  }

  Future<bool> confirm(String id) => _ownerAction(id, () => _service.confirm(id), 'listing_confirmed_thanks');
  Future<bool> markRented(String id) => _ownerAction(id, () => _service.markRented(id), 'listing_marked_rented');
  Future<bool> requestVerification(String id) => _ownerAction(id, () => _service.requestVerification(id), 'listing_verification_requested');

  Future<bool> _ownerAction(String id, Future<dynamic> Function() call, String okMessage) async {
    if (busyId != null) return false;
    busyId = id;
    update();
    Response response = await call();
    busyId = null;
    final bool ok = response.statusCode == 200;
    if (ok) {
      _remember(Listing.fromJson(Map<String, dynamic>.from(response.body['data'])));
      showCustomSnackBar(okMessage.tr, isError: false);
    } else {
      _error(response);
    }
    update();
    return ok;
  }

  // ---------------------------------------------------------------- reports

  Future<bool> report(String id, String reason, String? note) async {
    saving = true;
    update();
    Response response = await _service.report(id, reason, note);
    saving = false;
    update();
    if (response.statusCode == 200) {
      showCustomSnackBar('listing_report_sent'.tr, isError: false);
      return true;
    }
    _error(response);
    return false;
  }

  // ---------------------------------------------------------------- visits

  List<ListingVisit> visits = [];
  bool visitsLoading = false;
  bool visitsLoaded = false;

  List<ListingVisit> get myVisits => visits.where((v) => !v.asOwner).toList();
  List<ListingVisit> get visitsToMyPlaces => visits.where((v) => v.asOwner).toList();
  List<ListingVisit> visitsFor(String listingId) => visitsToMyPlaces.where((v) => v.listing?.id == listingId).toList();
  /// The seeker's open visit to this listing, if any.
  ListingVisit? openVisitTo(String listingId) =>
      myVisits.firstWhereOrNull((v) => v.listing?.id == listingId && (v.isOpen || v.canRate));

  Future<void> loadVisits() async {
    visitsLoading = !visitsLoaded;
    update();
    Response response = await _service.getVisits();
    visitsLoading = false;
    if (response.statusCode == 200) {
      visits = (response.body['data']['items'] as List).map((j) => ListingVisit.fromJson(Map<String, dynamic>.from(j))).toList();
      visitsLoaded = true;
    }
    update();
  }

  Future<bool> book(String listingId, DateTime date, String window) =>
      _visitAction(() => _service.bookVisit(listingId, _day(date), window), 'listing_visit_requested_ok');

  Future<bool> ownerRespond(String visitId, String action, {DateTime? date, String? window}) => _visitAction(
        () => _service.ownerRespond(visitId, action, date: date == null ? null : _day(date), window: window),
        action == 'accept' ? 'listing_visit_accepted_ok' : action == 'propose' ? 'listing_visit_proposed_ok' : 'listing_visit_answered_ok',
        refreshMine: action == 'rented',
      );

  Future<bool> seekerRespond(String visitId, String action) =>
      _visitAction(() => _service.seekerRespond(visitId, action), action == 'cancel' ? 'listing_visit_cancelled_ok' : 'listing_visit_accepted_ok');

  Future<bool> outcome(String visitId, String outcome, String? note) =>
      _visitAction(() => _service.outcome(visitId, outcome, note), 'listing_outcome_thanks');

  Future<bool> taking(String visitId) => _visitAction(() => _service.taking(visitId), 'listing_taking_sent');

  // ---------------------------------------------------------------- reservation money

  /// 'wallet' or a gateway key while a reservation payment is in progress.
  String? payingWith;

  double? get walletBalance => Get.find<ProfileController>().profileModel?.data?.wallet?.walletBalance;
  List<PaymentGateways> get gateways => Get.find<PaymentController>().paymentGateways ?? [];

  /// Wallet balance and gateways for the payment buttons.
  void preparePayment() {
    if (gateways.isEmpty) Get.find<PaymentController>().getPaymentGetWayList();
    Get.find<ProfileController>().getProfileInfo();
  }

  ListingVisit? visitById(String id) => visits.firstWhereOrNull((v) => v.id == id);

  /// Starts a reservation (not paid yet); the answer is the visit with it.
  Future<ListingReservation?> reserve(String visitId, DateTime moveIn) async {
    final bool ok = await _visitAction(() => _service.reserve(visitId, _day(moveIn)), null);
    return ok ? visitById(visitId)?.reservation : null;
  }

  Future<bool> payReservationWithWallet(String reservationId) async {
    if (payingWith != null) return false;
    payingWith = 'wallet';
    update();
    final bool ok = await _visitAction(() => _service.reservationAction(reservationId, 'wallet', {}), 'listing_reservation_paid_ok');
    payingWith = null;
    update();
    Get.find<ProfileController>().getProfileInfo();
    return ok;
  }

  /// Mobile money: the gateway page in a webview, then the server says whether it arrived.
  Future<bool> payReservationWithGateway(String visitId, String reservationId, String gateway) async {
    if (payingWith != null) return false;
    payingWith = gateway;
    update();
    final Response response = await _service.reservationPayUrl(reservationId, gateway);
    if (response.statusCode != 200 || response.body['data']?['pay_url'] == null) {
      payingWith = null;
      _error(response);
      update();
      return false;
    }
    await Get.to<bool>(() => StorePaymentScreen(url: response.body['data']['pay_url'].toString()));
    // The webview's answer is only a hint, and MoMo can land a few seconds after approval.
    ListingReservation? r;
    for (int i = 0; i < 6; i++) {
      await loadVisits();
      r = visitById(visitId)?.reservation;
      if (r == null || !r.isAwaiting) break;
      await Future.delayed(const Duration(seconds: 2));
    }
    payingWith = null;
    update();
    if (r != null && r.isHeld) {
      showCustomSnackBar('listing_reservation_paid_ok'.tr, isError: false);
      return true;
    }
    if (r?.isAwaiting ?? false) showCustomSnackBar('listing_reservation_not_received'.tr);
    return false;
  }

  Future<bool> respondReservation(String reservationId, String action, {DateTime? moveIn}) => _visitAction(
        () => _service.reservationAction(reservationId, 'respond', {'action': action, if (moveIn != null) 'move_in_date': _day(moveIn)}),
        action == 'accept' ? 'listing_reservation_accepted_ok' : 'listing_reservation_declined_ok',
        refreshMine: true,
      );

  Future<bool> cancelReservation(String reservationId, {String? note}) => _visitAction(
      () => _service.reservationAction(reservationId, 'cancel', {if (note != null && note.isNotEmpty) 'note': note}), 'listing_reservation_cancel_ok');

  Future<bool> movedIn(String reservationId) =>
      _visitAction(() => _service.reservationAction(reservationId, 'moved-in', {}), 'listing_reservation_moved_in_ok');

  Future<bool> reservationProblem(String reservationId, String reason, String? note) => _visitAction(
      () => _service.reservationAction(reservationId, 'problem', {'reason': reason, if (note != null && note.isNotEmpty) 'note': note}),
      'listing_reservation_problem_ok');

  Future<bool> refundToMomo(String reservationId, String phone) async {
    final bool ok = await _visitAction(() => _service.reservationAction(reservationId, 'refund-to-momo', {'phone': phone}), 'listing_refund_momo_ok');
    if (ok) Get.find<ProfileController>().getProfileInfo();
    return ok;
  }

  Future<bool> _visitAction(Future<dynamic> Function() call, String? okMessage, {bool refreshMine = false}) async {
    if (saving) return false;
    saving = true;
    update();
    Response response = await call();
    saving = false;
    final bool ok = response.statusCode == 200;
    if (ok) {
      final ListingVisit visit = ListingVisit.fromJson(Map<String, dynamic>.from(response.body['data']));
      final int i = visits.indexWhere((v) => v.id == visit.id);
      if (i >= 0) {
        visits[i] = visit;
      } else {
        visits.insert(0, visit);
      }
      if (okMessage != null) showCustomSnackBar(okMessage.tr, isError: false);
      if (refreshMine) loadMine();
    } else {
      _error(response);
    }
    update();
    return ok;
  }

  String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------- alerts

  List<ListingAlert> alerts = [];

  Future<void> loadAlerts() async {
    Response response = await _service.getAlerts();
    if (response.statusCode == 200) {
      alerts = (response.body['data']['items'] as List).map((j) => ListingAlert.fromJson(Map<String, dynamic>.from(j))).toList();
      update();
    }
  }

  /// "Alert me" for the current filters.
  Future<bool> alertForFilters() async {
    saving = true;
    update();
    Response response = await _service.addAlert({
      if (filters.type != null) 'type': filters.type,
      if (filters.neighbourhood != null) 'neighbourhood': filters.neighbourhood,
      if (filters.maxRent != null) 'max_monthly_rent': filters.maxRent!.round(),
      'verified_only': filters.verifiedOnly ? 1 : 0,
      if (filters.amenities.isNotEmpty) 'amenities': filters.amenities.join(','),
    });
    saving = false;
    update();
    if (response.statusCode == 200) {
      showCustomSnackBar('listing_alert_saved'.tr, isError: false);
      loadAlerts();
      return true;
    }
    _error(response);
    return false;
  }

  Future<void> deleteAlert(int id) async {
    alerts.removeWhere((a) => a.id == id);
    update();
    await _service.deleteAlert(id);
  }

  // ---------------------------------------------------------------- going there

  String? openingId;

  /// Ride booking with the place as the destination, when E-Ride serves it.
  Future<void> rideThere({required String id, required double latitude, required double longitude, required String label}) async {
    if (openingId != null) return;
    openingId = id;
    update();
    final zone = await Get.find<LocationController>().getZone(latitude.toString(), longitude.toString());
    openingId = null;
    update();
    if (!zone.isSuccess) {
      showCustomSnackBar('service_not_available_in_this_area'.tr);
      return;
    }
    Get.to(() => SetDestinationScreen(address: Address(latitude: latitude, longitude: longitude, address: label, addressLabel: 'others')));
  }

  // ---------------------------------------------------------------- errors

  /// Shows the server's message. Handles both error shapes the backend sends:
  /// a list of errors (our own refusals) and Laravel's field map (422).
  void _error(Response response) {
    final body = response.body;
    String? message;
    if (body is Map) {
      final errors = body['errors'];
      if (errors is List && errors.isNotEmpty && errors.first is Map) {
        message = errors.first['message']?.toString();
      } else if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        message = first is List && first.isNotEmpty ? first.first.toString() : first.toString();
      }
      message ??= body['message']?.toString();
    }
    if (response.statusCode == 401 || message == null) {
      ApiChecker.checkApi(response);
    } else {
      showCustomSnackBar(message);
    }
  }
}
