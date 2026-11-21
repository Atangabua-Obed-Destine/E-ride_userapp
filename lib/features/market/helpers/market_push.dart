import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/jobs/helpers/job_push.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_booking_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_chat_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_order_controller.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_booking_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_chat_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_home_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_item_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_order_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_shop_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/my_market_shop_screen.dart';

/// E-Ride Market pushes (action market_*): what they refresh, and where a tap goes.
class MarketPush {
  MarketPush._();

  static bool isMarketPush(Map<String, dynamic> data) => '${data['action']}'.startsWith('market_') || JobPush.isJobPush(data);

  /// The app is open. Returns true when the push needs no notification
  /// (a message in the chat that is on screen).
  static bool onForeground(Map<String, dynamic> data) {
    // E-Ride Jobs rides on the same push type.
    if (JobPush.isJobPush(data)) return JobPush.onForeground(data);
    final String action = '${data['action']}';
    if (action == 'market_message' && Get.isRegistered<MarketChatController>()) {
      final chats = Get.find<MarketChatController>();
      final String? id = data['conversation_id']?.toString();
      if (Get.isRegistered<MarketController>()) Get.find<MarketController>().loadMeta(force: true);
      if (id != null && chats.chat?.id == id && Get.currentRoute == '/MarketChatScreen') {
        chats.refreshChat();
        return true;
      }
      chats.loadInbox();
      return false;
    }
    if (action.startsWith('market_order_')) {
      final String? id = data['order_id']?.toString();
      if (Get.isRegistered<MarketOrderController>()) {
        final orders = Get.find<MarketOrderController>();
        if (id != null && orders.order(id) != null) orders.load(id, quiet: true);
        if (Get.isRegistered<MarketController>()) Get.find<MarketController>().loadMeta(force: true).then(orders.takeCounts);
      }
      return false;
    }
    if (action.startsWith('market_booking_')) {
      final String? id = data['booking_id']?.toString();
      if (Get.isRegistered<MarketBookingController>()) {
        final bookings = Get.find<MarketBookingController>();
        if (id != null && bookings.booking(id) != null) bookings.load(id, quiet: true);
        if (Get.isRegistered<MarketController>()) Get.find<MarketController>().loadMeta(force: true).then(bookings.takeCounts);
      }
      return false;
    }
    if (action.startsWith('market_auction_') && Get.isRegistered<MarketController>()) {
      // Outbid, a new bid, ending soon, won or lost: refresh the auction if it is loaded.
      final market = Get.find<MarketController>();
      final String? code = data['item_code']?.toString();
      if (code != null && market.itemFor(code) != null) {
        market.loadItem(code);
        market.loadBids(code);
      }
      final String? id = data['order_id']?.toString();
      if (id != null && Get.isRegistered<MarketOrderController>()) {
        final orders = Get.find<MarketOrderController>();
        market.loadMeta(force: true).then(orders.takeCounts);
      }
      if (market.myShop != null) market.loadMyShop();
      return false;
    }
    if (Get.isRegistered<MarketController>()) {
      final market = Get.find<MarketController>();
      if (market.myShop != null) market.loadMyShop();
    }
    return false;
  }

  /// The screen a tap on the push opens.
  static Widget screenFor(Map<String, dynamic> data) {
    if (JobPush.isJobPush(data)) return JobPush.screenFor(data);
    final String action = '${data['action']}';
    final String? chat = data['conversation_id']?.toString();
    final String? code = data['item_code']?.toString();
    final String? slug = data['shop_slug']?.toString();
    final String? order = data['order_id']?.toString();
    if (action.startsWith('market_order_') && order != null) return MarketOrderScreen(orderId: order);
    final String? booking = data['booking_id']?.toString();
    if (action.startsWith('market_booking_') && booking != null) return MarketBookingScreen(bookingId: booking);
    if (action.startsWith('market_auction_')) {
      if (order != null) return MarketOrderScreen(orderId: order);
      if (code != null) return MarketItemScreen(code: code);
    }
    if (action == 'market_message' && chat != null) return MarketChatScreen(chatId: chat);
    if ((action == 'market_item_hidden' || action == 'market_item_removed') && code != null) return MarketItemScreen(code: code);
    if (action == 'market_follow_new' && slug != null) return MarketShopScreen(slug: slug);
    if (action.startsWith('market_shop_')) return const MyMarketShopScreen();
    return const MarketHomeScreen();
  }
}
