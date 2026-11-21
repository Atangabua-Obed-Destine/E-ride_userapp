import 'package:get/get.dart';

/// A partner restaurant or shop (GET /api/customer/stores). For a brand with
/// several branches, [id] is the kitchen serving the customer (the list card
/// carries the brand's id), [name] the brand and [branchName] the branch.
class StoreModel {
  String? id;
  String? brandId;
  String? branchName;
  int branchCount;
  String? name;
  String? type;
  String? description;
  String? logo;
  String? cover;
  String? address;
  double? latitude;
  double? longitude;
  String? phone;
  bool openNow;
  String? opensAt;
  String? closesAt;
  int prepMinutes;
  double minOrderAmount;
  double? distanceKm;
  /// Average customer rating (1-5), null until someone rates the store.
  double? rating;
  int ratingCount;
  /// How an order can be had here: delivery, dine_in (eat there), pickup (collect).
  List<String> ways;
  /// The public page people share ([domain]/f/SLUG).
  String? slug;
  String? link;

  StoreModel({
    this.id,
    this.brandId,
    this.branchName,
    this.branchCount = 1,
    this.name,
    this.type,
    this.description,
    this.logo,
    this.cover,
    this.address,
    this.latitude,
    this.longitude,
    this.phone,
    this.openNow = false,
    this.opensAt,
    this.closesAt,
    this.prepMinutes = 20,
    this.minOrderAmount = 0,
    this.distanceKm,
    this.rating,
    this.ratingCount = 0,
    this.ways = const ['delivery'],
    this.slug,
    this.link,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    final hours = json['today_hours'];
    return StoreModel(
      id: json['id']?.toString(),
      brandId: json['brand_id']?.toString(),
      branchName: json['branch_name'],
      branchCount: int.tryParse('${json['branch_count']}') ?? 1,
      name: json['name'],
      type: json['type'],
      description: json['description'],
      logo: json['logo'],
      cover: json['cover'],
      address: json['address'],
      latitude: double.tryParse('${json['latitude']}'),
      longitude: double.tryParse('${json['longitude']}'),
      phone: json['phone'],
      openNow: json['open_now'] == true,
      opensAt: hours is Map ? hours['open'] : null,
      closesAt: hours is Map ? hours['close'] : null,
      prepMinutes: int.tryParse('${json['prep_minutes']}') ?? 20,
      minOrderAmount: double.tryParse('${json['min_order_amount']}') ?? 0,
      distanceKm: double.tryParse('${json['distance_km']}'),
      rating: double.tryParse('${json['rating']}'),
      ratingCount: int.tryParse('${json['rating_count']}') ?? 0,
      ways: (json['ways'] as List?)?.map((e) => '$e').toList() ?? const ['delivery'],
      slug: json['slug']?.toString(),
      link: json['link']?.toString(),
    );
  }

  bool get offersDineIn => ways.contains('dine_in');
  bool get offersPickup => ways.contains('pickup');

  bool get isShop => type == 'shop';

  /// What the saved cart keeps of the store.
  Map<String, dynamic> toJson() => {
        'id': id, 'brand_id': brandId, 'branch_name': branchName, 'branch_count': branchCount, 'name': name, 'type': type,
        'description': description, 'logo': logo, 'cover': cover, 'address': address, 'latitude': latitude, 'longitude': longitude,
        'phone': phone, 'open_now': openNow, 'prep_minutes': prepMinutes, 'min_order_amount': minOrderAmount, 'ways': ways,
        'slug': slug, 'link': link,
      };

  /// "Romz · Mile 6" when it names a branch.
  String get displayName => (branchName != null && branchName!.isNotEmpty) ? '${name ?? ''} · $branchName' : (name ?? '');
}

/// One branch of a brand: in the "Cooking at" banner (with [reason]) and in the
/// "Choose a branch" sheet.
class StoreBranch {
  String id;
  String name;
  String? address;
  double? distanceKm;
  double? deliveryFee;
  bool openNow;
  bool delivers;
  String? opensAt;
  String? closesAt;
  bool selected;
  /// Why the app picked it: preferred, preferred_closed, nearest_open,
  /// nearest_closed, only_open, all_closed, no_location.
  String? reason;
  /// The branch that was passed over (closed or out of range), for the reason line.
  String? skipped;
  int count;

  StoreBranch({required this.id, required this.name, this.address, this.distanceKm, this.deliveryFee, this.openNow = true,
      this.delivers = true, this.opensAt, this.closesAt, this.selected = false, this.reason, this.skipped, this.count = 1});

  factory StoreBranch.fromJson(Map<String, dynamic> json) {
    final hours = json['today_hours'];
    return StoreBranch(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      address: json['address'],
      distanceKm: double.tryParse('${json['distance_km']}'),
      deliveryFee: double.tryParse('${json['delivery_fee']}'),
      openNow: json['open_now'] != false,
      delivers: json['delivers'] != false,
      opensAt: hours is Map ? hours['open'] : null,
      closesAt: hours is Map ? hours['close'] : null,
      selected: json['selected'] == true,
      reason: json['reason'],
      skipped: json['skipped'],
      count: int.tryParse('${json['count']}') ?? 1,
    );
  }
}

/// Another open branch that has a dish this branch can't serve now.
class MenuElsewhere {
  String branchId;
  String branchName;
  double? distanceKm;
  /// How many more branches have it.
  int more;

  MenuElsewhere({required this.branchId, required this.branchName, this.distanceKm, this.more = 0});

  factory MenuElsewhere.fromJson(Map<String, dynamic> json) => MenuElsewhere(
        branchId: json['id'].toString(),
        branchName: json['name'] ?? '',
        distanceKm: double.tryParse('${json['distance_km']}'),
        more: int.tryParse('${json['more']}') ?? 0,
      );
}

/// A store and its products matching a search across every store (GET stores/search).
class StoreSearchGroup {
  final StoreModel store;
  final List<MenuItem> items;
  final Map<String, String> sections;
  final int count;
  const StoreSearchGroup({required this.store, required this.items, this.sections = const {}, this.count = 0});

  factory StoreSearchGroup.fromJson(Map<String, dynamic> json) {
    final List raw = (json['items'] as List?) ?? [];
    return StoreSearchGroup(
      store: StoreModel.fromJson(Map<String, dynamic>.from(json['store'] as Map)),
      items: raw.map((e) => MenuItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      sections: {for (final e in raw) if (e is Map && e['section'] != null) '${e['id']}': '${e['section']}'},
      count: int.tryParse('${json['count']}') ?? 0,
    );
  }
}

class MenuSection {
  String? id;
  String name;
  /// "section", or "not_today" for the last section: dishes served another day or at another time.
  String kind;
  List<MenuItem> items;

  MenuSection({this.id, required this.name, this.kind = 'section', required this.items});

  factory MenuSection.fromJson(Map<String, dynamic> json) => MenuSection(
        id: json['id']?.toString(),
        name: json['name'] ?? '',
        kind: json['kind'] ?? 'section',
        items: ((json['items'] as List?) ?? []).map((e) => MenuItem.fromJson(e)).toList(),
      );

  bool get isNotToday => kind == 'not_today';
}

class MenuItem {
  String id;
  String name;
  String? description;
  double price;
  String? image;
  /// Can be ordered right now.
  bool isAvailable;
  /// available, sold_out (today), later (served later today) or not_today.
  String state;
  /// Days served (mon ... sun), null for every day.
  List<String>? servedDays;
  String? servedFrom;
  String? servedUntil;
  /// Sold out here or not made here, but available now at another branch.
  MenuElsewhere? elsewhere;

  MenuItem({required this.id, required this.name, this.description, required this.price, this.image, this.isAvailable = true,
      String? state, this.servedDays, this.servedFrom, this.servedUntil, this.elsewhere})
      : state = state ?? (isAvailable ? 'available' : 'sold_out');

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'].toString(),
        name: json['name'] ?? '',
        description: json['description'],
        price: double.tryParse('${json['price']}') ?? 0,
        image: json['image'],
        isAvailable: json['is_available'] == true,
        state: json['state'],
        servedDays: (json['served_days'] as List?)?.map((e) => '$e').toList(),
        servedFrom: json['served_from'],
        servedUntil: json['served_until'],
        elsewhere: json['elsewhere'] is Map ? MenuElsewhere.fromJson(Map<String, dynamic>.from(json['elsewhere'])) : null,
      );

  /// What the saved cart keeps of the dish.
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'description': description, 'price': price, 'image': image,
        'is_available': isAvailable, 'state': state,
      };

  static const List<String> _days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  /// Why it can't be ordered now, for the menu: "Sold out today", "From 18:00",
  /// "Mon, Thu · 18:00–22:00". Null when it can be ordered.
  String? get unavailableNote {
    final window = (servedFrom != null && servedUntil != null) ? '$servedFrom–$servedUntil' : null;
    switch (state) {
      case 'available':
        return null;
      case 'sold_out':
        return 'sold_out_today'.tr;
      case 'not_here':
        return 'not_at_this_branch'.tr;
      case 'later':
        return 'served_from_time'.trParams({'time': servedFrom ?? ''});
      case 'not_today':
        final days = servedDays;
        final today = _days[DateTime.now().weekday - 1];
        if (days != null && !days.contains(today)) {
          if (days.isEmpty) return 'not_served_now'.tr;
          final names = days.map((d) => 'day_short_$d'.tr).join(', ');
          return window == null ? names : '$names · $window';
        }
        return window == null ? 'not_served_now'.tr : 'served_hours'.trParams({'hours': window});
      default:
        return isAvailable ? null : 'sold_out'.tr;
    }
  }
}
