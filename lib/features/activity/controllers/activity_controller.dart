import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ride_sharing_user_app/features/activity/domain/models/activity_item.dart';
import 'package:ride_sharing_user_app/features/activity/domain/services/activity_service_interface.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/guide/controllers/guide_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_controller.dart';
import 'package:ride_sharing_user_app/features/listing/controllers/listing_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_cart_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/message/controllers/chat_inbox_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';

/// "Your activity": what the customer started and has not finished, or what
/// needs them, from any screen through a floating button they can move.
///
/// The server sends food, bus, hotels, drivers' offers, rides to rate, the ID
/// check, lost items, Market orders and bookings, home visits and job posts;
/// the app adds the saved cart, rides and parcels in progress (with payment
/// and deposits due), unread driver chats, the tour being taken, and the
/// Market, Jobs and Homes counts it already keeps.
class ActivityController extends GetxController with WidgetsBindingObserver implements GetxService {
  final ActivityServiceInterface activityServiceInterface;
  ActivityController({required this.activityServiceInterface});

  List<ActivityItem> _server = [];
  DateTime? _loadedAt;
  bool _loading = false;
  Timer? _timer;

  /// The screen on top, from GetMaterialApp's routingCallback.
  String? currentRoute;
  /// A sheet or dialog is open: the button steps aside.
  bool overlayOpen = false;
  /// The activity sheet itself is open.
  bool sheetOpen = false;
  /// The first-time tour points at the button: shown even with nothing in it.
  bool tourShowing = false;

  // ---------------------------------------------------------------- button position

  static const String _sideKey = 'activity_bubble_right';
  static const String _heightKey = 'activity_bubble_y';
  /// Stuck to the right edge (else the left one).
  bool onRight = true;
  /// From the top, as a share of the screen height.
  double heightShare = 0.72;

  SharedPreferences get _prefs => Get.find<SharedPreferences>();

  void savePosition(bool right, double share) {
    onRight = right;
    heightShare = share.clamp(0.12, 0.86);
    _prefs.setBool(_sideKey, onRight);
    _prefs.setDouble(_heightKey, heightShare);
    update();
  }

  // ---------------------------------------------------------------- life

  @override
  void onInit() {
    super.onInit();
    onRight = _prefs.getBool(_sideKey) ?? true;
    heightShare = _prefs.getDouble(_heightKey) ?? 0.72;
    WidgetsBinding.instance.addObserver(this);
    // Deadlines move: refresh every minute while the app is in front. Rides
    // and parcels too, every minute while one is going, else every five.
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _watchOthers();
        load();
        _ticks++;
        if (loggedIn && (_hasTrips || _ticks % 5 == 0)) _refreshTrips();
      }
    });
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.onClose();
  }

  int _ticks = 0;

  bool get _hasTrips =>
      (Get.isRegistered<RideController>() && (Get.find<RideController>().runningRideList?.data ?? const []).isNotEmpty) ||
      (Get.isRegistered<ParcelController>() && (Get.find<ParcelController>().parcelListModel?.data ?? const []).isNotEmpty);

  /// Rides and parcels change on the driver's side: keep the button honest.
  Future<void> _refreshTrips() async {
    Future<void> safe(Future<dynamic> Function() run) async {
      try {
        await run();
      } catch (_) {}
    }
    await Future.wait([
      if (Get.isRegistered<RideController>()) safe(() => Get.find<RideController>().getRunningRideList()),
      if (Get.isRegistered<ParcelController>()) safe(() => Get.find<ParcelController>().getRunningParcelList()),
      if (Get.isRegistered<ParcelController>()) safe(() => Get.find<ParcelController>().getUnpaidParcelList()),
      if (Get.isRegistered<ChatInboxController>()) safe(() => Get.find<ChatInboxController>().refreshUnread()),
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      load(force: true);
      if (loggedIn) _refreshTrips();
    }
  }

  bool get loggedIn => Get.isRegistered<AuthController>() && Get.find<AuthController>().isLoggedIn();

  /// From the server, at most every 15 seconds unless forced.
  Future<void> load({bool force = false}) async {
    if (!loggedIn) {
      if (_server.isNotEmpty) {
        _server = [];
        update();
      }
      return;
    }
    if (_loading) return;
    if (!force && _loadedAt != null && DateTime.now().difference(_loadedAt!) < const Duration(seconds: 15)) return;
    _loading = true;
    try {
      final Response response = await activityServiceInterface.getActivity();
      if (response.statusCode == 200 && response.body is Map && response.body['data'] is Map) {
        _server = ((response.body['data']['items'] as List?) ?? [])
            .map((e) => ActivityItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _loadedAt = DateTime.now();
      }
    } catch (_) {
      // Keep what we had.
    }
    _loading = false;
    update();
  }

  /// Everything fresh, when the sheet opens: the server list, rides, parcels and counts.
  Future<void> refreshAll() async {
    Future<void> safe(Future<dynamic> Function() run) async {
      try {
        await run();
      } catch (_) {}
    }
    await Future.wait([
      safe(() => load(force: true)),
      if (Get.isRegistered<RideController>()) safe(() => Get.find<RideController>().getRunningRideList()),
      if (Get.isRegistered<ParcelController>()) safe(() => Get.find<ParcelController>().getRunningParcelList()),
      if (Get.isRegistered<ParcelController>()) safe(() => Get.find<ParcelController>().getUnpaidParcelList()),
      if (Get.isRegistered<ChatInboxController>()) safe(() => Get.find<ChatInboxController>().refreshUnread()),
      if (Get.isRegistered<MarketController>()) safe(() => Get.find<MarketController>().loadMeta(force: true)),
      if (Get.isRegistered<JobsController>()) safe(() => Get.find<JobsController>().loadMeta(force: true)),
      if (Get.isRegistered<ListingController>()) safe(() => Get.find<ListingController>().loadMeta(force: true)),
    ]);
    update();
  }

  void onRoute(Routing? routing) {
    currentRoute = routing?.current;
    overlayOpen = (routing?.isBottomSheet ?? false) || (routing?.isDialog ?? false);
    _watchOthers();
    update();
    load();
  }

  // The cart, rides, parcels and the Market, Jobs and Homes counts live in
  // their own controllers: the button redraws whenever one of them changes.
  final Set<Type> _watched = {};
  bool _redrawQueued = false;

  void _watch<T extends GetxController>() {
    if (_watched.contains(T) || !Get.isRegistered<T>()) return;
    _watched.add(T);
    Get.find<T>().addListener(_onOtherChanged);
  }

  void _watchOthers() {
    _watch<StoreController>();
    _watch<RideController>();
    _watch<ParcelController>();
    _watch<MarketController>();
    _watch<JobsController>();
    _watch<ListingController>();
    _watch<ChatInboxController>();
    _watch<GuideController>();
    if (!_watched.contains(MarketCartController) && Get.isRegistered<MarketCartController>()) {
      // The Market cart lives on the phone and loads lazily: read it now so the button knows.
      Get.find<MarketCartController>().load();
    }
    _watch<MarketCartController>();
  }

  void _onOtherChanged() {
    if (_redrawQueued) return;
    _redrawQueued = true;
    // After the other controller's own rebuild, never during it.
    Future.microtask(() {
      _redrawQueued = false;
      update();
    });
  }

  // ---------------------------------------------------------------- what to show

  List<ActivityItem> get items {
    final list = <ActivityItem>[..._server, ..._local()];
    final order = ActivityItem.groups;
    list.sort((a, b) {
      final g = order.indexOf(a.group).compareTo(order.indexOf(b.group));
      if (g != 0) return g;
      // Soonest deadline first, then the newest.
      if (a.deadline != null && b.deadline != null) return a.deadline!.compareTo(b.deadline!);
      if (a.deadline != null) return -1;
      if (b.deadline != null) return 1;
      return (b.at ?? DateTime(2000)).compareTo(a.at ?? DateTime(2000));
    });
    return list;
  }

  List<ActivityItem> _local() {
    final out = <ActivityItem>[];
    // The cart not sent yet.
    if (Get.isRegistered<StoreController>()) {
      final s = Get.find<StoreController>();
      if (s.cartStoreId != null && !s.cartIsEmpty) {
        out.add(ActivityItem(kind: 'food_cart', id: s.cartStoreId!, group: 'unfinished', params: {
          'store': s.cartStore?.displayName ?? s.cartStore?.name ?? '',
          'count': s.cartCount,
          'total': s.cartSubtotal,
        }));
      }
    }
    // The Market cart, one line per shop (each shop gets its own order).
    if (Get.isRegistered<MarketCartController>()) {
      final MarketCartController mc = Get.find<MarketCartController>();
      mc.byShop.forEach((slug, shopLines) {
        out.add(ActivityItem(kind: 'market_cart', id: slug, group: 'unfinished', params: {
          'shop': shopLines.first.shopName,
          'count': mc.piecesOf(slug),
          'total': mc.subtotal(slug),
        }));
      });
    }
    // Rides in progress or booked for later; finished ones still to pay; deposits due.
    if (Get.isRegistered<RideController>()) {
      // The server already says "drivers made offers" for these: one line per ride.
      final Set<String> withOffers = _server.where((s) => s.kind == 'ride_offers').map((s) => s.id).toSet();
      for (final t in Get.find<RideController>().runningRideList?.data ?? const []) {
        final String id = t.id ?? '';
        final String status = t.currentStatus ?? '';
        final Map<String, dynamic> params = {
          'place': t.destinationAddress ?? '',
          'time': t.scheduledAt,
          // Moves and emergency rides are rides too, worded as what they are.
          'type': t.isHealthRide ? 'health' : t.isMove ? 'move' : 'ride',
        };
        if ((status == 'completed' || status == 'cancelled') && t.paymentStatus != 'paid') {
          out.add(ActivityItem(kind: 'ride_pay', id: id, group: 'now', params: params));
          continue;
        }
        if (status == 'completed' || status == 'cancelled') continue;
        if (t.deposit?.isAwaiting ?? false) {
          out.add(ActivityItem(kind: 'ride_deposit', id: id, group: 'now', deadline: t.deposit!.dueAt?.toLocal(),
              params: {...params, 'total': t.deposit!.amount}));
          continue;
        }
        if (status == 'pending' && withOffers.contains(id)) continue;
        final scheduled = t.scheduledAt != null && status == 'pending';
        final kind = scheduled
            ? 'ride_scheduled'
            : switch (status) {
                'pending' => 'ride_pending',
                'accepted' || 'out_for_pickup' => 'ride_coming',
                _ => 'ride_ongoing',
              };
        out.add(ActivityItem(kind: kind, id: id, group: 'progress', at: DateTime.tryParse(t.scheduledAt ?? ''), params: params));
      }
    }
    // Parcels and moves on their way; one coming back to the sender; parcels to pay.
    if (Get.isRegistered<ParcelController>()) {
      final ParcelController pc = Get.find<ParcelController>();
      final parcels = pc.parcelListModel?.data ?? const [];
      final int returning = parcels.where((t) => t.currentStatus == 'returning').length;
      final int active = parcels.length - returning;
      if (returning > 0) out.add(ActivityItem(kind: 'parcel_returning', id: 'parcels', group: 'now', params: {'count': returning}));
      if (active > 0) out.add(ActivityItem(kind: 'parcel_active', id: 'parcels', group: 'progress', params: {'count': active}));
      final int unpaid = pc.unpaidParcelListModel?.data?.length ?? 0;
      if (unpaid > 0) out.add(ActivityItem(kind: 'parcel_pay', id: 'parcels_unpaid', group: 'now', params: {'count': unpaid}));
    }
    // Drivers' messages not read yet.
    if (Get.isRegistered<ChatInboxController>()) {
      final int n = Get.find<ChatInboxController>().totalUnread;
      if (n > 0) out.add(ActivityItem(kind: 'chat_unread', id: 'chats', group: 'now', params: {'count': n}));
    }
    // The tour, or the one-place visit, being taken (kept on the phone).
    if (Get.isRegistered<GuideController>()) {
      final run = Get.find<GuideController>().run;
      if (run != null) {
        out.add(ActivityItem(kind: run.isVisit ? 'tour_visit' : 'tour_active', id: run.tourId ?? run.current.id, group: 'progress', at: run.startedAt,
            params: {'title': run.title, 'place': run.current.name, 'n': run.index + 1, 'total': run.stops.length}));
      }
    }
    // Market, Jobs and Homes: what their own screens count.
    // Market: the server lists every order, booking, auction, shop and chat line itself.
    // Jobs and Homes: the server lists each application, applicant, visit and reservation itself.
    return out;
  }

  /// Things that need the customer now: the red count on the button.
  int get needsYou => items.where((i) => i.group == 'now').length;

  // Screens where a floating button would be in the way: signing in, paying,
  // checkout, chats, the ride map, cameras.
  static const List<String> _hiddenOn = [
    'Splash', 'SignIn', 'SignUp', 'Otp', 'OnBoarding', 'Forget', 'ResetPassword', 'Verification', 'Camera', 'Selfie',
    'Checkout', 'Payment', 'Chat', 'MessageScreen', 'MapScreen', 'ReviewScreen', 'Seats', 'Travellers', 'AccessLocation', 'PickMap', 'ShedScreen', 'ShopFormScreen', 'ShareShopScreen',
    // Trip Setup: the button sat on the pickup directions and the add-stop button.
    'SetDestinationScreen',
  ];

  bool get hiddenHere {
    final r = currentRoute ?? '';
    return _hiddenOn.any((part) => r.contains(part));
  }

  /// Always there once signed in (the user's choice), even with nothing going
  /// on: the sheet then says so and offers Ask E-Ride. Only out of the way on
  /// the screens above and while a sheet or dialog is open.
  bool get showButton => loggedIn && (tourShowing || (!hiddenHere && !overlayOpen && !sheetOpen));
}
