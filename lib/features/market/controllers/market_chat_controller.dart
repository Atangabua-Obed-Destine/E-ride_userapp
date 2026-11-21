import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_order_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/domain/services/market_service_interface.dart';

/// E-Ride Market chat: the inbox (both roles), one open chat (refreshed every few
/// seconds while it is on screen; pushes cover the rest), and the delivery the
/// seller books from a chat (its parcel id is posted back into that chat).
class MarketChatController extends GetxController implements GetxService {
  final MarketServiceInterface marketServiceInterface;
  MarketChatController({required this.marketServiceInterface});

  MarketServiceInterface get _service => marketServiceInterface;

  // ---------------------------------------------------------------- inbox

  List<MarketChat> chats = [];
  int unread = 0;
  bool inboxLoading = false;

  Future<void> loadInbox() async {
    inboxLoading = true;
    update();
    Response response = await _service.getChats();
    inboxLoading = false;
    if (response.statusCode == 200) {
      final data = response.body['data'];
      chats = [for (final j in data['chats'] as List) MarketChat.fromJson(Map<String, dynamic>.from(j))];
      unread = int.tryParse('${data['unread']}') ?? 0;
    }
    update();
  }

  // ---------------------------------------------------------------- one chat

  MarketChat? chat;
  List<MarketMessage> messages = [];
  bool loading = false;
  bool sending = false;
  Timer? _poll;
  bool _polling = false;

  /// The buyer opens the chat about an item: returns its id, or null (the error is shown).
  Future<String?> startChat(String itemCode) async {
    Response response = await _service.startChat(itemCode);
    if (response.statusCode == 200) {
      chat = MarketChat.fromJson(Map<String, dynamic>.from(response.body['data']));
      messages = [];
      update();
      return chat!.id;
    }
    ApiChecker.checkApi(response);
    return null;
  }

  Future<void> open(String chatId) async {
    if (chat?.id != chatId) {
      chat = null;
      messages = [];
    }
    loading = true;
    update();
    await _fetch(chatId, null);
    loading = false;
    update();
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => refreshChat());
  }

  void close() {
    _poll?.cancel();
    _poll = null;
    // Called from the chat screen's dispose: refresh the inbox after this frame.
    Future.microtask(loadInbox);
  }

  Future<void> refreshChat() async {
    final id = chat?.id;
    if (id == null || _polling) return;
    // Only while the app is in front; the push brings the rest.
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    _polling = true;
    await _fetch(id, messages.isEmpty ? null : messages.last.id);
    _polling = false;
  }

  Future<void> _fetch(String chatId, String? after) async {
    Response response = await _service.getMessages(chatId, after);
    if (response.statusCode != 200) {
      if (after == null) ApiChecker.checkApi(response);
      return;
    }
    final data = response.body['data'];
    chat = MarketChat.fromJson(Map<String, dynamic>.from(data['chat']));
    final fresh = [for (final j in data['messages'] as List) MarketMessage.fromJson(Map<String, dynamic>.from(j))];
    if (after == null) {
      messages = fresh;
    } else {
      // The server may send one we have (same second): keep each message once.
      final known = {for (final m in messages) m.id};
      messages.addAll(fresh.where((m) => !known.contains(m.id)));
    }
    update();
  }

  Future<bool> sendText(String text) => _send({'type': 'text', 'body': text.trim()});

  Future<bool> sendPhoto(XFile photo) => _send({'type': 'photo'}, photo: photo);

  /// The buyer asks for delivery: where to bring it.
  Future<bool> askDelivery(double latitude, double longitude, String address) =>
      _send({'type': 'delivery_point', 'latitude': '$latitude', 'longitude': '$longitude', 'address': address});

  Future<bool> _send(Map<String, String> fields, {XFile? photo}) async {
    final id = chat?.id;
    if (id == null || sending) return false;
    sending = true;
    update();
    Response response = await _service.sendMessage(id, fields, photo);
    sending = false;
    if (response.statusCode == 200) {
      final message = MarketMessage.fromJson(Map<String, dynamic>.from(response.body['data']));
      if (!messages.any((m) => m.id == message.id)) messages.add(message);
      update();
      return true;
    }
    update();
    ApiChecker.checkApi(response);
    return false;
  }

  Future<void> blockBuyer(bool on) async {
    final id = chat?.id;
    if (id == null) return;
    Response response = await _service.blockBuyer(id, on);
    if (response.statusCode == 200) {
      chat = MarketChat.fromJson(Map<String, dynamic>.from(response.body['data']));
      update();
    } else {
      ApiChecker.checkApi(response);
    }
  }

  // ---------------------------------------------------------------- the delivery the seller books

  /// Set when the seller opens the parcel booking from a chat or an order; the parcel booked to
  /// that delivery point (within the next hours) is posted back there.
  String? pendingDeliveryChatId;
  String? _pendingOrderId;
  double? _pendingLat;
  double? _pendingLng;
  DateTime? _pendingAt;

  void deliveryStarted(String? chatId, double lat, double lng, {String? orderId}) {
    pendingDeliveryChatId = chatId;
    _pendingOrderId = orderId;
    _pendingLat = lat;
    _pendingLng = lng;
    _pendingAt = DateTime.now();
  }

  /// Called once a parcel is booked (RideController.submitRideRequest) with its destination.
  Future<void> onParcelBooked(String tripId, double? lat, double? lng) async {
    final chatId = pendingDeliveryChatId;
    final orderId = _pendingOrderId;
    if ((chatId == null && orderId == null) || _pendingLat == null || lat == null || lng == null) return;
    final bool samePoint = (lat - _pendingLat!).abs() < 0.0005 && (lng - _pendingLng!).abs() < 0.0005;
    final bool recent = _pendingAt != null && DateTime.now().difference(_pendingAt!) < const Duration(hours: 3);
    if (!samePoint || !recent) return;
    pendingDeliveryChatId = null;
    _pendingOrderId = null;
    _pendingLat = _pendingLng = null;
    try {
      if (orderId != null) {
        // The order takes the trip, and the server posts it in the order's chat.
        await Get.find<MarketOrderController>().attachTrip(orderId, tripId);
      } else {
        await _service.sendMessage(chatId!, {'type': 'delivery_booked', 'trip_id': tripId}, null);
        if (chat?.id == chatId) refreshChat();
      }
    } catch (_) {}
  }

  @override
  void onClose() {
    _poll?.cancel();
    super.onClose();
  }
}
