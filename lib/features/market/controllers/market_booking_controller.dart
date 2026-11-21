import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/domain/services/market_service_interface.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';

/// E-Ride Market services for both sides: free times, booking a time, asking for a quote,
/// one booking with every step (accept, another time, price, move, cancel, code, no-show, rate),
/// the lists, and the provider's service settings.
class MarketBookingController extends GetxController implements GetxService {
  final MarketServiceInterface marketServiceInterface;
  MarketBookingController({required this.marketServiceInterface});

  MarketServiceInterface get _service => marketServiceInterface;

  // ---------------------------------------------------------------- free times

  MarketSlots? slots;
  bool slotsLoading = false;

  Future<MarketSlots?> loadSlots(String code, {String? date, String? ignore}) async {
    slotsLoading = true;
    update();
    Response response = await _service.getSlots(code, date, ignore);
    slotsLoading = false;
    if (response.statusCode == 200) {
      slots = MarketSlots.fromJson(Map<String, dynamic>.from(response.body['data']));
    } else {
      ApiChecker.checkApi(response);
    }
    update();
    return slots;
  }

  // ---------------------------------------------------------------- asking

  bool sending = false;

  Future<MarketBooking?> book(String code, Map<String, dynamic> body) =>
      _send(() => _service.book(code, body));

  Future<MarketBooking?> requestQuote(String code, Map<String, String> fields, List<XFile> photos) =>
      _send(() => _service.requestQuote(code, fields, photos));

  Future<MarketBooking?> _send(Future<dynamic> Function() call) async {
    if (sending) return null;
    sending = true;
    update();
    Response response = await call();
    sending = false;
    update();
    if (response.statusCode == 200) {
      final b = _keep(response);
      _refreshCounts();
      return b;
    }
    ApiChecker.checkApi(response);
    return null;
  }

  // ---------------------------------------------------------------- one booking

  final Map<String, MarketBooking> _bookings = {};
  bool loading = false;
  bool acting = false;
  String? error;

  MarketBooking? booking(String id) => _bookings[id];

  Future<MarketBooking?> load(String id, {bool quiet = false}) async {
    if (!quiet) {
      loading = true;
      error = null;
      update();
    }
    Response response = await _service.getBooking(id);
    loading = false;
    if (response.statusCode == 200) {
      _keep(response);
    } else if (!quiet) {
      final body = response.body;
      error = body is Map && body['errors'] is List && (body['errors'] as List).isNotEmpty ? '${body['errors'][0]['message']}' : 'market_booking_gone'.tr;
    }
    update();
    return _bookings[id];
  }

  MarketBooking _keep(Response response) {
    final b = MarketBooking.fromJson(Map<String, dynamic>.from(response.body['data']));
    _bookings[b.id] = b;
    for (final entry in lists.entries) {
      final i = entry.value.indexWhere((x) => x.id == b.id);
      if (i >= 0) entry.value[i] = b;
    }
    return b;
  }

  /// accept, decline, suggest, send-quote, agree, refuse, reschedule, cancel, complete, no-show, review
  Future<MarketBooking?> act(String id, String action, {Map<String, dynamic> body = const {}, String? done}) async {
    if (acting) return null;
    acting = true;
    update();
    Response response = await _service.bookingAction(id, action, body);
    acting = false;
    if (response.statusCode == 200) {
      final b = _keep(response);
      if (done != null) showCustomSnackBar(done.tr, isError: false);
      update();
      _refreshCounts();
      return b;
    }
    update();
    ApiChecker.checkApi(response);
    return null;
  }

  // ---------------------------------------------------------------- lists

  /// "client:upcoming", "provider:requests", "provider:day:2026-11-16"...
  final Map<String, List<MarketBooking>> lists = {};
  final Set<String> loadingLists = {};
  List<Map<String, dynamic>> providerDays = [];
  int providerRequests = 0;
  int clientAction = 0;

  static String key(String role, String tab, [String? date]) => date == null ? '$role:$tab' : '$role:$tab:$date';

  List<MarketBooking> list(String role, String tab, [String? date]) => lists[key(role, tab, date)] ?? const [];
  bool isLoading(String role, String tab, [String? date]) => loadingLists.contains(key(role, tab, date));

  Future<void> loadList(String role, String tab, {String? date}) async {
    final k = key(role, tab, date);
    loadingLists.add(k);
    update();
    Response response = await _service.getBookings(role, tab, date);
    loadingLists.remove(k);
    if (response.statusCode == 200) {
      final data = response.body['data'];
      lists[k] = [for (final j in data['bookings'] as List) MarketBooking.fromJson(Map<String, dynamic>.from(j))];
      if (data['counts'] is Map) {
        providerRequests = int.tryParse('${data['counts']['provider_requests']}') ?? providerRequests;
        clientAction = int.tryParse('${data['counts']['client_action']}') ?? clientAction;
      }
      if (data['days'] is List) {
        providerDays = [for (final d in data['days'] as List) Map<String, dynamic>.from(d)];
      }
    } else {
      ApiChecker.checkApi(response);
    }
    update();
  }

  void takeCounts(MarketMeta? meta) {
    if (meta == null) return;
    providerRequests = meta.providerRequests;
    clientAction = meta.clientAction;
    update();
  }

  void _refreshCounts() {
    if (Get.isRegistered<MarketController>()) {
      Get.find<MarketController>().loadMeta(force: true).then(takeCounts);
    }
  }

  // ---------------------------------------------------------------- the provider's settings

  Future<bool> saveSettings(Map<String, dynamic> body, {String? done}) async {
    acting = true;
    update();
    Response response = await _service.saveServiceSettings(body);
    acting = false;
    update();
    if (response.statusCode == 200) {
      if (done != null) showCustomSnackBar(done.tr, isError: false);
      if (Get.isRegistered<MarketController>()) await Get.find<MarketController>().loadMyShop();
      return true;
    }
    ApiChecker.checkApi(response);
    return false;
  }
}
