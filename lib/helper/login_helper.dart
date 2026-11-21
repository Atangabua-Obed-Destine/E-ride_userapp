import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/auth/domain/enums/verification_from_enum.dart';
import 'package:ride_sharing_user_app/features/auth/screens/otp_log_in_screen.dart';
import 'package:ride_sharing_user_app/features/auth/screens/sign_in_screen.dart';
import 'package:ride_sharing_user_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/location/view/access_location_screen.dart';
import 'package:ride_sharing_user_app/features/maintainance_mode/maintainance_screen.dart';
import 'package:ride_sharing_user_app/features/market/helpers/market_link_helper.dart';
import 'package:ride_sharing_user_app/features/realtime_location_trac/screens/live_location_screen.dart';
import 'package:ride_sharing_user_app/features/onboard/screens/onboarding_screen.dart';
import 'package:ride_sharing_user_app/features/payment/controllers/payment_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/refund_request/controllers/refund_request_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/splash/domain/models/config_model.dart';
import 'package:ride_sharing_user_app/features/splash/screens/app_version_warning_screen.dart';
import 'package:ride_sharing_user_app/features/trip/controllers/trip_controller.dart';
import 'package:ride_sharing_user_app/helper/firebase_helper.dart';
import 'package:ride_sharing_user_app/helper/notification_helper.dart';
import 'package:ride_sharing_user_app/helper/pusher_helper.dart';
import 'package:ride_sharing_user_app/localization/language_selection_screen.dart';
import 'package:ride_sharing_user_app/localization/localization_controller.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class LoginHelper{

  /// Loads the configuration, then routes to the first screen. Returns false,
  /// without routing, when the configuration could not be loaded (no or slow
  /// connection): the app needs it on every screen, so the splash retries.
  Future<bool> handleIncomingLinks(Map<String,dynamic>? notificationData) async{
    FirebaseHelper().subscribeFirebaseTopic();
    await MarketLinkHelper.checkInstallReferrer();
    String? path = await initDynamicLinks();
    MarketLinkHelper.listen();

    final ConfigController configController = Get.find<ConfigController>();

    // Open at once with the configuration saved last time and load the fresh
    // one behind it: waiting on it held the splash for one to two seconds.
    if (configController.config == null && configController.loadSavedConfig()) {
      configController.refreshing = configController.getConfigData().then((bool loaded) {
        if (loaded) _checkFreshConfig();
        return loaded;
      });
      _openFirstScreen(path, notificationData);
      return true;
    }

    final bool loaded = await configController.getConfigData();
    if(!loaded || configController.config == null) {
      return false;
    }
    _openFirstScreen(path, notificationData);
    return true;
  }

  /// What the fresh configuration can change after the app opened with the
  /// saved one: a required update, or maintenance before signing in (signed-in
  /// customers get Home's own maintenance check, which lets a running trip finish).
  void _checkFreshConfig() {
    final ConfigController configController = Get.find<ConfigController>();
    if (_isForceUpdate(configController.config)) {
      Get.offAll(() => const AppVersionWarningScreen());
    } else if (configController.isUnderMaintenance && !Get.find<AuthController>().isLoggedIn()) {
      Get.offAll(() => const MaintenanceScreen());
    }
  }

  void _openFirstScreen(String? path, Map<String,dynamic>? notificationData) {
    // Only once the configuration is in: the splash retries until it is, and
    // these used to be re-sent on every retry. A few seconds in, so they don't
    // queue ahead of Home's first requests: they matter only when the customer
    // cancels or pays.
    Future.delayed(const Duration(seconds: 4), () {
      Get.find<TripController>().getRideCancellationReasonList();
      Get.find<TripController>().getParcelCancellationReasonList();
      Get.find<RefundRequestController>().getParcelRefundReasonList();
      Get.find<PaymentController>().getPaymentGetWayList();
    });
    if(_isForceUpdate(Get.find<ConfigController>().config)) {
      Get.offAll(()=> const AppVersionWarningScreen());
    }else{
      if(path != null){
        Get.offAll(()=> LiveLocationScreen(trackingUrl: path));
      }else{
        route(notificationData);
      }
    }
  }

  Future<String?> initDynamicLinks() async {
    final appLinks = AppLinks();
    final uri = await appLinks.getInitialLink();
    String? path;
    final String? marketTarget = uri == null ? null : MarketLinkHelper.targetOf(uri);
    if (marketTarget != null) {
      // An E-Ride Market shop or item: opens once the rider is in the app.
      await MarketLinkHelper.open(marketTarget);
      path = null;
    } else if (uri != null) {
      path = uri.path;

    }else{
      path = null;
    }
    return path;

  }

  bool _isForceUpdate(ConfigModel? config) {
    double minimumVersion = Platform.isAndroid
        ? config?.androidAppMinimumVersion ?? 0
        : Platform.isIOS
        ? config?.iosAppMinimumVersion ?? 0
        : 0;

    return minimumVersion > 0 && minimumVersion > AppConstants.appVersion;
  }

  void route(Map<String,dynamic>? notificationData) async {

    if(Get.find<AuthController>().getUserToken().isNotEmpty){
      PusherHelper.initializePusher();
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if(Get.find<AuthController>().isLoggedIn()) {
        if(Get.find<LocalizationController>().haveLocalLanguageCode()){
          forLoginUserRoute(notificationData);
        }else{
          Get.offAll(()=> LanguageSelectionScreen(notificationData: notificationData));
        }

      }else{
        forNotLoginUserRoute(notificationData);
      }
    });

  }

  void forNotLoginUserRoute(Map<String,dynamic>? notificationData){
    // route() fires on a fixed 100ms delay, but the /configuration call it
    // depends on can still be in flight, so config is legitimately null here on
    // a slow or failing connection. It used to be dereferenced with `!`, which
    // threw and left the user stranded on the splash screen forever with no
    // error. isUnderMaintenance reads false when there is no config.
    if(Get.find<ConfigController>().isUnderMaintenance){
      Get.offAll(() => const MaintenanceScreen());
    }else{
      if (Get.find<ConfigController>().showIntro()) {
        Get.offAll(() => OnBoardingScreen(notificationData: notificationData));

      }else {
        if(Get.find<LocalizationController>().haveLocalLanguageCode()){
          checkLoginMedium();

        }else{
          Get.offAll(()=> LanguageSelectionScreen(notificationData: notificationData));
        }

      }
    }
  }

  void forLoginUserRoute(Map<String,dynamic>? notificationData){
    if(notificationData != null) {
      NotificationHelper.notificationRouteCheck(notificationData, formSplash: true, userName: notificationData['user_name']);

    }else if(Get.find<LocationController>().getUserAddress() != null
        && Get.find<LocationController>().getUserAddress()!.address != null
        && Get.find<LocationController>().getUserAddress()!.address!.isNotEmpty) {

      // Home opens at once and the profile loads alongside. It used to hold
      // the splash, and a failed load left the customer on it for good.
      Get.find<ProfileController>().getProfileInfo().then((value) {
        if(value.statusCode == 200) {
          Get.find<AuthController>().updateToken();
          Get.find<AuthController>().remainingFindingRideTime();
        }
      });
      Get.offAll(()=> const DashboardScreen());

    }else{
      Get.offAll(() => const AccessLocationScreen());
    }
  }

  static void checkLoginMedium(){
    final bool isManualLogin = (Get.find<ConfigController>().config?.customerLoginOptions?.manualLogin ?? false) ||
        (Get.find<ConfigController>().config?.customerLoginOptions?.socialMediaLogin ?? false);
    if(isManualLogin){
      Get.offAll(()=> const SignInScreen());
    }else{
      Get.offAll(()=> const OtpLoginScreen(from: VerificationForm.login));
    }
  }

}