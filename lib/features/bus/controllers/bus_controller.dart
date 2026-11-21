import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/bus/domain/models/bus_models.dart';
import 'package:ride_sharing_user_app/features/bus/domain/services/bus_service_interface.dart';

/// E-Ride Bus Travel: where you can go, the day's departures, a departure's live seat map,
/// seat requests, paying the agency, tickets.
class BusController extends GetxController implements GetxService {
  final BusServiceInterface busServiceInterface;
  BusController({required this.busServiceInterface});

  BusServiceInterface get _service => busServiceInterface;

  // ---------------------------------------------------------------- meta

  BusMeta? meta;
  DateTime? _metaAt;

  bool get enabled => meta?.enabled == true;

  Future<BusMeta?> loadMeta({bool force = false}) async {
    if (!force && meta != null && _metaAt != null && DateTime.now().difference(_metaAt!).inMinutes < 5) return meta;
    Response response = await _service.getMeta();
    if (response.statusCode == 200) {
      meta = BusMeta.fromJson(Map<String, dynamic>.from(response.body['data']));
      _metaAt = DateTime.now();
      from ??= meta!.routes.firstOrNull?.from;
      update();
    }
    return meta;
  }

  // ---------------------------------------------------------------- agencies

  List<BusAgency> agencies = [];
  bool agenciesLoading = false;

  Future<void> loadAgencies() async {
    agenciesLoading = agencies.isEmpty;
    update();
    Response response = await _service.getAgencies();
    agenciesLoading = false;
    if (response.statusCode == 200 && response.body['data'] is List) {
      agencies = (response.body['data'] as List).map((e) => BusAgency.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    update();
  }

  final Map<String, Map<String, dynamic>> _agencyPages = {};
  Map<String, dynamic>? agencyPage(String id) => _agencyPages[id];

  Future<void> loadAgency(String id) async {
    Response response = await _service.getAgency(id);
    if (response.statusCode == 200) {
      _agencyPages[id] = Map<String, dynamic>.from(response.body['data']);
    } else {
      ApiChecker.checkApi(response);
    }
    update();
  }

  // ---------------------------------------------------------------- search

  String? from;
  String? to;
  DateTime date = DateTime.now();
  /// all | morning | afternoon | vip | when_full
  String filter = 'all';
  BusSearchResult? result;
  bool searching = false;

  void setFrom(String? value) {
    from = value;
    final dests = meta?.routeFrom(from)?.to.map((d) => d.city).toList() ?? [];
    if (to != null && !dests.contains(to)) to = null;
    update();
  }

  void setTo(String? value) {
    to = value;
    update();
  }

  void setDate(DateTime value) {
    date = DateTime(value.year, value.month, value.day);
    update();
  }

  void setFilter(String value) {
    filter = value;
    update();
  }

  static String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> search() async {
    if (from == null) return;
    searching = true;
    update();
    Response response = await _service.search({'from': from!, if (to != null) 'to': to!, 'date': ymd(date)});
    searching = false;
    if (response.statusCode == 200) {
      result = BusSearchResult.fromJson(Map<String, dynamic>.from(response.body['data']));
    } else {
      ApiChecker.checkApi(response);
    }
    update();
  }

  List<BusDeparture> get shown {
    final list = result?.departures ?? [];
    return list.where((d) => switch (filter) {
          'morning' => (d.leavesAt?.hour ?? 0) < 12,
          'afternoon' => (d.leavesAt?.hour ?? 0) >= 12,
          'vip' => d.className != 'classic',
          'when_full' => d.whenFull,
          _ => true,
        }).toList();
  }

  // ---------------------------------------------------------------- one departure

  final Map<String, BusDeparture> _departures = {};
  BusDeparture? departure(String id) => _departures[id];
  bool departureLoading = false;

  /// Seats chosen on the open departure.
  final List<String> picked = [];
  String? _pickedFor;

  Future<BusDeparture?> loadDeparture(String id, {bool quiet = false}) async {
    if (!quiet) {
      departureLoading = true;
      update();
    }
    Response response = await _service.getDeparture(id);
    departureLoading = false;
    if (response.statusCode == 200) {
      final d = BusDeparture.fromJson(Map<String, dynamic>.from(response.body['data']));
      _departures[id] = d;
      if (_pickedFor != id) {
        picked.clear();
        _pickedFor = id;
      }
      // Seats someone else took meanwhile drop out.
      final gone = picked.where((n) => d.seatMap?.seat(n)?.free != true).toList();
      picked.removeWhere(gone.contains);
      update();
      return d;
    }
    if (!quiet) ApiChecker.checkApi(response);
    update();
    return null;
  }

  /// Returns false when the most seats are already chosen.
  bool toggleSeat(String n) {
    if (picked.contains(n)) {
      picked.remove(n);
    } else {
      if (picked.length >= (meta?.maxSeats ?? 6)) return false;
      picked.add(n);
      picked.sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    }
    update();
    return true;
  }

  Future<bool> toggleWaitlist(String departureId) async {
    Response response = await _service.toggleWaitlist(departureId);
    if (response.statusCode == 200) {
      await loadDeparture(departureId, quiet: true);
      return response.body['data']?['on_waitlist'] == true;
    }
    ApiChecker.checkApi(response);
    return false;
  }

  // ---------------------------------------------------------------- asking for seats

  bool sending = false;

  /// body: seats, drop_point_id, passengers [{name, phone, id_number, bags}], phone
  Future<BusBooking?> requestSeats(String departureId, Map<String, dynamic> body) async {
    if (sending) return null;
    sending = true;
    update();
    Response response = await _service.requestSeats(departureId, body);
    sending = false;
    if (response.statusCode == 200) {
      final b = _keep(response);
      picked.clear();
      update();
      return b;
    }
    update();
    ApiChecker.checkApi(response);
    // A seat taken meanwhile: show the map as it is now.
    loadDeparture(departureId, quiet: true);
    return null;
  }

  // ---------------------------------------------------------------- bookings

  final Map<String, BusBooking> _bookings = {};
  BusBooking? booking(String id) => _bookings[id];
  bool bookingLoading = false;
  bool acting = false;

  BusBooking _keep(Response response) {
    final b = BusBooking.fromJson(Map<String, dynamic>.from(response.body['data']));
    _bookings[b.id] = b;
    return b;
  }

  Future<BusBooking?> loadBooking(String id, {bool quiet = false}) async {
    if (!quiet) {
      bookingLoading = true;
      update();
    }
    Response response = await _service.getBooking(id);
    bookingLoading = false;
    BusBooking? b;
    if (response.statusCode == 200) {
      b = _keep(response);
      // An alias by code points at the same booking.
      if (b.id != id) _bookings[id] = b;
    } else if (!quiet) {
      ApiChecker.checkApi(response);
    }
    update();
    return b;
  }

  /// The checkout link at the agency's own Fapshi, or '' when already paid.
  Future<String?> payLink(String id) async {
    if (acting) return null;
    acting = true;
    update();
    Response response = await _service.pay(id);
    acting = false;
    update();
    if (response.statusCode == 200) {
      final data = response.body['data'];
      if (data['paid'] == true) return '';
      return data['link']?.toString();
    }
    ApiChecker.checkApi(response);
    return null;
  }

  Future<BusBooking?> cancel(String id) async {
    if (acting) return null;
    acting = true;
    update();
    Response response = await _service.cancel(id);
    acting = false;
    BusBooking? b;
    if (response.statusCode == 200) {
      b = _keep(response);
      _lists.clear();
    } else {
      ApiChecker.checkApi(response);
    }
    update();
    return b;
  }

  /// Moved off a lockdown: the passenger keeps the new time.
  Future<void> keepMove(String id) async {
    Response response = await _service.keep(id);
    if (response.statusCode == 200) {
      _keep(response);
    } else {
      ApiChecker.checkApi(response);
    }
    update();
  }

  // ---------------------------------------------------------------- my trips

  final Map<String, List<BusBooking>> _lists = {};
  final Set<String> _listLoading = {};

  List<BusBooking> list(String when) => _lists[when] ?? [];
  bool listLoading(String when) => _listLoading.contains(when);
  bool listLoaded(String when) => _lists.containsKey(when);

  Future<void> loadList(String when) async {
    _listLoading.add(when);
    update();
    Response response = await _service.getBookings(when, 1);
    _listLoading.remove(when);
    if (response.statusCode == 200) {
      _lists[when] = ((response.body['data']?['bookings'] as List?) ?? [])
          .map((e) => BusBooking.fromJson(Map<String, dynamic>.from(e))).toList();
      for (final b in _lists[when]!) {
        // A list row has no cancellation quote: keep the one the booking screen loaded while nothing changed.
        final known = _bookings[b.id];
        _bookings[b.id] = known != null && known.cancel != null && b.cancel == null && known.status == b.status
            && known.departureStatus == b.departureStatus ? known : b;
      }
    }
    update();
  }

  /// Upcoming trips that need the passenger: waiting for the agency, or to pay.
  int get attention => list('upcoming').where((b) => b.waiting || b.toPay).length;
}
