import 'package:ride_sharing_user_app/features/guide/controllers/guide_controller.dart';
import 'package:ride_sharing_user_app/features/guide/domain/repositories/guide_repository.dart';
import 'package:ride_sharing_user_app/features/guide/domain/repositories/guide_repository_interface.dart';
import 'package:ride_sharing_user_app/features/guide/domain/services/guide_service.dart';
import 'package:ride_sharing_user_app/features/guide/domain/services/guide_service_interface.dart';
import 'package:ride_sharing_user_app/features/assistant/controllers/assistant_controller.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/repositories/assistant_repository.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/repositories/assistant_repository_interface.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/services/assistant_service.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/services/assistant_service_interface.dart';
import 'package:ride_sharing_user_app/features/activity/controllers/activity_controller.dart';
import 'package:ride_sharing_user_app/features/activity/domain/repositories/activity_repository.dart';
import 'package:ride_sharing_user_app/features/activity/domain/repositories/activity_repository_interface.dart';
import 'package:ride_sharing_user_app/features/activity/domain/services/activity_service.dart';
import 'package:ride_sharing_user_app/features/activity/domain/services/activity_service_interface.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:ride_sharing_user_app/features/address/domain/repositories/address_repository_interface.dart';
import 'package:ride_sharing_user_app/features/address/domain/services/address_service.dart';
import 'package:ride_sharing_user_app/features/address/domain/services/address_service_interface.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/facebook_login_controller.dart';
import 'package:ride_sharing_user_app/features/auth/domain/repositories/auth_repository_interface.dart';
import 'package:ride_sharing_user_app/features/auth/domain/services/auth_service.dart';
import 'package:ride_sharing_user_app/features/auth/domain/services/auth_service_interface.dart';
import 'package:ride_sharing_user_app/features/coupon/domain/repositories/coupon_repository_interface.dart';
import 'package:ride_sharing_user_app/features/coupon/domain/services/coupon_service.dart';
import 'package:ride_sharing_user_app/features/coupon/domain/services/coupon_service_interface.dart';
import 'package:ride_sharing_user_app/features/home/domain/repositories/category_repo.dart';
import 'package:ride_sharing_user_app/features/location/domain/repositories/location_repository.dart';
import 'package:ride_sharing_user_app/features/location/domain/repositories/location_repository_interface.dart';
import 'package:ride_sharing_user_app/features/location/domain/services/location_service.dart';
import 'package:ride_sharing_user_app/features/location/domain/services/location_service_interface.dart';
import 'package:ride_sharing_user_app/features/message/domain/repositories/message_repository.dart';
import 'package:ride_sharing_user_app/features/message/domain/repositories/message_repository_interface.dart';
import 'package:ride_sharing_user_app/features/message/domain/services/message_service.dart';
import 'package:ride_sharing_user_app/features/message/domain/services/message_service_interface.dart';
import 'package:ride_sharing_user_app/features/my_level/controller/level_controller.dart';
import 'package:ride_sharing_user_app/features/my_level/domain/repositories/level_repository.dart';
import 'package:ride_sharing_user_app/features/my_level/domain/repositories/level_repository_interface.dart';
import 'package:ride_sharing_user_app/features/my_level/domain/services/level_service.dart';
import 'package:ride_sharing_user_app/features/my_level/domain/services/level_service_interface.dart';
import 'package:ride_sharing_user_app/features/my_offer/controller/offer_controller.dart';
import 'package:ride_sharing_user_app/features/my_offer/domain/repositories/offer_repository.dart';
import 'package:ride_sharing_user_app/features/my_offer/domain/repositories/offer_repository_interface.dart';
import 'package:ride_sharing_user_app/features/my_offer/domain/services/offer_service.dart';
import 'package:ride_sharing_user_app/features/my_offer/domain/services/offer_service_interface.dart';
import 'package:ride_sharing_user_app/features/notification/controllers/notification_controller.dart';
import 'package:ride_sharing_user_app/features/notification/domain/repositories/notification_repository.dart';
import 'package:ride_sharing_user_app/features/notification/domain/repositories/notification_repository_interface.dart';
import 'package:ride_sharing_user_app/features/notification/domain/services/notification_service.dart';
import 'package:ride_sharing_user_app/features/notification/domain/services/notification_service_interface.dart';
import 'package:ride_sharing_user_app/features/onboard/controllers/on_board_page_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/domain/repositories/parcel_repository.dart';
import 'package:ride_sharing_user_app/features/parcel/domain/repositories/parcel_repository_interface.dart';
import 'package:ride_sharing_user_app/features/parcel/domain/services/parcel_service.dart';
import 'package:ride_sharing_user_app/features/parcel/domain/services/parcel_service_interface.dart';
import 'package:ride_sharing_user_app/features/payment/controllers/payment_controller.dart';
import 'package:ride_sharing_user_app/features/payment/domain/repositories/payment_repository.dart';
import 'package:ride_sharing_user_app/features/payment/domain/repositories/payment_repository_interface.dart';
import 'package:ride_sharing_user_app/features/payment/domain/services/payment_service.dart';
import 'package:ride_sharing_user_app/features/payment/domain/services/payment_service_interface.dart';
import 'package:ride_sharing_user_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:ride_sharing_user_app/features/profile/domain/repositories/profile_repository_interface.dart';
import 'package:ride_sharing_user_app/features/profile/domain/services/profile_service.dart';
import 'package:ride_sharing_user_app/features/profile/domain/services/profile_service_interface.dart';
import 'package:ride_sharing_user_app/features/realtime_location_trac/controllers/location_tracking_controller.dart';
import 'package:ride_sharing_user_app/features/realtime_location_trac/domain/repository/location_tracking_repository.dart';
import 'package:ride_sharing_user_app/features/realtime_location_trac/domain/repository/location_tracking_repository_interface.dart';
import 'package:ride_sharing_user_app/features/realtime_location_trac/domain/service/location_tracking_service.dart';
import 'package:ride_sharing_user_app/features/realtime_location_trac/domain/service/location_tracking_service_interface.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/controllers/refer_and_earn_controller.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/domain/repositories/refer_earn_repository.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/domain/repositories/refer_earn_repository_interface.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/domain/services/refer_earn_service.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/domain/services/refer_earn_service_interface.dart';
import 'package:ride_sharing_user_app/features/refund_request/controllers/refund_request_controller.dart';
import 'package:ride_sharing_user_app/features/refund_request/domain/repositories/refund_request_repository.dart';
import 'package:ride_sharing_user_app/features/refund_request/domain/repositories/refund_request_repository_interface.dart';
import 'package:ride_sharing_user_app/features/refund_request/domain/services/refund_request_service.dart';
import 'package:ride_sharing_user_app/features/refund_request/domain/services/refund_request_service_interface.dart';
import 'package:ride_sharing_user_app/features/ride/domain/repositories/ride_repository.dart';
import 'package:ride_sharing_user_app/features/ride/domain/repositories/ride_repository_interface.dart';
import 'package:ride_sharing_user_app/features/ride/domain/services/ride_service.dart';
import 'package:ride_sharing_user_app/features/ride/domain/services/ride_service_interface.dart';
import 'package:ride_sharing_user_app/features/safety_setup/controllers/safety_alert_controller.dart';
import 'package:ride_sharing_user_app/features/safety_setup/domain/repositories/safety_alert_repository.dart';
import 'package:ride_sharing_user_app/features/safety_setup/domain/repositories/safety_alert_repository_interface.dart';
import 'package:ride_sharing_user_app/features/safety_setup/domain/services/safety_alert_service.dart';
import 'package:ride_sharing_user_app/features/safety_setup/domain/services/safety_alert_service_interface.dart';
import 'package:ride_sharing_user_app/features/splash/domain/repositories/config_repository.dart';
import 'package:ride_sharing_user_app/features/splash/domain/repositories/config_repository_interface.dart';
import 'package:ride_sharing_user_app/features/splash/domain/services/config_service.dart';
import 'package:ride_sharing_user_app/features/splash/domain/services/config_service_interface.dart';
import 'package:ride_sharing_user_app/features/support/controllers/help_support_controller.dart';
import 'package:ride_sharing_user_app/features/trip/controllers/trip_controller.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/coupon/controllers/coupon_controller.dart';
import 'package:ride_sharing_user_app/features/coupon/domain/repositories/coupon_repository.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';
import 'package:ride_sharing_user_app/features/address/controllers/address_controller.dart';
import 'package:ride_sharing_user_app/features/home/controllers/banner_controller.dart';
import 'package:ride_sharing_user_app/features/home/controllers/category_controller.dart';
import 'package:ride_sharing_user_app/features/address/domain/repositories/address_repository.dart';
import 'package:ride_sharing_user_app/features/home/domain/repositories/banner_repo.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:ride_sharing_user_app/features/message/controllers/message_controller.dart';
import 'package:ride_sharing_user_app/features/message/controllers/chat_inbox_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/nearby_drivers_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/trip/domain/repositories/trip_repository.dart';
import 'package:ride_sharing_user_app/features/trip/domain/repositories/trip_repository_interface.dart';
import 'package:ride_sharing_user_app/features/trip/domain/services/service.dart';
import 'package:ride_sharing_user_app/features/trip/domain/services/service_interface.dart';
import 'package:ride_sharing_user_app/features/wallet/controllers/wallet_controller.dart';
import 'package:ride_sharing_user_app/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:ride_sharing_user_app/features/wallet/domain/repositories/wallet_repository_interface.dart';
import 'package:ride_sharing_user_app/features/wallet/domain/services/wallet_service.dart';
import 'package:ride_sharing_user_app/features/wallet/domain/services/wallet_service_interface.dart';
import 'package:ride_sharing_user_app/localization/language_model.dart';
import 'package:ride_sharing_user_app/localization/localization_controller.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/domain/repositories/store_repository.dart';
import 'package:ride_sharing_user_app/features/store/domain/repositories/store_repository_interface.dart';
import 'package:ride_sharing_user_app/features/store/domain/services/store_service.dart';
import 'package:ride_sharing_user_app/features/store/domain/services/store_service_interface.dart';
import 'package:ride_sharing_user_app/features/explore/controllers/explore_controller.dart';
import 'package:ride_sharing_user_app/features/listing/controllers/listing_controller.dart';
import 'package:ride_sharing_user_app/features/bus/controllers/bus_controller.dart';
import 'package:ride_sharing_user_app/features/id_verification/controllers/id_verification_controller.dart';
import 'package:ride_sharing_user_app/features/id_verification/domain/repositories/id_verification_repository.dart';
import 'package:ride_sharing_user_app/features/id_verification/domain/repositories/id_verification_repository_interface.dart';
import 'package:ride_sharing_user_app/features/id_verification/domain/services/id_verification_service.dart';
import 'package:ride_sharing_user_app/features/id_verification/domain/services/id_verification_service_interface.dart';
import 'package:ride_sharing_user_app/features/bus/domain/repositories/bus_repository.dart';
import 'package:ride_sharing_user_app/features/bus/domain/repositories/bus_repository_interface.dart';
import 'package:ride_sharing_user_app/features/bus/domain/services/bus_service.dart';
import 'package:ride_sharing_user_app/features/bus/domain/services/bus_service_interface.dart';
import 'package:ride_sharing_user_app/features/hotel/controllers/hotel_controller.dart';
import 'package:ride_sharing_user_app/features/hotel/domain/repositories/hotel_repository.dart';
import 'package:ride_sharing_user_app/features/hotel/domain/repositories/hotel_repository_interface.dart';
import 'package:ride_sharing_user_app/features/hotel/domain/services/hotel_service.dart';
import 'package:ride_sharing_user_app/features/hotel/domain/services/hotel_service_interface.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_chat_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_cart_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_order_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_booking_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/repositories/market_repository.dart';
import 'package:ride_sharing_user_app/features/market/domain/repositories/market_repository_interface.dart';
import 'package:ride_sharing_user_app/features/market/domain/services/market_service.dart';
import 'package:ride_sharing_user_app/features/market/domain/services/market_service_interface.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_employer_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/repositories/jobs_repository.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/repositories/jobs_repository_interface.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/services/jobs_service.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/services/jobs_service_interface.dart';
import 'package:ride_sharing_user_app/features/listing/domain/repositories/listing_repository.dart';
import 'package:ride_sharing_user_app/features/listing/domain/repositories/listing_repository_interface.dart';
import 'package:ride_sharing_user_app/features/listing/domain/services/listing_service.dart';
import 'package:ride_sharing_user_app/features/listing/domain/services/listing_service_interface.dart';
import 'package:ride_sharing_user_app/features/deposit/controllers/deposit_controller.dart';
import 'package:ride_sharing_user_app/features/move/controllers/move_controller.dart';
import 'package:ride_sharing_user_app/features/area_safety/controllers/area_safety_controller.dart';
import 'package:ride_sharing_user_app/features/trip_checkin/controllers/trip_checkin_controller.dart';
import 'package:ride_sharing_user_app/features/trip_checkin/domain/repositories/trip_checkin_repository.dart';
import 'package:ride_sharing_user_app/features/trip_checkin/domain/repositories/trip_checkin_repository_interface.dart';
import 'package:ride_sharing_user_app/features/trip_checkin/domain/services/trip_checkin_service.dart';
import 'package:ride_sharing_user_app/features/trip_checkin/domain/services/trip_checkin_service_interface.dart';
import 'package:ride_sharing_user_app/features/area_safety/domain/repositories/area_safety_repository.dart';
import 'package:ride_sharing_user_app/features/area_safety/domain/repositories/area_safety_repository_interface.dart';
import 'package:ride_sharing_user_app/features/area_safety/domain/services/area_safety_service.dart';
import 'package:ride_sharing_user_app/features/area_safety/domain/services/area_safety_service_interface.dart';
import 'package:ride_sharing_user_app/features/trip_share/controllers/trip_share_controller.dart';
import 'package:ride_sharing_user_app/features/health_ride/controllers/health_ride_controller.dart';
import 'package:ride_sharing_user_app/features/health_ride/domain/repositories/health_ride_repository.dart';
import 'package:ride_sharing_user_app/features/health_ride/domain/repositories/health_ride_repository_interface.dart';
import 'package:ride_sharing_user_app/features/health_ride/domain/services/health_ride_service.dart';
import 'package:ride_sharing_user_app/features/health_ride/domain/services/health_ride_service_interface.dart';
import 'package:ride_sharing_user_app/features/lost_item/controllers/lost_item_controller.dart';
import 'package:ride_sharing_user_app/features/lost_item/domain/repositories/lost_item_repository.dart';
import 'package:ride_sharing_user_app/features/lost_item/domain/repositories/lost_item_repository_interface.dart';
import 'package:ride_sharing_user_app/features/lost_item/domain/services/lost_item_service.dart';
import 'package:ride_sharing_user_app/features/lost_item/domain/services/lost_item_service_interface.dart';
import 'package:ride_sharing_user_app/features/trip_share/domain/repositories/trip_share_repository.dart';
import 'package:ride_sharing_user_app/features/trip_share/domain/repositories/trip_share_repository_interface.dart';
import 'package:ride_sharing_user_app/features/trip_share/domain/services/trip_share_service.dart';
import 'package:ride_sharing_user_app/features/trip_share/domain/services/trip_share_service_interface.dart';
import 'package:ride_sharing_user_app/features/move/domain/repositories/move_repository.dart';
import 'package:ride_sharing_user_app/features/move/domain/repositories/move_repository_interface.dart';
import 'package:ride_sharing_user_app/features/move/domain/services/move_service.dart';
import 'package:ride_sharing_user_app/features/move/domain/services/move_service_interface.dart';
import 'package:ride_sharing_user_app/features/deposit/domain/repositories/deposit_repository.dart';
import 'package:ride_sharing_user_app/features/deposit/domain/repositories/deposit_repository_interface.dart';
import 'package:ride_sharing_user_app/features/deposit/domain/services/deposit_service.dart';
import 'package:ride_sharing_user_app/features/deposit/domain/services/deposit_service_interface.dart';
import 'package:ride_sharing_user_app/features/explore/domain/repositories/explore_repository.dart';
import 'package:ride_sharing_user_app/features/explore/domain/repositories/explore_repository_interface.dart';
import 'package:ride_sharing_user_app/features/explore/domain/services/explore_service.dart';
import 'package:ride_sharing_user_app/features/explore/domain/services/explore_service_interface.dart';
import 'package:ride_sharing_user_app/theme/theme_controller.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

Future<Map<String, Map<String, String>>> init() async {
  // Core
  final sharedPreferences = await SharedPreferences.getInstance();
  Get.lazyPut(() => sharedPreferences, fenix: true);
  Get.lazyPut(() => ApiClient(appBaseUrl: AppConstants.baseUrl, sharedPreferences: Get.find()), fenix: true);

  // Service
  Get.lazyPut(() => AddressService(addressRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => AuthService(authRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => CouponService(couponRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => StoreService(storeRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => ActivityService(activityRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => AssistantService(assistantRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => ExploreService(exploreRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => GuideService(guideRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => ListingService(listingRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => MarketService(marketRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => BusService(busRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => HotelService(hotelRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => IdVerificationService(idVerificationRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => JobsService(jobsRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => DepositService(depositRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => MoveService(moveRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => TripShareService(tripShareRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => HealthRideService(healthRideRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => LostItemService(lostItemRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => AreaSafetyService(areaSafetyRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => TripCheckinService(tripCheckinRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => LocationService(locationRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => MessageService(messageRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => NotificationService(notificationRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => ParcelService(parcelRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => PaymentService(paymentRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => ProfileService(profileRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => RideService(rideRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => ConfigService(configRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => TripService(tripRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => WalletService(walletRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => OfferService(offerRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => LevelService(levelRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => ReferEarnService(referEarnRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => RefundRequestService(refundRequestRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => SafetyAlertService(safetyAlertRepositoryInterface: Get.find()), fenix: true);
  Get.lazyPut(() => LocationTrackingService(locationTrackingRepositoryInterface: Get.find()), fenix: true);

  // Repository
  Get.lazyPut(() => ConfigRepository(sharedPreferences: Get.find(), apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => NotificationRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => TripRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => WalletRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => BannerRepo(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => CategoryRepo(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => AddressRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => ParcelRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => RideRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => PaymentRepository(apiClient: Get.find(),sharedPreferences: Get.find()), fenix: true);
  Get.lazyPut(() => LocationRepository(apiClient: Get.find(), sharedPreferences: Get.find()), fenix: true);
  Get.lazyPut(() => CouponRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => StoreRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => ActivityRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => AssistantRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => ExploreRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => GuideRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => ListingRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => MarketRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => BusRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => HotelRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => IdVerificationRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => JobsRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => DepositRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => MoveRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => AuthRepository(apiClient: Get.find(), sharedPreferences: Get.find()), fenix: true);
  Get.lazyPut(() => ProfileRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => MessageRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => OfferRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => LevelRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => ReferEarnRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => RefundRequestRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => SafetyAlertRepository(apiClient: Get.find()), fenix: true);
  Get.lazyPut(() => LocationTrackingRepository(apiClient: Get.find()), fenix: true);

  // Controller
  Get.lazyPut(() => ConfigController(configServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => ThemeController(sharedPreferences: Get.find()), fenix: true);
  Get.lazyPut(() => LocalizationController(sharedPreferences: Get.find()), fenix: true);
  Get.lazyPut(() => OnBoardController(), fenix: true);
  Get.lazyPut(() => AuthController(authServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => NotificationController(notificationServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => TripController(tripServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => ProfileController(profileServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => MessageController(messageServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => ChatInboxController(messageServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => WalletController(walletService: Get.find()), fenix: true);
  Get.lazyPut(() => BannerController(bannerRepo: Get.find()), fenix: true);
  Get.lazyPut(() => CategoryController(categoryRepo: Get.find()), fenix: true);
  Get.lazyPut(() => AddressController(addressServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => MapController(), fenix: true);
  Get.lazyPut(() => ParcelController(parcelServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => RideController(rideServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => NearbyDriversController(rideServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => PaymentController(paymentServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => LocationController(locationServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => BottomMenuController(), fenix: true);
  Get.lazyPut(() => CouponController(couponServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => StoreController(storeServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => AssistantController(assistantServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => ExploreController(exploreServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => GuideController(guideServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => ListingController(listingServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => MarketController(marketServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => MarketChatController(marketServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => MarketOrderController(marketServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => MarketBookingController(marketServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => MarketCartController(), fenix: true);
  Get.lazyPut(() => BusController(busServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => HotelController(hotelServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => IdVerificationController(idVerificationServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => JobsController(jobsServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => JobsEmployerController(jobsServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => DepositController(depositServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => MoveController(moveServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => TripShareController(tripShareServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => HealthRideController(healthRideServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => LostItemController(lostItemServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => AreaSafetyController(areaSafetyServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => TripCheckinController(tripCheckinServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => OfferController(offerServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => LevelController(levelServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => ReferAndEarnController(referEarnServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => HelpSupportController(), fenix: true);
  Get.lazyPut(() => RefundRequestController(refundRequestServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => SafetyAlertController(safetyAlertServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => LocationTrackingController(locationTrackingServiceInterface: Get.find()), fenix: true);
  Get.lazyPut(() => FacebookLoginController(), fenix: true);


  AddressRepositoryInterface addressRepositoryInterface = AddressRepository(apiClient: Get.find());
  Get.lazyPut(() => addressRepositoryInterface, fenix: true);
  AddressServiceInterface addressServiceInterface = AddressService(addressRepositoryInterface: Get.find());
  Get.lazyPut(() => addressServiceInterface, fenix: true);

  AuthRepositoryInterface authRepositoryInterface = AuthRepository(apiClient: Get.find(), sharedPreferences: Get.find());
  Get.lazyPut(() => authRepositoryInterface, fenix: true);
  AuthServiceInterface authServiceInterface = AuthService(authRepositoryInterface: Get.find());
  Get.lazyPut(() => authServiceInterface, fenix: true);

  CouponRepositoryInterface couponRepositoryInterface = CouponRepository(apiClient: Get.find());
  Get.lazyPut(() => couponRepositoryInterface, fenix: true);
  CouponServiceInterface couponServiceInterface = CouponService(couponRepositoryInterface: Get.find());
  Get.lazyPut(() => couponServiceInterface, fenix: true);

  StoreRepositoryInterface storeRepositoryInterface = StoreRepository(apiClient: Get.find());
  Get.lazyPut(() => storeRepositoryInterface, fenix: true);
  StoreServiceInterface storeServiceInterface = StoreService(storeRepositoryInterface: Get.find());
  Get.lazyPut(() => storeServiceInterface, fenix: true);

  ActivityRepositoryInterface activityRepositoryInterface = ActivityRepository(apiClient: Get.find());
  Get.lazyPut(() => activityRepositoryInterface, fenix: true);
  ActivityServiceInterface activityServiceInterface = ActivityService(activityRepositoryInterface: Get.find());
  Get.lazyPut(() => activityServiceInterface, fenix: true);

  AssistantRepositoryInterface assistantRepositoryInterface = AssistantRepository(apiClient: Get.find());
  Get.lazyPut(() => assistantRepositoryInterface, fenix: true);
  AssistantServiceInterface assistantServiceInterface = AssistantService(assistantRepositoryInterface: Get.find());
  Get.lazyPut(() => assistantServiceInterface, fenix: true);

  ExploreRepositoryInterface exploreRepositoryInterface = ExploreRepository(apiClient: Get.find());
  Get.lazyPut(() => exploreRepositoryInterface, fenix: true);
  ExploreServiceInterface exploreServiceInterface = ExploreService(exploreRepositoryInterface: Get.find());
  Get.lazyPut(() => exploreServiceInterface, fenix: true);

  GuideRepositoryInterface guideRepositoryInterface = GuideRepository(apiClient: Get.find());
  Get.lazyPut(() => guideRepositoryInterface, fenix: true);
  GuideServiceInterface guideServiceInterface = GuideService(guideRepositoryInterface: Get.find());
  Get.lazyPut(() => guideServiceInterface, fenix: true);

  ListingRepositoryInterface listingRepositoryInterface = ListingRepository(apiClient: Get.find());
  Get.lazyPut(() => listingRepositoryInterface, fenix: true);
  ListingServiceInterface listingServiceInterface = ListingService(listingRepositoryInterface: Get.find());
  Get.lazyPut(() => listingServiceInterface, fenix: true);

  MarketRepositoryInterface marketRepositoryInterface = MarketRepository(apiClient: Get.find());
  Get.lazyPut(() => marketRepositoryInterface, fenix: true);
  MarketServiceInterface marketServiceInterface = MarketService(marketRepositoryInterface: Get.find());
  Get.lazyPut(() => marketServiceInterface, fenix: true);

  IdVerificationRepositoryInterface idVerificationRepositoryInterface = IdVerificationRepository(apiClient: Get.find());
  Get.lazyPut(() => idVerificationRepositoryInterface, fenix: true);
  IdVerificationServiceInterface idVerificationServiceInterface = IdVerificationService(idVerificationRepositoryInterface: Get.find());
  Get.lazyPut(() => idVerificationServiceInterface, fenix: true);

  BusRepositoryInterface busRepositoryInterface = BusRepository(apiClient: Get.find());
  Get.lazyPut(() => busRepositoryInterface, fenix: true);
  BusServiceInterface busServiceInterface = BusService(busRepositoryInterface: Get.find());
  Get.lazyPut(() => busServiceInterface, fenix: true);

  HotelRepositoryInterface hotelRepositoryInterface = HotelRepository(apiClient: Get.find());
  Get.lazyPut(() => hotelRepositoryInterface, fenix: true);
  HotelServiceInterface hotelServiceInterface = HotelService(hotelRepositoryInterface: Get.find());
  Get.lazyPut(() => hotelServiceInterface, fenix: true);

  JobsRepositoryInterface jobsRepositoryInterface = JobsRepository(apiClient: Get.find());
  Get.lazyPut(() => jobsRepositoryInterface, fenix: true);
  JobsServiceInterface jobsServiceInterface = JobsService(jobsRepositoryInterface: Get.find());
  Get.lazyPut(() => jobsServiceInterface, fenix: true);

  DepositRepositoryInterface depositRepositoryInterface = DepositRepository(apiClient: Get.find());
  Get.lazyPut(() => depositRepositoryInterface, fenix: true);
  DepositServiceInterface depositServiceInterface = DepositService(depositRepositoryInterface: Get.find());
  Get.lazyPut(() => depositServiceInterface, fenix: true);

  MoveRepositoryInterface moveRepositoryInterface = MoveRepository(apiClient: Get.find());
  Get.lazyPut(() => moveRepositoryInterface, fenix: true);
  MoveServiceInterface moveServiceInterface = MoveService(moveRepositoryInterface: Get.find());
  Get.lazyPut(() => moveServiceInterface, fenix: true);

  TripShareRepositoryInterface tripShareRepositoryInterface = TripShareRepository(apiClient: Get.find());
  Get.lazyPut(() => tripShareRepositoryInterface, fenix: true);
  TripShareServiceInterface tripShareServiceInterface = TripShareService(tripShareRepositoryInterface: Get.find());
  Get.lazyPut(() => tripShareServiceInterface, fenix: true);

  HealthRideRepositoryInterface healthRideRepositoryInterface = HealthRideRepository(apiClient: Get.find());
  Get.lazyPut(() => healthRideRepositoryInterface, fenix: true);
  HealthRideServiceInterface healthRideServiceInterface = HealthRideService(healthRideRepositoryInterface: Get.find());
  Get.lazyPut(() => healthRideServiceInterface, fenix: true);

  LostItemRepositoryInterface lostItemRepositoryInterface = LostItemRepository(apiClient: Get.find());
  Get.lazyPut(() => lostItemRepositoryInterface, fenix: true);
  LostItemServiceInterface lostItemServiceInterface = LostItemService(lostItemRepositoryInterface: Get.find());
  Get.lazyPut(() => lostItemServiceInterface, fenix: true);

  AreaSafetyRepositoryInterface areaSafetyRepositoryInterface = AreaSafetyRepository(apiClient: Get.find());
  Get.lazyPut(() => areaSafetyRepositoryInterface, fenix: true);
  AreaSafetyServiceInterface areaSafetyServiceInterface = AreaSafetyService(areaSafetyRepositoryInterface: Get.find());
  Get.lazyPut(() => areaSafetyServiceInterface, fenix: true);

  TripCheckinRepositoryInterface tripCheckinRepositoryInterface = TripCheckinRepository(apiClient: Get.find());
  Get.lazyPut(() => tripCheckinRepositoryInterface, fenix: true);
  TripCheckinServiceInterface tripCheckinServiceInterface = TripCheckinService(tripCheckinRepositoryInterface: Get.find());
  Get.lazyPut(() => tripCheckinServiceInterface, fenix: true);

  LocationRepositoryInterface locationRepositoryInterface = LocationRepository(apiClient: Get.find(), sharedPreferences:  Get.find());
  Get.lazyPut(() => locationRepositoryInterface, fenix: true);
  LocationServiceInterface locationServiceInterface = LocationService(locationRepositoryInterface: Get.find());
  Get.lazyPut(() => locationServiceInterface, fenix: true);

  MessageRepositoryInterface messageRepositoryInterface = MessageRepository(apiClient: Get.find());
  Get.lazyPut(() => messageRepositoryInterface, fenix: true);
  MessageServiceInterface messageServiceInterface = MessageService(messageRepositoryInterface: Get.find());
  Get.lazyPut(() => messageServiceInterface, fenix: true);

  NotificationRepositoryInterface notificationRepositoryInterface = NotificationRepository(apiClient: Get.find());
  Get.lazyPut(() => notificationRepositoryInterface, fenix: true);
  NotificationServiceInterface notificationServiceInterface = NotificationService(notificationRepositoryInterface: Get.find());
  Get.lazyPut(() => notificationServiceInterface, fenix: true);

  ParcelRepositoryInterface parcelRepositoryInterface = ParcelRepository(apiClient: Get.find());
  Get.lazyPut(() => parcelRepositoryInterface, fenix: true);
  ParcelServiceInterface parcelServiceInterface = ParcelService(parcelRepositoryInterface: Get.find());
  Get.lazyPut(() => parcelServiceInterface, fenix: true);

  PaymentRepositoryInterface paymentRepositoryInterface = PaymentRepository(apiClient: Get.find(),sharedPreferences: Get.find());
  Get.lazyPut(() => paymentRepositoryInterface, fenix: true);
  PaymentServiceInterface paymentServiceInterface = PaymentService(paymentRepositoryInterface: Get.find());
  Get.lazyPut(() => paymentServiceInterface, fenix: true);

  ProfileRepositoryInterface profileRepositoryInterface = ProfileRepository(apiClient: Get.find());
  Get.lazyPut(() => profileRepositoryInterface, fenix: true);
  ProfileServiceInterface profileServiceInterface = ProfileService(profileRepositoryInterface: Get.find());
  Get.lazyPut(() => profileServiceInterface, fenix: true);

  RideRepositoryInterface rideRepositoryInterface = RideRepository(apiClient: Get.find());
  Get.lazyPut(() => rideRepositoryInterface, fenix: true);
  RideServiceInterface rideServiceInterface = RideService(rideRepositoryInterface: Get.find());
  Get.lazyPut(() => rideServiceInterface, fenix: true);

  ConfigRepositoryInterface configRepositoryInterface = ConfigRepository(apiClient: Get.find(), sharedPreferences: Get.find());
  Get.lazyPut(() => configRepositoryInterface, fenix: true);
  ConfigServiceInterface configServiceInterface = ConfigService(configRepositoryInterface: Get.find());
  Get.lazyPut(() => configServiceInterface, fenix: true);

  TripRepositoryInterface tripRepositoryInterface = TripRepository(apiClient: Get.find());
  Get.lazyPut(() => tripRepositoryInterface, fenix: true);
  TripServiceInterface tripServiceInterface = TripService(tripRepositoryInterface: Get.find());
  Get.lazyPut(() => tripServiceInterface, fenix: true);

  WalletRepositoryInterface walletRepositoryInterface = WalletRepository(apiClient: Get.find());
  Get.lazyPut(() => walletRepositoryInterface, fenix: true);
  WalletServiceInterface walletServiceInterface = WalletService(walletRepositoryInterface: Get.find());
  Get.lazyPut(() => walletServiceInterface, fenix: true);

  OfferRepositoryInterface offerRepositoryInterface = OfferRepository(apiClient: Get.find());
  Get.lazyPut(() => offerRepositoryInterface, fenix: true);
  OfferServiceInterface offerServiceInterface = OfferService(offerRepositoryInterface: Get.find());
  Get.lazyPut(() => offerServiceInterface, fenix: true);

  LevelRepositoryInterface levelRepositoryInterface = LevelRepository(apiClient: Get.find());
  Get.lazyPut(() => levelRepositoryInterface, fenix: true);
  LevelServiceInterface levelServiceInterface = LevelService(levelRepositoryInterface: Get.find());
  Get.lazyPut(() => levelServiceInterface, fenix: true);

  ReferEarnRepositoryInterface referEarnRepositoryInterface = ReferEarnRepository(apiClient: Get.find());
  Get.lazyPut(() => referEarnRepositoryInterface, fenix: true);
  ReferEarnServiceInterface referEarnServiceInterface = ReferEarnService(referEarnRepositoryInterface: Get.find());
  Get.lazyPut(() => referEarnServiceInterface, fenix: true);

  RefundRequestRepositoryInterface refundRequestRepositoryInterface = RefundRequestRepository(apiClient: Get.find());
  Get.lazyPut(() => refundRequestRepositoryInterface, fenix: true);
  RefundRequestServiceInterface refundRequestServiceInterface = RefundRequestService(refundRequestRepositoryInterface: Get.find());
  Get.lazyPut(() => refundRequestServiceInterface, fenix: true);

  SafetyAlertRepositoryInterface safetyAlertRepositoryInterface = SafetyAlertRepository(apiClient: Get.find());
  Get.lazyPut(() => safetyAlertRepositoryInterface, fenix: true);
  SafetyAlertServiceInterface safetyAlertServiceInterface = SafetyAlertService(safetyAlertRepositoryInterface: Get.find());
  Get.lazyPut(() => safetyAlertServiceInterface, fenix: true);

  LocationTrackingRepositoryInterface locationTrackingRepositoryInterface = LocationTrackingRepository(apiClient: Get.find());
  Get.lazyPut(()=> locationTrackingRepositoryInterface, fenix: true);
  LocationTrackingServiceInterface locationTrackingServiceInterface = LocationTrackingService(locationTrackingRepositoryInterface: Get.find());
  Get.lazyPut(()=> locationTrackingServiceInterface, fenix: true);

  // Retrieving localized data
  // Put now, not lazily, once everything it reads is registered: it follows
  // the screens from the start, for the floating activity button.
  Get.put(ActivityController(activityServiceInterface: Get.find()), permanent: true);

  Map<String, Map<String, String>> languages = {};
  for(LanguageModel languageModel in AppConstants.languages) {
    String jsonStringValues =  await rootBundle.loadString('assets/language/${languageModel.languageCode}.json');
    Map<String, dynamic> mappedJson = json.decode(jsonStringValues);
    Map<String, String> languageJson = {};
    mappedJson.forEach((key, value) {
      languageJson[key] = value.toString();
    });
    languages['${languageModel.languageCode}_${languageModel.countryCode}'] = languageJson;
  }
  return languages;
}
