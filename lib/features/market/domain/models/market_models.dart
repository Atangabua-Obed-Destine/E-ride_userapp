// E-Ride Market: shops anyone can open, items (physical or digital), and the
// buyer-seller chat. Buyers and sellers arrange payment between them: E-Ride
// never holds money here. Phone numbers never come through, except the buyer's
// for the seller once the buyer asked for delivery (to book the parcel).

String? _text(dynamic v) => v == null || '$v'.trim().isEmpty ? null : '$v'.trim();
double? _num(dynamic v) => v == null ? null : double.tryParse('$v');
int _int(dynamic v) => int.tryParse('$v') ?? 0;
bool _bool(dynamic v) => v == true || '$v' == '1' || '$v' == 'true';
List<String> _strings(dynamic v) => [for (final x in (v is List ? v : const [])) '$x'];
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

class MarketMeta {
  final bool enabled;
  final List<String> categories;
  final List<String> digitalKinds;
  final bool digitalAllowed;
  final List<String> reportReasons;
  final int maxPhotos;
  final int maxPreviews;
  final int itemsPerShop;
  /// Who pays the rest of a delivery fare: buyer | seller | seller_chooses.
  final String deliveryPayer;
  final MarketShop? myShop;
  final String? cannotOpenReason;
  final int unread;
  /// Orders: requests waiting for me as a seller, my orders that need me as a buyer, my open orders.
  final int sellingNew;
  final int buyingAction;
  final int buyingOpen;
  final int answerMinutes;
  final int agreeMinutes;
  final List<String> declineReasons;
  final List<String> reviewTags;
  /// Items a private seller can have for sale at once.
  final int privateMaxItems;
  final MarketAuctionRules auctionRules;
  final MarketServiceRules serviceRules;
  /// Bookings waiting for me: as a provider (requests), as a client (a time or a price to answer).
  final int providerRequests;
  final int clientAction;
  final int clientUpcoming;

  /// What needs me in the Market: unread chats, orders to answer (as a seller or a buyer), bookings to answer.
  int get attention => unread + sellingNew + buyingAction + providerRequests + clientAction;

  const MarketMeta({
    this.enabled = false, this.categories = const [], this.digitalKinds = const [], this.digitalAllowed = true,
    this.reportReasons = const [], this.maxPhotos = 6, this.maxPreviews = 3, this.itemsPerShop = 50,
    this.deliveryPayer = 'buyer', this.myShop, this.cannotOpenReason, this.unread = 0,
    this.sellingNew = 0, this.buyingAction = 0, this.buyingOpen = 0, this.answerMinutes = 120, this.agreeMinutes = 60,
    this.declineReasons = const ['sold_out', 'no_delivery_area', 'price_changed', 'closed_today', 'other'],
    this.reviewTags = const ['as_described', 'fast_reply', 'good_price', 'well_packed', 'problem'],
    this.privateMaxItems = 10, this.auctionRules = const MarketAuctionRules(), this.serviceRules = const MarketServiceRules(),
    this.providerRequests = 0, this.clientAction = 0, this.clientUpcoming = 0,
  });

  factory MarketMeta.fromJson(Map<String, dynamic> j) {
    final orders = j['orders'] is Map ? Map<String, dynamic>.from(j['orders']) : const <String, dynamic>{};
    final rules = j['order_rules'] is Map ? Map<String, dynamic>.from(j['order_rules']) : const <String, dynamic>{};
    return MarketMeta(
        enabled: _bool(j['enabled']),
        categories: [for (final c in (j['categories'] as List? ?? const [])) '$c'],
        digitalKinds: [for (final c in (j['digital_kinds'] as List? ?? const [])) '$c'],
        digitalAllowed: _bool(j['digital_allowed']),
        reportReasons: [for (final c in (j['report_reasons'] as List? ?? const [])) '$c'],
        maxPhotos: _int(j['max_photos']) == 0 ? 6 : _int(j['max_photos']),
        maxPreviews: _int(j['max_previews']) == 0 ? 3 : _int(j['max_previews']),
        itemsPerShop: _int(j['items_per_shop']),
        deliveryPayer: _text(j['delivery_payer']) ?? 'buyer',
        myShop: j['my_shop'] is Map ? MarketShop.fromJson(Map<String, dynamic>.from(j['my_shop'])) : null,
        cannotOpenReason: _text(j['cannot_open_reason']),
        unread: _int(j['unread']),
        sellingNew: _int(orders['selling_new']),
        buyingAction: _int(orders['buying_action']),
        buyingOpen: _int(orders['buying_open']),
        answerMinutes: _int(rules['answer_minutes']) == 0 ? 120 : _int(rules['answer_minutes']),
        agreeMinutes: _int(rules['agree_minutes']) == 0 ? 60 : _int(rules['agree_minutes']),
        declineReasons: j['decline_reasons'] is List ? _strings(j['decline_reasons']) : const ['sold_out', 'no_delivery_area', 'price_changed', 'closed_today', 'other'],
        reviewTags: j['review_tags'] is List ? _strings(j['review_tags']) : const ['as_described', 'fast_reply', 'good_price', 'well_packed', 'problem'],
        privateMaxItems: _int(j['private_max_items']) == 0 ? 10 : _int(j['private_max_items']),
        auctionRules: j['auctions'] is Map ? MarketAuctionRules.fromJson(Map<String, dynamic>.from(j['auctions'])) : const MarketAuctionRules(),
        serviceRules: j['services'] is Map ? MarketServiceRules.fromJson(Map<String, dynamic>.from(j['services'])) : const MarketServiceRules(),
        providerRequests: j['bookings'] is Map ? _int(j['bookings']['provider_requests']) : 0,
        clientAction: j['bookings'] is Map ? _int(j['bookings']['client_action']) : 0,
        clientUpcoming: j['bookings'] is Map ? _int(j['bookings']['client_upcoming']) : 0,
      );
  }
}

class MarketShopStats {
  final int visits;
  final int chats;
  final int newUsers;
  final int followers;
  const MarketShopStats({this.visits = 0, this.chats = 0, this.newUsers = 0, this.followers = 0});

  factory MarketShopStats.fromJson(Map<String, dynamic> j) =>
      MarketShopStats(visits: _int(j['visits']), chats: _int(j['chats']), newUsers: _int(j['new_users']), followers: _int(j['followers']));
}

class MarketShop {
  final String id;
  final String slug;
  final String name;
  /// shop | private (a person selling things they own)
  final String kind;
  /// A shop's place for buyers (pin, address, how to find it); null for private sellers or when hidden.
  final MarketPoint? map;
  final String? mapNote;
  // The owner's view.
  final bool mapVisible;
  final String? addressNote;
  // Services
  final bool takingBookings;
  final int bookingsCompleted;
  /// "mon": ["08:00","18:00"] or null (closed)
  final Map<String, List<String>?> serviceHours;
  final int serviceCapacity;
  final int serviceNoticeMinutes;
  final int serviceAheadDays;
  final bool serviceAutoConfirm;
  final String? serviceAreas;
  final double? travelFee;
  final bool hasServices;
  final String? category;
  /// Everything the shop sells (the first is [category]).
  final List<String> categories;
  final String? about;
  final String? area;
  final String? logo;
  final bool verified;
  final bool isNew;
  final bool live;
  final String? since;
  final String link;
  final int itemsCount;
  final bool mine;
  // The owner's view only.
  final String? status;
  final String? closedReason;
  final bool verificationRequested;
  final double? pickupLat;
  final double? pickupLng;
  final String? pickupAddress;
  final MarketShopStats? stats;
  // The viewer's relation to it.
  final bool following;
  /// Following with new-post alerts on.
  final bool followNotify;
  final bool blocked;
  // Orders.
  final bool takingOrders;
  /// The owner's switch (takingOrders is false also when the shop is closed).
  final bool takingOrdersSwitch;
  final List<String> fulfilment;
  final List<String> payMethods;
  final String? openFrom;
  final String? openTo;
  final bool openNow;
  final double? minOrder;
  final double? rating;
  final int ratingCount;
  final int ordersCompleted;
  final int? replyMinutes;
  final int todayOrders;
  final double todayConfirmed;
  /// In one of E-Ride's markets: which, the shed, the shopfront. Null when not in one.
  final MarketShopVenue? venue;
  /// What the shop sells, in buyers' words ("school shoes", "bags").
  final List<String> sells;
  /// From a market search: the shop's items that matched (why it is listed).
  final List<String> matchedItems;

  const MarketShop({
    required this.id, required this.slug, required this.name, this.kind = 'shop', this.map, this.mapNote, this.mapVisible = true, this.addressNote,
    this.takingBookings = true, this.bookingsCompleted = 0, this.serviceHours = const {}, this.serviceCapacity = 1, this.serviceNoticeMinutes = 120,
    this.serviceAheadDays = 14, this.serviceAutoConfirm = false, this.serviceAreas, this.travelFee, this.hasServices = false,
    this.category, this.categories = const [], this.about, this.area, this.logo,
    this.verified = false, this.isNew = false, this.live = true, this.since, this.link = '', this.itemsCount = 0,
    this.mine = false, this.status, this.closedReason, this.verificationRequested = false, this.pickupLat, this.pickupLng,
    this.pickupAddress, this.stats, this.following = false, this.followNotify = false, this.blocked = false,
    this.takingOrders = false, this.takingOrdersSwitch = true, this.fulfilment = const ['pickup'], this.payMethods = const ['cash_delivery'],
    this.openFrom, this.openTo, this.openNow = true, this.minOrder, this.rating, this.ratingCount = 0, this.ordersCompleted = 0,
    this.replyMinutes, this.todayOrders = 0, this.todayConfirmed = 0, this.venue, this.sells = const [], this.matchedItems = const [],
  });

  factory MarketShop.fromJson(Map<String, dynamic> j) => MarketShop(
        id: '${j['id']}',
        slug: '${j['slug']}',
        name: '${j['name'] ?? ''}',
        kind: _text(j['kind']) ?? 'shop',
        map: MarketPoint.fromJson(j['map']),
        mapNote: j['map'] is Map ? _text(j['map']['note']) : null,
        mapVisible: j['map_visible'] == null ? true : _bool(j['map_visible']),
        addressNote: _text(j['address_note']),
        takingBookings: j['taking_bookings'] == null ? true : _bool(j['taking_bookings']),
        bookingsCompleted: _int(j['bookings_completed']),
        serviceHours: marketHours(j['service_hours']),
        serviceCapacity: _int(j['service_capacity']) == 0 ? 1 : _int(j['service_capacity']),
        serviceNoticeMinutes: j['service_notice_minutes'] == null ? 120 : _int(j['service_notice_minutes']),
        serviceAheadDays: _int(j['service_ahead_days']) == 0 ? 14 : _int(j['service_ahead_days']),
        serviceAutoConfirm: _bool(j['service_auto_confirm']),
        serviceAreas: _text(j['service_areas']),
        travelFee: _num(j['travel_fee']),
        hasServices: _bool(j['has_services']),
        category: _text(j['category']),
        categories: j['categories'] is List ? _strings(j['categories']) : (_text(j['category']) != null ? [_text(j['category'])!] : const []),
        about: _text(j['about']),
        area: _text(j['area']),
        logo: _text(j['logo']),
        verified: _bool(j['verified']),
        isNew: _bool(j['is_new']),
        live: j['live'] == null ? true : _bool(j['live']),
        since: _text(j['since']),
        link: '${j['link'] ?? ''}',
        itemsCount: _int(j['items_count']),
        mine: _bool(j['mine']),
        status: _text(j['status']),
        closedReason: _text(j['closed_reason']),
        verificationRequested: _bool(j['verification_requested']),
        pickupLat: _num(j['pickup_lat']),
        pickupLng: _num(j['pickup_lng']),
        pickupAddress: _text(j['pickup_address']),
        stats: j['stats'] is Map ? MarketShopStats.fromJson(Map<String, dynamic>.from(j['stats'])) : null,
        following: _bool(j['following']),
        followNotify: _bool(j['follow_notify']),
        blocked: _bool(j['blocked']),
        takingOrders: _bool(j['taking_orders']),
        takingOrdersSwitch: j['taking_orders_switch'] == null ? _bool(j['taking_orders']) : _bool(j['taking_orders_switch']),
        fulfilment: j['fulfilment'] is List ? _strings(j['fulfilment']) : const ['pickup'],
        payMethods: j['pay_methods'] is List ? _strings(j['pay_methods']) : const ['cash_delivery'],
        openFrom: _text(j['open_from']),
        openTo: _text(j['open_to']),
        openNow: j['open_now'] == null ? true : _bool(j['open_now']),
        minOrder: _num(j['min_order']),
        rating: _num(j['rating']),
        ratingCount: _int(j['rating_count']),
        ordersCompleted: _int(j['orders_completed']),
        replyMinutes: j['reply_minutes'] == null ? null : _int(j['reply_minutes']),
        todayOrders: j['today'] is Map ? _int(j['today']['orders']) : 0,
        todayConfirmed: j['today'] is Map ? (_num(j['today']['confirmed_total']) ?? 0) : 0,
        venue: j['venue'] is Map ? MarketShopVenue.fromJson(Map<String, dynamic>.from(j['venue'])) : null,
        sells: _strings(j['sells']),
        matchedItems: _strings(j['matched_items']),
      );
}

/// A gate of a market (riders drop buyers at the one nearest the shed).
class MarketEntrance {
  final String name;
  final double lat;
  final double lng;
  const MarketEntrance({required this.name, required this.lat, required this.lng});
  static List<MarketEntrance> list(dynamic v) => [
        for (final e in (v is List ? v : const []))
          if (e is Map && _num(e['lat']) != null) MarketEntrance(name: _text(e['name']) ?? '', lat: _num(e['lat'])!, lng: _num(e['lng']) ?? 0),
      ];
}

/// A shop's place in a market: the market, its block and shed, a photo of the shopfront.
class MarketShopVenue {
  final String id;
  final String slug;
  final String name;
  final String? shedNumber;
  final String? shedBlock;
  final String? shedBuilding;
  /// 0 = ground floor, 1 = first floor, -1 = basement; null when not in a building.
  final int? shedFloor;
  /// "Block C, Shed 112"
  final String? label;
  final String? shopfront;
  /// Verified in a market: E-Ride checked the shed, its place and what it sells.
  final bool checked;
  final List<MarketEntrance> entrances;
  const MarketShopVenue({required this.id, required this.slug, required this.name, this.shedNumber, this.shedBlock, this.shedBuilding, this.shedFloor, this.label,
      this.shopfront, this.checked = false, this.entrances = const []});
  factory MarketShopVenue.fromJson(Map<String, dynamic> j) => MarketShopVenue(
        id: '${j['id']}', slug: '${j['slug']}', name: '${j['name'] ?? ''}', shedNumber: _text(j['shed_number']), shedBlock: _text(j['shed_block']),
        shedBuilding: _text(j['shed_building']), shedFloor: j['shed_floor'] == null ? null : int.tryParse('${j['shed_floor']}'),
        label: _text(j['label']), shopfront: _text(j['shopfront']), checked: _bool(j['checked']), entrances: MarketEntrance.list(j['entrances']));
}

/// A building of a market and its floors (with the ground floor: 3 = ground, 1st and 2nd).
class MarketBuilding {
  final String name;
  final int floors;
  const MarketBuilding({required this.name, this.floors = 1});
}

/// A market E-Ride created (Bamenda Main Market...), where shops list their shed.
class MarketVenue {
  final String id;
  final String slug;
  final String name;
  final String city;
  final String? area;
  final String? about;
  final double lat;
  final double lng;
  final List<MarketEntrance> entrances;
  final List<String> blocks;
  final List<MarketBuilding> buildings;
  final int shopsCount;
  final int verifiedCount;
  final double? distanceKm;
  const MarketVenue({required this.id, required this.slug, required this.name, this.city = '', this.area, this.about, required this.lat,
      required this.lng, this.entrances = const [], this.blocks = const [], this.buildings = const [], this.shopsCount = 0, this.verifiedCount = 0, this.distanceKm});
  factory MarketVenue.fromJson(Map<String, dynamic> j) => MarketVenue(
        id: '${j['id']}', slug: '${j['slug']}', name: '${j['name'] ?? ''}', city: '${j['city'] ?? ''}', area: _text(j['area']),
        about: _text(j['about']), lat: _num(j['lat']) ?? 0, lng: _num(j['lng']) ?? 0, entrances: MarketEntrance.list(j['entrances']),
        blocks: _strings(j['blocks']), shopsCount: _int(j['shops_count']),
        buildings: [for (final b in (j['buildings'] is List ? j['buildings'] as List : const [])) if (b is Map) MarketBuilding(name: '${b['name'] ?? ''}', floors: _int(b['floors']) < 1 ? 1 : _int(b['floors']))], verifiedCount: _int(j['verified_count']), distanceKm: _num(j['distance_km']));
}

extension MarketShopKind on MarketShop {
  bool get isPrivate => kind == 'private';
}

class MarketPhoto {
  final int id;
  final String url;
  const MarketPhoto({required this.id, required this.url});
  factory MarketPhoto.fromJson(Map<String, dynamic> j) => MarketPhoto(id: _int(j['id']), url: '${j['url']}');
}

class MarketItemShop {
  final String slug;
  final String name;
  final String? area;
  final bool verified;
  final String? logo;
  final String kind;
  /// Has a shed in one of E-Ride's markets ([area] then says "Bamenda Main Market, Shed 112").
  final bool inMarket;
  const MarketItemShop({required this.slug, required this.name, this.area, this.verified = false, this.logo, this.kind = 'shop', this.inMarket = false});
  bool get isPrivate => kind == 'private';
  factory MarketItemShop.fromJson(Map<String, dynamic> j) => MarketItemShop(slug: '${j['slug']}', name: '${j['name'] ?? ''}',
      area: _text(j['area']), verified: _bool(j['verified']), logo: _text(j['logo']), kind: _text(j['kind']) ?? 'shop', inMarket: _bool(j['in_market']));
}

/// What the app needs to know about auctions (admin settings).
class MarketAuctionRules {
  final bool canRun;
  final int maxDays;
  final int payHours;
  final int strikesLimit;
  final int extendMinutes;
  /// Why this person cannot bid now (null: they can).
  final String? cannotBidReason;
  const MarketAuctionRules({this.canRun = true, this.maxDays = 7, this.payHours = 24, this.strikesLimit = 2, this.extendMinutes = 2, this.cannotBidReason});
  factory MarketAuctionRules.fromJson(Map<String, dynamic> j) => MarketAuctionRules(
        canRun: j['can_run'] == null ? true : _bool(j['can_run']),
        maxDays: _int(j['max_days']) == 0 ? 7 : _int(j['max_days']),
        payHours: _int(j['pay_hours']) == 0 ? 24 : _int(j['pay_hours']),
        strikesLimit: _int(j['strikes_limit']) == 0 ? 2 : _int(j['strikes_limit']),
        extendMinutes: _int(j['extend_minutes']),
        cannotBidReason: _text(j['cannot_bid_reason']),
      );
}

/// An auction as this person sees it.
class MarketAuction {
  final bool live;
  /// live | ending (time is up, closing) | sold | unsold | cancelled
  final String status;
  final double startPrice;
  final double step;
  final double? currentBid;
  final int bidCount;
  final DateTime? endsAt;
  final bool hasReserve;
  final bool? reserveMet;
  final double minNext;
  // The viewer.
  final bool leading;
  final double? myBid;
  final bool won;
  final String? orderId;
  final double? offerPrice;
  final DateTime? offerExpiresAt;
  // The seller.
  final double? reservePrice;
  final String? winnerName;
  final double? winnerBid;
  final String? orderStatus;
  final DateTime? paymentDueAt;
  final bool offered;
  final bool nextBidder;

  const MarketAuction({this.live = false, this.status = 'live', this.startPrice = 0, this.step = 0, this.currentBid, this.bidCount = 0, this.endsAt,
      this.hasReserve = false, this.reserveMet, this.minNext = 0, this.leading = false, this.myBid, this.won = false, this.orderId, this.offerPrice,
      this.offerExpiresAt, this.reservePrice, this.winnerName, this.winnerBid, this.orderStatus, this.paymentDueAt, this.offered = false,
      this.nextBidder = false});

  /// What the item costs now: the current bid, or the starting price before any bid.
  double get price => currentBid ?? startPrice;
  bool get hasOffer => offerPrice != null && (offerExpiresAt?.isAfter(DateTime.now()) ?? false);

  factory MarketAuction.fromJson(Map<String, dynamic> j) => MarketAuction(
        live: _bool(j['live']), status: _text(j['status']) ?? 'live', startPrice: _num(j['start_price']) ?? 0, step: _num(j['step']) ?? 0,
        currentBid: _num(j['current_bid']), bidCount: _int(j['bid_count']), endsAt: _date(j['ends_at']), hasReserve: _bool(j['has_reserve']),
        reserveMet: j['reserve_met'] == null ? null : _bool(j['reserve_met']), minNext: _num(j['min_next']) ?? 0, leading: _bool(j['leading']),
        myBid: _num(j['my_bid']), won: _bool(j['won']), orderId: _text(j['order_id']),
        offerPrice: j['offer'] is Map ? _num(j['offer']['price']) : null, offerExpiresAt: j['offer'] is Map ? _date(j['offer']['expires_at']) : null,
        reservePrice: _num(j['reserve_price']), winnerName: _text(j['winner_name']), winnerBid: _num(j['winner_bid']), orderStatus: _text(j['order_status']),
        paymentDueAt: _date(j['payment_due_at']), offered: _bool(j['offered']), nextBidder: _bool(j['next_bidder']),
      );
}

class MarketBid {
  final double amount;
  final String? name;
  final bool mine;
  final DateTime? createdAt;
  const MarketBid({required this.amount, this.name, this.mine = false, this.createdAt});
  factory MarketBid.fromJson(Map<String, dynamic> j) =>
      MarketBid(amount: _num(j['amount']) ?? 0, name: _text(j['name']), mine: _bool(j['mine']), createdAt: _date(j['created_at']));
}

class MarketColour {
  final String name;
  final int? photoId;
  final String? photo;
  const MarketColour({required this.name, this.photoId, this.photo});
  factory MarketColour.fromJson(Map<String, dynamic> j) =>
      MarketColour(name: '${j['name'] ?? ''}', photoId: j['photo_id'] == null ? null : _int(j['photo_id']), photo: _text(j['photo']));
}

/// How a shop takes orders, as shown on its items.
class MarketShopOrders {
  final bool takingOrders;
  final List<String> fulfilment;
  final List<String> payMethods;
  final double? rating;
  final int ratingCount;
  final int ordersCompleted;
  final int? replyMinutes;
  const MarketShopOrders({this.takingOrders = false, this.fulfilment = const [], this.payMethods = const [], this.rating,
      this.ratingCount = 0, this.ordersCompleted = 0, this.replyMinutes});
  factory MarketShopOrders.fromJson(Map<String, dynamic> j) => MarketShopOrders(
        takingOrders: _bool(j['taking_orders']), fulfilment: _strings(j['fulfilment']), payMethods: _strings(j['pay_methods']),
        rating: _num(j['rating']), ratingCount: _int(j['rating_count']), ordersCompleted: _int(j['orders_completed']),
        replyMinutes: j['reply_minutes'] == null ? null : _int(j['reply_minutes']),
      );
}

class MarketItem {
  static const String live = 'live';
  static const String hidden = 'hidden';
  static const String blocked = 'blocked';
  static const String removed = 'removed';
  static const String soldOut = 'sold_out';

  final String id;
  final String code;
  final String title;
  final double? price;
  final bool negotiable;
  final String condition; // new | used | digital
  final String? digitalKind;
  final String? category;
  /// Words buyers might search for, chosen by the seller.
  final List<String> tags;
  final int quantity;
  final String status;
  final String? cover;
  final String link;
  final MarketItemShop? shop;
  final bool mine;
  final String? createdAt;
  // Details.
  final String? description;
  final List<MarketPhoto> photos;
  final List<MarketPhoto> previews;
  final bool pickup;
  final bool erideDelivery;
  final bool sellerDelivers;
  final bool strongWarning;
  final bool following;
  final bool followNotify;
  // The seller's view.
  final int visits;
  final int chats;
  final String? statusNote;
  final String? blockedWord;
  // Options and orders.
  final List<MarketColour> colours;
  final List<String> sizes;
  /// Pieces left per "colour|size" (null for an item without options: then [quantity]).
  final Map<String, int>? stock;
  final double? wholesalePrice;
  final int? wholesaleMin;
  final bool orderable;
  final MarketShopOrders? shopOrders;
  /// fixed | offers | auction
  final String saleType;
  /// Used items: like_new | good | fair | parts
  final String? usedGrade;
  final MarketAuction? auction;
  /// Services: booked for a time or quoted.
  final MarketServiceInfo? service;

  const MarketItem({
    required this.id, required this.code, required this.title, this.price, this.negotiable = false, this.condition = 'new',
    this.digitalKind, this.category, this.tags = const [], this.quantity = 1, this.status = live, this.cover, this.link = '', this.shop, this.mine = false,
    this.createdAt, this.description, this.photos = const [], this.previews = const [], this.pickup = true, this.erideDelivery = true,
    this.sellerDelivers = false, this.strongWarning = false, this.following = false, this.followNotify = false, this.visits = 0, this.chats = 0,
    this.statusNote, this.blockedWord, this.colours = const [], this.sizes = const [], this.stock, this.wholesalePrice,
    this.wholesaleMin, this.orderable = false, this.shopOrders, this.saleType = 'fixed', this.usedGrade, this.auction, this.service,
  });

  bool get isAuction => saleType == 'auction' && auction != null;
  bool get fromPrivateSeller => shop?.isPrivate ?? false;
  bool get isService => condition == 'service';

  bool get isDigital => condition == 'digital';
  bool get isPublic => status == live || status == soldOut;
  bool get hasOptions => colours.isNotEmpty || sizes.isNotEmpty;
  bool get hasWholesale => wholesalePrice != null && wholesaleMin != null;

  static String stockKey(String? colour, String? size) => '${colour ?? ''}|${size ?? ''}';

  /// Pieces left of one choice.
  int stockFor(String? colour, String? size) => hasOptions ? (stock?[stockKey(colour, size)] ?? 0) : quantity;

  /// A size is worth showing as available for this colour (or any colour when none is picked).
  bool sizeAvailable(String size, String? colour) {
    if (colours.isEmpty || colour != null) return stockFor(colours.isEmpty ? null : colour, size) > 0;
    return colours.any((c) => stockFor(c.name, size) > 0);
  }

  bool colourAvailable(String colour) => sizes.isEmpty ? stockFor(colour, null) > 0 : sizes.any((s) => stockFor(colour, s) > 0);

  /// The price of one piece when [pieces] of this item are in one order.
  double unitPrice(int pieces) => hasWholesale && pieces >= wholesaleMin! && wholesalePrice! < (price ?? 0) ? wholesalePrice! : (price ?? 0);

  factory MarketItem.fromJson(Map<String, dynamic> j) => MarketItem(
        id: '${j['id']}',
        code: '${j['code']}',
        title: '${j['title'] ?? ''}',
        price: _num(j['price']),
        negotiable: _bool(j['negotiable']),
        condition: _text(j['condition']) ?? 'new',
        digitalKind: _text(j['digital_kind']),
        category: _text(j['category']),
        tags: ((j['tags'] as List?) ?? const []).map((e) => '$e').toList(),
        quantity: _int(j['quantity']),
        status: _text(j['status']) ?? live,
        cover: _text(j['cover']),
        link: '${j['link'] ?? ''}',
        shop: j['shop'] is Map ? MarketItemShop.fromJson(Map<String, dynamic>.from(j['shop'])) : null,
        mine: _bool(j['mine']),
        createdAt: _text(j['created_at']),
        description: _text(j['description']),
        photos: [for (final p in (j['photos'] as List? ?? const [])) MarketPhoto.fromJson(Map<String, dynamic>.from(p))],
        previews: [for (final p in (j['previews'] as List? ?? const [])) MarketPhoto.fromJson(Map<String, dynamic>.from(p))],
        pickup: j['pickup'] == null ? true : _bool(j['pickup']),
        erideDelivery: j['eride_delivery'] == null ? true : _bool(j['eride_delivery']),
        sellerDelivers: _bool(j['seller_delivers']),
        strongWarning: _bool(j['strong_warning']),
        following: _bool(j['following']),
        followNotify: _bool(j['follow_notify']),
        visits: _int(j['visits']),
        chats: _int(j['chats']),
        statusNote: _text(j['status_note']),
        blockedWord: _text(j['blocked_word']),
        colours: j['options'] is Map && j['options']['colours'] is List
            ? [for (final c in j['options']['colours'] as List) MarketColour.fromJson(Map<String, dynamic>.from(c))]
            : const [],
        sizes: j['options'] is Map ? _strings(j['options']['sizes']) : const [],
        stock: j['stock'] is Map ? {for (final e in (j['stock'] as Map).entries) '${e.key}': _int(e.value)} : null,
        wholesalePrice: _num(j['wholesale_price']),
        wholesaleMin: j['wholesale_min'] == null ? null : _int(j['wholesale_min']),
        orderable: _bool(j['orderable']),
        shopOrders: j['shop_orders'] is Map ? MarketShopOrders.fromJson(Map<String, dynamic>.from(j['shop_orders'])) : null,
        saleType: _text(j['sale_type']) ?? 'fixed',
        usedGrade: _text(j['used_grade']),
        auction: j['auction'] is Map ? MarketAuction.fromJson(Map<String, dynamic>.from(j['auction'])) : null,
        service: j['service'] is Map ? MarketServiceInfo.fromJson(Map<String, dynamic>.from(j['service'])) : null,
      );
}

class MarketReceiver {
  final String name;
  final String? phone;
  const MarketReceiver({required this.name, this.phone});
}

class MarketChat {
  final String id;
  final String role; // buyer | seller
  final MarketItem? item;
  final MarketItemShop? shop;
  final bool shopLive;
  final String? buyerName;
  final String? lastMessage;
  final String? lastMessageAt;
  final int unread;
  final bool buyerBlocked;
  /// The seller's view, once the buyer asked for delivery.
  final MarketReceiver? receiver;

  const MarketChat({
    required this.id, required this.role, this.item, this.shop, this.shopLive = true, this.buyerName, this.lastMessage,
    this.lastMessageAt, this.unread = 0, this.buyerBlocked = false, this.receiver,
  });

  bool get isSeller => role == 'seller';

  /// The other side's name, as this person sees it.
  String get otherName => isSeller ? (buyerName ?? '') : (shop?.name ?? '');

  factory MarketChat.fromJson(Map<String, dynamic> j) {
    final shop = j['shop'] is Map ? Map<String, dynamic>.from(j['shop']) : null;
    final receiver = j['receiver'] is Map ? Map<String, dynamic>.from(j['receiver']) : null;
    return MarketChat(
      id: '${j['id']}',
      role: _text(j['role']) ?? 'buyer',
      item: j['item'] is Map ? MarketItem.fromJson(Map<String, dynamic>.from(j['item'])) : null,
      shop: shop != null ? MarketItemShop.fromJson(shop) : null,
      shopLive: shop == null || shop['live'] == null || _bool(shop['live']),
      buyerName: _text(j['buyer_name']),
      lastMessage: _text(j['last_message']),
      lastMessageAt: _text(j['last_message_at']),
      unread: _int(j['unread']),
      buyerBlocked: _bool(j['buyer_blocked']),
      receiver: receiver != null ? MarketReceiver(name: '${receiver['name'] ?? ''}', phone: _text(receiver['phone'])) : null,
    );
  }
}

class MarketDelivery {
  final String tripId;
  final String? refId;
  final String? status;
  const MarketDelivery({required this.tripId, this.refId, this.status});
}

class MarketMessage {
  final String id;
  final bool mine;
  final String type; // text | photo | delivery_point | delivery_booked
  final String? body;
  final String? photo;
  final double? latitude;
  final double? longitude;
  final String? address;
  final MarketDelivery? delivery;
  final String? createdAt;
  /// type "order": the order this note is about.
  final String? orderId;
  /// type "booking": the booking this note is about.
  final String? bookingId;

  const MarketMessage({
    required this.id, required this.mine, this.type = 'text', this.body, this.photo, this.latitude, this.longitude,
    this.address, this.delivery, this.createdAt, this.orderId, this.bookingId,
  });

  factory MarketMessage.fromJson(Map<String, dynamic> j) {
    final meta = j['meta'] is Map ? Map<String, dynamic>.from(j['meta']) : const <String, dynamic>{};
    final delivery = j['delivery'] is Map ? Map<String, dynamic>.from(j['delivery']) : null;
    return MarketMessage(
      id: '${j['id']}',
      mine: _bool(j['mine']),
      type: _text(j['type']) ?? 'text',
      body: _text(j['body']),
      photo: _text(j['photo']),
      latitude: _num(meta['latitude']),
      longitude: _num(meta['longitude']),
      address: _text(meta['address']),
      delivery: delivery != null ? MarketDelivery(tripId: '${delivery['trip_id']}', refId: _text(delivery['ref_id']), status: _text(delivery['status'])) : null,
      createdAt: _text(j['created_at']),
      orderId: _text(meta['order_id']),
      bookingId: _text(meta['booking_id']),
    );
  }
}

// ---------------------------------------------------------------- orders

class MarketOrderLine {
  final int id;
  final String? itemCode;
  final String title;
  final String? photo;
  final String? colour;
  final String? size;
  final double unitPrice;
  final bool wholesale;
  final int qty;
  final int? qtyConfirmed;
  final String? sellerNote;
  /// The seller's view: pieces left of this choice now.
  final int? inStock;

  const MarketOrderLine({required this.id, this.itemCode, required this.title, this.photo, this.colour, this.size, this.unitPrice = 0,
      this.wholesale = false, this.qty = 1, this.qtyConfirmed, this.sellerNote, this.inStock});

  int get finalQty => qtyConfirmed ?? qty;
  bool get changed => qtyConfirmed != null && qtyConfirmed != qty;
  String get choice => [if (colour != null) colour!, if (size != null) size!].join(' · ');

  factory MarketOrderLine.fromJson(Map<String, dynamic> j) => MarketOrderLine(
        id: _int(j['id']), itemCode: _text(j['item_code']), title: '${j['title'] ?? ''}', photo: _text(j['photo']), colour: _text(j['colour']),
        size: _text(j['size']), unitPrice: _num(j['unit_price']) ?? 0, wholesale: _bool(j['wholesale']), qty: _int(j['qty']),
        qtyConfirmed: j['qty_confirmed'] == null ? null : _int(j['qty_confirmed']), sellerNote: _text(j['seller_note']),
        inStock: j['in_stock'] == null ? null : _int(j['in_stock']),
      );
}

class MarketPoint {
  final double lat;
  final double lng;
  final String? address;
  const MarketPoint({required this.lat, required this.lng, this.address});
  static MarketPoint? fromJson(dynamic j) =>
      j is Map && j['lat'] != null ? MarketPoint(lat: _num(j['lat']) ?? 0, lng: _num(j['lng']) ?? 0, address: _text(j['address'])) : null;
}

class MarketOrder {
  static const String requested = 'requested';
  static const String changes = 'changes';
  static const String confirmed = 'confirmed';
  static const String ready = 'ready';
  static const String onTheWay = 'on_the_way';
  static const String completed = 'completed';
  static const String declined = 'declined';
  static const String expired = 'expired';
  static const String cancelled = 'cancelled';
  static const List<String> held = [confirmed, ready, onTheWay];
  static const List<String> open = [requested, changes, confirmed, ready, onTheWay];

  final String id;
  final String code;
  final String role; // buyer | seller
  final String status;
  final MarketItemShop? shop;
  final String? buyerName;
  final String fulfilment; // pickup | eride | seller
  final String payMethod;
  final int pieces;
  final int piecesConfirmed;
  final double requestedTotal;
  final double? confirmedTotal;
  final String? photo;
  final String summary;
  final DateTime? respondBy;
  final DateTime? agreeBy;
  final DateTime? createdAt;
  // Full view.
  final List<MarketOrderLine> lines;
  final String? note;
  final MarketPoint? drop;
  final String? declineReason;
  final String? declineNote;
  final String? cancelReason;
  final String? cancelledBy;
  final DateTime? confirmedAt;
  final DateTime? readyAt;
  final DateTime? completedAt;
  final String? conversationId;
  final String? receiveCode;
  final MarketPoint? pickup;
  final MarketReceiver? receiver;
  final MarketDelivery? trip;
  final int? reviewStars;
  final List<String> reviewTags;
  final String? reviewComment;
  final bool canReview;
  /// An auction order: the winner arranges payment with the seller before [paymentDueAt].
  final bool fromAuction;
  final DateTime? paymentDueAt;
  final bool paymentArranged;

  const MarketOrder({
    required this.id, required this.code, required this.role, required this.status, this.shop, this.buyerName, this.fulfilment = 'pickup',
    this.payMethod = 'cash_delivery', this.pieces = 0, this.piecesConfirmed = 0, this.requestedTotal = 0, this.confirmedTotal, this.photo,
    this.summary = '', this.respondBy, this.agreeBy, this.createdAt, this.lines = const [], this.note, this.drop, this.declineReason,
    this.declineNote, this.cancelReason, this.cancelledBy, this.confirmedAt, this.readyAt, this.completedAt, this.conversationId,
    this.receiveCode, this.pickup, this.receiver, this.trip, this.reviewStars, this.reviewTags = const [], this.reviewComment,
    this.canReview = false, this.fromAuction = false, this.paymentDueAt, this.paymentArranged = false,
  });

  bool get isSeller => role == 'seller';
  bool get isHeld => held.contains(status);
  bool get isOpen => open.contains(status);
  double get total => confirmedTotal ?? requestedTotal;
  String get otherName => isSeller ? (buyerName ?? '') : (shop?.name ?? '');

  /// The deadline that matters now (seller answer, or buyer agreement).
  DateTime? get deadline => status == requested ? respondBy : (status == changes ? agreeBy : null);

  factory MarketOrder.fromJson(Map<String, dynamic> j) {
    final review = j['review'] is Map ? Map<String, dynamic>.from(j['review']) : null;
    final receiver = j['receiver'] is Map ? Map<String, dynamic>.from(j['receiver']) : null;
    final trip = j['trip'] is Map ? Map<String, dynamic>.from(j['trip']) : null;
    return MarketOrder(
      id: '${j['id']}', code: '${j['code'] ?? ''}', role: _text(j['role']) ?? 'buyer', status: _text(j['status']) ?? requested,
      shop: j['shop'] is Map ? MarketItemShop.fromJson(Map<String, dynamic>.from(j['shop'])) : null,
      buyerName: _text(j['buyer_name']), fulfilment: _text(j['fulfilment']) ?? 'pickup', payMethod: _text(j['pay_method']) ?? 'cash_delivery',
      pieces: _int(j['pieces']), piecesConfirmed: _int(j['pieces_confirmed']), requestedTotal: _num(j['requested_total']) ?? 0,
      confirmedTotal: _num(j['confirmed_total']), photo: _text(j['photo']), summary: '${j['summary'] ?? ''}',
      respondBy: _date(j['respond_by']), agreeBy: _date(j['agree_by']), createdAt: _date(j['created_at']),
      lines: [for (final l in (j['lines'] as List? ?? const [])) MarketOrderLine.fromJson(Map<String, dynamic>.from(l))],
      note: _text(j['note']), drop: MarketPoint.fromJson(j['drop']), declineReason: _text(j['decline_reason']),
      declineNote: _text(j['decline_note']), cancelReason: _text(j['cancel_reason']), cancelledBy: _text(j['cancelled_by']),
      confirmedAt: _date(j['confirmed_at']), readyAt: _date(j['ready_at']), completedAt: _date(j['completed_at']),
      conversationId: _text(j['conversation_id']), receiveCode: _text(j['receive_code']), pickup: MarketPoint.fromJson(j['pickup']),
      receiver: receiver != null ? MarketReceiver(name: '${receiver['name'] ?? ''}', phone: _text(receiver['phone'])) : null,
      trip: trip != null ? MarketDelivery(tripId: '${trip['id']}', refId: _text(trip['ref_id']), status: _text(trip['status'])) : null,
      reviewStars: review == null ? null : _int(review['stars']), reviewTags: review == null ? const [] : _strings(review['tags']),
      reviewComment: review == null ? null : _text(review['comment']), canReview: _bool(j['can_review']),
      fromAuction: _bool(j['auction']), paymentDueAt: _date(j['payment_due_at']), paymentArranged: _bool(j['payment_arranged']),
    );
  }
}

class MarketReview {
  final int stars;
  final List<String> tags;
  final String? comment;
  final String buyer;
  final DateTime? createdAt;
  const MarketReview({required this.stars, this.tags = const [], this.comment, this.buyer = '', this.createdAt});
  factory MarketReview.fromJson(Map<String, dynamic> j) => MarketReview(
      stars: _int(j['stars']), tags: _strings(j['tags']), comment: _text(j['comment']), buyer: '${j['buyer'] ?? ''}', createdAt: _date(j['created_at']));
}

/// One choice in the cart, kept on the phone until the order is sent.
class MarketCartLine {
  final String shopSlug;
  final String shopName;
  final String? shopLogo;
  final String itemCode;
  final String title;
  final String? photo;
  final String? colour;
  final String? size;
  final double price;
  final double? wholesalePrice;
  final int? wholesaleMin;
  final int maxQty;
  int qty;

  MarketCartLine({required this.shopSlug, required this.shopName, this.shopLogo, required this.itemCode, required this.title, this.photo,
      this.colour, this.size, required this.price, this.wholesalePrice, this.wholesaleMin, this.maxQty = 9999, this.qty = 1});

  String get key => '$itemCode|${colour ?? ''}|${size ?? ''}';
  String get choice => [if (colour != null) colour!, if (size != null) size!].join(' · ');

  Map<String, dynamic> toJson() => {
        'shop_slug': shopSlug, 'shop_name': shopName, 'shop_logo': shopLogo, 'item': itemCode, 'title': title, 'photo': photo,
        'colour': colour, 'size': size, 'price': price, 'wholesale_price': wholesalePrice, 'wholesale_min': wholesaleMin,
        'max_qty': maxQty, 'qty': qty,
      };

  factory MarketCartLine.fromJson(Map<String, dynamic> j) => MarketCartLine(
        shopSlug: '${j['shop_slug']}', shopName: '${j['shop_name'] ?? ''}', shopLogo: _text(j['shop_logo']), itemCode: '${j['item']}',
        title: '${j['title'] ?? ''}', photo: _text(j['photo']), colour: _text(j['colour']), size: _text(j['size']),
        price: _num(j['price']) ?? 0, wholesalePrice: _num(j['wholesale_price']),
        wholesaleMin: j['wholesale_min'] == null ? null : _int(j['wholesale_min']), maxQty: _int(j['max_qty']) == 0 ? 9999 : _int(j['max_qty']),
        qty: _int(j['qty']) < 1 ? 1 : _int(j['qty']),
      );
}


// ---------------------------------------------------------------- services

/// "mon": ["08:00","18:00"] or null, for the 7 days.
Map<String, List<String>?> marketHours(dynamic v) {
  final out = <String, List<String>?>{};
  if (v is! Map) return out;
  for (final d in const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']) {
    final h = v[d];
    out[d] = h is List && h.length == 2 ? ['${h[0]}', '${h[1]}'] : null;
  }
  return out;
}

/// What the app needs to know about services (admin settings).
class MarketServiceRules {
  final List<String> kinds;
  final List<int> durations;
  final int answerMinutes;
  final int quoteHours;
  final int cancelHours;
  final List<String> reviewTags;
  final String? cannotBookReason;
  const MarketServiceRules({
    this.kinds = const ['hair_beauty', 'repairs', 'tailoring', 'cleaning', 'lessons', 'events', 'photography', 'other'],
    this.durations = const [30, 60, 90, 120, 180, 240, 360, 480], this.answerMinutes = 120, this.quoteHours = 24, this.cancelHours = 3,
    this.reviewTags = const ['on_time', 'great_result', 'friendly', 'clean_place', 'fair_price', 'problem'], this.cannotBookReason,
  });
  factory MarketServiceRules.fromJson(Map<String, dynamic> j) => MarketServiceRules(
        kinds: j['kinds'] is List ? _strings(j['kinds']) : const ['hair_beauty', 'repairs', 'tailoring', 'cleaning', 'lessons', 'events', 'photography', 'other'],
        durations: j['durations'] is List ? [for (final d in j['durations'] as List) _int(d)] : const [30, 60, 90, 120, 180, 240, 360, 480],
        answerMinutes: _int(j['answer_minutes']) == 0 ? 120 : _int(j['answer_minutes']),
        quoteHours: _int(j['quote_hours']) == 0 ? 24 : _int(j['quote_hours']),
        cancelHours: _int(j['cancel_hours']),
        reviewTags: j['review_tags'] is List ? _strings(j['review_tags']) : const ['on_time', 'great_result', 'friendly', 'clean_place', 'fair_price', 'problem'],
        cannotBookReason: _text(j['cannot_book_reason']),
      );
}

class MarketExtra {
  final String name;
  final double price;
  const MarketExtra({required this.name, this.price = 0});
  factory MarketExtra.fromJson(Map<String, dynamic> j) => MarketExtra(name: '${j['name'] ?? ''}', price: _num(j['price']) ?? 0);
  Map<String, dynamic> toJson() => {'name': name, 'price': price};
}

/// A service on its item: how it is priced, how long, where, extras, the next free time.
class MarketServiceInfo {
  /// fixed | from | hour | quote
  final String priceType;
  final int durationMinutes;
  /// place | client | online
  final List<String> where;
  final List<MarketExtra> extras;
  final String? kind;
  final DateTime? nextFree;
  final bool takingBookings;
  final int bookingsDone;
  final Map<String, List<String>?> hours;
  final String? areas;
  final double? travelFee;
  const MarketServiceInfo({this.priceType = 'fixed', this.durationMinutes = 60, this.where = const ['place'], this.extras = const [], this.kind,
      this.nextFree, this.takingBookings = true, this.bookingsDone = 0, this.hours = const {}, this.areas, this.travelFee});

  bool get isQuote => priceType == 'quote';

  factory MarketServiceInfo.fromJson(Map<String, dynamic> j) => MarketServiceInfo(
        priceType: _text(j['price_type']) ?? 'fixed',
        durationMinutes: _int(j['duration_minutes']) == 0 ? 60 : _int(j['duration_minutes']),
        where: j['where'] is List ? _strings(j['where']) : const ['place'],
        extras: [for (final e in (j['extras'] as List? ?? const [])) if (e is Map) MarketExtra.fromJson(Map<String, dynamic>.from(e))],
        kind: _text(j['kind']),
        nextFree: _date(j['next_free']),
        takingBookings: j['taking_bookings'] == null ? true : _bool(j['taking_bookings']),
        bookingsDone: _int(j['bookings_done']),
        hours: marketHours(j['hours']),
        areas: _text(j['areas']),
        travelFee: _num(j['travel_fee']),
      );
}

class MarketSlot {
  final String time;
  final bool free;
  const MarketSlot({required this.time, this.free = true});
}

class MarketSlotDay {
  final String date;
  final bool open;
  final int free;
  const MarketSlotDay({required this.date, this.open = false, this.free = 0});
  DateTime get day => DateTime.parse(date);
}

/// The day strip and the start times of the chosen day.
class MarketSlots {
  final List<MarketSlotDay> days;
  final String date;
  final List<MarketSlot> slots;
  final int durationMinutes;
  const MarketSlots({this.days = const [], required this.date, this.slots = const [], this.durationMinutes = 60});
  factory MarketSlots.fromJson(Map<String, dynamic> j) => MarketSlots(
        days: [for (final d in (j['days'] as List? ?? const [])) if (d is Map) MarketSlotDay(date: '${d['date']}', open: _bool(d['open']), free: _int(d['free']))],
        date: '${j['date']}',
        slots: [for (final s in (j['slots'] as List? ?? const [])) if (s is Map) MarketSlot(time: '${s['time']}', free: _bool(s['free']))],
        durationMinutes: _int(j['duration_minutes']) == 0 ? 60 : _int(j['duration_minutes']),
      );
}

class MarketBookingPlace {
  final double? lat;
  final double? lng;
  final String? address;
  final String? note;
  const MarketBookingPlace({this.lat, this.lng, this.address, this.note});
  bool get hasPoint => lat != null && lng != null;
}

/// A booking (or a quote) as one side sees it.
class MarketBooking {
  static const String requested = 'requested';
  static const String suggested = 'suggested';
  static const String quoteRequested = 'quote_requested';
  static const String quoted = 'quoted';
  static const String confirmed = 'confirmed';
  static const String completed = 'completed';
  static const String declined = 'declined';
  static const String expired = 'expired';
  static const String cancelled = 'cancelled';
  static const String noShow = 'no_show';
  static const List<String> open = [requested, suggested, quoteRequested, quoted, confirmed];

  final String id;
  final String code;
  /// booking | quote
  final String kind;
  final String status;
  /// client | provider
  final String role;
  final String? itemCode;
  final String itemTitle;
  final String? cover;
  final int durationMinutes;
  final String? shopSlug;
  final String shopName;
  final String? shopLogo;
  final bool shopPrivate;
  final String? clientName;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? suggestedStartsAt;
  /// place | client | online
  final String location;
  final MarketBookingPlace? place;
  final bool areaOnly;
  final String? priceType;
  final double? price;
  final double? quotePrice;
  final String? quoteNote;
  final DateTime? quoteExpiresAt;
  final double? finalPrice;
  final DateTime? respondBy;
  final List<MarketExtra> extras;
  final String? note;
  final String? whenText;
  final String? declineReason;
  final String? cancelledBy;
  final String? cancelReason;
  final bool lateCancel;
  final String? conversationId;
  final String? receiveCode;
  final bool canReview;
  final DateTime? cancelFreeUntil;
  final bool freeToChange;
  final int clientKept;
  final int clientMissed;
  final bool canNoShow;
  final List<String> photos;
  final int? reviewStars;
  final List<String> reviewTags;
  final String? reviewComment;
  final DateTime? createdAt;

  const MarketBooking({
    required this.id, required this.code, this.kind = 'booking', required this.status, this.role = 'client', this.itemCode, this.itemTitle = '',
    this.cover, this.durationMinutes = 60, this.shopSlug, this.shopName = '', this.shopLogo, this.shopPrivate = false, this.clientName,
    this.startsAt, this.endsAt, this.suggestedStartsAt, this.location = 'place', this.place, this.areaOnly = false, this.priceType, this.price,
    this.quotePrice, this.quoteNote, this.quoteExpiresAt, this.finalPrice, this.respondBy, this.extras = const [], this.note, this.whenText,
    this.declineReason, this.cancelledBy, this.cancelReason, this.lateCancel = false, this.conversationId, this.receiveCode, this.canReview = false,
    this.cancelFreeUntil, this.freeToChange = true, this.clientKept = 0, this.clientMissed = 0, this.canNoShow = false, this.photos = const [],
    this.reviewStars, this.reviewTags = const [], this.reviewComment, this.createdAt,
  });

  bool get isProvider => role == 'provider';
  bool get isQuote => kind == 'quote';
  bool get isOpen => open.contains(status);

  factory MarketBooking.fromJson(Map<String, dynamic> j) {
    final item = j['item'] is Map ? Map<String, dynamic>.from(j['item']) : const <String, dynamic>{};
    final shop = j['shop'] is Map ? Map<String, dynamic>.from(j['shop']) : const <String, dynamic>{};
    final place = j['place'] is Map ? Map<String, dynamic>.from(j['place']) : null;
    final record = j['client_record'] is Map ? Map<String, dynamic>.from(j['client_record']) : const <String, dynamic>{};
    final review = j['review'] is Map ? Map<String, dynamic>.from(j['review']) : null;
    return MarketBooking(
      id: '${j['id']}', code: '${j['code'] ?? ''}', kind: _text(j['kind']) ?? 'booking', status: _text(j['status']) ?? requested,
      role: _text(j['role']) ?? 'client', itemCode: _text(item['code']), itemTitle: '${item['title'] ?? ''}', cover: _text(item['cover']),
      durationMinutes: _int(item['duration_minutes']) == 0 ? 60 : _int(item['duration_minutes']),
      shopSlug: _text(shop['slug']), shopName: '${shop['name'] ?? ''}', shopLogo: _text(shop['logo']), shopPrivate: _text(shop['kind']) == 'private',
      clientName: _text(j['client_name']), startsAt: _date(j['starts_at']), endsAt: _date(j['ends_at']), suggestedStartsAt: _date(j['suggested_starts_at']),
      location: _text(j['location']) ?? 'place',
      place: place == null ? null : MarketBookingPlace(lat: _num(place['lat']), lng: _num(place['lng']), address: _text(place['address']), note: _text(place['note'])),
      areaOnly: _bool(j['area_only']), priceType: _text(j['price_type']), price: _num(j['price']), quotePrice: _num(j['quote_price']),
      quoteNote: _text(j['quote_note']), quoteExpiresAt: _date(j['quote_expires_at']), finalPrice: _num(j['final_price']), respondBy: _date(j['respond_by']),
      extras: [for (final e in (j['extras'] as List? ?? const [])) if (e is Map) MarketExtra.fromJson(Map<String, dynamic>.from(e))],
      note: _text(j['note']), whenText: _text(j['when_text']), declineReason: _text(j['decline_reason']), cancelledBy: _text(j['cancelled_by']),
      cancelReason: _text(j['cancel_reason']), lateCancel: _bool(j['late_cancel']), conversationId: _text(j['conversation_id']),
      receiveCode: _text(j['receive_code']), canReview: _bool(j['can_review']), cancelFreeUntil: _date(j['cancel_free_until']),
      freeToChange: j['free_to_change'] == null ? true : _bool(j['free_to_change']),
      clientKept: _int(record['kept']), clientMissed: _int(record['missed']), canNoShow: _bool(j['can_no_show']),
      photos: _strings(j['photos']), reviewStars: review == null ? null : _int(review['stars']), reviewTags: review == null ? const [] : _strings(review['tags']),
      reviewComment: review == null ? null : _text(review['comment']), createdAt: _date(j['created_at']),
    );
  }
}
