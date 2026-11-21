/// E-Ride Bus Travel: what the customer API returns (api/customer/bus/...).
library;

double? _d(dynamic v) => v == null ? null : double.tryParse('$v');
int _i(dynamic v, [int fallback = 0]) => v == null ? fallback : (int.tryParse('$v') ?? double.tryParse('$v')?.round() ?? fallback);
String? _s(dynamic v) => v == null || '$v'.isEmpty || '$v' == 'null' ? null : '$v';
DateTime? _t(dynamic v) => _s(v) == null ? null : DateTime.tryParse('$v')?.toLocal();
List<Map<String, dynamic>> _list(dynamic v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

/// A lockdown or ghost town an agency declared: who, what, when.
class BusNotice {
  final String? agency;
  final String kind;
  final String? note;
  final String when;
  final bool atRisk;
  BusNotice({this.agency, required this.kind, this.note, required this.when, this.atRisk = false});
  factory BusNotice.fromJson(Map<String, dynamic> j) =>
      BusNotice(agency: _s(j['agency']), kind: '${j['kind'] ?? ''}', note: _s(j['note']), when: '${j['when'] ?? ''}', atRisk: j['at_risk'] == true);
}

/// Whether bus booking is on, and every "from" city with its destinations.
class BusMeta {
  final bool enabled;
  final int maxSeats;
  final int answerMinutes;
  final int payMinutes;
  final int openDays;
  final List<BusRoute> routes;
  final List<BusNotice> notices;
  BusMeta({required this.enabled, required this.maxSeats, required this.answerMinutes, required this.payMinutes, required this.openDays, required this.routes,
    this.notices = const []});

  factory BusMeta.fromJson(Map<String, dynamic> j) => BusMeta(
        enabled: j['enabled'] == true,
        maxSeats: _i(j['max_seats'], 6),
        answerMinutes: _i(j['answer_minutes'], 10),
        payMinutes: _i(j['pay_minutes'], 15),
        openDays: _i(j['open_days'], 14),
        routes: _list(j['routes']).map(BusRoute.fromJson).toList(),
        notices: _list(j['notices']).map(BusNotice.fromJson).toList(),
      );

  BusRoute? routeFrom(String? city) => routes.where((r) => r.from == city).firstOrNull ?? routes.firstOrNull;
}

class BusRoute {
  final String from;
  final List<BusDestinationSummary> to;
  BusRoute({required this.from, required this.to});
  factory BusRoute.fromJson(Map<String, dynamic> j) =>
      BusRoute(from: '${j['from']}', to: _list(j['to']).map(BusDestinationSummary.fromJson).toList());
}

class BusDestinationSummary {
  final String city;
  final double? fromFare;
  final int departures;
  BusDestinationSummary({required this.city, this.fromFare, required this.departures});
  factory BusDestinationSummary.fromJson(Map<String, dynamic> j) =>
      BusDestinationSummary(city: '${j['city']}', fromFare: _d(j['from_fare']), departures: _i(j['departures']));
}

/// The agency's rules passengers see: bags, refunds, ID.
class BusRules {
  final int freeBags;
  final int bagKg;
  final double extraBagFee;
  final bool requireId;
  /// eride (trust E-Ride ID Verified) | agents (agents look at the ID photo) | number (the number only)
  final String idCheck;
  /// app (tickets in the app) | collect (printed at the agency counter)
  final String tickets;
  final int onlineCutoffMinutes;
  /// [hours before departure, % back], most generous first.
  final List<List<int>> cancelTiers;
  BusRules({required this.freeBags, required this.bagKg, required this.extraBagFee, required this.requireId, this.idCheck = 'eride', this.tickets = 'app',
    required this.onlineCutoffMinutes, required this.cancelTiers});

  factory BusRules.fromJson(Map<String, dynamic>? j) => BusRules(
        freeBags: _i(j?['free_bags'], 1),
        bagKg: _i(j?['bag_kg'], 20),
        extraBagFee: _d(j?['extra_bag_fee']) ?? 0,
        requireId: j?['require_id'] != false,
        idCheck: '${j?['id_check'] ?? 'eride'}',
        tickets: '${j?['tickets'] ?? 'app'}',
        onlineCutoffMinutes: _i(j?['online_cutoff_minutes'], 60),
        cancelTiers: (j?['cancel_tiers'] is List ? j!['cancel_tiers'] as List : const [])
            .whereType<List>().map((t) => [_i(t.isNotEmpty ? t[0] : 0), _i(t.length > 1 ? t[1] : 0)]).toList(),
      );

  /// Hours before departure up to which everything comes back, or null.
  int? get freeCancelHours => cancelTiers.where((t) => t[1] >= 100).map((t) => t[0]).firstOrNull;
}

class BusAgency {
  final String id;
  final String name;
  final String? originCity;
  final String? logo;
  final double? rating;
  final int ratingCount;
  final int? answerMinutes;
  final String? googlePlaceId;
  final String? address;
  final double? lat;
  final double? lng;
  final String? phone;
  final String? about;
  final List<String> destinations;
  final DateTime? nextDeparture;
  final BusRules? rules;
  BusAgency({required this.id, required this.name, this.originCity, this.logo, this.rating, this.ratingCount = 0, this.answerMinutes, this.googlePlaceId,
    this.address, this.lat, this.lng, this.phone, this.about, this.destinations = const [], this.nextDeparture, this.rules});

  factory BusAgency.fromJson(Map<String, dynamic> j) => BusAgency(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        originCity: _s(j['origin_city']),
        logo: _s(j['logo']),
        rating: _d(j['rating']),
        ratingCount: _i(j['rating_count']),
        answerMinutes: j['answer_minutes'] == null ? null : _i(j['answer_minutes']),
        googlePlaceId: _s(j['google_place_id']),
        address: _s(j['address']),
        lat: _d(j['lat']),
        lng: _d(j['lng']),
        phone: _s(j['phone']),
        about: _s(j['about']),
        destinations: (j['destinations'] is List ? j['destinations'] as List : const []).map((e) => e is Map ? '${e['city']}' : '$e').toList(),
        nextDeparture: _t(j['next_departure']),
        rules: j['rules'] is Map ? BusRules.fromJson(Map<String, dynamic>.from(j['rules'])) : null,
      );

  bool get hasLocation => lat != null && lng != null;

  /// "VE" for Vatican Express: the logo when there is none.
  String get initials {
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0].substring(0, words[0].length < 2 ? words[0].length : 2).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }
}

class BusDropPoint {
  final String id;
  final String name;
  final double? fare;
  final int? minutesFromStart;
  BusDropPoint({required this.id, required this.name, this.fare, this.minutesFromStart});
  factory BusDropPoint.fromJson(Map<String, dynamic> j) =>
      BusDropPoint(id: '${j['id']}', name: '${j['name']}', fare: _d(j['fare']), minutesFromStart: j['minutes_from_start'] == null ? null : _i(j['minutes_from_start']));
}

/// One departure in a list, or opened with its seat map.
class BusDeparture {
  final String id;
  final BusAgency? agency;
  final String? from;
  final String? to;
  final int? durationMinutes;
  final String className;
  final String classLabel;
  /// fixed | when_full
  final String kind;
  final DateTime? leavesAt;
  final DateTime? arrivesAt;
  final bool delayed;
  final String status;
  final bool instant;
  final int seatsTotal;
  final int seatsLeft;
  final double? fromFare;
  final List<BusDropPoint> dropPoints;
  final String? busName;
  final List<String> amenities;
  final bool bookable;
  final String? closedReason;
  final DateTime? onlineClosesAt;
  // Opened alone.
  final BusAgency? agencyFull;
  final BusSeatMap? seatMap;
  final String? myBookingId;
  final bool onWaitlist;

  BusDeparture({required this.id, this.agency, this.from, this.to, this.durationMinutes, required this.className, required this.classLabel, required this.kind,
    this.leavesAt, this.arrivesAt, this.delayed = false, required this.status, this.instant = false, this.seatsTotal = 0, this.seatsLeft = 0, this.fromFare,
    this.dropPoints = const [], this.busName, this.amenities = const [], this.bookable = false, this.closedReason, this.onlineClosesAt, this.agencyFull,
    this.seatMap, this.myBookingId, this.onWaitlist = false});

  factory BusDeparture.fromJson(Map<String, dynamic> j) => BusDeparture(
        id: '${j['id']}',
        agency: j['agency'] is Map ? BusAgency.fromJson(Map<String, dynamic>.from(j['agency'])) : null,
        from: _s(j['from']),
        to: _s(j['to']),
        durationMinutes: j['duration_minutes'] == null ? null : _i(j['duration_minutes']),
        className: '${j['class'] ?? 'classic'}',
        classLabel: '${j['class_label'] ?? ''}',
        kind: '${j['kind'] ?? 'fixed'}',
        leavesAt: _t(j['leaves_at']),
        arrivesAt: _t(j['arrives_at']),
        delayed: j['delayed'] == true,
        status: '${j['status'] ?? 'scheduled'}',
        instant: j['instant'] == true,
        seatsTotal: _i(j['seats_total']),
        seatsLeft: _i(j['seats_left']),
        fromFare: _d(j['from_fare']),
        dropPoints: _list(j['drop_points']).map(BusDropPoint.fromJson).toList(),
        busName: j['bus'] is Map ? _s(j['bus']['name']) : null,
        amenities: j['bus'] is Map && j['bus']['amenities'] is List ? (j['bus']['amenities'] as List).map((e) => '$e').toList() : const [],
        bookable: j['bookable'] == true,
        closedReason: _s(j['closed_reason']),
        onlineClosesAt: _t(j['online_closes_at']),
        agencyFull: j['agency_full'] is Map ? BusAgency.fromJson(Map<String, dynamic>.from(j['agency_full'])) : null,
        seatMap: j['seat_map'] is Map ? BusSeatMap.fromJson(Map<String, dynamic>.from(j['seat_map'])) : null,
        myBookingId: _s(j['my_booking_id']),
        onWaitlist: j['on_waitlist'] == true,
      );

  bool get whenFull => kind == 'when_full';
  bool get full => seatsLeft <= 0;
  BusRules get rules => agencyFull?.rules ?? BusRules.fromJson(null);
}

/// The seat plan as the agency built it: decks of rows of cells.
class BusSeatMap {
  final int total;
  final List<BusDeck> decks;
  BusSeatMap({required this.total, required this.decks});
  factory BusSeatMap.fromJson(Map<String, dynamic> j) =>
      BusSeatMap(total: _i(j['total']), decks: _list(j['decks']).map(BusDeck.fromJson).toList());

  BusSeatCell? seat(String n) {
    for (final d in decks) {
      for (final r in d.rows) {
        for (final c in r) {
          if (c.isSeat && c.n == n) return c;
        }
      }
    }
    return null;
  }
}

class BusDeck {
  /// lower | upper
  final String deck;
  final bool cabin;
  final List<List<BusSeatCell>> rows;
  BusDeck({required this.deck, required this.cabin, required this.rows});
  factory BusDeck.fromJson(Map<String, dynamic> j) => BusDeck(
        deck: '${j['deck'] ?? 'lower'}',
        cabin: j['cabin'] == true,
        rows: (j['rows'] is List ? j['rows'] as List : const []).map((r) => _list(r).map(BusSeatCell.fromJson).toList()).toList(),
      );
}

class BusSeatCell {
  /// seat | aisle | empty | driver | door
  final String t;
  final String? n;
  final bool window;
  final int span;
  /// For seats: free | taken | counter | mine
  final String? state;
  BusSeatCell({required this.t, this.n, this.window = false, this.span = 1, this.state});
  factory BusSeatCell.fromJson(Map<String, dynamic> j) =>
      BusSeatCell(t: '${j['t']}', n: _s(j['n']), window: j['window'] == true, span: _i(j['span'], 1), state: _s(j['s']));

  bool get isSeat => t == 'seat';
  bool get free => state == 'free';
}

class BusSearchResult {
  final String date;
  final List<BusDeparture> departures;
  /// date (Y-m-d) => departures that day
  final Map<String, int> days;
  final List<BusNotice> notices;
  BusSearchResult({required this.date, required this.departures, required this.days, this.notices = const []});
  factory BusSearchResult.fromJson(Map<String, dynamic> j) => BusSearchResult(
        date: '${j['date']}',
        departures: _list(j['departures']).map(BusDeparture.fromJson).toList(),
        days: {for (final d in _list(j['days'])) '${d['date']}': _i(d['departures'])},
        notices: _list(j['notices']).map(BusNotice.fromJson).toList(),
      );
}

class BusTicket {
  final String code;
  final String seat;
  final String passengerName;
  final String? idNumber;
  final int bags;
  final double fare;
  /// held | valid | boarded | no_show | cancelled
  final String status;
  final String? qr;
  final bool collected;
  BusTicket({required this.code, required this.seat, required this.passengerName, this.idNumber, this.bags = 1, this.fare = 0, required this.status, this.qr,
    this.collected = false});
  factory BusTicket.fromJson(Map<String, dynamic> j) => BusTicket(
        code: '${j['code']}', seat: '${j['seat']}', passengerName: '${j['passenger_name'] ?? ''}', idNumber: _s(j['id_number']),
        bags: _i(j['bags'], 1), fare: _d(j['fare']) ?? 0, status: '${j['status']}', qr: _s(j['qr']), collected: j['collected'] == true,
      );
}

class BusCancelQuote {
  final bool cancellable;
  final int percent;
  final double refund;
  final bool paid;
  BusCancelQuote({required this.cancellable, required this.percent, required this.refund, required this.paid});
  factory BusCancelQuote.fromJson(Map<String, dynamic> j) =>
      BusCancelQuote(cancellable: j['cancellable'] == true, percent: _i(j['percent']), refund: _d(j['refund']) ?? 0, paid: j['paid'] == true);
}

class BusBooking {
  static const String requested = 'requested';
  static const String accepted = 'accepted';
  static const String paid = 'paid';
  static const String declined = 'declined';
  static const String expired = 'expired';
  static const String cancelled = 'cancelled';

  final String id;
  final String code;
  final String status;
  final BusAgency? agency;
  final String? departureId;
  final String? from;
  final String? to;
  final String classLabel;
  final DateTime? leavesAt;
  final bool delayed;
  final String departureStatus;
  final String? departureCancelReason;
  final String? busName;
  final String? busRegistration;
  final String? dropPoint;
  final double amount;
  final DateTime? respondBy;
  final DateTime? payBy;
  final DateTime? paidAt;
  final String? paymentMethod;
  final String? declineReason;
  final String? cancelledBy;
  final double? refundAmount;
  final String? refundStatus;
  final DateTime? refundDueBy;
  final String? refundReference;
  final List<BusTicket> tickets;
  final bool canPay;
  final BusCancelQuote? cancel;
  final DateTime? createdAt;
  /// The person booking's ID, as the agency sees it.
  final String? bookerIdType;
  final String? bookerMaskedNumber;
  final bool bookerVerified;
  /// Tickets printed at the agency counter: the code to show there.
  final String? collectCode;
  final String? collectQr;
  final bool collected;
  final DateTime? collectedAt;
  /// Moved off a departure a lockdown stopped.
  final DateTime? movedFrom;
  final String? movedReason;
  final bool moveKept;
  /// The departure may not go ahead: why, and when the agency decides.
  final String? atRiskReason;
  final DateTime? atRiskDecideBy;

  BusBooking({required this.id, required this.code, required this.status, this.agency, this.departureId, this.from, this.to, this.classLabel = '',
    this.leavesAt, this.delayed = false, this.departureStatus = 'scheduled', this.departureCancelReason, this.busName, this.busRegistration, this.dropPoint,
    this.amount = 0, this.respondBy, this.payBy, this.paidAt, this.paymentMethod, this.declineReason, this.cancelledBy, this.refundAmount, this.refundStatus,
    this.refundDueBy, this.refundReference, this.tickets = const [], this.canPay = false, this.cancel, this.createdAt, this.bookerIdType, this.bookerMaskedNumber,
    this.bookerVerified = false, this.collectCode, this.collectQr, this.collected = false, this.collectedAt, this.movedFrom, this.movedReason,
    this.moveKept = false, this.atRiskReason, this.atRiskDecideBy});

  factory BusBooking.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> d = j['departure'] is Map ? Map<String, dynamic>.from(j['departure']) : {};
    final Map<String, dynamic> r = j['refund'] is Map ? Map<String, dynamic>.from(j['refund']) : {};
    final Map<String, dynamic> bk = j['booker'] is Map ? Map<String, dynamic>.from(j['booker']) : {};
    final Map<String, dynamic> col = j['collect'] is Map ? Map<String, dynamic>.from(j['collect']) : {};
    final Map<String, dynamic> mv = j['moved'] is Map ? Map<String, dynamic>.from(j['moved']) : {};
    final Map<String, dynamic> risk = j['at_risk'] is Map ? Map<String, dynamic>.from(j['at_risk']) : {};
    return BusBooking(
      id: '${j['id']}',
      code: '${j['code']}',
      status: '${j['status']}',
      agency: j['agency'] is Map ? BusAgency.fromJson(Map<String, dynamic>.from(j['agency'])) : null,
      departureId: _s(d['id']),
      from: _s(d['from']),
      to: _s(d['to']),
      classLabel: '${d['class_label'] ?? ''}',
      leavesAt: _t(d['leaves_at']),
      delayed: d['delayed'] == true,
      departureStatus: '${d['status'] ?? 'scheduled'}',
      departureCancelReason: _s(d['cancel_reason']),
      busName: d['bus'] is Map ? _s(d['bus']['name']) : null,
      busRegistration: d['bus'] is Map ? _s(d['bus']['registration']) : null,
      dropPoint: j['drop_point'] is Map ? _s(j['drop_point']['name']) : null,
      amount: _d(j['amount']) ?? 0,
      respondBy: _t(j['respond_by']),
      payBy: _t(j['pay_by']),
      paidAt: _t(j['paid_at']),
      paymentMethod: _s(j['payment_method']),
      declineReason: _s(j['decline_reason']),
      cancelledBy: _s(j['cancelled_by']),
      refundAmount: _d(r['amount']),
      refundStatus: _s(r['status']),
      refundDueBy: _t(r['due_by']),
      refundReference: _s(r['reference']),
      tickets: _list(j['tickets']).map(BusTicket.fromJson).toList(),
      canPay: j['can_pay'] == true,
      cancel: j['cancel'] is Map ? BusCancelQuote.fromJson(Map<String, dynamic>.from(j['cancel'])) : null,
      createdAt: _t(j['created_at']),
      bookerIdType: _s(bk['id_type']),
      bookerMaskedNumber: _s(bk['masked_number']),
      bookerVerified: bk['verified'] == true,
      collectCode: _s(col['code']),
      collectQr: _s(col['qr']),
      collected: col['collected'] == true,
      collectedAt: _t(col['collected_at']),
      movedFrom: j['moved'] is Map ? _t(mv['from_leaves_at']) : null,
      movedReason: _s(mv['reason']),
      moveKept: mv['kept'] == true,
      atRiskReason: j['at_risk'] is Map ? (_s(risk['reason']) ?? '') : null,
      atRiskDecideBy: _t(risk['decide_by']),
    );
  }

  bool get waiting => status == requested;
  bool get toPay => status == accepted;
  bool get isPaid => status == paid;
  bool get ended => status == declined || status == expired || status == cancelled;
  List<String> get seats => tickets.where((t) => t.status != 'cancelled' || !isPaid).map((t) => t.seat).toList();
  bool get boarding => departureStatus == 'boarding';
  bool get departed => departureStatus == 'departed';
  /// Paid, and the agency prints the tickets at its counter.
  bool get collectAtCounter => collectCode != null;
  bool get moved => movedFrom != null || movedReason != null;
  bool get atRisk => atRiskReason != null;
}
