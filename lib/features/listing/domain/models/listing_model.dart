// Homes & spaces (backend Modules/PlaceManagement, ListingPresenter): places to
// rent listed by customers, their visits, and saved alerts.

double? _double(dynamic v) => v == null ? null : double.tryParse(v.toString());
int? _int(dynamic v) => v == null ? null : int.tryParse(v.toString());
bool _bool(dynamic v) => v == true || v == 1 || v == '1';
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];

/// The choices and policy numbers the screens need, and whether this user may list.
class ListingMeta {
  final List<String> types;
  final List<String> shortTypes;
  final List<String> neighbourhoods;
  final List<String> water;
  final List<String> power;
  /// Extras an owner can tick (wifi, cctv...), in display order.
  final List<String> amenities;
  final List<String> windows;
  final List<String> reportReasons;
  final int minPhotos;
  final int maxPhotos;
  final int confirmDaysShort;
  final int confirmDaysLong;
  final int strikeLimit;
  final int banDays;
  final String? landmarkName;
  final String? cannotListReason;
  /// Reservation money rules, or null while E-Ride has it switched off.
  final ListingReservationRules? reservations;
  /// What needs me as an owner (visits to answer, a reservation to accept, a place to confirm or fix).
  final int ownerAttention;
  /// What needs me as a seeker (a new time to answer, a reservation to pay, a visit to rate).
  final int seekerAttention;

  int get attention => ownerAttention + seekerAttention;

  const ListingMeta({
    required this.types, required this.shortTypes, required this.neighbourhoods, required this.water, required this.power,
    this.amenities = const [], required this.windows, required this.reportReasons, required this.minPhotos, required this.maxPhotos,
    required this.confirmDaysShort, required this.confirmDaysLong, required this.strikeLimit, required this.banDays,
    this.landmarkName, this.cannotListReason, this.reservations, this.ownerAttention = 0, this.seekerAttention = 0,
  });

  factory ListingMeta.fromJson(Map<String, dynamic> j) => ListingMeta(
        types: _strings(j['types']),
        shortTypes: _strings(j['short_types']),
        neighbourhoods: _strings(j['neighbourhoods']),
        water: _strings(j['water']),
        power: _strings(j['power']),
        amenities: _strings(j['amenities']),
        windows: _strings(j['windows']),
        reportReasons: _strings(j['report_reasons']),
        minPhotos: _int(j['min_photos']) ?? 4,
        maxPhotos: _int(j['max_photos']) ?? 10,
        confirmDaysShort: _int(j['confirm_days_short']) ?? 14,
        confirmDaysLong: _int(j['confirm_days_long']) ?? 30,
        strikeLimit: _int(j['strike_limit']) ?? 3,
        banDays: _int(j['ban_days']) ?? 30,
        landmarkName: j['landmark_name']?.toString(),
        cannotListReason: j['cannot_list_reason']?.toString(),
        reservations: j['reservations'] is Map ? ListingReservationRules.fromJson(Map<String, dynamic>.from(j['reservations'])) : null,
        ownerAttention: j['attention'] is Map ? _int(j['attention']['owner']) ?? 0 : 0,
        seekerAttention: j['attention'] is Map ? _int(j['attention']['seeker']) ?? 0 : 0,
      );

  int confirmDaysFor(String type) => shortTypes.contains(type) ? confirmDaysShort : confirmDaysLong;
}

class ListingReservationRules {
  final double min;
  final double max;
  final double feePercent;
  final int acceptHours;
  final int releaseDays;
  final int moveInDays;
  const ListingReservationRules({required this.min, required this.max, required this.feePercent, required this.acceptHours,
    required this.releaseDays, required this.moveInDays});

  factory ListingReservationRules.fromJson(Map<String, dynamic> j) => ListingReservationRules(
        min: _double(j['min']) ?? 5000, max: _double(j['max']) ?? 200000, feePercent: _double(j['fee_percent']) ?? 5,
        acceptHours: _int(j['accept_hours']) ?? 24, releaseDays: _int(j['release_days']) ?? 3, moveInDays: _int(j['move_in_days']) ?? 30);
}

class ListingPhoto {
  final int id;
  final String url;
  final bool byEride;
  final DateTime? takenAt;
  const ListingPhoto({required this.id, required this.url, required this.byEride, this.takenAt});

  factory ListingPhoto.fromJson(Map<String, dynamic> j) =>
      ListingPhoto(id: _int(j['id']) ?? 0, url: j['url']?.toString() ?? '', byEride: _bool(j['by_eride']), takenAt: _date(j['taken_at']));
}

class Listing {
  final String id;
  final String type;
  final String title;
  final String? description;
  final String neighbourhood;
  final String? address;
  final double latitude;
  final double longitude;
  final int unitsAvailable;
  final bool furnished;
  final double rent;
  final String rentPeriod;
  final double monthlyRent;
  final int? advanceMonths;
  final double? caution;
  final DateTime? availableFrom;
  final String? water;
  final String? power;
  final bool backupPower;
  final String? toilet;
  final String? kitchen;
  final bool fenced;
  final bool security;
  final List<String> amenities;
  final String ownerRole;
  final String? ownerFirstName;
  final String status;
  final bool verified;
  final DateTime? verificationDate;
  final List<String> verificationChecks;
  final DateTime? confirmedAt;
  final bool notConfirmedRecently;
  final List<ListingPhoto> photos;
  final String? landmarkName;
  final int? landmarkDistanceM;
  final bool zoneServed;
  final bool isMine;
  // Owner only.
  final String? reviewNote;
  final DateTime? confirmDueAt;
  final DateTime? takenCheckUntil;
  final String? verificationStatus;
  final DateTime? verificationScheduledFor;
  final int views;
  final int visitsCount;
  final int openVisits;
  final int takingRequests;
  /// Reservation money: the offer seekers see (null when they cannot reserve now).
  final ListingReservationOffer? reservation;
  // Owner only: their reservation settings.
  final bool reservationsOn;
  final double? reservationAmount;
  final String? payoutPhone;
  final String? payoutName;
  final int reservationsWaiting;

  const Listing({
    required this.id, required this.type, required this.title, this.description, required this.neighbourhood, this.address,
    required this.latitude, required this.longitude, required this.unitsAvailable, required this.furnished, required this.rent,
    required this.rentPeriod, required this.monthlyRent, this.advanceMonths, this.caution, this.availableFrom, this.water, this.power,
    required this.backupPower, this.toilet, this.kitchen, required this.fenced, required this.security, this.amenities = const [], required this.ownerRole,
    this.ownerFirstName, required this.status, required this.verified, this.verificationDate, this.verificationChecks = const [],
    this.confirmedAt, required this.notConfirmedRecently, this.photos = const [], this.landmarkName, this.landmarkDistanceM,
    required this.zoneServed, required this.isMine, this.reviewNote, this.confirmDueAt, this.takenCheckUntil, this.verificationStatus,
    this.verificationScheduledFor, this.views = 0, this.visitsCount = 0, this.openVisits = 0, this.takingRequests = 0,
    this.reservation, this.reservationsOn = false, this.reservationAmount, this.payoutPhone, this.payoutName, this.reservationsWaiting = 0,
  });

  factory Listing.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic>? verification = j['verification'] is Map ? Map<String, dynamic>.from(j['verification']) : null;
    final Map<String, dynamic>? landmark = j['landmark'] is Map ? Map<String, dynamic>.from(j['landmark']) : null;
    return Listing(
      id: j['id'].toString(),
      type: j['type']?.toString() ?? 'room',
      title: j['title']?.toString() ?? '',
      description: j['description']?.toString(),
      neighbourhood: j['neighbourhood']?.toString() ?? '',
      address: j['address']?.toString(),
      latitude: _double(j['latitude']) ?? 0,
      longitude: _double(j['longitude']) ?? 0,
      unitsAvailable: _int(j['units_available']) ?? 0,
      furnished: _bool(j['furnished']),
      rent: _double(j['rent']) ?? 0,
      rentPeriod: j['rent_period']?.toString() ?? 'month',
      monthlyRent: _double(j['monthly_rent']) ?? 0,
      advanceMonths: _int(j['advance_months']),
      caution: _double(j['caution']),
      availableFrom: _date(j['available_from']),
      water: j['water']?.toString(),
      power: j['power']?.toString(),
      backupPower: _bool(j['backup_power']),
      toilet: j['toilet']?.toString(),
      kitchen: j['kitchen']?.toString(),
      fenced: _bool(j['fenced']),
      security: _bool(j['security']),
      amenities: _strings(j['amenities']),
      ownerRole: j['owner_role']?.toString() ?? 'owner',
      ownerFirstName: j['owner_first_name']?.toString(),
      status: j['status']?.toString() ?? 'pending',
      verified: _bool(j['verified']),
      verificationDate: _date(verification?['date']),
      verificationChecks: _strings(verification?['checks']),
      confirmedAt: _date(j['confirmed_at']),
      notConfirmedRecently: _bool(j['not_confirmed_recently']),
      photos: (j['photos'] is List ? j['photos'] as List : const []).map((p) => ListingPhoto.fromJson(Map<String, dynamic>.from(p))).toList(),
      landmarkName: landmark?['name']?.toString(),
      landmarkDistanceM: _int(landmark?['distance_m']),
      zoneServed: _bool(j['zone_served']),
      isMine: _bool(j['is_mine']),
      reviewNote: j['review_note']?.toString(),
      confirmDueAt: _date(j['confirm_due_at']),
      takenCheckUntil: _date(j['taken_check_until']),
      verificationStatus: j['verification_status']?.toString(),
      verificationScheduledFor: _date(j['verification_scheduled_for']),
      views: _int(j['views']) ?? 0,
      visitsCount: _int(j['visits_count']) ?? 0,
      openVisits: _int(j['open_visits']) ?? 0,
      takingRequests: _int(j['taking_requests']) ?? 0,
      reservation: j['reservation'] is Map ? ListingReservationOffer.fromJson(Map<String, dynamic>.from(j['reservation'])) : null,
      reservationsOn: _bool(j['reservations_on']),
      reservationAmount: _double(j['reservation_amount']),
      payoutPhone: j['payout_phone']?.toString(),
      payoutName: j['payout_name']?.toString(),
      reservationsWaiting: _int(j['reservations_waiting']) ?? 0,
    );
  }

  String? get cover => photos.isEmpty ? null : photos.first.url;
  bool get isLive => status == 'live';
  bool get isOpen => status == 'live' || status == 'paused';
  bool get hasEridePhotos => photos.any((p) => p.byEride);
}

/// The listing as a visit carries it.
class ListingVisitPlace {
  final String id;
  final String title;
  final String type;
  final String neighbourhood;
  final String status;
  final double latitude;
  final double longitude;
  final String? address;
  final String? cover;
  /// The reservation amount while seekers can reserve this place through E-Ride, else null.
  final double? reservationAmount;
  const ListingVisitPlace({required this.id, required this.title, required this.type, required this.neighbourhood,
    required this.status, required this.latitude, required this.longitude, this.address, this.cover, this.reservationAmount});

  factory ListingVisitPlace.fromJson(Map<String, dynamic> j) => ListingVisitPlace(
        id: j['id'].toString(), title: j['title']?.toString() ?? '', type: j['type']?.toString() ?? '',
        neighbourhood: j['neighbourhood']?.toString() ?? '', status: j['status']?.toString() ?? '',
        latitude: _double(j['latitude']) ?? 0, longitude: _double(j['longitude']) ?? 0,
        address: j['address']?.toString(), cover: j['cover']?.toString(), reservationAmount: _double(j['reservation_amount']),
      );
}

class ListingVisit {
  final String id;
  final String role; // seeker | owner
  final String status; // requested | proposed | accepted | declined | cancelled | done
  final DateTime? date;
  final String window;
  final DateTime? proposedDate;
  final String? proposedWindow;
  final String? outcome;
  final bool taking;
  final String otherName;
  final String? otherPhone;
  final ListingVisitPlace? listing;
  final ListingReservation? reservation;

  const ListingVisit({required this.id, required this.role, required this.status, this.date, required this.window, this.proposedDate,
    this.proposedWindow, this.outcome, required this.taking, required this.otherName, this.otherPhone, this.listing, this.reservation});

  factory ListingVisit.fromJson(Map<String, dynamic> j) => ListingVisit(
        id: j['id'].toString(),
        role: j['role']?.toString() ?? 'seeker',
        status: j['status']?.toString() ?? 'requested',
        date: _date(j['date']),
        window: j['window']?.toString() ?? 'morning',
        proposedDate: _date(j['proposed_date']),
        proposedWindow: j['proposed_window']?.toString(),
        outcome: j['outcome']?.toString(),
        taking: _bool(j['taking']),
        otherName: j['other_name']?.toString() ?? '',
        otherPhone: j['other_phone']?.toString(),
        listing: j['listing'] is Map ? ListingVisitPlace.fromJson(Map<String, dynamic>.from(j['listing'])) : null,
        reservation: j['reservation'] is Map ? ListingReservation.fromJson(Map<String, dynamic>.from(j['reservation'])) : null,
      );

  bool get asOwner => role == 'owner';
  bool get isOpen => status == 'requested' || status == 'proposed' || status == 'accepted';
  /// The visit day has come: the seeker can say how it went.
  bool get canRate => (status == 'accepted' || status == 'done') && outcome == null && date != null
      && !DateTime.now().isBefore(DateTime(date!.year, date!.month, date!.day));

  /// The seeker can start a reservation: the owner accepted the visit, the place takes reservations,
  /// and no reservation is going on.
  bool get canReserve => !asOwner && (status == 'accepted' || status == 'done') && listing?.reservationAmount != null
      && listing?.status == 'live' && (reservation == null || reservation!.isRefunded);
}

/// What a seeker sees before reserving: the amount and the numbers of the rules.
class ListingReservationOffer {
  final double amount;
  final double feePercent;
  final int moveInDays;
  const ListingReservationOffer({required this.amount, required this.feePercent, required this.moveInDays});

  factory ListingReservationOffer.fromJson(Map<String, dynamic> j) => ListingReservationOffer(
        amount: _double(j['amount']) ?? 0, feePercent: _double(j['fee_percent']) ?? 0, moveInDays: _int(j['move_in_days']) ?? 30);
}

/// Money E-Ride sends on mobile money: an owner payout or a seeker refund.
class ListingPayoutInfo {
  final String kind; // owner | refund
  final double amount;
  final String phone;
  final String status; // pending | paid
  final String? reference;
  final DateTime? paidAt;
  const ListingPayoutInfo({required this.kind, required this.amount, required this.phone, required this.status, this.reference, this.paidAt});

  factory ListingPayoutInfo.fromJson(Map<String, dynamic> j) => ListingPayoutInfo(
        kind: j['kind']?.toString() ?? 'owner', amount: _double(j['amount']) ?? 0, phone: j['phone']?.toString() ?? '',
        status: j['status']?.toString() ?? 'pending', reference: j['reference']?.toString(), paidAt: _date(j['paid_at']));

  bool get isPaid => status == 'paid';
}

/// Reservation money held by E-Ride (backend ListingPresenter::reservation).
/// awaiting (paying), held (owner answers), reserved (until move-in), released;
/// or lapsed, refunded, or problem (E-Ride decides).
class ListingReservation {
  final String id;
  final String status;
  final double amount;
  final double? ownerAmount;
  final double? fee;
  final double refundedAmount;
  final String? paymentMethod;
  final DateTime? moveInDate;
  final DateTime? payDueAt;
  final DateTime? acceptDueAt;
  final DateTime? releaseDueAt;
  final String? problemBy;
  final String? problemReason;
  final String? decisionNote;
  final String? closedReason;
  final ListingPayoutInfo? payout;
  final bool canRefundToMomo;

  const ListingReservation({required this.id, required this.status, required this.amount, this.ownerAmount, this.fee,
    this.refundedAmount = 0, this.paymentMethod, this.moveInDate, this.payDueAt, this.acceptDueAt, this.releaseDueAt, this.problemBy,
    this.problemReason, this.decisionNote, this.closedReason, this.payout, this.canRefundToMomo = false});

  factory ListingReservation.fromJson(Map<String, dynamic> j) => ListingReservation(
        id: j['id'].toString(),
        status: j['status']?.toString() ?? 'awaiting',
        amount: _double(j['amount']) ?? 0,
        ownerAmount: _double(j['owner_amount']),
        fee: _double(j['fee']),
        refundedAmount: _double(j['refunded_amount']) ?? 0,
        paymentMethod: j['payment_method']?.toString(),
        moveInDate: _date(j['move_in_date']),
        payDueAt: _date(j['pay_due_at']),
        acceptDueAt: _date(j['accept_due_at']),
        releaseDueAt: _date(j['release_due_at']),
        problemBy: j['problem_by']?.toString(),
        problemReason: j['problem_reason']?.toString(),
        decisionNote: j['decision_note']?.toString(),
        closedReason: j['closed_reason']?.toString(),
        payout: j['payout'] is Map ? ListingPayoutInfo.fromJson(Map<String, dynamic>.from(j['payout'])) : null,
        canRefundToMomo: _bool(j['can_refund_to_momo']),
      );

  bool get isAwaiting => status == 'awaiting';
  bool get isHeld => status == 'held';
  bool get isReserved => status == 'reserved';
  bool get isProblem => status == 'problem';
  bool get isReleased => status == 'released';
  bool get isRefunded => status == 'refunded';
  /// The move-in date has come (from then the owner may say the seeker did not come).
  bool get moveInReached => moveInDate != null && !DateTime.now().isBefore(DateTime(moveInDate!.year, moveInDate!.month, moveInDate!.day));
}

class ListingAlert {
  final int id;
  final String? type;
  final String? neighbourhood;
  final double? maxMonthlyRent;
  final bool verifiedOnly;
  const ListingAlert({required this.id, this.type, this.neighbourhood, this.maxMonthlyRent, required this.verifiedOnly});

  factory ListingAlert.fromJson(Map<String, dynamic> j) => ListingAlert(
        id: _int(j['id']) ?? 0, type: j['type']?.toString(), neighbourhood: j['neighbourhood']?.toString(),
        maxMonthlyRent: _double(j['max_monthly_rent']), verifiedOnly: _bool(j['verified_only']),
      );
}

/// The seeker's search filters.
class ListingFilters {
  final String? type;
  final String? neighbourhood;
  final double? maxRent;
  final bool verifiedOnly;
  final bool water;
  final bool backupPower;
  /// Must have all of these extras.
  final List<String> amenities;
  const ListingFilters({this.type, this.neighbourhood, this.maxRent, this.verifiedOnly = false, this.water = false, this.backupPower = false,
    this.amenities = const []});

  ListingFilters copyWith({String? type, String? neighbourhood, double? maxRent, bool? verifiedOnly, bool? water, bool? backupPower,
      List<String>? amenities, bool clearType = false, bool clearArea = false, bool clearRent = false}) =>
      ListingFilters(
        type: clearType ? null : (type ?? this.type),
        neighbourhood: clearArea ? null : (neighbourhood ?? this.neighbourhood),
        maxRent: clearRent ? null : (maxRent ?? this.maxRent),
        verifiedOnly: verifiedOnly ?? this.verifiedOnly,
        water: water ?? this.water,
        backupPower: backupPower ?? this.backupPower,
        amenities: amenities ?? this.amenities,
      );

  Map<String, dynamic> toQuery() => {
        if (type != null) 'type': type,
        if (neighbourhood != null) 'neighbourhood': neighbourhood,
        if (maxRent != null) 'max_rent': maxRent!.round(),
        if (verifiedOnly) 'verified': 1,
        if (water) 'water': 1,
        if (backupPower) 'backup_power': 1,
        if (amenities.isNotEmpty) 'amenities': amenities.join(','),
      };

  bool get isEmpty => type == null && neighbourhood == null && maxRent == null && !verifiedOnly && !water && !backupPower && amenities.isEmpty;
}
