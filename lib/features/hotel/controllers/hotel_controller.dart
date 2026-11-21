import 'dart:async';

import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/hotel/domain/models/hotel_models.dart';
import 'package:ride_sharing_user_app/features/hotel/domain/services/hotel_service_interface.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';

/// Partner hotels: a hotel's rooms for some dates, asking the reception, and the chats that follow.
class HotelController extends GetxController implements GetxService {
  final HotelServiceInterface hotelServiceInterface;
  HotelController({required this.hotelServiceInterface});

  static String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

  // ------------------------------------------------------------- Dates (shared by the list and the hotel page)

  DateTime checkIn = day(DateTime.now());
  DateTime checkOut = day(DateTime.now()).add(const Duration(days: 1));
  int get nights => checkOut.difference(checkIn).inDays;

  void setDates(DateTime from, DateTime to) {
    checkIn = day(from);
    checkOut = day(to).isAfter(checkIn) ? day(to) : checkIn.add(const Duration(days: 1));
    update();
  }

  // ------------------------------------------------------------- A hotel

  HotelDetail? detail;
  bool loadingDetail = false;
  String? _detailId;

  Future<void> loadHotel(String id) async {
    _detailId = id;
    loadingDetail = true;
    if (detail != null && detail!.id != id && detail!.placeId != id) detail = null;
    update();
    final Response r = await hotelServiceInterface.getHotel(id, ymd(checkIn), ymd(checkOut));
    if (_detailId != id) return;
    loadingDetail = false;
    if (r.statusCode == 200 && r.body['data'] is Map) {
      detail = HotelDetail.fromJson(Map<String, dynamic>.from(r.body['data']));
    } else {
      ApiChecker.checkApi(r);
    }
    update();
  }

  bool asking = false;

  /// Sends the question. Returns the question's id to open its chat.
  Future<String?> ask(String hotelId, {required String roomTypeId, required int guests, required int rooms, String? arrival, String? question}) async {
    asking = true;
    update();
    final Response r = await hotelServiceInterface.ask(hotelId, {
      'room_type_id': roomTypeId, 'check_in': ymd(checkIn), 'check_out': ymd(checkOut), 'guests': guests, 'rooms': rooms,
      if (arrival != null) 'arrival': arrival, if (question != null && question.trim().isNotEmpty) 'question': question.trim(),
    });
    asking = false;
    update();
    if (r.statusCode == 200 && r.body['data'] is Map) {
      final HotelInquiry q = HotelInquiry.fromJson(Map<String, dynamic>.from(r.body['data']));
      chat = q;
      chatId = q.id;
      loadInquiries(quiet: true);
      return q.id;
    }
    ApiChecker.checkApi(r);
    return null;
  }

  // ------------------------------------------------------------- My questions

  List<HotelInquiry>? inquiries;
  int unread = 0;
  bool loadingList = false;

  Future<void> loadInquiries({bool quiet = false}) async {
    if (!quiet) {
      loadingList = true;
      update();
    }
    final Response r = await hotelServiceInterface.getInquiries();
    loadingList = false;
    if (r.statusCode == 200 && r.body['data'] is Map) {
      final data = Map<String, dynamic>.from(r.body['data']);
      inquiries = ((data['inquiries'] as List?) ?? []).whereType<Map>().map((e) => HotelInquiry.fromJson(Map<String, dynamic>.from(e))).toList();
      unread = int.tryParse('${data['unread']}') ?? 0;
    } else if (!quiet) {
      ApiChecker.checkApi(r);
    }
    update();
  }

  // ------------------------------------------------------------- One chat

  HotelInquiry? chat;
  String? chatId;
  bool loadingChat = false;
  bool sending = false;
  Timer? _poll;
  bool _polling = false;

  Future<void> openChat(String id) async {
    if (chatId != id) chat = null;
    chatId = id;
    loadingChat = chat == null;
    update();
    await _load(id, full: true);
    loadingChat = false;
    update();
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => refreshChat());
  }

  void closeChat() {
    _poll?.cancel();
    _poll = null;
    chatId = null;
    loadInquiries(quiet: true);
  }

  Future<void> refreshChat() async {
    final String? id = chatId;
    if (id == null || _polling) return;
    _polling = true;
    await _load(id, full: false);
    _polling = false;
  }

  Future<void> _load(String id, {required bool full}) async {
    final int? after = !full && chat != null && chat!.id == id && chat!.messages.isNotEmpty ? chat!.messages.last.id : null;
    final Response r = await hotelServiceInterface.getInquiry(id, after: after);
    if (chatId != id) return;
    if (r.statusCode == 200 && r.body['data'] is Map) {
      final HotelInquiry fresh = HotelInquiry.fromJson(Map<String, dynamic>.from(r.body['data']));
      if (after != null && chat != null) {
        final known = chat!.messages.map((m) => m.id).toSet();
        final added = fresh.messages.where((m) => !known.contains(m.id)).toList();
        chat = fresh.withMessages([...chat!.messages, ...added]);
      } else {
        chat = fresh;
      }
      update();
    } else if (full) {
      ApiChecker.checkApi(r);
    }
  }

  Future<bool> send(String text) async {
    final String? id = chatId;
    if (id == null || text.trim().isEmpty || sending) return false;
    sending = true;
    update();
    final Response r = await hotelServiceInterface.send(id, text.trim());
    sending = false;
    update();
    if (r.statusCode == 200) {
      await refreshChat();
      return true;
    }
    ApiChecker.checkApi(r);
    return false;
  }

  /// "I no longer need it": the question closes and a kept room is free again.
  Future<bool> release() async {
    final String? id = chatId;
    if (id == null) return false;
    final Response r = await hotelServiceInterface.release(id);
    if (r.statusCode == 200 && r.body['data'] is Map) {
      chat = HotelInquiry.fromJson(Map<String, dynamic>.from(r.body['data']));
      update();
      loadInquiries(quiet: true);
      showCustomSnackBar('hotel_released_done'.tr, isError: false);
      return true;
    }
    ApiChecker.checkApi(r);
    return false;
  }

  @override
  void onClose() {
    _poll?.cancel();
    super.onClose();
  }
}
