import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_menu_screen.dart';
import 'package:ride_sharing_user_app/features/store/domain/services/store_service_interface.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_booking_screen.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_home_screen.dart';
import 'package:ride_sharing_user_app/features/id_verification/screens/id_verification_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/job_screen.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_item_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_shop_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// E-Ride Market links into the app:
/// - `https://MARKET_DOMAIN/s/SLUG` and `/i/CODE` (App Links, once the domain is verified);
/// - `eride://market/s/SLUG` and `/i/CODE` ("Open in the app" on the web pages);
/// - after a fresh install from such a page, the Play install referrer `market=i:CODE`.
/// The bus website (eride.../bus) uses the same doors: `bt/CODE` a bus booking, `bv/id` ID
/// verification, `bh/home` the bus home ("Continue in the app").
/// A link that arrives before the rider is signed in waits, and opens once the dashboard is up.
class MarketLinkHelper {
  MarketLinkHelper._();

  static const String _referrerCheckedKey = 'market_referrer_checked';
  static const String _referralKey = 'market_referral_target';

  static bool _appReady = false;
  static StreamSubscription<Uri>? _links;
  static String? _lastTarget;
  static DateTime? _lastAt;

  /// `i:CODE` or `s:SLUG` from a link, or null when it is not a market link.
  static String? targetOf(Uri uri) {
    final bool custom = uri.scheme == 'eride';
    if (custom && uri.host != 'market') return null;
    // s: shop, i: item, j: a job (E-Ride Jobs); bt: a bus booking, bv: ID verification, bh: bus home.
    // f: a Food & Shops partner's store page.
    final match = RegExp(r'/(s|i|j|f|bt|bv|bh)/([A-Za-z0-9_-]{2,140})(/app)?/?$').firstMatch(uri.path);
    if (match == null) return null;
    return '${match.group(1)}:${match.group(2)}';
  }

  static bool isMarketLink(Uri? uri) => uri != null && targetOf(uri) != null;

  /// Listens for links while the app runs (the stream also repeats the launch link).
  static void listen() {
    _links ??= AppLinks().uriLinkStream.listen((uri) {
      final target = targetOf(uri);
      if (target != null) open(target);
    }, onError: (_) {});
  }

  /// Opens [target] now when the rider is in the app, otherwise keeps it for later.
  static Future<void> open(String target, {bool referral = false}) async {
    final now = DateTime.now();
    if (_lastTarget == target && _lastAt != null && now.difference(_lastAt!) < const Duration(seconds: 30)) return;
    _lastTarget = target;
    _lastAt = now;
    if (!_appReady || !Get.find<AuthController>().isLoggedIn()) {
      await Get.find<MarketController>().setPendingLink(target);
      return;
    }
    _go(target);
  }

  /// The dashboard is up (signed in): open what was waiting, and count the
  /// install a market link brought in.
  static Future<void> onAppReady() async {
    _appReady = true;
    final market = Get.find<MarketController>();
    final prefs = await SharedPreferences.getInstance();
    final referral = prefs.getString(_referralKey);
    if (referral != null) {
      await prefs.remove(_referralKey);
      if (referral.startsWith('f:')) {
        // A partner's store link: counted for the store.
        try {
          await Get.find<StoreServiceInterface>().claimLinkReferral(referral.substring(2));
        } catch (_) {}
      } else {
        market.claimReferral(referral);
      }
    }
    final pending = await market.takePendingLink();
    if (pending != null) {
      _lastTarget = pending;
      _lastAt = DateTime.now();
      // Let the dashboard finish its first frame before pushing on top of it.
      Future.delayed(const Duration(milliseconds: 600), () => _go(pending));
    }
  }

  /// First launch after install (Android): the Play Store referrer of a market page.
  static Future<void> checkInstallReferrer() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_referrerCheckedKey) ?? false) return;
      await prefs.setBool(_referrerCheckedKey, true);
      final details = await PlayInstallReferrer.installReferrer;
      final raw = details.installReferrer;
      if (raw == null || raw.isEmpty) return;
      final target = Uri.splitQueryString(raw)['market'];
      if (target == null || !RegExp(r'^(s|i|j|f|bt|bv|bh):[A-Za-z0-9_-]{2,140}$').hasMatch(target)) return;
      await prefs.setString(_referralKey, target);
      await Get.find<MarketController>().setPendingLink(target);
    } catch (_) {}
  }

  static void _go(String target) {
    final colon = target.indexOf(':');
    final kind = target.substring(0, colon);
    final value = target.substring(colon + 1);
    if (kind == 'bt') {
      Get.to(() => BusBookingScreen(bookingId: value));
    } else if (kind == 'bv') {
      Get.to(() => const IdVerificationScreen());
    } else if (kind == 'bh') {
      Get.to(() => BusHomeScreen(title: 'assistant_bus_title'.tr));
    } else if (target.startsWith('i:')) {
      Get.to(() => MarketItemScreen(code: value));
    } else if (target.startsWith('s:')) {
      Get.to(() => MarketShopScreen(slug: value));
    } else if (target.startsWith('j:')) {
      Get.to(() => JobScreen(code: value));
    } else if (kind == 'f') {
      _openStore(value);
    }
  }

  /// A partner's store from its public link: the store's page, or a word when it is not in the customer's area.
  static Future<void> _openStore(String slug) async {
    final store = Get.find<StoreController>();
    if (await store.openStoreBySlug(slug)) {
      Get.to(() => const StoreMenuScreen());
    } else {
      showCustomSnackBar('store_link_not_here'.tr);
    }
  }
}
