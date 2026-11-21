import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/hotel/controllers/hotel_controller.dart';
import 'package:ride_sharing_user_app/features/hotel/screens/hotel_chat_screen.dart';
import 'package:ride_sharing_user_app/features/hotel/screens/hotel_chats_screen.dart';

/// Pushes about questions to hotels (type hotel, actions hotel_*): what they refresh, and where a tap goes.
class HotelPush {
  HotelPush._();

  static bool isHotelPush(Map<String, dynamic> data) => '${data['action']}'.startsWith('hotel_') || '${data['type']}' == 'hotel';

  static String? _s(dynamic v) => v == null || '$v'.isEmpty || '$v' == 'null' ? null : '$v';

  /// The app is open. When that chat is on screen, it refreshes and the notification is not needed (returns true).
  static bool onForeground(Map<String, dynamic> data) {
    if (!Get.isRegistered<HotelController>()) return false;
    final c = Get.find<HotelController>();
    final id = _s(data['hotel_inquiry_id']);
    if (c.inquiries != null) c.loadInquiries(quiet: true);
    if (id != null && c.chatId == id) {
      c.refreshChat();
      return true;
    }
    return false;
  }

  static Widget screenFor(Map<String, dynamic> data) {
    final id = _s(data['hotel_inquiry_id']);
    return id != null ? HotelChatScreen(inquiryId: id) : const HotelChatsScreen();
  }
}
