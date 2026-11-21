import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// "Your Romz cart is still waiting", for as long as the cart is not sent:
/// an hour after the cart was last changed, then again after 4 hours, a day
/// and three days. Every change starts the series again; sending or emptying
/// the cart cancels it.
class CartReminder {
  static const int id = 7301;
  static const String action = 'store_cart';
  static const List<Duration> after = [Duration(hours: 1), Duration(hours: 4), Duration(days: 1), Duration(days: 3)];
  static bool _tzReady = false;

  static FlutterLocalNotificationsPlugin get _plugin => FlutterLocalNotificationsPlugin();

  static Future<void> schedule({required String storeName, required int count, required double subtotal}) async {
    try {
      if (!_tzReady) {
        tzdata.initializeTimeZones();
        _tzReady = true;
      }
      await cancel();
      final tz.TZDateTime now = tz.TZDateTime.now(tz.UTC);
      for (int i = 0; i < after.length; i++) {
        await _plugin.zonedSchedule(
          id: id + i,
          title: 'cart_reminder_title'.trParams({'store': storeName}),
          body: 'cart_reminder_body'.trParams({'count': '$count', 'total': PriceConverter.convertPrice(subtotal)}),
          scheduledDate: now.add(after[i]),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails('eride_reminders', 'Reminders', importance: Importance.defaultImportance, priority: Priority.defaultPriority, icon: 'notification_icon'),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: jsonEncode({'action': action}),
        );
      }
    } catch (_) {
      // A reminder that can't be scheduled is not worth an error.
    }
  }

  static Future<void> cancel() async {
    for (int i = 0; i < after.length; i++) {
      try {
        await _plugin.cancel(id: id + i);
      } catch (_) {}
    }
  }

  /// Whether a tapped notification is the cart reminder.
  static bool isReminder(String? payload) {
    if (payload == null || !payload.startsWith('{')) return false;
    try {
      return (jsonDecode(payload) as Map)['action'] == action;
    } catch (_) {
      return false;
    }
  }
}
