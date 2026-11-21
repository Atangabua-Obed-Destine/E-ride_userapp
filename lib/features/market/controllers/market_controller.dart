import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/domain/services/market_service_interface.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// E-Ride Market: browsing, an item, a shop, the rider's own shop and items,
/// follows, blocks, reports, and the link that brought a new rider in.
class MarketController extends GetxController implements GetxService {
  final MarketServiceInterface marketServiceInterface;
  MarketController({required this.marketServiceInterface});

  MarketServiceInterface get _service => marketServiceInterface;

  static const String _safetySeenKey = 'market_safety_seen';
  static const String _pendingLinkKey = 'market_pending_link';

  // ---------------------------------------------------------------- meta

  MarketMeta? meta;
  bool metaLoading = false;

  Future<MarketMeta?>? _metaCall;

  /// [force]: always ends with a fetch that started after this call (a push may have just changed the counts).
  Future<MarketMeta?> loadMeta({bool force = false}) async {
    if (meta != null && !force) return meta;
    while (_metaCall != null) {
      await _metaCall;
      if (!force) return meta;
    }
    _metaCall = _fetchMeta();
    try {
      return await _metaCall;
    } finally {
      _metaCall = null;
    }
  }

  Future<MarketMeta?> _fetchMeta() async {
    metaLoading = true;
    Response response = await _service.getMeta();
    metaLoading = false;
    if (response.statusCode == 200) {
      meta = MarketMeta.fromJson(Map<String, dynamic>.from(response.body['data']));
    }
    update();
    return meta;
  }

  // ---------------------------------------------------------------- feed

  String? category;
  String query = '';
  bool followingOnly = false;
  /// "retail" (everything) or "wholesale" (items with a wholesale price).
  String kind = 'retail';
  bool verifiedOnly = false;
  bool auctionsOnly = false;
  /// null (everyone) | private | shop
  String? sellerKind;
  /// Services: one kind (hair_beauty, repairs...), and only providers who come to the client.
  String? serviceKind;
  bool comesToMe = false;
  List<MarketItem> items = [];
  List<MarketShop> followedShops = [];
  int total = 0;
  int _page = 1;
  bool loading = false;
  bool loadingMore = false;
  bool failed = false;
  int _seq = 0;

  Map<String, dynamic> _feedQuery() {
    final location = Get.find<LocationController>();
    final near = location.fromAddress ?? location.getUserAddress();
    return {
      if (category != null) 'category': category,
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (followingOnly) 'following': 1,
      if (kind == 'wholesale') 'kind': 'wholesale',
      if (verifiedOnly) 'verified': 1,
      if (auctionsOnly) 'sale': 'auction',
      if (sellerKind != null) 'seller': sellerKind,
      if (category == 'services' && serviceKind != null) 'service_kind': serviceKind,
      if (category == 'services' && comesToMe) 'comes': 1,
      if (near?.latitude != null && near?.longitude != null && near!.latitude != 0) ...{'lat': near.latitude, 'lng': near.longitude},
    };
  }

  Future<void> loadFeed() async {
    final int seq = ++_seq;
    loading = true;
    failed = false;
    _page = 1;
    update();
    Response response = await _service.getFeed(_feedQuery(), 1);
    if (seq != _seq) return;
    loading = false;
    if (response.statusCode == 200) {
      final data = response.body['data'];
      items = [for (final j in data['items'] as List) MarketItem.fromJson(Map<String, dynamic>.from(j))];
      followedShops = [for (final j in (data['following'] as List? ?? const [])) MarketShop.fromJson(Map<String, dynamic>.from(j))];
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
    Response response = await _service.getFeed(_feedQuery(), _page + 1);
    loadingMore = false;
    if (response.statusCode == 200) {
      _page++;
      items.addAll([for (final j in response.body['data']['items'] as List) MarketItem.fromJson(Map<String, dynamic>.from(j))]);
    }
    update();
  }

  /// A category (null: all). Other filters stay as they are.
  void setCategory(String? value) {
    category = value;
    if (value != 'services') {
      serviceKind = null;
      comesToMe = false;
    }
    loadFeed();
  }

  void setServiceKind(String? value) {
    serviceKind = value;
    loadFeed();
  }

  void setComesToMe(bool value) {
    comesToMe = value;
    loadFeed();
  }

  void setFollowingOnly(bool value) {
    followingOnly = value;
    loadFeed();
  }

  void setKind(String value) {
    kind = value;
    loadFeed();
  }

  void setVerifiedOnly(bool value) {
    verifiedOnly = value;
    loadFeed();
  }

  /// The filters behind the "Filters" button, set together (one reload).
  void applyFilters({required bool wholesale, required bool verified, required bool following, bool auctions = false, String? seller}) {
    kind = wholesale ? 'wholesale' : 'retail';
    verifiedOnly = verified;
    followingOnly = following;
    auctionsOnly = auctions;
    sellerKind = seller;
    loadFeed();
  }

  void setAuctionsOnly(bool value) {
    auctionsOnly = value;
    loadFeed();
  }

  void setSellerKind(String? value) {
    sellerKind = value;
    loadFeed();
  }

  /// How many of the "Filters" button filters are on.
  int get extraFilters =>
      (kind == 'wholesale' ? 1 : 0) + (verifiedOnly ? 1 : 0) + (followingOnly ? 1 : 0) + (auctionsOnly ? 1 : 0) + (sellerKind != null ? 1 : 0);

  /// Anything narrowing the list: a category, a search, or a filter.
  bool get anyFilter => extraFilters > 0 || category != null || query.trim().isNotEmpty;

  /// Back to everything.
  void clearFilters() {
    _resetFilters();
    loadFeed();
  }

  /// Opening the Market starts from everything.
  void resetForEntry() => _resetFilters();

  void _resetFilters() {
    category = null;
    query = '';
    kind = 'retail';
    verifiedOnly = false;
    followingOnly = false;
    auctionsOnly = false;
    sellerKind = null;
    serviceKind = null;
    comesToMe = false;
  }

  void setQuery(String value) {
    query = value;
    loadFeed();
  }

  // ---------------------------------------------------------------- an item, a shop

  MarketItem? item;
  bool itemLoading = false;
  String? itemError;
  final Map<String, MarketItem> _items = {};

  /// The full item, kept per code so screens further back keep theirs.
  MarketItem? itemFor(String code) => _items[code];

  Future<MarketItem?> loadItem(String code) async {
    itemLoading = true;
    itemError = null;
    if (item?.code != code) item = null;
    update();
    Response response = await _service.getItem(code);
    itemLoading = false;
    if (response.statusCode == 200) {
      item = MarketItem.fromJson(Map<String, dynamic>.from(response.body['data']));
      _items[code] = item!;
    } else {
      _items.remove(code);
      itemError = _message(response) ?? 'market_item_gone'.tr;
    }
    update();
    return item;
  }

  MarketShop? shop;
  List<MarketItem> shopItems = [];
  bool shopLoading = false;
  String? shopError;
  final Map<String, MarketShop> _shops = {};
  final Map<String, List<MarketItem>> _shopItems = {};

  MarketShop? shopFor(String slug) => _shops[slug];
  List<MarketItem> shopItemsFor(String slug) => _shopItems[slug] ?? const [];

  Future<void> loadShop(String slug) async {
    shopLoading = true;
    shopError = null;
    if (shop?.slug != slug) {
      shop = null;
      shopItems = [];
    }
    update();
    final results = await Future.wait([_service.getShop(slug), _service.getFeed({'shop': slug}, 1)]);
    shopLoading = false;
    final Response s = results[0];
    final Response f = results[1];
    if (s.statusCode == 200) {
      shop = MarketShop.fromJson(Map<String, dynamic>.from(s.body['data']));
      if (f.statusCode == 200) {
        shopItems = [for (final j in f.body['data']['items'] as List) MarketItem.fromJson(Map<String, dynamic>.from(j))];
      }
      _shops[slug] = shop!;
      _shopItems[slug] = shopItems;
    } else {
      _shops.remove(slug);
      shopError = _message(s) ?? 'market_shop_gone'.tr;
    }
    update();
  }

  /// Follows (optionally choosing new-post alerts) or unfollows. Returns whether it worked.
  Future<bool> follow(String slug, bool on, {bool? notify}) async {
    Response response = await _service.follow(slug, on, notify);
    if (response.statusCode == 200) {
      // Every open screen of this shop or its items shows the new state.
      if (_shops.containsKey(slug)) await loadShop(slug);
      for (final code in _items.values.where((i) => i.shop?.slug == slug).map((i) => i.code).toList()) {
        await loadItem(code);
      }
      if (on) loadFeed();
      return true;
    }
    ApiChecker.checkApi(response);
    return false;
  }

  Future<bool> block(String slug, bool on) async {
    Response response = await _service.block(slug, on);
    if (response.statusCode == 200) {
      showCustomSnackBar((on ? 'market_shop_blocked' : 'market_shop_unblocked').tr, isError: false);
      loadFeed();
      return true;
    }
    ApiChecker.checkApi(response);
    return false;
  }

  bool reporting = false;

  /// Reports an item ([code]) or a whole shop ([slug]).
  Future<bool> report({String? code, String? slug, required String reason, String? note, bool block = false}) async {
    reporting = true;
    update();
    Response response = code != null
        ? await _service.reportItem(code, reason, note, block)
        : await _service.reportShop(slug!, reason, note, block);
    reporting = false;
    update();
    if (response.statusCode == 200) {
      showCustomSnackBar('market_report_sent'.tr, isError: false);
      if (block) loadFeed();
      return true;
    }
    ApiChecker.checkApi(response);
    return false;
  }

  // ---------------------------------------------------------------- my shop

  MarketShop? myShop;
  List<MarketItem> myItems = [];
  String? cannotOpenReason;
  bool myLoading = false;
  bool saving = false;

  Future<void> loadMyShop() async {
    myLoading = true;
    update();
    Response response = await _service.getMyShop();
    myLoading = false;
    if (response.statusCode == 200) {
      final data = response.body['data'];
      myShop = data['shop'] is Map ? MarketShop.fromJson(Map<String, dynamic>.from(data['shop'])) : null;
      myItems = [for (final j in (data['items'] as List? ?? const [])) MarketItem.fromJson(Map<String, dynamic>.from(j))];
      cannotOpenReason = '${data['cannot_open_reason'] ?? ''}'.trim().isEmpty ? null : '${data['cannot_open_reason']}';
    }
    update();
  }

  Future<MarketShop?> saveShop(Map<String, String> fields, XFile? logo, {XFile? shopfront}) async {
    saving = true;
    update();
    Response response = await _service.saveShop(fields, logo, shopfront: shopfront);
    saving = false;
    if (response.statusCode == 200) {
      myShop = MarketShop.fromJson(Map<String, dynamic>.from(response.body['data']));
      update();
      // my_shop changed: the Sell / My items / My shop button follows at once.
      await loadMeta(force: true);
      return myShop;
    }
    update();
    ApiChecker.checkApi(response);
    return null;
  }

  /// "Sell something I own": the person's private seller profile (made once, from their name).
  Future<MarketShop?> openPrivate() async {
    if (myShop != null) return myShop;
    return saveShop({'kind': 'private', 'agree_rules': '1'}, null);
  }

  /// A private seller turns into a shop: a name and the shop details.
  Future<MarketShop?> turnIntoShop(Map<String, String> fields, XFile? logo, {XFile? shopfront}) => saveShop({...fields, 'kind': 'shop'}, logo, shopfront: shopfront);

  // ---------------------------------------------------------------- markets (Bamenda Main Market...)
  List<MarketVenue>? venues;

  Future<List<MarketVenue>> loadVenues({bool force = false}) async {
    if (venues != null && !force) return venues!;
    final address = Get.find<LocationController>().getUserAddress();
    final Response response = await _service.getVenues(lat: address?.latitude, lng: address?.longitude);
    if (response.statusCode == 200 && response.body['data'] is Map) {
      venues = [for (final v in (response.body['data']['venues'] as List? ?? [])) if (v is Map) MarketVenue.fromJson(Map<String, dynamic>.from(v))];
      update();
    }
    return venues ?? const [];
  }

  // ---------------------------------------------------------------- auctions

  final Map<String, List<MarketBid>> _bids = {};
  bool bidding = false;

  List<MarketBid> bidsFor(String code) => _bids[code] ?? const [];

  Future<void> loadBids(String code) async {
    Response response = await _service.getBids(code);
    if (response.statusCode == 200) {
      _bids[code] = [for (final j in response.body['data']['bids'] as List) MarketBid.fromJson(Map<String, dynamic>.from(j))];
      update();
    }
  }

  /// Places a bid; the item comes back with the new state. True when it went through.
  Future<bool> bid(String code, double amount) async {
    bidding = true;
    update();
    Response response = await _service.bid(code, amount);
    bidding = false;
    if (response.statusCode == 200) {
      _keepItem(response);
      await loadBids(code);
      update();
      return true;
    }
    update();
    ApiChecker.checkApi(response);
    return false;
  }

  Future<bool> auctionOfferNext(String code) async {
    Response response = await _service.auctionOfferNext(code);
    if (response.statusCode == 200) {
      _keepItem(response);
      showCustomSnackBar('market_offer_sent'.tr, isError: false);
      update();
      return true;
    }
    ApiChecker.checkApi(response);
    return false;
  }

  /// The next bidder answers the seller's offer. Returns the new order's id when accepted.
  Future<String?> auctionAnswer(String code, bool accept) async {
    Response response = await _service.auctionAnswer(code, accept);
    if (response.statusCode == 200) {
      await loadItem(code);
      final id = response.body['data']['order_id'];
      return id == null ? null : '$id';
    }
    ApiChecker.checkApi(response);
    return null;
  }

  Future<bool> auctionRelist(String code, int days) async {
    Response response = await _service.auctionRelist(code, days);
    if (response.statusCode == 200) {
      _keepItem(response);
      _bids.remove(code);
      showCustomSnackBar('market_relisted'.tr, isError: false);
      loadMyShop();
      update();
      return true;
    }
    ApiChecker.checkApi(response);
    return false;
  }

  void _keepItem(Response response) {
    final it = MarketItem.fromJson(Map<String, dynamic>.from(response.body['data']));
    _items[it.code] = it;
    if (item?.code == it.code) item = it;
  }

  Future<void> requestVerification() async {
    Response response = await _service.requestVerification();
    if (response.statusCode == 200) {
      myShop = MarketShop.fromJson(Map<String, dynamic>.from(response.body['data']));
      showCustomSnackBar('market_verification_asked'.tr, isError: false);
      update();
    } else {
      ApiChecker.checkApi(response);
    }
  }

  Future<MarketItem?> saveItem({String? code, required Map<String, String> fields, List<XFile> photos = const [],
      List<XFile> previews = const [], List<int> removePhotoIds = const []}) async {
    saving = true;
    update();
    Response response = code == null
        ? await _service.createItem(fields, photos, previews)
        : await _service.updateItem(code, fields, photos, removePhotoIds, previews);
    saving = false;
    update();
    if (response.statusCode == 200) {
      final saved = MarketItem.fromJson(Map<String, dynamic>.from(response.body['data']));
      _items[saved.code] = saved;
      if (item?.code == saved.code) item = saved;
      loadMyShop();
      // A new item shows in the feed when the seller goes back to it.
      if (code == null) loadFeed();
      return saved;
    }
    ApiChecker.checkApi(response);
    return null;
  }

  Future<void> setSoldOut(String code, bool soldOut) async {
    Response response = await _service.setSoldOut(code, soldOut);
    if (response.statusCode == 200) {
      item = MarketItem.fromJson(Map<String, dynamic>.from(response.body['data']));
      _items[code] = item!;
      await loadMyShop();
    } else {
      ApiChecker.checkApi(response);
    }
  }

  Future<bool> deleteItem(String code) async {
    Response response = await _service.deleteItem(code);
    if (response.statusCode == 200) {
      await loadMyShop();
      return true;
    }
    ApiChecker.checkApi(response);
    return false;
  }

  // ---------------------------------------------------------------- safety and links

  /// The safety rules, before the first chat (always again for a digital product).
  Future<bool> safetySeen() async => (await SharedPreferences.getInstance()).getBool(_safetySeenKey) ?? false;

  Future<void> markSafetySeen() async => (await SharedPreferences.getInstance()).setBool(_safetySeenKey, true);

  /// A shared link to open once the rider is signed in: `i:CODE` or `s:SLUG`.
  Future<void> setPendingLink(String target) async => (await SharedPreferences.getInstance()).setString(_pendingLinkKey, target);

  Future<String?> takePendingLink() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_pendingLinkKey);
    await prefs.remove(_pendingLinkKey);
    return value;
  }

  Future<void> claimReferral(String target) async {
    try {
      await _service.claimReferral(target);
    } catch (_) {}
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
