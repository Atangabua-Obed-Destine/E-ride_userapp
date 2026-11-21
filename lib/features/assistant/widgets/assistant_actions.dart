import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ride_sharing_user_app/features/activity/widgets/activity_sheet.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/models/assistant_models.dart';
import 'package:ride_sharing_user_app/features/assistant/widgets/getting_started.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_booking_screen.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_home_screen.dart';
import 'package:ride_sharing_user_app/features/explore/controllers/explore_controller.dart';
import 'package:ride_sharing_user_app/features/explore/domain/models/explore_place_model.dart';
import 'package:ride_sharing_user_app/features/explore/screens/explore_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_controller.dart';
import 'package:ride_sharing_user_app/features/health_ride/screens/health_ride_screen.dart';
import 'package:ride_sharing_user_app/features/hotel/screens/hotel_chat_screen.dart';
import 'package:ride_sharing_user_app/features/id_verification/screens/id_verification_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/jobs_home_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_home_screen.dart';
import 'package:ride_sharing_user_app/features/parcel/screens/parcel_screen.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/set_destination/screens/set_destination_screen.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_list_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_order_screen.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/features/bus/controllers/bus_controller.dart';
import 'package:ride_sharing_user_app/features/explore/screens/place_detail_screen.dart';
import 'package:ride_sharing_user_app/features/guide/screens/things_screen.dart';
import 'package:ride_sharing_user_app/features/guide/screens/tour_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/job_screen.dart';
import 'package:ride_sharing_user_app/features/listing/screens/listing_detail_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_item_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_shop_screen.dart';
import 'package:ride_sharing_user_app/features/my_offer/screens/my_offer_screen.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/screens/refer_and_earn_screen.dart';
import 'package:ride_sharing_user_app/features/safety_setup/screens/safety_setup_screen.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_model.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_menu_screen.dart';

/// Opens what an answer's button points to. The assistant never acts by itself:
/// every button lands on the app's own screen, where the customer decides.
Future<void> openAssistantAction(AssistantAction a) async {
  final id = a.id;
  switch (a.type) {
    // A place the customer named fills the destination search ("Ride to Up Station").
    case 'ride':
      Get.to(() => SetDestinationScreen(searchText: _place(id)));
    case 'ride_later':
      Get.to(() => SetDestinationScreen(rideType: RideType.scheduleRide, searchText: _place(id)));
    case 'health_ride':
      Get.to(() => const HealthRideScreen());
    case 'parcel':
      Get.to(() => const ParcelScreen());
    case 'move':
      Get.to(() => SetDestinationScreen(move: true, searchText: _place(id)));
    case 'guide':
      await GettingStarted.show();
    case 'food':
      Get.to(() => const StoreListScreen());
    case 'bus':
      Get.to(() => BusHomeScreen(title: 'assistant_bus_title'.tr));
    case 'hotels' || 'explore':
      // One category when the button names it ("explore:pharmacy"), hotels as Explore's stays.
      final ExploreCategory? category = Get.find<ExploreController>().categoryOf(a.type == 'hotels' ? 'stay' : (id ?? ''));
      if (category != null) {
        await ExploreCategoryTile.open(category);
      } else {
        Get.to(() => const ExploreScreen());
      }
    case 'market':
      // From the smart search, id carries what to look for ("phone").
      Get.to(() => MarketHomeScreen(query: id));
    case 'jobs':
      if (id != null) Get.find<JobsController>().query = id;
      Get.to(() => const JobsHomeScreen());
    case 'activity':
      ActivitySheet.show();
    case 'order':
      if (id != null) Get.to(() => StoreOrderScreen(orderId: id));
    case 'bus_booking':
      if (id != null) Get.to(() => BusBookingScreen(bookingId: id));
    case 'hotel_chat':
      if (id != null) Get.to(() => HotelChatScreen(inquiryId: id));
    case 'id_verify':
      Get.to(() => const IdVerificationScreen());
    case 'things':
      Get.to(() => ThingsToDoScreen(title: 'things_to_do'.tr));
    case 'safety':
      Get.to(() => const SafetySetupScreen());
    case 'refer':
      Get.to(() => const ReferAndEarnScreen());
    case 'coupons':
      Get.to(() => const MyOfferScreen(isCoupon: true));
    case 'support':
      await openWhatsAppSupport();
  }
}

String? _place(String? id) => (id ?? '').trim().isEmpty ? null : id!.trim();

/// Opens what an answer's card is: the item, shop, store, place, tour, job, home or bus itself.
Future<void> openAssistantCard(AssistantCard c) async {
  switch (c.type) {
    case 'market_item':
      Get.to(() => MarketItemScreen(code: c.id));
    case 'market_shop':
      Get.to(() => MarketShopScreen(slug: c.id));
    case 'store':
      final StoreController stores = Get.find<StoreController>();
      if (stores.stores == null) await stores.loadStores();
      final StoreModel? store = stores.stores?.firstWhereOrNull((s) => s.id == c.id || s.brandId == c.id);
      if (store != null) {
        stores.openStore(store);
        Get.to(() => const StoreMenuScreen());
      } else {
        // Closed or out of the customer's area: the store list says why.
        Get.to(() => const StoreListScreen());
      }
    case 'place':
      if (c.place != null) Get.to(() => PlaceDetailScreen(place: ExplorePlace.fromJson(c.place!)));
    case 'tour':
      Get.to(() => TourScreen(tourId: c.id, title: c.title));
    case 'job':
      Get.to(() => JobScreen(code: c.id));
    case 'listing':
      Get.to(() => ListingDetailScreen(listingId: c.id));
    case 'bus':
      Get.find<BusController>().setTo(c.id);
      Get.to(() => BusHomeScreen(title: 'assistant_bus_title'.tr));
  }
}

/// E-Ride support on WhatsApp, at the number the admin set.
Future<void> openWhatsAppSupport() async {
  String d = (Get.find<ConfigController>().config?.businessSupportPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('00')) d = d.substring(2);
  if (d.length == 9 && d.startsWith('6')) d = '237$d';
  if (d.isEmpty) {
    showCustomSnackBar('could_not_open_link'.tr);
    return;
  }
  try {
    final ok = await launchUrl(Uri.parse('https://wa.me/$d'), mode: LaunchMode.externalApplication);
    if (!ok) showCustomSnackBar('could_not_open_link'.tr);
  } catch (_) {
    showCustomSnackBar('could_not_open_link'.tr);
  }
}

/// The icon and colour of a button type, for the "Did you know?" cards and the
/// smart search: each service keeps one look everywhere.
(IconData, Color) assistantActionStyle(String type, [String? id]) => switch ((type, id)) {
      ('explore', 'pharmacy') => (Icons.local_pharmacy_rounded, const Color(0xFF0F9D6B)),
      ('explore', 'health') => (Icons.local_hospital_rounded, const Color(0xFFD93025)),
      ('explore', 'bank') => (Icons.account_balance_rounded, const Color(0xFF1A73E8)),
      ('explore', 'stay') || ('hotels', _) => (Icons.bed_rounded, const Color(0xFF7B3FE4)),
      ('explore', 'homes') => (Icons.home_work_rounded, const Color(0xFF00897B)),
      ('explore', 'eat' || 'swim' || 'party' || 'visit' || 'market' || 'things') || ('things', _) => (Icons.local_activity_rounded, const Color(0xFF0E9F6E)),
      ('explore', _) => (Icons.place_rounded, const Color(0xFF0F9D6B)),
      ('safety', _) => (Icons.shield_outlined, const Color(0xFF15803D)),
      ('refer', _) => (Icons.card_giftcard_rounded, const Color(0xFFB45309)),
      ('coupons', _) => (Icons.local_offer_rounded, const Color(0xFFE02020)),
      ('health_ride', _) => (Icons.add_rounded, const Color(0xFFE02020)),
      ('bus', _) => (Icons.directions_bus_rounded, const Color(0xFF1D4ED8)),
      ('food' || 'store' || 'order', _) => (Icons.restaurant_rounded, const Color(0xFFE8710A)),
      ('market', _) => (Icons.storefront_rounded, const Color(0xFF188038)),
      ('jobs', _) => (Icons.work_outline_rounded, const Color(0xFF3949AB)),
      ('parcel', _) => (Icons.inventory_2_rounded, const Color(0xFFB06000)),
      ('move', _) => (Icons.local_shipping_rounded, const Color(0xFF5F6368)),
      ('ride' || 'ride_later', _) => (type == 'ride_later' ? Icons.schedule_rounded : Icons.local_taxi_rounded, const Color(0xFFE02020)),
      ('id_verify', _) => (Icons.verified_user_outlined, const Color(0xFF1A73E8)),
      ('guide', _) => (Icons.flag_rounded, const Color(0xFF15803D)),
      ('activity', _) => (Icons.pending_actions_rounded, const Color(0xFF5F6368)),
      ('support', _) => (Icons.chat_rounded, const Color(0xFF25A244)),
      _ => (Icons.arrow_forward_rounded, const Color(0xFF5F6368)),
    };

/// The icon for a button type, so answers read at a glance.
IconData assistantActionIcon(String type) => switch (type) {
      'ride' || 'ride_later' => Icons.local_taxi_rounded,
      'health_ride' => Icons.local_hospital_rounded,
      'parcel' => Icons.inventory_2_rounded,
      'move' => Icons.local_shipping_rounded,
      'food' || 'order' => Icons.restaurant_rounded,
      'bus' || 'bus_booking' => Icons.directions_bus_rounded,
      'hotels' || 'hotel_chat' => Icons.bed_rounded,
      'explore' => Icons.place_rounded,
      'things' => Icons.local_activity_rounded,
      'safety' => Icons.shield_outlined,
      'refer' => Icons.card_giftcard_rounded,
      'coupons' => Icons.local_offer_rounded,
      'market' => Icons.storefront_rounded,
      'jobs' => Icons.work_outline_rounded,
      'activity' => Icons.pending_actions_rounded,
      'id_verify' => Icons.badge_outlined,
      'guide' => Icons.flag_rounded,
      'support' => Icons.chat_rounded,
      _ => Icons.arrow_forward_rounded,
    };
