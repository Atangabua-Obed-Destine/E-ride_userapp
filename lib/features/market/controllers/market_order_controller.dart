import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/domain/services/market_service_interface.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';

/// E-Ride Market orders for both sides: the buyer's orders and the seller's requests,
/// one order at a time with every action (answer, decline, agree, cancel, ready,
/// E-Ride delivery, close with the code, rate), and the shop's order settings.
class MarketOrderController extends GetxController implements GetxService {
  final MarketServiceInterface marketServiceInterface;
  MarketOrderController({required this.marketServiceInterface});

  MarketServiceInterface get _service => marketServiceInterface;

  // ---------------------------------------------------------------- lists

  /// "buying:active", "selling:new", ...
  final Map<String, List<MarketOrder>> lists = {};
  final Map<String, int> totals = {};
  final Set<String> loadingLists = {};

  List<MarketOrder> list(String role, String tab) => lists['$role:$tab'] ?? const [];
  bool isLoading(String role, String tab) => loadingLists.contains('$role:$tab');

  Future<void> loadList(String role, String tab) async {
    final key = '$role:$tab';
    loadingLists.add(key);
    update();
    Response response = await _service.getOrders(role, tab, 1);
    loadingLists.remove(key);
    if (response.statusCode == 200) {
      final data = response.body['data'];
      lists[key] = [for (final j in data['orders'] as List) MarketOrder.fromJson(Map<String, dynamic>.from(j))];
      totals[key] = int.tryParse('${data['total']}') ?? 0;
      _counts(data['counts']);
    }
    update();
  }

  int sellingNew = 0;
  int buyingAction = 0;
  int buyingOpen = 0;

  void _counts(dynamic c) {
    if (c is! Map) return;
    sellingNew = int.tryParse('${c['selling_new']}') ?? sellingNew;
    buyingAction = int.tryParse('${c['buying_action']}') ?? buyingAction;
    buyingOpen = int.tryParse('${c['buying_open']}') ?? buyingOpen;
  }

  void takeCounts(MarketMeta? meta) {
    if (meta == null) return;
    sellingNew = meta.sellingNew;
    buyingAction = meta.buyingAction;
    buyingOpen = meta.buyingOpen;
    update();
  }

  // ---------------------------------------------------------------- one order

  final Map<String, MarketOrder> _orders = {};
  bool loading = false;
  bool acting = false;
  String? error;

  MarketOrder? order(String id) => _orders[id];

  Future<MarketOrder?> load(String id, {bool quiet = false}) async {
    if (!quiet) {
      loading = true;
      error = null;
      update();
    }
    Response response = await _service.getOrder(id);
    loading = false;
    if (response.statusCode == 200) {
      _keep(response);
    } else if (!quiet) {
      error = _message(response) ?? 'market_order_gone'.tr;
    }
    update();
    return _orders[id];
  }

  MarketOrder? _keep(Response response) {
    final o = MarketOrder.fromJson(Map<String, dynamic>.from(response.body['data']));
    _orders[o.id] = o;
    // Keep list rows in step.
    for (final entry in lists.entries) {
      final i = entry.value.indexWhere((x) => x.id == o.id);
      if (i >= 0) entry.value[i] = o;
    }
    return o;
  }

  Future<MarketOrder?> _act(Future<dynamic> Function() call, {String? done}) async {
    if (acting) return null;
    acting = true;
    update();
    Response response = await call();
    acting = false;
    if (response.statusCode == 200) {
      final o = _keep(response);
      if (done != null) showCustomSnackBar(done.tr, isError: false);
      update();
      _refreshMeta();
      return o;
    }
    update();
    ApiChecker.checkApi(response);
    return null;
  }

  void _refreshMeta() {
    if (Get.isRegistered<MarketController>()) {
      Get.find<MarketController>().loadMeta(force: true).then(takeCounts);
    }
  }

  /// The buyer sends a shop's cart.
  Future<MarketOrder?> place(Map<String, dynamic> body) => _act(() => _service.placeOrder(body));

  /// The seller's answer: qty per line id (0 = not available) and a note.
  Future<MarketOrder?> respond(String id, Map<int, int> qty, Map<int, String> notes) => _act(() => _service.respondOrder(id, [
        for (final e in qty.entries) {'id': e.key, 'qty': e.value, if ((notes[e.key] ?? '').trim().isNotEmpty) 'note': notes[e.key]!.trim()},
      ]));

  Future<MarketOrder?> decline(String id, String reason, String? note, bool soldOut) =>
      _act(() => _service.declineOrder(id, reason, note, soldOut), done: 'market_order_declined_done');

  Future<MarketOrder?> agree(String id) => _act(() => _service.agreeOrder(id));

  Future<MarketOrder?> cancel(String id, String? reason) => _act(() => _service.cancelOrder(id, reason), done: 'market_order_cancelled_done');

  Future<MarketOrder?> ready(String id) => _act(() => _service.readyOrder(id));

  Future<MarketOrder?> complete(String id, String code) => _act(() => _service.completeOrder(id, code), done: 'market_order_completed_done');

  Future<MarketOrder?> review(String id, int stars, List<String> tags, String? comment) =>
      _act(() => _service.reviewOrder(id, stars, tags, comment), done: 'market_review_thanks');

  /// Auction orders: the seller says the winner arranged payment (no deadline any more).
  Future<MarketOrder?> paymentArranged(String id) => _act(() => _service.paymentArranged(id), done: 'market_payment_arranged_done');

  /// The winner did not arrange payment in time. Returns the item's code (to offer it to the next bidder).
  Future<String?> noShow(String id) async {
    if (acting) return null;
    acting = true;
    update();
    Response response = await _service.noShow(id);
    acting = false;
    update();
    if (response.statusCode == 200) {
      await load(id, quiet: true);
      _refreshMeta();
      return response.body['data']['item_code']?.toString();
    }
    ApiChecker.checkApi(response);
    return null;
  }

  /// Called once the seller booked the E-Ride parcel for an order.
  Future<void> attachTrip(String id, String tripId) async {
    Response response = await _service.attachTrip(id, tripId);
    if (response.statusCode == 200) {
      _keep(response);
      update();
    }
  }

  // ---------------------------------------------------------------- shop order settings

  Future<bool> saveSettings(Map<String, dynamic> body, {String? done}) async {
    acting = true;
    update();
    Response response = await _service.saveOrderSettings(body);
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

  // ---------------------------------------------------------------- reviews

  final Map<String, List<MarketReview>> reviews = {};

  Future<void> loadReviews(String slug) async {
    Response response = await _service.getReviews(slug);
    if (response.statusCode == 200) {
      reviews[slug] = [for (final j in response.body['data']['reviews'] as List) MarketReview.fromJson(Map<String, dynamic>.from(j))];
      update();
    }
  }

  String? _message(Response response) {
    final body = response.body;
    if (body is Map) {
      if (body['errors'] is List && (body['errors'] as List).isNotEmpty) return '${body['errors'][0]['message']}';
      if (body['message'] != null) return '${body['message']}';
    }
    return null;
  }
}
