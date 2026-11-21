import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/payment/controllers/payment_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/splash/domain/models/config_model.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_model.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_order_model.dart';
import 'package:ride_sharing_user_app/features/store/domain/services/store_service_interface.dart';
import 'package:ride_sharing_user_app/features/store/widgets/cart_reminder.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

/// Food & Shops: stores, one cart (one store at a time), checkout and orders.
class StoreController extends GetxController implements GetxService {
  final StoreServiceInterface storeServiceInterface;
  StoreController({required this.storeServiceInterface});

  // ---------------------------------------------------------------- stores
  List<StoreModel>? stores;
  bool storesLoading = false;

  StoreModel? store;
  List<MenuSection> menu = [];
  bool menuLoading = false;

  // ---------------------------------------------------------------- branches
  /// The branch cooking for this customer and why; null for a store without branches.
  StoreBranch? branch;
  /// Every branch of the brand, for the "Choose a branch" sheet.
  List<StoreBranch> branches = [];
  bool branchesLoading = false;
  /// The customer picked the branch during this visit (the banner says so).
  bool branchPickedNow = false;
  String? _brandId;

  // ---------------------------------------------------------------- cart
  /// The store the cart is for, kept with the cart so it survives a restart.
  StoreModel? cartStore;
  String? cartStoreId;
  /// The brand of the cart's branch: the cart can move between its branches.
  String? cartBrandId;
  final Map<String, int> _cart = {};
  final Map<String, MenuItem> _cartItems = {};

  // ---------------------------------------------------------------- checkout
  double? dropLatitude;
  double? dropLongitude;
  String dropAddress = '';
  String note = '';
  /// The Mobile Money gateway to pay with (MTN MoMo or Orange Money, e.g. 'fapshi').
  /// Customers pay with Mobile Money only: anything that is not one of the
  /// offered gateways (an old 'wallet' choice, nothing yet) reads as the first one.
  String _paymentMethod = '';
  String get paymentMethod {
    final keys = gateways.map((g) => g.gateway).whereType<String>().toList();
    if (keys.contains(_paymentMethod)) return _paymentMethod;
    return keys.isNotEmpty ? keys.first : '';
  }

  set paymentMethod(String method) => _paymentMethod = method;
  StoreQuote? quote;
  bool quoting = false;
  bool placing = false;
  /// How the order is had: delivery, dine_in (eat there) or pickup (collect).
  String way = 'delivery';
  /// Eat there or collect: when they come, and for how many.
  DateTime? arriveAt;
  int guests = 2;

  /// The ways this store offers (delivery first, unless the store turned delivery off).
  List<String> get ways {
    final List<String> w = (cartStore ?? store)?.ways ?? const ['delivery'];
    return w.isEmpty ? const ['pickup'] : w;
  }

  void setWay(String value) {
    if (!ways.contains(value)) return;
    way = value;
    _defaultTime();
    requestQuote();
  }

  /// Eat there or collect: the earliest they can have it ready, rounded up to 5 minutes.
  void _defaultTime() {
    if (way == 'delivery') return;
    final int prep = (cartStore ?? store)?.prepMinutes ?? 20;
    final DateTime earliest = DateTime.now().add(Duration(minutes: prep + 5));
    if (arriveAt != null && arriveAt!.isAfter(earliest)) return;
    arriveAt = DateTime(earliest.year, earliest.month, earliest.day, earliest.hour, (earliest.minute / 5).ceil() * 5);
  }

  void setArriveAt(DateTime value) {
    arriveAt = value;
    requestQuote();
  }

  void setGuests(int value) {
    guests = value.clamp(1, 30);
    update();
  }

  /// "Deliver it instead": with preview, only the fee; otherwise the change, and the delivery fee's payment page when the order was paid.
  Future<({bool ok, double? fee, bool paid, String? payUrl})> deliverInstead(StoreOrderModel o, double lat, double lng, String address, {bool preview = false}) async {
    final Response response = await storeServiceInterface.deliverInstead(o.id, {
      'drop_latitude': lat,
      'drop_longitude': lng,
      'drop_address': address,
      if (preview) 'preview': 1 else 'payment_method': paymentMethod,
    });
    if (response.statusCode == 200 && response.body['data'] is Map) {
      final Map data = response.body['data'];
      if (preview) {
        return (ok: true, fee: double.tryParse('${data['fee']}'), paid: data['paid'] == true, payUrl: null);
      }
      if (data['order'] is Map) order = StoreOrderModel.fromJson(Map<String, dynamic>.from(data['order']));
      update();
      return (ok: true, fee: null, paid: false, payUrl: data['pay_url']?.toString());
    }
    showCustomSnackBar(_firstError(response));
    return (ok: false, fee: null, paid: false, payUrl: null);
  }

  /// "Keep it as it was": drop a change to delivery still waiting for its fee.
  Future<void> keepWay(StoreOrderModel o) async {
    final Response response = await storeServiceInterface.keepWay(o.id);
    if (response.statusCode == 200 && response.body['data'] is Map) {
      order = StoreOrderModel.fromJson(Map<String, dynamic>.from(response.body['data']));
      update();
    } else {
      showCustomSnackBar(_firstError(response));
    }
  }

  // ---------------------------------------------------------------- orders
  List<StoreOrderModel>? orders;
  bool ordersLoading = false;
  StoreOrderModel? order;
  Timer? _poll;
  Timer? _quoteDebounce;
  int _quoteSeq = 0;

  String get serviceLabel {
    final label = Get.find<ConfigController>().config?.storeServiceLabel;
    return (label == null || label.isEmpty) ? 'food_and_shops'.tr : label;
  }

  /// Where the customer is, for searches and distances.
  ({double? lat, double? lng}) get here => _here;

  ({double? lat, double? lng}) get _here {
    final address = Get.find<LocationController>().getUserAddress();
    return (lat: address?.latitude, lng: address?.longitude);
  }

  Future<void> loadStores() async {
    storesLoading = true;
    update();
    final here = _here;
    final Response response = await storeServiceInterface.getStores(latitude: here.lat, longitude: here.lng);
    if (response.statusCode == 200) {
      stores = ((response.body['data']?['stores'] as List?) ?? []).map((e) => StoreModel.fromJson(e)).toList();
    } else {
      stores ??= [];
      ApiChecker.checkApi(response);
    }
    storesLoading = false;
    update();
  }

  SharedPreferences get _prefs => Get.find<SharedPreferences>();
  String _branchKey(String brandId) => 'store_branch_$brandId';

  /// Opens a store. For a brand with branches the server picks the branch
  /// (the customer's usual one if it is open, else the nearest open one) and says why.
  Future<void> openStore(StoreModel selected) async {
    store = selected;
    menu = [];
    branch = null;
    branches = [];
    branchPickedNow = false;
    _brandId = selected.brandId ?? selected.id;
    menuLoading = true;
    update();
    await _loadMenu(_prefs.getString(_branchKey(_brandId!)));
    menuLoading = false;
    update();
  }

  /// Opens a store from its id (a place that is a partner, a search result). False when it is not in the customer's area.
  Future<bool> openStoreById(String id) async {
    if (stores == null) await loadStores();
    final StoreModel? found = (stores ?? []).firstWhereOrNull((s) => s.id == id || s.brandId == id);
    if (found == null) return false;
    openStore(found);
    return true;
  }

  /// Opens a store from its public link ([domain]/f/SLUG). False when it is not in the customer's area.
  Future<bool> openStoreBySlug(String slug) async {
    if (stores == null || !(stores ?? []).any((s) => s.slug == slug)) await loadStores();
    final StoreModel? found = (stores ?? []).firstWhereOrNull((s) => s.slug == slug);
    if (found == null) return false;
    openStore(found);
    return true;
  }

  /// The customer chose a branch: remembered for next time, and the cart follows.
  Future<void> chooseBranch(String branchId) async {
    if (_brandId == null) return;
    await _prefs.setString(_branchKey(_brandId!), branchId);
    branchPickedNow = true;
    menuLoading = true;
    update();
    await _loadMenu(branchId);
    menuLoading = false;
    update();
  }

  /// Branches with their delivery fee to the customer's address, for the sheet.
  Future<void> loadBranchOptions() async {
    if (_brandId == null) return;
    branchesLoading = true;
    update();
    final here = _here;
    final Response response = await storeServiceInterface.getBranches(_brandId!, latitude: here.lat, longitude: here.lng, branchId: branch?.id);
    if (response.statusCode == 200) {
      branches = ((response.body['data']?['branches'] as List?) ?? []).map((e) => StoreBranch.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    branchesLoading = false;
    update();
  }

  Future<void> _loadMenu(String? branchId) async {
    final here = _here;
    final Response response = await storeServiceInterface.getStore(_brandId!, latitude: here.lat, longitude: here.lng, branchId: branchId);
    if (response.statusCode != 200) {
      ApiChecker.checkApi(response);
      return;
    }
    final data = response.body['data'];
    store = StoreModel.fromJson(data['store']);
    branch = data['branch'] is Map ? StoreBranch.fromJson(Map<String, dynamic>.from(data['branch'])) : null;
    branches = ((data['branches'] as List?) ?? []).map((e) => StoreBranch.fromJson(Map<String, dynamic>.from(e))).toList();
    menu = ((data['menu'] as List?) ?? []).map((e) => MenuSection.fromJson(e)).toList();
    _syncCart();
  }

  /// Keeps the cart in step with the menu (prices, sold out). When the branch
  /// changed, the cart moves to it and the customer is told what was dropped.
  void _syncCart() {
    if (cartStoreId == null || store == null || _cart.isEmpty) return;
    final brandId = store!.brandId ?? store!.id;
    final moved = cartStoreId != store!.id;
    if (moved && cartBrandId != brandId) return;
    final fresh = {for (final s in menu) for (final i in s.items) i.id: i};
    final removed = <String>[];
    for (final id in _cart.keys.toList()) {
      final item = fresh[id];
      if (item == null || !item.isAvailable) {
        removed.add(_cartItems[id]?.name ?? item?.name ?? '');
        _cart.remove(id);
        _cartItems.remove(id);
      } else {
        _cartItems[id] = item;
      }
    }
    if (moved) {
      cartStoreId = store!.id;
      quote = null;
    }
    cartStore = store;
    if (_cart.isEmpty) {
      cartStoreId = null;
      cartBrandId = null;
    }
    _saveCart();
    final branchName = store!.branchName ?? store!.name ?? '';
    final parts = [
      if (moved) 'cart_moved_to_branch'.trParams({'branch': branchName}),
      if (removed.isNotEmpty) 'cart_items_removed'.trParams({'items': removed.where((n) => n.isNotEmpty).join(', ')}),
    ];
    if (parts.isNotEmpty) {
      showCustomSnackBar(parts.join(' '), isError: removed.isNotEmpty, seconds: 5);
    }
  }

  /// Why this branch, in words: shown under "Cooking at ...".
  String? get branchReason {
    final b = branch;
    if (b == null) return null;
    final params = {'branch': b.name, 'skipped': b.skipped ?? ''};
    switch (b.reason) {
      case 'preferred':
        return branchPickedNow ? 'branch_reason_picked'.tr : 'branch_reason_usual'.tr;
      case 'preferred_closed':
        return 'branch_reason_preferred_closed'.trParams(params);
      case 'nearest_closed':
        return 'branch_reason_nearest_closed'.trParams(params);
      case 'only_open':
        return 'branch_reason_only_open'.tr;
      case 'all_closed':
        return 'branch_reason_all_closed'.tr;
      case 'no_location':
        return 'branch_reason_no_location'.tr;
      default:
        return 'branch_reason_nearest'.tr;
    }
  }

  // ---------------------------------------------------------------- cart

  int quantityOf(String itemId) => _cart[itemId] ?? 0;
  int get cartCount => _cart.values.fold(0, (a, b) => a + b);
  bool get cartIsEmpty => _cart.isEmpty;
  double get cartSubtotal => _cart.entries.fold(0.0, (sum, e) => sum + (_cartItems[e.key]?.price ?? 0) * e.value);
  List<({MenuItem item, int quantity})> get cartLines =>
      _cart.entries.where((e) => _cartItems[e.key] != null).map((e) => (item: _cartItems[e.key]!, quantity: e.value)).toList();

  /// Adding from another store asks first: one store per order.
  bool needsCartSwitch(String storeId) => cartStoreId != null && cartStoreId != storeId && _cart.isNotEmpty;

  void addItem(MenuItem item) {
    if (store == null || !item.isAvailable) return;
    if (cartStoreId != store!.id) {
      _cart.clear();
      _cartItems.clear();
      cartStoreId = store!.id;
      cartBrandId = store!.brandId ?? store!.id;
    }
    cartStore = store;
    _cart[item.id] = (_cart[item.id] ?? 0) + 1;
    _cartItems[item.id] = item;
    quote = null;
    _saveCart();
    update();
  }

  // ---------------------------------------------------------------- saved cart

  static const String _cartKey = 'store_cart';

  @override
  void onInit() {
    super.onInit();
    _restoreCart();
  }

  /// The cart outlives the app: it is saved on the phone at every change.
  void _saveCart() {
    if (_cart.isEmpty || cartStoreId == null) {
      _prefs.remove(_cartKey);
      CartReminder.cancel();
      return;
    }
    _prefs.setString(_cartKey, jsonEncode({
      'store_id': cartStoreId,
      'brand_id': cartBrandId,
      'store': cartStore?.toJson(),
      'lines': [for (final e in _cart.entries) if (_cartItems[e.key] != null) {'quantity': e.value, 'item': _cartItems[e.key]!.toJson()}],
      'saved_at': DateTime.now().toIso8601String(),
    }));
    CartReminder.schedule(storeName: cartStore?.name ?? '', count: cartCount, subtotal: cartSubtotal);
  }

  void _restoreCart() {
    try {
      final raw = _prefs.getString(_cartKey);
      if (raw == null) return;
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      // A cart forgotten for days is not worth bringing back.
      final saved = DateTime.tryParse('${data['saved_at']}');
      if (saved == null || DateTime.now().difference(saved).inDays >= 3) {
        _prefs.remove(_cartKey);
        return;
      }
      cartStoreId = data['store_id']?.toString();
      cartBrandId = data['brand_id']?.toString();
      cartStore = data['store'] is Map ? StoreModel.fromJson(Map<String, dynamic>.from(data['store'])) : null;
      for (final line in (data['lines'] as List? ?? [])) {
        final item = MenuItem.fromJson(Map<String, dynamic>.from(line['item']));
        _cart[item.id] = int.tryParse('${line['quantity']}') ?? 1;
        _cartItems[item.id] = item;
      }
      if (_cart.isEmpty) cartStoreId = null;
    } catch (_) {
      _prefs.remove(_cartKey);
    }
  }

  /// Opens the store the cart is for, on the branch it was for (from the
  /// activity sheet or the reminder).
  Future<void> openCartStore() async {
    final saved = cartStore;
    if (saved == null) return;
    if (saved.brandId != null && cartStoreId != null) {
      await _prefs.setString(_branchKey(saved.brandId!), cartStoreId!);
    }
    await openStore(saved);
  }

  void removeItem(String itemId) {
    final current = _cart[itemId] ?? 0;
    if (current <= 1) {
      _cart.remove(itemId);
      _cartItems.remove(itemId);
    } else {
      _cart[itemId] = current - 1;
    }
    if (_cart.isEmpty) {
      cartStoreId = null;
      cartBrandId = null;
    }
    quote = null;
    _saveCart();
    update();
  }

  void clearCart() {
    _cart.clear();
    _cartItems.clear();
    cartStoreId = null;
    cartBrandId = null;
    cartStore = null;
    quote = null;
    note = '';
    _saveCart();
    update();
  }

  // ---------------------------------------------------------------- checkout

  void prepareCheckout() {
    if (!ways.contains(way)) way = ways.first;
    _defaultTime();
    if (dropLatitude == null) {
      final address = Get.find<LocationController>().getUserAddress();
      if (address?.latitude != null) {
        dropLatitude = address!.latitude;
        dropLongitude = address.longitude;
        dropAddress = address.address ?? '';
      }
    }
    if (Get.find<PaymentController>().paymentGateways?.isEmpty ?? true) {
      Get.find<PaymentController>().getPaymentGetWayList();
    }
    requestQuote();
  }

  List<PaymentGateways> get gateways => Get.find<PaymentController>().paymentGateways ?? [];
  double? get walletBalance => Get.find<ProfileController>().profileModel?.data?.wallet?.walletBalance;

  void setDrop(double latitude, double longitude, String address) {
    dropLatitude = latitude;
    dropLongitude = longitude;
    dropAddress = address;
    requestQuote();
  }

  void setPaymentMethod(String method) {
    paymentMethod = method;
    update();
  }

  Map<String, dynamic> _cartBody() => {
        'store_id': cartStoreId,
        'items': _cart.entries.map((e) => {'item_id': e.key, 'quantity': e.value}).toList(),
        if (way == 'delivery') ...{'drop_latitude': dropLatitude, 'drop_longitude': dropLongitude} else ...{
          'fulfilment': way,
          if (arriveAt != null) 'arrive_at': arriveAt!.toIso8601String(),
          if (way == 'dine_in') 'guests': guests,
        },
      };

  /// For the quantity steppers: one quote once the taps stop, not one per tap.
  /// The checkout shows "quoting" (and holds Place order) meanwhile.
  void requestQuoteSoon() {
    _quoteDebounce?.cancel();
    quoting = true;
    update();
    _quoteDebounce = Timer(const Duration(milliseconds: 600), requestQuote);
  }

  Future<void> requestQuote() async {
    _quoteDebounce?.cancel();
    if (cartIsEmpty || (way == 'delivery' && dropLatitude == null)) {
      quoting = false;
      update();
      return;
    }
    quoting = true;
    update();
    final int seq = ++_quoteSeq;
    final Response response = await storeServiceInterface.quote(_cartBody());
    if (seq != _quoteSeq) return; // a newer quote is on its way
    if (response.statusCode == 200) {
      quote = StoreQuote.fromJson(response.body['data']);
    } else {
      quote = StoreQuote(ok: false, problems: [_firstError(response)]);
    }
    quoting = false;
    update();
  }

  /// Sends the order to the restaurant. Nothing is paid yet: the customer pays
  /// once the restaurant confirms (an older backend may still return a pay URL).
  Future<({StoreOrderModel? order, String? payUrl})> placeOrder() async {
    placing = true;
    update();
    final profile = Get.find<ProfileController>().profileModel?.data;
    final Response response = await storeServiceInterface.placeOrder({
      ..._cartBody(),
      if (way == 'delivery') 'drop_address': dropAddress,
      'receiver_name': '${profile?.firstName ?? ''} ${profile?.lastName ?? ''}'.trim(),
      'receiver_phone': profile?.phone ?? '',
      if (note.trim().isNotEmpty) 'note': note.trim(),
      'payment_method': paymentMethod,
    });
    placing = false;
    if (response.statusCode == 200) {
      final placed = StoreOrderModel.fromJson(response.body['data']['order']);
      final payUrl = response.body['data']['pay_url']?.toString();
      clearCart();
      order = placed;
      if (paymentMethod == 'wallet') {
        Get.find<ProfileController>().getProfileInfo();
      }
      update();
      return (order: placed, payUrl: payUrl);
    }
    showCustomSnackBar(_firstError(response));
    update();
    requestQuote();
    return (order: null, payUrl: null);
  }

  bool paying = false;

  /// Pays an order the restaurant confirmed. Wallet: paid now. Gateway: the
  /// returned URL opens in the payment screen.
  Future<({bool ok, String? payUrl})> payConfirmed(StoreOrderModel o) async {
    paying = true;
    update();
    final Response response = await storeServiceInterface.payOrder(o.id, paymentMethod);
    paying = false;
    if (response.statusCode == 200 && response.body['data'] is Map) {
      final data = response.body['data'];
      if (data['order'] is Map) order = StoreOrderModel.fromJson(Map<String, dynamic>.from(data['order']));
      if (paymentMethod == 'wallet') Get.find<ProfileController>().getProfileInfo();
      update();
      return (ok: true, payUrl: data['pay_url']?.toString());
    }
    update();
    showCustomSnackBar(_firstError(response));
    loadOrder(o.id);
    return (ok: false, payUrl: null);
  }

  /// The customer's answer to the restaurant's suggested changes.
  Future<bool> answerChanges(String orderId, bool accept) async {
    final Response response = await storeServiceInterface.answerChanges(orderId, accept);
    if (response.statusCode == 200 && response.body['data'] is Map) {
      order = StoreOrderModel.fromJson(Map<String, dynamic>.from(response.body['data']));
      update();
      return true;
    }
    showCustomSnackBar(_firstError(response));
    loadOrder(orderId);
    return false;
  }

  /// Opened again from the order screen when a gateway payment did not finish.
  String payUrlFor(StoreOrderModel unpaid, String gateway) =>
      '${AppConstants.baseUrl}${AppConstants.storeOrders}/${unpaid.id}/pay?payment_method=$gateway';

  // ---------------------------------------------------------------- orders

  /// Delivered orders not rated yet: the red count on the Home tile.
  int toRate = 0;

  Future<void> loadAttention() async {
    final Response response = await storeServiceInterface.getAttention();
    if (response.statusCode == 200 && response.body['data'] is Map) {
      toRate = int.tryParse('${response.body['data']['to_rate']}') ?? 0;
      update();
    }
  }

  Future<void> loadOrders() async {
    ordersLoading = true;
    update();
    final Response response = await storeServiceInterface.getOrders();
    if (response.statusCode == 200) {
      orders = ((response.body['data'] as List?) ?? []).map((e) => StoreOrderModel.fromJson(e)).toList();
    } else {
      orders ??= [];
      ApiChecker.checkApi(response);
    }
    ordersLoading = false;
    update();
  }

  Future<StoreOrderModel?> loadOrder(String orderId) async {
    final Response response = await storeServiceInterface.getOrder(orderId);
    if (response.statusCode == 200) {
      order = StoreOrderModel.fromJson(response.body['data']);
      update();
    }
    return order;
  }

  /// Refreshes the open order every 10 s while it is in progress.
  void watchOrder(String orderId) {
    _poll?.cancel();
    loadOrder(orderId);
    _poll = Timer.periodic(const Duration(seconds: 10), (_) async {
      // Hidden: the order's pushes refresh it, and the next tick after resume does.
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
      final current = await loadOrder(orderId);
      if (current != null && !current.isActive && current.status != StoreOrderModel.awaitingPayment) {
        _poll?.cancel();
      }
    });
  }

  void stopWatching() => _poll?.cancel();

  Future<bool> cancelOrder(String orderId) async {
    final Response response = await storeServiceInterface.cancelOrder(orderId);
    if (response.statusCode == 200) {
      order = StoreOrderModel.fromJson(response.body['data']);
      Get.find<ProfileController>().getProfileInfo();
      update();
      return true;
    }
    showCustomSnackBar(_firstError(response));
    return false;
  }

  /// Whether a trip is the delivery of one of this customer's food orders.
  bool isStoreOrderTrip(String? tripId) =>
      tripId != null && (order?.tripRequestId == tripId || (orders ?? []).any((o) => o.tripRequestId == tripId));

  // ---------------------------------------------------------------- rating

  bool reviewing = false;
  /// Orders whose rating sheet already opened by itself this session, so it
  /// asks once and then waits for the customer to tap "Rate".
  final Set<String> _ratingPrompted = {};

  bool shouldPromptRating(StoreOrderModel o) => o.canReview && _ratingPrompted.add(o.id);

  Future<bool> submitReview(String orderId, {required int storeRating, String? storeComment, int? riderRating, String? riderComment}) async {
    reviewing = true;
    update();
    final Response response = await storeServiceInterface.reviewOrder(orderId, {
      'store_rating': storeRating,
      if (storeComment != null && storeComment.trim().isNotEmpty) 'store_comment': storeComment.trim(),
      if (riderRating != null) 'rider_rating': riderRating,
      if (riderComment != null && riderComment.trim().isNotEmpty) 'rider_comment': riderComment.trim(),
    });
    reviewing = false;
    if (response.statusCode == 200 && response.body['data'] is Map) {
      order = StoreOrderModel.fromJson(response.body['data']);
      update();
      return true;
    }
    update();
    showCustomSnackBar(_firstError(response));
    return false;
  }

  String _firstError(Response response) {
    final body = response.body;
    if (body is Map) {
      final errors = body['errors'];
      if (errors is List && errors.isNotEmpty && errors.first is Map) return errors.first['message'].toString();
      if (errors is Map && errors.isNotEmpty) return (errors.values.first is List ? errors.values.first.first : errors.values.first).toString();
      if (body['message'] != null) return body['message'].toString();
    }
    return 'something_went_wrong'.tr;
  }

  @override
  void onClose() {
    _poll?.cancel();
    _quoteDebounce?.cancel();
    super.onClose();
  }
}
