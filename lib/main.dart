import 'package:ride_sharing_user_app/features/assistant/controllers/assistant_controller.dart';
import 'package:ride_sharing_user_app/features/store/widgets/cart_reminder.dart';
import 'package:ride_sharing_user_app/features/activity/controllers/activity_controller.dart';
import 'package:ride_sharing_user_app/features/activity/widgets/activity_bubble.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/splash/screens/splash_screen.dart';
import 'package:ride_sharing_user_app/helper/chat_notification_helper.dart';
import 'package:ride_sharing_user_app/helper/notification_helper.dart';
import 'package:ride_sharing_user_app/helper/di_container.dart' as di;
import 'package:ride_sharing_user_app/localization/localization_controller.dart';
import 'package:ride_sharing_user_app/localization/messages.dart';
import 'package:ride_sharing_user_app/theme/dark_theme.dart';
import 'package:ride_sharing_user_app/theme/light_theme.dart';
import 'package:ride_sharing_user_app/theme/theme_controller.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Also one greppable line per error (adb logcat | grep E-RIDE-CRASH), with
  // where it was thrown, so a red screen seen on a device can be traced.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    final String where = (details.stack ?? StackTrace.empty).toString().split('\n').take(6).join(' <- ');
    debugPrint('E-RIDE-CRASH ${details.exceptionAsString()} | ${details.context?.toDescription() ?? ''} | $where', wrapWidth: 4000);
  };

  // Firebase and the app's own set-up (preferences, languages) do not depend
  // on each other: side by side, not one after the other.
  final List<Object?> ready = await Future.wait<Object?>([Firebase.initializeApp(), di.init()]);
  final Map<String, Map<String, String>> languages = ready[1] as Map<String, Map<String, String>>;

  final RemoteMessage? remoteMessage = await FirebaseMessaging.instance.getInitialMessage();
  await NotificationHelper.initialize(flutterLocalNotificationsPlugin);
  await ChatNotificationHelper.ensureChannel(flutterLocalNotificationsPlugin);
  FirebaseMessaging.onBackgroundMessage(myBackgroundMessageHandler);

  // Opened by tapping a chat notification while the app was closed: route to
  // that chat the same way an FCM tap does.
  Map<String, dynamic>? launchData = remoteMessage?.data;
  try {
    final NotificationAppLaunchDetails? launch = await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    final Map<String, dynamic>? tapped = ChatNotificationHelper.decode(launch?.notificationResponse?.payload);
    if ((launch?.didNotificationLaunchApp ?? false) && CartReminder.isReminder(launch?.notificationResponse?.payload)) {
      launchData = {'action': CartReminder.action};
    } else if ((launch?.didNotificationLaunchApp ?? false) && tapped != null && ChatNotificationHelper.isChatPush(tapped)) {
      launchData = tapped;
      ChatNotificationHelper.cancelConversation(ChatNotificationHelper.conversationOf(tapped), flutterLocalNotificationsPlugin);
    }
  } catch (_) {}

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(MyApp(languages: languages, notificationData: launchData));
}

class MyApp extends StatelessWidget {
  final Map<String, Map<String, String>> languages;
  final Map<String,dynamic>? notificationData;
  const MyApp({super.key, required this.languages, this.notificationData});


  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(builder: (themeController) {
      return GetBuilder<LocalizationController>(builder: (localizeController) {
        return SafeArea(
          top: false,
          child: GetMaterialApp(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              navigatorKey: Get.key,
              scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch},),
              theme: themeController.darkTheme ? darkTheme : lightTheme,
              locale: localizeController.locale,
              home: SplashScreen(notificationData: notificationData),
              translations: Messages(languages: languages),
              fallbackLocale: Locale(AppConstants.languages[0].languageCode, AppConstants.languages[0].countryCode),
              defaultTransition: Transition.fadeIn,
              transitionDuration: const Duration(milliseconds: 500),
              // Which screen is on top: the activity button steps aside on some.
              routingCallback: (routing) {
                if (Get.isRegistered<ActivityController>()) Get.find<ActivityController>().onRoute(routing);
                // Which services the customer has found, for the "Did you know?" cards.
                if (Get.isRegistered<AssistantController>()) Get.find<AssistantController>().noteRoute(routing?.current);
              },
              builder:(context,child){
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(0.95)),
                  // The floating "Your activity" button, over every screen.
                  child: Stack(children: [child!, const ActivityBubble()]),
                );
              }
          ),
        );
      });
    });
  }
}
