import 'package:ride_sharing_user_app/features/hotel/domain/models/hotel_models.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

/// An Explore Bamenda category (GET /api/customer/explore).
class ExploreCategory {
  static const String stay = 'stay';
  static const String pharmacy = 'pharmacy';
  static const String health = 'health';
  /// Homes & spaces: customers' listings, with their own screens (features/listing).
  static const String homes = 'homes';
  /// Things to do: one tile for the tour guide's categories (eat, swim, party, sights, markets).
  static const String things = 'things';

  final String key;
  final String name;
  /// One of the backend's PlaceCategory::ICONS; ExploreIcons draws it.
  final String icon;
  /// Places to stay show a price per night.
  final bool hasPrice;

  const ExploreCategory({required this.key, required this.name, required this.icon, this.hasPrice = false});

  factory ExploreCategory.fromJson(Map<String, dynamic> json) => ExploreCategory(
        key: json['key']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        icon: json['icon']?.toString() ?? 'place',
        hasPrice: json['has_price'] == true,
      );
}

/// A place in Explore Bamenda, from either source. Mirrors the backend's
/// PlacePresenter (Modules/PlaceManagement/Transformers/PlacePresenter.php).
///
/// [isVerified] places are E-Ride's own listings (photos, contacts, and for
/// places to stay prices and amenities). The others are live Google Places
/// results: their rating, photos, hours and address come from Google and must
/// be shown with Google's attribution.
class ExplorePlace {
  static const String hotel = 'hotel';
  static const String guestHouse = 'guest_house';
  static const String lodging = 'lodging';

  final String id;
  final String source;
  final String? googlePlaceId;
  final String name;
  final String exploreCategory;
  /// The place's type within its category: hotel, pharmacy, hospital, atm...
  final String category;
  final String? description;
  final String address;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final String? phone;
  final String? whatsapp;
  final String? website;
  final String? mapsUrl;
  final double? rating;
  final int reviews;
  final double? priceMin;
  final double? priceMax;
  final List<String> amenities;
  final List<PlacePhoto> photos;
  final String? checkIn;
  final String? checkOut;
  /// Open around the clock (a hotel's 24h reception, a 24h pharmacy).
  final bool reception24h;
  /// From Google's current hours; null when unknown.
  final bool? openNow;
  /// "Monday: 8:00 AM - 6:00 PM", one line per day, when Google has them.
  final List<String> hours;
  /// A pharmacy on this week's on-duty rota (pharmacie de garde).
  final bool onDuty;
  final DateTime? onDutyUntil;
  final bool isFeatured;
  /// A partner hotel: free rooms for the dates, answer time (null for any other place).
  final HotelPartnerInfo? partner;
  /// E-Ride riders' ratings (Things to do), next to Google's.
  final double? erideRating;
  final int erideRatings;
  final String? erideQuote;
  /// The team checked and published a guide for this place.
  final bool hasGuide;
  final int? stayMinutes;
  /// Entry fee: null unknown, 0 free.
  final int? entryFee;
  /// The E-Ride partner store (Food & Shops) this place is: the app offers "Order".
  final PartnerStore? partnerStore;

  const ExplorePlace({
    required this.id,
    required this.source,
    required this.name,
    required this.category,
    required this.address,
    this.exploreCategory = ExploreCategory.stay,
    this.googlePlaceId,
    this.description,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.phone,
    this.whatsapp,
    this.website,
    this.mapsUrl,
    this.rating,
    this.reviews = 0,
    this.priceMin,
    this.priceMax,
    this.amenities = const [],
    this.photos = const [],
    this.checkIn,
    this.checkOut,
    this.reception24h = false,
    this.openNow,
    this.hours = const [],
    this.onDuty = false,
    this.onDutyUntil,
    this.isFeatured = false,
    this.partner,
    this.erideRating,
    this.erideRatings = 0,
    this.erideQuote,
    this.hasGuide = false,
    this.stayMinutes,
    this.entryFee,
    this.partnerStore,
  });

  bool get isVerified => source == 'eride';
  bool get hasLocation => latitude != null && longitude != null;
  bool get hasPrice => (priceMin ?? 0) > 0 || (priceMax ?? 0) > 0;
  bool get hasRating => rating != null && reviews > 0;
  bool get hasErideRating => erideRating != null && erideRatings > 0;
  String? get coverThumb => photos.isEmpty ? null : photos.first.thumb;

  static double? _double(dynamic v) => v == null ? null : double.tryParse('$v');
  static String? _text(dynamic v) {
    final String? s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory ExplorePlace.fromJson(Map<String, dynamic> json) => ExplorePlace(
        id: json['id'].toString(),
        source: json['source']?.toString() ?? 'google',
        googlePlaceId: _text(json['google_place_id']),
        name: json['name']?.toString() ?? '',
        exploreCategory: json['explore_category']?.toString() ?? ExploreCategory.stay,
        category: json['category']?.toString() ?? lodging,
        description: _text(json['description']),
        address: json['address']?.toString() ?? '',
        latitude: _double(json['latitude']),
        longitude: _double(json['longitude']),
        distanceKm: _double(json['distance_km']),
        phone: _text(json['phone']),
        whatsapp: _text(json['whatsapp']),
        website: _text(json['website']),
        mapsUrl: _text(json['maps_url']),
        rating: _double(json['rating']),
        reviews: int.tryParse('${json['reviews']}') ?? 0,
        priceMin: _double(json['price_min']),
        priceMax: _double(json['price_max']),
        amenities: ((json['amenities'] as List?) ?? []).map((e) => e.toString()).toList(),
        photos: ((json['photos'] as List?) ?? []).whereType<Map>().map((e) => PlacePhoto.fromJson(Map<String, dynamic>.from(e))).toList(),
        checkIn: _text(json['check_in']),
        checkOut: _text(json['check_out']),
        reception24h: json['reception_24h'] == true,
        openNow: json['open_now'] is bool ? json['open_now'] as bool : null,
        hours: ((json['hours'] as List?) ?? []).map((e) => e.toString()).toList(),
        onDuty: json['on_duty'] == true,
        onDutyUntil: json['on_duty_until'] != null ? DateTime.tryParse(json['on_duty_until'].toString()) : null,
        isFeatured: json['is_featured'] == true,
        partner: json['partner'] is Map ? HotelPartnerInfo.fromJson(Map<String, dynamic>.from(json['partner'])) : null,
        erideRating: _double(json['eride_rating']),
        erideRatings: int.tryParse('${json['eride_ratings']}') ?? 0,
        erideQuote: _text(json['eride_quote']),
        hasGuide: json['has_guide'] == true,
        stayMinutes: int.tryParse('${json['stay_minutes']}'),
        entryFee: int.tryParse('${json['entry_fee']}'),
        partnerStore: json['partner_store'] is Map ? PartnerStore.fromJson(Map<String, dynamic>.from(json['partner_store'])) : null,
      );

  /// What a tour run keeps on the phone about a stop (enough to ride there and show it).
  Map<String, dynamic> toRunJson() => {
        'id': id,
        'source': source,
        'google_place_id': googlePlaceId,
        'name': name,
        'explore_category': exploreCategory,
        'category': category,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'photos': photos.take(1).map((p) => {'url': p.url, 'thumb': p.thumb, 'author': p.author, 'author_uri': p.authorUri}).toList(),
      };
}

/// A Food & Shops partner behind a place.
class PartnerStore {
  final String id;
  final String name;
  final bool isShop;
  final bool openNow;
  const PartnerStore({required this.id, required this.name, this.isShop = false, this.openNow = false});

  factory PartnerStore.fromJson(Map<String, dynamic> json) => PartnerStore(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        isShop: json['type'] == 'shop',
        openNow: json['open_now'] == true,
      );
}

class PlacePhoto {
  final String url;
  final String thumb;
  /// Who took a Google photo. Google requires it to be shown with the photo.
  final String? author;
  final String? authorUri;

  const PlacePhoto({required this.url, required this.thumb, this.author, this.authorUri});

  /// Google photos come back as a path on our own server (a signed proxy
  /// link), so the base URL is added here; verified photos are already full URLs.
  static String _absolute(String url) => url.startsWith('/') ? '${AppConstants.baseUrl}$url' : url;

  factory PlacePhoto.fromJson(Map<String, dynamic> json) {
    final String url = _absolute(json['url']?.toString() ?? '');
    return PlacePhoto(
      url: url,
      thumb: json['thumb'] != null ? _absolute(json['thumb'].toString()) : url,
      author: json['author']?.toString(),
      authorUri: json['author_uri']?.toString(),
    );
  }
}

/// GET /api/customer/explore/{category}
class ExploreResult {
  final bool enabled;
  final ExploreCategory? category;
  final List<ExplorePlace> onDuty;
  final String? notice;
  final List<ExplorePlace> verified;
  final List<ExplorePlace> topRated;
  final List<ExplorePlace> nearby;
  final bool googleAvailable;
  final double? radiusKm;
  final bool hotelPartners;

  const ExploreResult({
    required this.enabled,
    this.category,
    this.onDuty = const [],
    this.notice,
    this.verified = const [],
    this.topRated = const [],
    this.nearby = const [],
    this.googleAvailable = false,
    this.radiusKm,
    this.hotelPartners = false,
  });

  static List<ExplorePlace> _list(dynamic v) =>
      ((v as List?) ?? []).whereType<Map>().map((e) => ExplorePlace.fromJson(Map<String, dynamic>.from(e))).toList();

  factory ExploreResult.fromJson(Map<String, dynamic> json) => ExploreResult(
        enabled: json['enabled'] == true,
        category: json['category'] is Map ? ExploreCategory.fromJson(Map<String, dynamic>.from(json['category'])) : null,
        onDuty: _list(json['on_duty']),
        notice: (json['notice']?.toString().trim().isNotEmpty ?? false) ? json['notice'].toString().trim() : null,
        verified: _list(json['verified']),
        topRated: _list(json['top_rated']),
        nearby: _list(json['nearby']),
        googleAvailable: json['google_available'] == true,
        radiusKm: double.tryParse('${json['radius_km']}'),
        hotelPartners: json['hotel_partners'] == true,
      );

  bool get isEmpty => verified.isEmpty && topRated.isEmpty && nearby.isEmpty;
}
