import 'package:ride_sharing_user_app/features/explore/domain/models/explore_place_model.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

/// The city and tour guide. Mirrors the backend's GuideService
/// (Modules/PlaceManagement/Service/GuideService.php).

double? _double(dynamic v) => v == null ? null : double.tryParse('$v');
int? _int(dynamic v) => v == null ? null : int.tryParse('$v');
String? _text(dynamic v) {
  final String? s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

List<Map<String, dynamic>> _maps(dynamic v) =>
    ((v as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

/// A Things to do kind: an Explore category of the group (eat, swim, party, visit, market).
class ThingKind {
  final String key;
  final String name;
  final String icon;
  const ThingKind({required this.key, required this.name, required this.icon});

  factory ThingKind.fromJson(Map<String, dynamic> json) => ThingKind(
        key: json['key']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        icon: json['icon']?.toString() ?? 'place',
      );
}

/// An estimate for one ride: road km, minutes, and the zone's cheapest fare.
class RideLeg {
  final double km;
  final int minutes;
  final double? fare;
  const RideLeg({required this.km, required this.minutes, this.fare});

  static RideLeg? fromJson(dynamic json) {
    if (json is! Map) return null;
    return RideLeg(km: _double(json['km']) ?? 0, minutes: _int(json['minutes']) ?? 0, fare: _double(json['fare']));
  }
}

/// The team's checked guide of a place.
class PlaceGuide {
  final String? story;
  final String? bestTime;
  final String? tips;
  final int? stayMinutes;
  /// Null unknown, 0 free.
  final int? entryFee;
  const PlaceGuide({this.story, this.bestTime, this.tips, this.stayMinutes, this.entryFee});

  static PlaceGuide? fromJson(dynamic json) {
    if (json is! Map) return null;
    return PlaceGuide(
      story: _text(json['story']),
      bestTime: _text(json['best_time']),
      tips: _text(json['tips']),
      stayMinutes: _int(json['stay_minutes']),
      entryFee: _int(json['entry_fee']),
    );
  }

  List<String> get tipLines => (tips ?? '').split('\n').map((l) => l.replaceFirst(RegExp(r'^[-*•\s]+'), '').trim()).where((l) => l.isNotEmpty).toList();
}

class PlaceReview {
  final String id;
  final String name;
  final int stars;
  final String? comment;
  final DateTime? date;
  const PlaceReview({required this.id, required this.name, required this.stars, this.comment, this.date});

  factory PlaceReview.fromJson(Map<String, dynamic> json) => PlaceReview(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        stars: _int(json['stars']) ?? 0,
        comment: _text(json['comment']),
        date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) : null,
      );
}

/// Everything about one place beyond its card (GET places/{id}/guide).
class PlaceGuideInfo {
  final String id;
  final String? verifiedId;
  final PlaceGuide? guide;
  final double? erideRating;
  final int erideRatings;
  final List<PlaceReview> reviews;
  final int? myStars;
  final String? myComment;
  final List<TourCard> tours;
  /// Verified Things to do nearby, each with a ride estimate from this place.
  final List<NearbyThing> nearby;

  const PlaceGuideInfo({
    required this.id,
    this.verifiedId,
    this.guide,
    this.erideRating,
    this.erideRatings = 0,
    this.reviews = const [],
    this.myStars,
    this.myComment,
    this.tours = const [],
    this.nearby = const [],
  });

  factory PlaceGuideInfo.fromJson(Map<String, dynamic> json) {
    final Map? mine = json['my_rating'] is Map ? json['my_rating'] as Map : null;
    return PlaceGuideInfo(
      id: json['id']?.toString() ?? '',
      verifiedId: _text(json['verified_id']),
      guide: PlaceGuide.fromJson(json['guide']),
      erideRating: _double(json['eride_rating']),
      erideRatings: _int(json['eride_ratings']) ?? 0,
      reviews: _maps(json['reviews']).map(PlaceReview.fromJson).toList(),
      myStars: _int(mine?['stars']),
      myComment: _text(mine?['comment']),
      tours: _maps(json['tours']).map(TourCard.fromJson).toList(),
      nearby: _maps(json['nearby']).map(NearbyThing.fromJson).toList(),
    );
  }
}

class NearbyThing {
  final ExplorePlace place;
  final RideLeg? ride;
  const NearbyThing({required this.place, this.ride});

  factory NearbyThing.fromJson(Map<String, dynamic> json) => NearbyThing(place: ExplorePlace.fromJson(json), ride: RideLeg.fromJson(json['ride']));
}

/// A tour as a card (lists).
class TourCard {
  final String id;
  final String slug;
  final String title;
  final String? intro;
  final int stopsCount;
  final List<String> stopNames;
  final int minutes;
  final double rideKm;
  final double? rideFare;
  final String? cover;
  final bool isFeatured;

  const TourCard({
    required this.id,
    required this.slug,
    required this.title,
    this.intro,
    this.stopsCount = 0,
    this.stopNames = const [],
    this.minutes = 0,
    this.rideKm = 0,
    this.rideFare,
    this.cover,
    this.isFeatured = false,
  });

  factory TourCard.fromJson(Map<String, dynamic> json) {
    final String? cover = _text(json['cover']);
    return TourCard(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      intro: _text(json['intro']),
      stopsCount: _int(json['stops_count']) ?? 0,
      stopNames: ((json['stop_names'] as List?) ?? []).map((e) => e.toString()).toList(),
      minutes: _int(json['minutes']) ?? 0,
      rideKm: _double(json['ride_km']) ?? 0,
      rideFare: _double(json['ride_fare']),
      cover: cover == null ? null : (cover.startsWith('/') ? '${AppConstants.baseUrl}$cover' : cover),
      isFeatured: json['is_featured'] == true,
    );
  }
}

class TourStopItem {
  final int position;
  final String? note;
  final int stayMinutes;
  final ExplorePlace place;
  final PlaceGuide? guide;
  /// The ride to this stop from the stop before (the first: from where the person is).
  final RideLeg? ride;

  const TourStopItem({required this.position, this.note, required this.stayMinutes, required this.place, this.guide, this.ride});

  factory TourStopItem.fromJson(Map<String, dynamic> json) => TourStopItem(
        position: _int(json['position']) ?? 0,
        note: _text(json['note']),
        stayMinutes: _int(json['stay_minutes']) ?? 45,
        place: ExplorePlace.fromJson(Map<String, dynamic>.from(json['place'] as Map)),
        guide: PlaceGuide.fromJson(json['guide']),
        ride: RideLeg.fromJson(json['ride']),
      );
}

class TourDetail {
  final TourCard card;
  final String? city;
  final List<TourStopItem> stops;
  const TourDetail({required this.card, this.city, this.stops = const []});

  factory TourDetail.fromJson(Map<String, dynamic> json) => TourDetail(
        card: TourCard.fromJson(json),
        city: _text(json['city']),
        stops: _maps(json['stops']).where((m) => m['place'] is Map).map(TourStopItem.fromJson).toList(),
      );
}

/// Things to do home (GET things).
class ThingsHome {
  final bool enabled;
  final List<ThingKind> kinds;
  final List<ExplorePlace> picks;
  final List<TourCard> tours;
  final String? city;
  const ThingsHome({this.enabled = false, this.kinds = const [], this.picks = const [], this.tours = const [], this.city});

  factory ThingsHome.fromJson(Map<String, dynamic> json) => ThingsHome(
        enabled: json['enabled'] == true,
        kinds: _maps(json['kinds']).map(ThingKind.fromJson).toList(),
        picks: _maps(json['picks']).map(ExplorePlace.fromJson).toList(),
        tours: _maps(json['tours']).map(TourCard.fromJson).toList(),
        city: _text(json['city']),
      );
}

/// A tour (or a one-place visit) the person is taking, kept on the phone.
/// [index] is the stop they are riding to or are at.
class TourRun {
  final String? tourId;
  final String title;
  final List<ExplorePlace> stops;
  final int index;
  final DateTime startedAt;

  const TourRun({this.tourId, required this.title, required this.stops, this.index = 0, required this.startedAt});

  bool get isVisit => tourId == null;
  bool get isLast => index >= stops.length - 1;
  ExplorePlace get current => stops[index.clamp(0, stops.length - 1)];
  ExplorePlace? get next => isLast ? null : stops[index + 1];

  TourRun copyWith({int? index}) => TourRun(tourId: tourId, title: title, stops: stops, index: index ?? this.index, startedAt: startedAt);

  Map<String, dynamic> toJson() => {
        'tour_id': tourId,
        'title': title,
        'stops': stops.map((s) => s.toRunJson()).toList(),
        'index': index,
        'started_at': startedAt.toIso8601String(),
      };

  static TourRun? fromJson(dynamic json) {
    if (json is! Map) return null;
    final List<ExplorePlace> stops = _maps(json['stops']).map(ExplorePlace.fromJson).toList();
    final DateTime? started = json['started_at'] != null ? DateTime.tryParse(json['started_at'].toString()) : null;
    if (stops.isEmpty || started == null) return null;
    return TourRun(
      tourId: _text(json['tour_id']),
      title: json['title']?.toString() ?? '',
      stops: stops,
      index: (_int(json['index']) ?? 0).clamp(0, stops.length - 1),
      startedAt: started,
    );
  }
}
