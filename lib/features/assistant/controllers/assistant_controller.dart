import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/activity/controllers/activity_controller.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/models/assistant_models.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/need_finder.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/services/assistant_service_interface.dart';
import 'package:ride_sharing_user_app/features/assistant/widgets/home_tour.dart';
import 'package:ride_sharing_user_app/features/bus/controllers/bus_controller.dart';
import 'package:ride_sharing_user_app/features/explore/controllers/explore_controller.dart';
import 'package:ride_sharing_user_app/features/id_verification/controllers/id_verification_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';

/// Ask E-Ride and the info sheets. The sheets come from the server's knowledge
/// pack (so the admin can change them) and are kept on the phone for offline use.
class AssistantController extends GetxController implements GetxService {
  final AssistantServiceInterface assistantServiceInterface;
  AssistantController({required this.assistantServiceInterface});

  static const String _cacheKey = 'assistant_help';

  /// Ask E-Ride switched on by the admin.
  bool enabled = false;
  final Map<String, HelpSheet> _sheets = {};

  final List<AssistantMessage> messages = [];
  bool asking = false;
  /// The screen the conversation was opened from, so answers fit it.
  String? fromScreen;

  SharedPreferences get _prefs => Get.find<SharedPreferences>();

  @override
  void onInit() {
    super.onInit();
    try {
      final raw = _prefs.getString(_cacheKey);
      if (raw != null) _read(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {}
  }

  HelpSheet? sheet(String key) => _sheets[key];

  Future<void> loadHelp() async {
    final Response response = await assistantServiceInterface.getHelp();
    if (response.statusCode == 200 && response.body is Map && response.body['data'] is Map) {
      final data = Map<String, dynamic>.from(response.body['data']);
      _read(data);
      _prefs.setString(_cacheKey, jsonEncode(data));
      update();
    }
  }

  void _read(Map<String, dynamic> data) {
    enabled = data['assistant'] == true;
    _sheets
      ..clear()
      ..addEntries(((data['sheets'] as List?) ?? []).map((e) {
        final s = HelpSheet.fromJson(Map<String, dynamic>.from(e));
        return MapEntry(s.key, s);
      }));
    tips
      ..clear()
      ..addAll(((data['tips'] as List?) ?? []).whereType<Map>().map((e) => AssistantTip.fromJson(Map<String, dynamic>.from(e)))
          .where((t) => t.key.isNotEmpty && t.action.type.isNotEmpty));
    searchWords
      ..clear()
      ..addAll(((data['search_words'] as List?) ?? []).whereType<Map>().map((e) => SearchWordSet.fromJson(Map<String, dynamic>.from(e))));
  }

  // ------------------------------------------------------------ "Did you know?"

  final List<AssistantTip> tips = [];
  final List<SearchWordSet> searchWords = [];

  static const String _hiddenTipsKey = 'tips_hidden';
  static const String _shownTipsKey = 'tips_shown';
  static const String _openedKey = 'services_opened';

  /// The card for this app session: chosen once, so Home does not shuffle.
  String? _sessionTip;
  bool _sessionTipCounted = false;

  /// Home has loaded what the cards depend on (bus booking on, ID status...):
  /// no card before, so none pops in while the page is still filling.
  bool _tipsReady = false;

  void showTips() {
    if (_tipsReady) return;
    _tipsReady = true;
    // Cards closed before this change were hidden for good: bring them back.
    _prefs.remove(_hiddenTipsKey);
    update();
  }

  /// Closed cards, for this app session only (they used to be hidden for good).
  final Set<String> _closedThisSession = {};
  bool _hideCardThisSession = false;
  Set<String> get _opened => (_prefs.getStringList(_openedKey) ?? const []).toSet();
  Map<String, int> get _shownTips {
    try {
      return Map<String, int>.from(jsonDecode(_prefs.getString(_shownTipsKey) ?? '{}') as Map);
    } catch (_) {
      return {};
    }
  }

  /// Which service a tip is about, as the customer's visits are recorded.
  static String _area(AssistantAction a) => switch ((a.type, a.id)) {
        ('explore', 'stay') || ('hotels', _) => 'hotels',
        ('explore', 'homes') => 'homes',
        ('explore', 'eat' || 'swim' || 'party' || 'visit' || 'market' || 'things') => 'things',
        ('explore', _) => 'explore',
        ('health_ride', _) => 'health',
        (final String type, _) => type,
      };

  bool _tipFits(AssistantTip tip) {
    final AssistantAction a = tip.action;
    if (a.type == 'id_verify') {
      // Only once the app knows the customer is not verified yet.
      final status = Get.isRegistered<IdVerificationController>() ? Get.find<IdVerificationController>().status : null;
      return status != null && !status.verified;
    }
    final String? service = NeedFinder.serviceOf(a.type);
    if (service != null && !services.contains(service)) return false;
    if (a.type == 'explore' && a.id != null) {
      final ExploreController explore = Get.find<ExploreController>();
      if (explore.categories != null && explore.categoryOf(a.id!) == null) return false;
    }
    return true;
  }

  /// The "Did you know?" card for Home, or null. Services the customer has not
  /// opened yet come first; a card shown three times without a tap goes to the
  /// back. None on the day of the first-time tour: one thing at a time.
  AssistantTip? get tip {
    // Always on Home (the user's choice), once the first-time tour is over;
    // closing it hides it until the app is opened again.
    if (!_tipsReady || tips.isEmpty || _hideCardThisSession) return null;
    final String? userId = Get.find<ProfileController>().profileModel?.data?.id;
    if (userId == null || !HomeTour.doneFor(userId)) return null;
    final Set<String> hidden = _closedThisSession;
    final AssistantTip? kept = tips.firstWhereOrNull((t) => t.key == _sessionTip);
    if (kept != null && !hidden.contains(kept.key) && _tipFits(kept)) return kept;

    final Set<String> opened = _opened;
    final Map<String, int> shown = _shownTips;
    final List<AssistantTip> open = tips.where((t) => !hidden.contains(t.key) && _tipFits(t)).toList();
    if (open.isEmpty) return null;
    int rank(AssistantTip t) => (opened.contains(_area(t.action)) ? 1 : 0) + ((shown[t.key] ?? 0) >= 3 ? 2 : 0);
    final List<AssistantTip> ordered = [...open]
      ..sort((a, b) {
        final int r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        final int s = (shown[a.key] ?? 0).compareTo(shown[b.key] ?? 0);
        return s != 0 ? s : tips.indexOf(a).compareTo(tips.indexOf(b));
      });
    _sessionTip = ordered.first.key;
    _sessionTipCounted = false;
    return ordered.first;
  }

  /// The card was on screen: counted once per session.
  void tipSeen(AssistantTip t) {
    if (_sessionTipCounted || t.key != _sessionTip) return;
    _sessionTipCounted = true;
    final Map<String, int> shown = _shownTips..update(t.key, (n) => n + 1, ifAbsent: () => 1);
    _prefs.setString(_shownTipsKey, jsonEncode(shown));
  }

  /// The close button, or the card's button: hidden until the app is opened
  /// again, when a card shows again (the least shown first).
  void dismissTip(AssistantTip t) {
    _closedThisSession.add(t.key);
    _sessionTip = null;
    _hideCardThisSession = true;
    update();
  }

  /// Screens that mean the customer has found a service (route names contain these).
  static const Map<String, String> _screens = {
    'BusHome': 'bus', 'BusResults': 'bus', 'StoreList': 'food', 'StoreMenu': 'food', 'MarketHome': 'market', 'JobsHome': 'jobs',
    'ExploreScreen': 'explore', 'PlaceList': 'explore', 'Hotel': 'hotels', 'ListingHome': 'homes', 'ParcelScreen': 'parcel',
    'HealthRide': 'health', 'IdVerification': 'id_verify',
    'ThingsToDo': 'things', 'TourScreen': 'things', 'ToursScreen': 'things', 'TourStop': 'things',
    'SafetySetup': 'safety', 'TrustedContacts': 'safety', 'ReferAndEarn': 'refer', 'MyOffer': 'coupons',
  };

  /// Every screen change: remember which services the customer has found.
  void noteRoute(String? route) {
    if (route == null) return;
    for (final MapEntry<String, String> e in _screens.entries) {
      if (route.contains(e.key)) {
        final Set<String> opened = _opened;
        if (opened.add(e.value)) _prefs.setStringList(_openedKey, opened.toList());
        return;
      }
    }
  }

  // ------------------------------------------------------------ smart search

  /// What the search knows now: services on, Explore's categories, bus
  /// destinations, partner stores and the admin's words. Built from what is
  /// already loaded: typing never waits on a request.
  NeedFinder needFinder() {
    final ExploreController explore = Get.find<ExploreController>();
    final BusController? bus = Get.isRegistered<BusController>() ? Get.find<BusController>() : null;
    final StoreController? stores = Get.isRegistered<StoreController>() ? Get.find<StoreController>() : null;
    return NeedFinder(NeedContext(
      services: services.toSet(),
      exploreKeys: explore.categoryKeys,
      busPlaces: [
        for (final route in bus?.meta?.routes ?? const [])
          for (final d in route.to) BusPlace(city: d.city, from: route.from, fare: d.fromFare, departures: d.departures),
      ],
      stores: [
        for (final s in stores?.stores ?? const [])
          if (s.id != null && (s.name ?? '').isNotEmpty) StorePlace(id: s.id!, name: s.name!, openNow: s.openNow),
      ],
      extraWords: [for (final w in searchWords) SearchWords(type: w.type, id: w.id, words: w.words)],
    ));
  }

  /// Services switched on in this app, so answers only point to those.
  List<String> get services {
    final c = Get.find<ConfigController>().config;
    final bus = Get.isRegistered<BusController>() && Get.find<BusController>().enabled;
    final explore = c?.exploreStatus ?? c?.stayStatus ?? false;
    return [
      'ride',
      'parcel',
      if (c?.healthRideStatus ?? false) 'health',
      if (c?.moveStatus ?? false) 'move',
      if (c?.storeOrderingStatus ?? false) 'food',
      if (bus) 'bus',
      if (explore) ...['explore', 'hotels'],
      if (c?.marketStatus ?? false) 'market',
      if (c?.jobsStatus ?? false) 'jobs',
    ];
  }

  /// When the last message was added: a conversation older than this starts over.
  DateTime? _lastMessageAt;
  static const Duration _keepFor = Duration(minutes: 30);

  /// Ask E-Ride opens, from [screen]. The conversation of the last 30 minutes
  /// is still there, so the customer can carry on where they stopped.
  void start({String? screen, bool fresh = false}) {
    final route = screen ?? (Get.isRegistered<ActivityController>() ? Get.find<ActivityController>().currentRoute : null);
    fromScreen = route?.replaceAll('/', '');
    if (fresh || _lastMessageAt == null || DateTime.now().difference(_lastMessageAt!) > _keepFor) {
      messages.clear();
    }
    asking = false;
    // No update(): it runs from the screen's initState, and the screen builds
    // fresh anyway (notifying here rebuilt Home's Ask chip mid-build).
  }

  /// The "New chat" button.
  void newChat() {
    messages.clear();
    _lastMessageAt = null;
    asking = false;
    update();
  }

  /// The last turns, oldest first, so a follow-up ("how much?") makes sense.
  List<Map<String, String>> _history() {
    final List<Map<String, String>> turns = [];
    for (int i = 0; i + 1 < messages.length; i++) {
      if (messages[i].fromUser && !messages[i + 1].fromUser) {
        final AssistantMessage a = messages[i + 1];
        turns.add({'q': messages[i].text, 'a': [a.text, ...a.steps].join(' ')});
      }
    }
    return turns.length > 4 ? turns.sublist(turns.length - 4) : turns;
  }

  Future<void> ask(String question) async {
    final q = question.trim();
    if (q.isEmpty || asking) return;
    final List<Map<String, String>> history = _history();
    messages.add(AssistantMessage(fromUser: true, text: q));
    _lastMessageAt = DateTime.now();
    asking = true;
    update();
    // Where the customer is, so suggestions come with distances.
    final here = Get.find<LocationController>().getUserAddress();
    final Response response = await assistantServiceInterface.ask({
      'question': q,
      if (fromScreen != null && fromScreen!.isNotEmpty) 'screen': fromScreen,
      'services': services,
      if (here?.latitude != null && here?.longitude != null) ...{'latitude': here!.latitude, 'longitude': here.longitude},
      if (history.isNotEmpty) 'history': history,
    });
    asking = false;
    if (response.statusCode == 200 && response.body is Map && response.body['data'] is Map) {
      final d = Map<String, dynamic>.from(response.body['data']);
      messages.add(AssistantMessage(
        fromUser: false,
        text: d['reply']?.toString() ?? '',
        actions: ((d['actions'] as List?) ?? []).map((e) => AssistantAction.fromJson(Map<String, dynamic>.from(e))).toList(),
        cards: ((d['cards'] as List?) ?? []).whereType<Map>().map((e) => AssistantCard.fromJson(Map<String, dynamic>.from(e))).toList(),
        // Only real answers can be rated; "busy" or "limit reached" replies have nothing to judge.
        questionId: (d['status'] == 'answered' || d['status'] == 'no_answer') ? d['id']?.toString() : null,
        steps: ((d['steps'] as List?) ?? []).map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList(),
        followUps: ((d['follow_ups'] as List?) ?? []).map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList(),
      ));
    } else {
      messages.add(AssistantMessage(
        fromUser: false,
        text: response.statusCode == 429 ? 'assistant_slow_down'.tr : 'assistant_offline'.tr,
        actions: [AssistantAction(type: 'support', label: 'assistant_whatsapp_support'.tr)],
      ));
    }
    update();
  }

  /// Sends a voice note recorded while booking ([kind] ride or parcel). The
  /// recording is kept for the driver even when it could not be read; null
  /// only when it could not be uploaded.
  Future<VoiceTripResult?> voiceTrip(String path, int seconds, String kind, {List<String> categories = const []}) async {
    final Response response = await assistantServiceInterface.voiceTrip(path, seconds, kind, categories);
    if (response.statusCode == 200 && response.body is Map && response.body['data'] is Map) {
      final VoiceTripResult r = VoiceTripResult.fromJson(Map<String, dynamic>.from(response.body['data']), path);
      return r.name.isEmpty ? null : r;
    }
    return null;
  }

  Future<void> feedback(AssistantMessage m, bool helped) async {
    if (m.questionId == null || m.helped != null) return;
    m.helped = helped;
    update();
    await assistantServiceInterface.feedback(m.questionId!, helped);
  }
}
