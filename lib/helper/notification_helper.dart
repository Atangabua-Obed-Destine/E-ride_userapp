import 'package:ride_sharing_user_app/features/store/widgets/cart_reminder.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_menu_screen.dart';
import 'package:ride_sharing_user_app/features/notification/controllers/notification_controller.dart';
import 'package:ride_sharing_user_app/features/bus/helpers/bus_push.dart';
import 'package:ride_sharing_user_app/features/hotel/helpers/hotel_push.dart';
import 'package:ride_sharing_user_app/features/id_verification/screens/id_verification_screen.dart';
import 'package:ride_sharing_user_app/features/market/helpers/market_push.dart';
import 'package:ride_sharing_user_app/features/area_safety/controllers/area_safety_controller.dart';
import 'package:ride_sharing_user_app/features/trip_checkin/controllers/trip_checkin_controller.dart';
import 'package:ride_sharing_user_app/features/lost_item/controllers/lost_item_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/move/widgets/move_widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_order_screen.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/map/screens/map_screen.dart';
import 'package:ride_sharing_user_app/features/message/controllers/chat_inbox_controller.dart';
import 'package:ride_sharing_user_app/features/message/controllers/message_controller.dart';
import 'package:ride_sharing_user_app/features/message/screens/message_screen.dart';
import 'package:ride_sharing_user_app/features/my_level/controller/level_controller.dart';
import 'package:ride_sharing_user_app/features/my_level/widget/level_complete_dialog_widget.dart';
import 'package:ride_sharing_user_app/features/my_offer/screens/my_offer_screen.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/driver_request_dialog.dart';
import 'package:ride_sharing_user_app/features/payment/screens/payment_screen.dart';
import 'package:ride_sharing_user_app/features/payment/screens/review_screen.dart';
import 'package:ride_sharing_user_app/helper/trip_details_helper.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/controllers/refer_and_earn_controller.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/screens/refer_and_earn_screen.dart';
import 'package:ride_sharing_user_app/features/ride/widgets/confirmation_trip_dialog.dart';
import 'package:ride_sharing_user_app/features/safety_setup/controllers/safety_alert_controller.dart';
import 'package:ride_sharing_user_app/features/settings/domain/html_enum_types.dart';
import 'package:ride_sharing_user_app/features/settings/screens/policy_screen.dart';
import 'package:ride_sharing_user_app/features/trip/screens/trip_details_screen.dart';
import 'package:ride_sharing_user_app/features/wallet/screens/wallet_screen.dart';
import 'package:ride_sharing_user_app/helper/chat_notification_helper.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/pusher_helper.dart';
import 'package:ride_sharing_user_app/features/listing/listing_push.dart';
import 'package:ride_sharing_user_app/helper/trip_event_gate.dart';
import 'package:ride_sharing_user_app/main.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ride_sharing_user_app/features/deposit/widgets/deposit_widgets.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';

class NotificationHelper {
  static Future<void> initialize(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
    var androidInitialize = const AndroidInitializationSettings('notification_icon');
    var iOSInitialize = const DarwinInitializationSettings();
    var initializationsSettings = InitializationSettings(android: androidInitialize, iOS: iOSInitialize);
    flutterLocalNotificationsPlugin.initialize(settings: initializationsSettings, onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (CartReminder.isReminder(response.payload)) {
        notificationRouteCheck({'action': CartReminder.action});
        return;
      }
      await _handleChatResponse(response, flutterLocalNotificationsPlugin);
      return;
    },
    onDidReceiveBackgroundNotificationResponse: myBackgroundMessageReceiver);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      AndroidInitializationSettings androidInitialize = const AndroidInitializationSettings('notification_icon');
      var iOSInitialize = const DarwinInitializationSettings();
      var initializationsSettings = InitializationSettings(android: androidInitialize, iOS: iOSInitialize);
      flutterLocalNotificationsPlugin.initialize(
        settings: initializationsSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          // The cart reminder is not this push: open the cart.
          if (CartReminder.isReminder(response.payload)) {
            notificationRouteCheck({'action': CartReminder.action});
            return;
          }
          if (await _handleChatResponse(response, flutterLocalNotificationsPlugin)) return;
          notificationRouteCheck(message.data);
          return;
        },

        onDidReceiveBackgroundNotificationResponse: myBackgroundMessageReceiver,
      );

      ///Debug print
      customPrint('onMessage: ${message.data}');

      // The Notification tab's badge and the group counts.
      if (Get.isRegistered<NotificationController>()) Get.find<NotificationController>().loadCounts();

      if (ChatNotificationHelper.isChatPush(message.data)) {
        Get.find<ChatInboxController>().onForegroundPush(message.data);
        return;
      }

      // E-Ride Market: refresh chats and the shop; no notification for the chat on screen.
      if (MarketPush.isMarketPush(message.data) && MarketPush.onForeground(message.data)) {
        return;
      }

      // Hotels: refresh the chats; no notification for the chat on screen.
      if (HotelPush.isHotelPush(message.data) && HotelPush.onForeground(message.data)) {
        return;
      }

      // Bus travel: refresh the booking on screen; the notification still shows.
      if (BusPush.isBusPush(message.data)) {
        BusPush.onForeground(message.data);
      }

      // Homes & spaces: refresh what is on screen; the notification still shows.
      if (ListingPush.isListingPush(message.data)) {
        ListingPush.onForeground(message.data);
      }

      // Area pause and danger reports: refresh the home banner; the notification still shows.
      if ('${message.data['type']}' == 'safety' && Get.isRegistered<AreaSafetyController>()) {
        Get.find<AreaSafetyController>().loadNearby();
      }

      // Trip check-in: ask at once when the app is open; the notification still shows.
      if (message.data['action'] == 'trip_checkin') {
        Get.find<TripCheckinController>().check(message.data['ride_request_id']?.toString());
      }
      // Lost and found: refresh the case if the rider has the trip open; the notification still shows.
      if (message.data['action'] == 'lost_item') {
        Get.find<LostItemController>().onPush(message.data['ride_request_id']?.toString());
      }

      ///Check maintenance mode
      if(!Get.find<ConfigController>().isUnderMaintenance || Get.find<ConfigController>().haveOngoingRides()){

        // Trip events also arrive over the websocket: the first of the two acts.
        if (TripEventGate.shouldHandlePush(message.data)) {
          if (message.data['action'] == 'driver_on_the_way') {
            Get.find<RideController>().getRideDetails(message.data['ride_request_id']).then((value) {
              if (value.statusCode == 200) {
                if(message.data['type'] == AppConstants.parcel){
                  Get.find<ParcelController>().updateParcelState(ParcelDeliveryState.acceptRider);
                  Get.find<RideController>().startLocationRecord();
                  Get.find<MapController>().notifyMapController();
                  Get.offAll(() => const MapScreen(fromScreen: MapScreenType.parcel));

                }else{
                  Get.find<RideController>().updateRideCurrentState(RideState.outForPickup);
                  Get.find<RideController>().startLocationRecord();
                  Get.find<MapController>().notifyMapController();
                  Get.offAll(() => const MapScreen(fromScreen: MapScreenType.splash));

                }
              }
            });

          } else if(message.data['action'] == "new_message"){
            Get.find<MessageController>().getConversation(message.data['type'], 1);

          } else if (message.data['action'] == 'trip_started' && message.data['type'] == 'ride_request') {
            Get.find<RideController>().startLocationRecord();
            Get.find<RideController>().getRideDetails(message.data['ride_request_id']);
            Get.find<SafetyAlertController>().checkDriverNeedSafety();
            Get.find<RideController>().updateRideCurrentState(RideState.ongoingRide);
            MapScreen.open(const MapScreen(fromScreen: MapScreenType.splash));

          } else if ((message.data['action'] == 'trip_resumed' || message.data['action'] == 'trip_paused') && message.data['type'] == 'ride_request') {
            Get.find<RideController>().getRideDetails(message.data['ride_request_id']);

          } else if (message.data['action'] == 'trip_started' && message.data['type'] == AppConstants.parcel) {
            Get.find<RideController>().startLocationRecord();
            Get.find<MapController>().getPolyline();
            Get.find<ParcelController>().updateParcelState(ParcelDeliveryState.parcelOngoing);
            if(Get.find<RideController>().tripDetails == null ){
              Get.find<RideController>().getRideDetails(message.data['ride_request_id']).then((value) {
                if (Get.find<RideController>().tripDetails!.parcelInformation!.payer == 'sender' && Get.find<RideController>().tripDetails!.paymentStatus != AppConstants.paid) {
                  Get.find<RideController>().getFinalFare(message.data['ride_request_id']).then((value) {
                    if (value.statusCode == 200) {
                      Get.find<MapController>().notifyMapController();
                      Get.off(() => const PaymentScreen(fromParcel: true,));
                    }
                  });

                }
              });

            }else{
              if (Get.find<RideController>().tripDetails!.parcelInformation!.payer == 'sender' && Get.find<RideController>().tripDetails!.paymentStatus != AppConstants.paid) {
                Get.find<RideController>().getFinalFare(message.data['ride_request_id']).then((value) {
                  if (value.statusCode == 200) {
                    Get.find<MapController>().notifyMapController();
                    Get.off(() => const PaymentScreen(fromParcel: true,));
                  }
                });
              }

            }

          } else if (message.data['action'] == 'payment_successful') {
            if (message.data['type'] == 'ride_request') {
              if(Get.find<ConfigController>().config!.reviewStatus!){
                Get.off(() => ReviewScreen(tripId: message.data['ride_request_id']));
                Get.find<RideController>().tripDetails = null;
              }else{
                Get.offAll(() => const DashboardScreen());
                Get.find<RideController>().tripDetails = null;
              }

            } else {
              Get.find<RideController>().getRideDetails(message.data['ride_request_id']).then((_){
                if(Get.find<RideController>().tripDetails?.parcelInformation?.payer == 'sender'){
                  Get.find<ParcelController>().updateParcelState(ParcelDeliveryState.parcelOngoing);
                  Get.find<RideController>().startLocationRecord();
                  Get.offAll(() => const MapScreen(fromScreen: MapScreenType.parcel));
                }else{
                  Get.offAll(() => const DashboardScreen());
                  Get.find<RideController>().tripDetails = null;
                }
              });
            }

          } else if (message.data['action'] == 'trip_completed' && message.data['type'] == 'ride_request'
              && (Get.find<RideController>().tripDetails?.isMove ?? false)) {
            // A move is paid to the driver in person: no payment screen.
            finishCompletedMove(message.data['ride_request_id']);

          } else if (message.data['action'] == 'trip_completed' && message.data['type'] == 'ride_request') {
            Get.find<SafetyAlertController>().cancelDriverNeedSafetyStream();
            Get.dialog(
                const ConfirmationTripDialog(isStartedTrip: false),
                barrierDismissible: false
            );
            Get.find<RideController>().getFinalFare(message.data['ride_request_id']).then((value) {
              if (value.statusCode == 200) {
                Get.find<RideController>().updateRideCurrentState(RideState.completeRide);
                Get.find<MapController>().notifyMapController();
                Get.find<RideController>().stopLocationRecord();
                Get.off(() => const PaymentScreen());
              }
            });

          } else if (message.data['action'] == 'trip_completed' || message.data['action'] == 'parcel_completed') {
            Get.find<RideController>().clearRideDetails();
            if(message.data['action'] == 'trip_completed'){
              Get.offAll(const DashboardScreen());

            }else{
              if(Get.find<ConfigController>().config!.reviewStatus!){
                Get.offAll(ReviewScreen(tripId: message.data['ride_request_id']));
              }else{
                Get.offAll(const DashboardScreen());
              }

            }

          } else if (message.data['action'] == 'trip_canceled') {
            Get.find<RideController>().stopLocationRecord();
            Get.find<SafetyAlertController>().cancelDriverNeedSafetyStream();
            Get.offAll(const DashboardScreen());
            showDriverCancelledSheet(message.data['ride_request_id']);

          } else if (message.data['action'] == 'received_new_bid') {
            Get.find<RideController>().getBiddingList(message.data['ride_request_id'], 1).then((value) {
              if (value.statusCode == 200) {
                // Closes the previous offers dialog only: a dismissed one would pop the map itself.
                if (Get.find<RideController>().biddingList.length != 1 && (Get.isDialogOpen ?? false)) Get.back();

                Get.dialog(
                    barrierDismissible: true,
                    barrierColor: Colors.black.withValues(alpha:0.5),
                    transitionDuration: const Duration(milliseconds: 500),
                    DriverRideRequestDialog(tripId: message.data['ride_request_id'])
                );
              }
            });

          }else if(message.data['action'] == 'level_up'){
            Get.find<LevelController>().getProfileLevelInfo();
            showDialog(
              context: Get.context!,
              barrierDismissible: false,
              builder: (_) => LevelCompleteDialogWidget(
                levelName: message.data['next_level'],
                rewardType: message.data['reward_type'],
                reward: message.data['reward_amount'],
              ),
            );

          }else if(message.data['action'] == 'driver_canceled_ride_request'){
            Get.find<RideController>().getBiddingList(message.data['ride_request_id'], 1).then((value) {
              if (value.statusCode == 200) {
                if(Get.find<RideController>().biddingList.isEmpty && Get.isDialogOpen!){
                  Get.back();
                }
              }
            });

          }else if(message.data['action'] == 'parcel_canceled'){
            Get.offAll(const DashboardScreen());

          }else if(message.data['action'] == 'parcel_returned'){
            Get.find<RideController>().getRideDetails(message.data['ride_request_id']);
            Get.find<ParcelController>().getRunningParcelList();

          }else if(message.data['action'] == 'referral_reward_received'){
            Get.find<ReferAndEarnController>().getEarningHistoryList(1);
            Get.find<ProfileController>().getProfileInfo();

          }else if(message.data['action'] == 'safety_problem_resolved'){
            Get.find<SafetyAlertController>().getSafetyAlertDetails(message.data['ride_request_id']);

          }else if(message.data['action'] == 'trip_accepted'){
            Get.find<RideController>().getRideDetails(message.data['ride_request_id']);

          }else if(message.data['action'] == 'parcel_canceled_after_trip_started'){
            Get.offAll(const DashboardScreen());

          }else if(message.data['action'] == 'auto_arrival_notification_customer_message'){
            Get.find<RideController>().toggleShowDriverNearByTooltip(true);

          }else if(message.data['action'] == 'verify_driver_identity'){
            Get.find<RideController>().toggleShowDriverVerificationTooltip(true);

          }else if(message.data['action'] == 'deposit_expired'){
            _whenDepositExpired(message.data['ride_request_id']);

          }else if(message.data['action'] == 'move_no_agreement'){
            _whenMoveNoAgreement(message.data['ride_request_id']);

          }else if(message.data['action'] == 'deposit_refunded' || message.data['action'] == 'deposit_forfeited'){
            Get.find<ProfileController>().getProfileInfo();

          }else if(message.data['action'] == 'deposit_due' || message.data['action'] == 'scheduled_no_driver'
              || message.data['action'] == 'scheduled_rebooked'){
            // A scheduled ride changed (deposit asked, no driver, a new driver being found): refresh it if it is open.
            final String? id = message.data['ride_request_id']?.toString();
            final rideController = Get.find<RideController>();
            if (id != null && (rideController.tripDetails?.id == id || message.data['action'] == 'scheduled_rebooked')) {
              rideController.getRideDetails(id);
            }

          }else if(message.data['action'] == 'searching_for_rider'){
            _whenNewAutoTripCreate(message);

          }

        }

        // An open order screen refreshes as soon as its push lands.
        if ('${message.data['action']}'.startsWith('store_order_')) {
          final StoreController storeController = Get.find<StoreController>();
          if (storeController.order?.id == message.data['order_id']) {
            storeController.loadOrder(message.data['order_id'].toString());
          }
        }

        ///check for silent notification.
        if(!(message.data['type'] == 'maintenance_mode_on' || message.data['type'] == 'maintenance_mode_off')){
          if(message.data['status'] == '1'){
            NotificationHelper.showNotification(message, flutterLocalNotificationsPlugin, true);
          }
        }

      }

      if(message.data['type'] == 'maintenance_mode_on' || message.data['type'] == 'maintenance_mode_off'){
        Get.find<ConfigController>().getConfigData();
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      customPrint('onOpenApp: ${message.data}');
      notificationRouteCheck(message.data);

    });

  }

  static Future<void> hintForBetterServiceLocationTurnOn({String? body}) async {
    BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      body ?? 'When your\'re riding with ${AppConstants.appName}, your location is being collected for faster pick-ups and safety features. Manage permissions in your device\'s settings',
      htmlFormatBigText: true,
      contentTitle: 'Faster pick-ups, safer trips',
      htmlFormatContentTitle: true,
    );
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'hexaride',
      'hexaride',
      channelDescription: 'progress channel description',
      styleInformation: bigTextStyleInformation,
      channelShowBadge: true,
      importance: Importance.max,
      priority: Priority.high,
      onlyAlertOnce: true,
      showProgress: false,
      color: const Color(0xFF00A08D),
    );
    var platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    flutterLocalNotificationsPlugin.show(
        id: 0,
        title: 'Faster pick-ups, safer trips',
        body: body ?? 'When your\'re riding with ${AppConstants.appName}, your location is being collected for faster pick-ups and safety features. Manage permissions in your device\'s settings',
        notificationDetails: platformChannelSpecifics,
        payload: 'item x'
    );
  }

  static Future<void> showNotification(RemoteMessage message, FlutterLocalNotificationsPlugin fln, bool data) async {
    String title = message.data['title'];
    String body = message.data['body'];
    String? orderID = message.data['order_id'];
    String? image = (message.data['image'] != null && message.data['image'].isNotEmpty) ?
    message.data['image'].startsWith('http') ?
    message.data['image'] :
    '${AppConstants.baseUrl}/storage/app/public/notification/${message.data['image']}' :
    null;

    try {
      await showBigPictureNotificationHiddenLargeIcon(title, body, orderID, image, fln);
    } catch (e) {
      await showBigPictureNotificationHiddenLargeIcon(title, body, orderID, null, fln);
      customPrint('Failed to show notification: ${e.toString()}');
    }
  }

  static Future<void> showBigPictureNotificationHiddenLargeIcon(String title, String body, String? orderID, String? image, FlutterLocalNotificationsPlugin fln) async {
    String? largeIconPath;
    String? bigPicturePath;
    BigPictureStyleInformation? bigPictureStyleInformation;
    BigTextStyleInformation? bigTextStyleInformation;
    if (image != null && !GetPlatform.isWeb) {
      largeIconPath = await _downloadAndSaveFile(image, 'largeIcon');
      bigPicturePath = largeIconPath;
      bigPictureStyleInformation = BigPictureStyleInformation(
        FilePathAndroidBitmap(bigPicturePath),
        hideExpandedLargeIcon: true,
        contentTitle: title,
        htmlFormatContentTitle: true,
        summaryText: body,
        htmlFormatSummaryText: true,
      );
    } else {
      bigTextStyleInformation = BigTextStyleInformation(
        body,
        htmlFormatBigText: true,
        contentTitle: title,
        htmlFormatContentTitle: true,
      );
    }
    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'hexaride',
      'hexaride',
      priority: Priority.max,
      importance: Importance.max,
      playSound: true,
      largeIcon: largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
      styleInformation: largeIconPath != null ? bigPictureStyleInformation : bigTextStyleInformation,
      sound: const RawResourceAndroidNotificationSound('notification'),
    );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show(id: 0, title: title, body: body, notificationDetails: platformChannelSpecifics, payload: orderID);
  }

  static Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  static void notificationRouteCheck(Map<String,dynamic> data, {bool formSplash = false , String? userName}){
    // "Your cart is still waiting": back to that store, cart and all.
    if (data['action'] == CartReminder.action) {
      Get.find<StoreController>().openCartStore();
      _toRoute(formSplash, const StoreMenuScreen());
      return;
    }
    // E-Ride Market: the chat, the item, or the shop.
    if (MarketPush.isMarketPush(data)) {
      _toRoute(formSplash, MarketPush.screenFor(data));
      return;
    }
    // E-Ride ID Verified: verified, refused or expired, all open the ID screen.
    if ('${data['action']}'.startsWith('id_')) {
      _toRoute(formSplash, const IdVerificationScreen());
      return;
    }
    // Hotels: the chat with the reception.
    if (HotelPush.isHotelPush(data)) {
      _toRoute(formSplash, HotelPush.screenFor(data));
      return;
    }
    // Bus travel: the booking (waiting, pay, tickets), or the departure with a free seat.
    if (BusPush.isBusPush(data)) {
      _toRoute(formSplash, BusPush.screenFor(data));
      return;
    }
    // Homes & spaces: the owner's or the seeker's screen for that push.
    if (ListingPush.isListingPush(data)) {
      _toRoute(formSplash, ListingPush.screenFor(data));
      return;
    }
    // Food & Shops: every order push opens that order.
    if ('${data['action']}'.startsWith('store_order_') && data['order_id'] != null) {
      _toRoute(formSplash, StoreOrderScreen(orderId: data['order_id'].toString()));
      return;
    }
    // Trip check-in: back to the ride; the map asks the question when it opens.
    if (data['action'] == 'trip_checkin' && data['ride_request_id'] != null) {
      if (formSplash || Get.currentRoute != '/MapScreen') {
        notificationToRouteNavigate(data['ride_request_id'].toString(), formSplash);
      } else {
        Get.find<TripCheckinController>().check(data['ride_request_id'].toString());
      }
      return;
    }
    // Lost and found: the trip, where the case is.
    if (data['action'] == 'lost_item' && data['ride_request_id'] != null) {
      Get.find<LostItemController>().onPush(data['ride_request_id'].toString());
      _toRoute(formSplash, TripDetailsScreen(tripId: data['ride_request_id'].toString()));
      return;
    }
    // A trusted contact's trip (check-in alert, night ride): open the live link.
    if (data['action'] == 'trip_checkin_contact' || data['action'] == 'night_ride_shared') {
      final RegExpMatch? link = RegExp(r'https?://\S+').firstMatch('${data['body'] ?? ''}');
      if (link != null) launchUrl(Uri.parse(link.group(0)!), mode: LaunchMode.externalApplication);
      if (formSplash) _toRoute(formSplash, const DashboardScreen());
      return;
    }
    if (data['action'] == "new_message") {
      Get.find<MessageController>().getConversation(data['type'], 1);
      _toRoute(formSplash, MessageScreen(channelId: data['type'], tripId: data['ride_request_id'], userName: userName ?? data['user_name']));

    }else if(data['action'] == 'driver_on_the_way'){
      notificationToRouteNavigate(data['ride_request_id'], formSplash);

    }else if(data['action'] == 'trip_started' && data['type'] == 'ride_request'){
      notificationToRouteNavigate(data['ride_request_id'], formSplash);

    }else if((data['action'] == 'trip_resumed' || data['action'] == 'trip_paused') && data['type'] == 'ride_request'){
      notificationToRouteNavigate(data['ride_request_id'], formSplash);

    }else if(data['action'] == 'trip_started' && data['type'] == AppConstants.parcel){
      notificationToRouteNavigate(data['ride_request_id'], formSplash);

    }else if(data['action'] == 'payment_successful'){
      notificationToRouteNavigate(data['ride_request_id'], formSplash);

    }else if(data['action'] == 'trip_completed' && data['type'] == 'ride_request'){
      notificationToRouteNavigate(data['ride_request_id'], formSplash);

    }else if(data['action'] == 'trip_completed' || data['action'] == 'parcel_completed'){
      notificationToRouteNavigate(data['ride_request_id'], formSplash);

    }else if(data['action'] == 'trip_canceled'){
      notificationToRouteNavigate(data['ride_request_id'], formSplash);

    }else if(data['action'] == 'received_new_bid'){
      Get.find<RideController>().getRideDetails(data['ride_request_id']).then((value) => {
        if(Get.currentRoute != '/MapScreen'){
          Get.find<RideController>().updateRideCurrentState(RideState.findingRider),

          _toRoute(formSplash, const MapScreen(fromScreen: MapScreenType.ride)),


        },
        Get.find<RideController>().getBiddingList(data['ride_request_id'], 1).then((value) async {
          if (value.statusCode == 200) {
            Get.dialog(
                barrierDismissible: true,
                barrierColor: Colors.black.withValues(alpha:0.5),
                transitionDuration: const Duration(milliseconds: 500),
                DriverRideRequestDialog(tripId: data['ride_request_id'])
            );
          }
        })
      });

    }else if(data['action'] == 'level_up'){
      Get.find<LevelController>().getProfileLevelInfo();

      if(formSplash) {
        _toRoute(formSplash, const DashboardScreen());
      }

      showDialog(
        context: Get.context!,
        barrierDismissible: false,
        builder: (_) => LevelCompleteDialogWidget(
          levelName: data['next_level'],
          rewardType: data['reward_type'],
          reward: data['reward_amount'],
        ),
      );

    }else if(data['action'] == 'privacy_policy_updated'){
      Get.find<ConfigController>().getConfigData().then((value){

        _toRoute(formSplash, PolicyScreen(
          htmlType: HtmlType.privacyPolicy,
          image: Get.find<ConfigController>().config?.privacyPolicy?.image??'',
        ));


      });

    }else if(data['action'] == 'legal_updated'){
      Get.find<ConfigController>().getConfigData().then((value){
        _toRoute(formSplash, PolicyScreen(
          htmlType: HtmlType.legal,
          image: Get.find<ConfigController>().config?.legal?.image??'',
        ));
      });

    }else if(data['action'] == 'terms_and_conditions_updated'){
      Get.find<ConfigController>().getConfigData().then((value){

        _toRoute(formSplash, PolicyScreen(
          htmlType: HtmlType.termsAndConditions,
          image: Get.find<ConfigController>().config?.termsAndConditions?.image??'',
        ));

      });

    }else if(data['action'] == 'referral_reward_received'){
      Get.find<ReferAndEarnController>().updateCurrentTabIndex(1);
      _toRoute(formSplash, const ReferAndEarnScreen());

    }else if(data['action'] == 'parcel_returned'){
      _toRoute(formSplash, TripDetailsScreen(tripId: data['ride_request_id']));

    }else if(data['action'] == 'someone_used_your_code'){
      _toRoute(formSplash, const ReferAndEarnScreen());

    }else if(data['action'] == 'refund_accepted'){
      _toRoute(formSplash, TripDetailsScreen(tripId: data['ride_request_id']));

    }else if(data['action'] == 'refund_denied'){
      _toRoute(formSplash, TripDetailsScreen(tripId: data['ride_request_id']));

    }else if(data['action'] == 'refunded_to_wallet'){
      _toRoute(formSplash, const WalletScreen());

    }else if(data['action'] == 'deposit_refunded' || data['action'] == 'deposit_forfeited' || data['action'] == 'move_no_agreement'){
      _toRoute(formSplash, TripDetailsScreen(tripId: data['ride_request_id']));

    }else if(['deposit_due', 'scheduled_still_looking', 'scheduled_no_driver', 'scheduled_safety_alert', 'scheduled_rebooked', 'scheduled_reminder'].contains(data['action'])){
      // Scheduled rides: the ride itself (pay the deposit, the heads-up, the new driver search).
      _toRoute(formSplash, TripDetailsScreen(tripId: data['ride_request_id']));

    }else if(data['action'] == 'deposit_expired'){
      _toRoute(formSplash, const DashboardScreen());

    }else if(data['action'] == 'refunded_as_coupon'){
      _toRoute(formSplash,  MyOfferScreen(isCoupon: true));

    }else if(data['action'] == 'fund_added_by_admin'){
      _toRoute(formSplash, const WalletScreen());

    }else if(data['action'] == 'review_from_driver'){
      _toRoute(formSplash, TripDetailsScreen(tripId: data['ride_request_id']));

    }else if(data['action'] == 'withdraw_request_rejected'){
      _toRoute(formSplash, const WalletScreen());

    }else if(data['action'] == 'withdraw_request_reversed'){
      _toRoute(formSplash, const WalletScreen());

    }else if(data['action'] == 'safety_problem_resolved' && data['type'] == 'safety_alert'){
      notificationToRouteNavigate(data['ride_request_id'], formSplash);

    }else if(data['action'] == 'trip_accepted'){
      _toRoute(formSplash, TripDetailsScreen(tripId: data['ride_request_id']));
    }else if(data['action'] == 'fund_added_digitally'){

    }else{
      Get.find<BottomMenuController>().setTabIndex(0);
      Get.offAll(const DashboardScreen());
    }

  }

  static void notificationToRouteNavigate(String tripId, bool formSplash){
    Get.find<RideController>().getRideDetails(tripId).then((value) => {
      if(Get.find<RideController>().tripDetails!.type == AppConstants.parcel){
        if(Get.find<RideController>().tripDetails!.currentStatus == AppConstants.accepted || Get.find<RideController>().tripDetails!.currentStatus == AppConstants.ongoing){
          if(Get.currentRoute != '/MapScreen'){
            if(Get.find<RideController>().tripDetails!.currentStatus == AppConstants.accepted){
              Get.find<ParcelController>().updateParcelState(ParcelDeliveryState.acceptRider)

            }else{
              Get.find<ParcelController>().updateParcelState(ParcelDeliveryState.parcelOngoing)

            },
            _toRoute(formSplash, MapScreen(fromScreen: MapScreenType.parcel)),
          }

        // Delivered and paid, not rated yet: the rating, as when the app was open.
        }else if(Get.find<RideController>().tripDetails!.currentStatus == AppConstants.completed && Get.find<RideController>().tripDetails!.paymentStatus == AppConstants.paid
            && TripDetailsHelper.isReviewButtonShow(Get.find<RideController>())){
          if(Get.currentRoute != '/ReviewScreen'){
            _toRoute(formSplash, ReviewScreen(tripId: tripId)),
          }

        }else if(Get.find<RideController>().tripDetails!.currentStatus == AppConstants.cancelled  || (Get.find<RideController>().tripDetails!.currentStatus == AppConstants.completed && Get.find<RideController>().tripDetails!.paymentStatus == AppConstants.paid)){
          if(Get.currentRoute != '/TripDetailsScreen'){
            _toRoute(formSplash, TripDetailsScreen(tripId: tripId,fromNotification: true)),

          }

        }else if((Get.find<RideController>().tripDetails!.currentStatus == AppConstants.completed && Get.find<RideController>().tripDetails!.paymentStatus == AppConstants.unPaid)){
          if(Get.currentRoute != '/PaymentScreen'){
            Get.find<RideController>().getFinalFare(tripId).then((_){
              _toRoute(formSplash, const PaymentScreen(fromParcel: false));
            })

          }

        }
      }else{
        if(Get.find<RideController>().tripDetails!.currentStatus == AppConstants.outForPickup || Get.find<RideController>().tripDetails!.currentStatus == AppConstants.ongoing){
          if(Get.currentRoute != '/MapScreen'){
            if(Get.find<RideController>().tripDetails!.currentStatus == AppConstants.outForPickup){
              Get.find<RideController>().updateRideCurrentState(RideState.outForPickup)

            }else{
              Get.find<RideController>().updateRideCurrentState(RideState.ongoingRide)

            },
            _toRoute(formSplash, MapScreen(fromScreen: MapScreenType.ride)),

          }

        // Delivered and paid, not rated yet: the rating, as when the app was open.
        }else if(Get.find<RideController>().tripDetails!.currentStatus == AppConstants.completed && Get.find<RideController>().tripDetails!.paymentStatus == AppConstants.paid
            && TripDetailsHelper.isReviewButtonShow(Get.find<RideController>())){
          if(Get.currentRoute != '/ReviewScreen'){
            _toRoute(formSplash, ReviewScreen(tripId: tripId)),
          }

        }else if(Get.find<RideController>().tripDetails!.currentStatus == AppConstants.cancelled  || (Get.find<RideController>().tripDetails!.currentStatus == AppConstants.completed && Get.find<RideController>().tripDetails!.paymentStatus == AppConstants.paid)){
          if(Get.currentRoute != '/TripDetailsScreen'){
            _toRoute(formSplash, TripDetailsScreen(tripId: tripId,fromNotification: true)),

          }

        }else if((Get.find<RideController>().tripDetails!.currentStatus == AppConstants.completed && Get.find<RideController>().tripDetails!.paymentStatus == AppConstants.unPaid)){
          if(Get.currentRoute != '/PaymentScreen'){
            Get.find<RideController>().getFinalFare(tripId).then((_){
              _toRoute(formSplash, const PaymentScreen(fromParcel: false));
            })

          }

        }
      }

    });

  }

  static Future _toRoute(bool formSplash, Widget page) async {
    if(formSplash) {
      await Get.offAll(() => page);

    }else if (page is MapScreen) {
      // Back to the open trip map instead of a second one on top.
      await MapScreen.open(page);
    }else {
     await Get.to(() => page);
    }
  }

}

@pragma('vm:entry-point')
Future<dynamic> myBackgroundMessageHandler(RemoteMessage remoteMessage) async {
  customPrint('onBackground: ${remoteMessage.data}');
  // Only data-only chat pushes are ours to show; one that carries its own
  // notification block (older backend) is already shown by Android.
  if (ChatNotificationHelper.isChatPush(remoteMessage.data) && remoteMessage.notification == null) {
    final FlutterLocalNotificationsPlugin fln = FlutterLocalNotificationsPlugin();
    await fln.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('notification_icon'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveBackgroundNotificationResponse: myBackgroundMessageReceiver,
    );
    await ChatNotificationHelper.show(Map<String, dynamic>.from(remoteMessage.data), fln);
  }
  // var androidInitialize = new AndroidInitializationSettings('notification_icon');
  // var iOSInitialize = new IOSInitializationSettings();
  // var initializationsSettings = new InitializationSettings(android: androidInitialize, iOS: iOSInitialize);
  // FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  // flutterLocalNotificationsPlugin.initialize(initializationsSettings);
  // NotificationHelper.showNotification(message, flutterLocalNotificationsPlugin, true);
}

@pragma('vm:entry-point')
Future<dynamic> myBackgroundMessageReceiver(NotificationResponse response) async {
  customPrint('onBackgroundClicked: ${response.payload}');
  // "Reply" / "Mark as read" on a chat notification, handled without
  // opening the app.
  DartPluginRegistrant.ensureInitialized();
  final FlutterLocalNotificationsPlugin fln = FlutterLocalNotificationsPlugin();
  await fln.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('notification_icon'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  await ChatNotificationHelper.handleAction(response, fln);

}

/// The driver ended a move with "We couldn't agree" on the price.
void _whenMoveNoAgreement(String? tripId) {
  Get.find<RideController>().stopLocationRecord();
  Get.offAll(const DashboardScreen());
  if (tripId != null) showDriverCancelledSheet(tripId);
}

/// The deposit was not paid in time: the trip is cancelled.
void _whenDepositExpired(String? tripId) {
  Get.find<RideController>().stopLocationRecord();
  Get.offAll(const DashboardScreen());
  if (tripId != null) showDepositExpiredSheet(tripId);
}

void _whenNewAutoTripCreate(RemoteMessage message){
  Get.find<AuthController>().saveFindingRideCreatedTime();
  Get.find<MapController>().initializeData();
  Get.find<RideController>().updateRideCurrentState(RideState.findingRider);
  PusherHelper().pusherDriverStatus(message.data['new_trip_id']);
  Get.find<RideController>().getRideDetails(message.data['new_trip_id'], isUpdate: false);
  Get.find<MapController>().setOwnCurrentLocation(LatLng(
      Get.find<LocationController>().fromAddress?.latitude ?? 0,
      Get.find<LocationController>().fromAddress?.longitude ?? 0
  ));

}

/// A tap on a chat notification (or one of its buttons) while the app runs.
/// Returns false for any other notification.
Future<bool> _handleChatResponse(NotificationResponse response, FlutterLocalNotificationsPlugin fln) async {
  if (await ChatNotificationHelper.handleAction(response, fln)) return true;
  final Map<String, dynamic>? data = ChatNotificationHelper.decode(response.payload);
  if (data == null || !ChatNotificationHelper.isChatPush(data)) return false;
  Get.find<ChatInboxController>().openChat(
    channelId: ChatNotificationHelper.conversationOf(data),
    tripId: (data['ride_request_id'] as String?) ?? '',
    peerName: ((data['sender_name'] ?? data['user_name']) as String?) ?? '',
  );
  return true;
}
