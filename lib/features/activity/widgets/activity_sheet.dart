import 'package:ride_sharing_user_app/features/assistant/controllers/assistant_controller.dart';
import 'package:ride_sharing_user_app/features/assistant/screens/assistant_screen.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ride_sharing_user_app/features/activity/controllers/activity_controller.dart';
import 'package:ride_sharing_user_app/features/activity/domain/models/activity_item.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_booking_screen.dart';
import 'package:ride_sharing_user_app/features/guide/screens/tour_stop_screen.dart';
import 'package:ride_sharing_user_app/features/id_verification/screens/id_verification_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/my_jobs_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/my_applications_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/applicants_screen.dart';
import 'package:ride_sharing_user_app/features/listing/screens/my_listings_screen.dart';
import 'package:ride_sharing_user_app/features/listing/screens/listing_home_screen.dart';
import 'package:ride_sharing_user_app/features/listing/screens/my_visits_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_booking_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_cart_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_chats_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_item_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/my_market_shop_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_order_screen.dart';
import 'package:ride_sharing_user_app/features/message/screens/message_list.dart';
import 'package:ride_sharing_user_app/features/payment/screens/review_screen.dart';
import 'package:ride_sharing_user_app/features/trip/screens/trip_details_screen.dart';
import 'package:ride_sharing_user_app/features/hotel/screens/hotel_chat_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/jobs_home_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_home_screen.dart';
import 'package:ride_sharing_user_app/features/parcel/screens/parcel_list_view_screen.dart';
import 'package:ride_sharing_user_app/features/ride/screens/ride_list_view_screen.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_menu_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_order_screen.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// "Your activity": grouped by urgency, each line opens the screen to act on.
class ActivitySheet extends StatelessWidget {
  const ActivitySheet({super.key});

  static Future<void> show() async {
    final c = Get.find<ActivityController>();
    c.sheetOpen = true;
    c.update();
    c.refreshAll();
    await Get.bottomSheet(const ActivitySheet(), isScrollControlled: true, backgroundColor: Colors.transparent);
    c.sheetOpen = false;
    c.update();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<ActivityController>(builder: (c) {
      final items = c.items;
      return Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 42, height: 4,
              decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 2),
              child: Row(children: [
                Expanded(child: Text('act_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor))),
                IconButton(tooltip: 'close'.tr, onPressed: () => Get.back(), icon: Icon(Icons.close_rounded, color: theme.hintColor)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('act_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ),
            // Ask E-Ride, when the admin has it on.
            if (Get.isRegistered<AssistantController>() && Get.find<AssistantController>().enabled) const _AskBar(),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Center(child: Text('act_empty'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(color: theme.hintColor))),
              )
            else
              Flexible(child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), children: [
                for (final group in ActivityItem.groups)
                  if (items.any((i) => i.group == group)) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                      child: Text('act_group_$group'.tr.toUpperCase(), style: textBold.copyWith(
                        fontSize: Dimensions.fontSizeExtraSmall, letterSpacing: 0.6,
                        color: group == 'now' ? theme.primaryColor : theme.hintColor,
                      )),
                    ),
                    for (final i in items.where((i) => i.group == group)) _ActivityTile(item: i),
                  ],
              ])),
          ]),
        ),
      );
    });
  }
}

/// "Ask E-Ride anything", a microphone, and a few common questions.
class _AskBar extends StatelessWidget {
  const _AskBar();

  void _open({String? question, bool listen = false}) {
    if (Get.isBottomSheetOpen ?? false) Get.back();
    Get.to(() => AssistantScreen(question: question, listen: listen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ideas = ['assistant_idea_1'.tr, 'assistant_idea_2'.tr, 'assistant_idea_3'.tr];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.05),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _open,
            child: SizedBox(
              height: 48,
              child: Row(children: [
                const SizedBox(width: 14),
                Icon(Icons.auto_awesome_rounded, color: theme.primaryColor, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('assistant_ask_anything'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.hintColor))),
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: Material(
                    color: theme.primaryColor,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'assistant_speak'.tr,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _open(listen: true),
                      icon: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final idea in ideas)
            ActionChip(
              label: Text(idea, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
              onPressed: () => _open(question: idea),
              backgroundColor: theme.cardColor,
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
        ]),
      ]),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityItem item;
  const _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = describeActivity(item);
    final urgent = item.group == 'now';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: urgent ? theme.primaryColor.withValues(alpha: 0.06) : theme.hintColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => openActivity(item),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: d.color.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(d.icon, color: d.color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
                if (d.subtitle.isNotEmpty)
                  Text(d.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                if (item.deadline != null) ...[
                  const SizedBox(height: 4),
                  _TimeLeft(deadline: item.deadline!, color: urgent ? theme.primaryColor : theme.hintColor),
                ],
              ])),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: urgent ? theme.primaryColor : Colors.transparent,
                  border: urgent ? null : Border.all(color: theme.hintColor.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(Dimensions.radiusOverLarge),
                ),
                child: Text(d.action, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: urgent ? Colors.white : theme.textTheme.bodyLarge?.color)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "8:12 left", ticking.
class _TimeLeft extends StatefulWidget {
  final DateTime deadline;
  final Color color;
  const _TimeLeft({required this.deadline, required this.color});

  @override
  State<_TimeLeft> createState() => _TimeLeftState();
}

class _TimeLeftState extends State<_TimeLeft> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.deadline.difference(DateTime.now());
    final s = left.isNegative ? 0 : left.inSeconds;
    final text = s >= 3600
        ? 'act_until'.trParams({'time': DateFormat('HH:mm').format(widget.deadline)})
        : 'act_left'.trParams({'time': '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'});
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.timer_outlined, size: 14, color: widget.color),
      const SizedBox(width: 3),
      Text(text, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: widget.color, fontFeatures: const [FontFeature.tabularFigures()])),
    ]);
  }
}

String _clock(dynamic iso) {
  final t = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (t == null) return '';
  final now = DateTime.now();
  final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
  // Default locale on purpose: the app does not load intl's French date data.
  return sameDay ? DateFormat('HH:mm').format(t) : DateFormat('d MMM HH:mm').format(t);
}

String _day(dynamic iso) {
  final t = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  return t == null ? '' : DateFormat('d MMM').format(t);
}

/// Rides, moves and emergency rides use the same states, worded as what they are.
String _rideWords(String key, Map<String, dynamic> p) {
  final String type = '${p['type'] ?? 'ride'}';
  final String specific = '${key}_$type';
  return type != 'ride' && specific.tr != specific ? specific.tr : key.tr;
}

IconData _rideIcon(Map<String, dynamic> p) => switch ('${p['type'] ?? 'ride'}') {
      'health' => Icons.local_hospital_rounded,
      'move' => Icons.local_shipping_rounded,
      _ => Icons.local_taxi_rounded,
    };

String _money(dynamic v) => PriceConverter.convertPrice(double.tryParse('${v ?? 0}') ?? 0);

/// "1 thing needs you" / "4 things need you": the key, or its _one form for one.
String _counted(String key, dynamic count) {
  final n = int.tryParse('${count ?? 1}') ?? 1;
  return (n == 1 ? '${key}_one' : key).trParams({'count': '$n'});
}

/// Icon, colour and words for one line.
({IconData icon, Color color, String title, String subtitle, String action}) describeActivity(ActivityItem i) {
  final p = i.params;
  final store = '${p['store'] ?? ''}';
  const food = Color(0xFFE8590C), bus = Color(0xFF1D4ED8), hotel = Color(0xFF7C3AED), ride = Color(0xFF0F766E), other = Color(0xFF6B7280);
  return switch (i.kind) {
    'food_cart' => (icon: Icons.shopping_cart_rounded, color: food, title: 'act_food_cart'.trParams({'store': store}),
        subtitle: '${_counted('act_items', p['count'])} · ${_money(p['total'])}', action: 'act_continue'.tr),
    'food_waiting' => (icon: Icons.hourglass_top_rounded, color: food, title: 'act_food_waiting'.trParams({'store': store}), subtitle: 'act_food_waiting_sub'.tr, action: 'act_open'.tr),
    'food_changes' => (icon: Icons.edit_note_rounded, color: food, title: 'act_food_changes'.trParams({'store': store}), subtitle: 'act_food_changes_sub'.tr, action: 'act_see'.tr),
    'food_pay' => (icon: Icons.payments_rounded, color: food, title: 'act_food_pay'.trParams({'store': store}), subtitle: 'act_pay_amount'.trParams({'total': _money(p['total'])}), action: 'act_pay'.tr),
    // Eat there or collect: ready (show the code), or when it will be.
    'food_preparing' when p['ready'] == true => (icon: Icons.room_service_rounded, color: food, title: 'act_food_ready_here'.trParams({'store': store}),
        subtitle: 'act_food_show_code'.tr, action: 'act_open'.tr),
    'food_preparing' when p['way'] == 'dine_in' || p['way'] == 'pickup' => (icon: p['way'] == 'dine_in' ? Icons.restaurant_rounded : Icons.shopping_bag_rounded, color: food,
        title: (p['way'] == 'dine_in' ? 'act_food_table' : 'act_food_collect').trParams({'store': store, 'time': _clock(p['time'])}),
        subtitle: 'act_food_show_code'.tr, action: 'act_open'.tr),
    'food_preparing' => (icon: Icons.soup_kitchen_rounded, color: food, title: 'act_food_preparing'.trParams({'store': store}),
        subtitle: p['time'] != null ? 'act_ready_about'.trParams({'time': _clock(p['time'])}) : '', action: 'act_open'.tr),
    'food_rider' => (icon: Icons.two_wheeler_rounded, color: food, title: 'act_food_rider'.trParams({'store': store}), subtitle: '', action: 'act_open'.tr),
    'food_on_the_way' => (icon: Icons.delivery_dining_rounded, color: food, title: 'act_food_on_the_way'.trParams({'store': store}), subtitle: '', action: 'act_open'.tr),
    'food_rate' => (icon: Icons.star_rounded, color: const Color(0xFFF5A623), title: 'act_food_rate'.trParams({'store': store}), subtitle: '', action: 'act_rate'.tr),
    'bus_requested' => (icon: Icons.directions_bus_rounded, color: bus, title: 'act_bus_requested'.trParams({'agency': '${p['agency'] ?? ''}'}),
        subtitle: 'act_bus_to'.trParams({'city': '${p['city'] ?? ''}'}), action: 'act_open'.tr),
    'bus_pay' => (icon: Icons.directions_bus_rounded, color: bus, title: 'act_bus_pay'.trParams({'agency': '${p['agency'] ?? ''}'}),
        subtitle: '${'act_bus_to'.trParams({'city': '${p['city'] ?? ''}'})} · ${'act_pay_amount'.trParams({'total': _money(p['total'])})}', action: 'act_pay'.tr),
    'bus_ticket' => (icon: Icons.confirmation_number_rounded, color: bus, title: 'act_bus_ticket'.trParams({'city': '${p['city'] ?? ''}'}),
        subtitle: 'act_bus_leaves'.trParams({'agency': '${p['agency'] ?? ''}', 'time': _clock(p['time'])}), action: 'act_ticket'.tr),
    'hotel_reply' => (icon: Icons.mark_chat_unread_rounded, color: hotel, title: 'act_hotel_reply'.trParams({'hotel': '${p['hotel'] ?? ''}'}),
        subtitle: _counted('act_new_messages', p['count']), action: 'act_reply'.tr),
    'hotel_kept' => (icon: Icons.bed_rounded, color: hotel, title: 'act_hotel_kept'.trParams({'hotel': '${p['hotel'] ?? ''}'}), subtitle: 'act_hotel_kept_sub'.tr, action: 'act_open'.tr),
    'hotel_waiting' => (icon: Icons.bed_rounded, color: hotel, title: 'act_hotel_waiting'.trParams({'hotel': '${p['hotel'] ?? ''}'}), subtitle: '', action: 'act_open'.tr),
    'ride_pending' => (icon: _rideIcon(p), color: ride, title: _rideWords('act_ride_pending', p), subtitle: '${p['place'] ?? ''}', action: 'act_open'.tr),
    'ride_coming' => (icon: _rideIcon(p), color: ride, title: _rideWords('act_ride_coming', p), subtitle: '${p['place'] ?? ''}', action: 'act_open'.tr),
    'ride_ongoing' => (icon: _rideIcon(p), color: ride, title: _rideWords('act_ride_ongoing', p), subtitle: '${p['place'] ?? ''}', action: 'act_open'.tr),
    'ride_pay' => (icon: Icons.payments_rounded, color: ride, title: _rideWords('act_ride_pay', p), subtitle: '${p['place'] ?? ''}', action: 'act_pay'.tr),
    'ride_deposit' => (icon: Icons.lock_clock_rounded, color: ride, title: 'act_ride_deposit'.tr,
        subtitle: 'act_pay_amount'.trParams({'total': _money(p['total'])}), action: 'act_pay'.tr),
    'ride_offers' => (icon: Icons.local_offer_rounded, color: ride, title: _counted('act_ride_offers', p['count']), subtitle: 'act_ride_offers_sub'.tr, action: 'act_see'.tr),
    'ride_rate' => (icon: Icons.star_rounded, color: const Color(0xFFF5A623),
        title: '${p['driver'] ?? ''}'.isEmpty ? 'act_ride_rate'.tr : 'act_ride_rate_driver'.trParams({'driver': '${p['driver']}'}), subtitle: '', action: 'act_rate'.tr),
    'ride_scheduled' => (icon: Icons.event_rounded, color: ride, title: 'act_ride_scheduled'.trParams({'time': _clock(p['time'])}), subtitle: '${p['place'] ?? ''}', action: 'act_open'.tr),
    'parcel_active' => (icon: Icons.inventory_2_rounded, color: ride, title: _counted('act_parcel_active', p['count']), subtitle: '', action: 'act_open'.tr),
    'parcel_returning' => (icon: Icons.assignment_return_rounded, color: ride, title: _counted('act_parcel_returning', p['count']), subtitle: 'act_parcel_returning_sub'.tr, action: 'act_see'.tr),
    'parcel_pay' => (icon: Icons.payments_rounded, color: ride, title: _counted('act_parcel_pay', p['count']), subtitle: '', action: 'act_pay'.tr),
    'chat_unread' => (icon: Icons.mark_chat_unread_rounded, color: ride, title: _counted('act_chat_unread', p['count']), subtitle: '', action: 'act_reply'.tr),
    'tour_active' => (icon: Icons.route_rounded, color: const Color(0xFF0E9F6E), title: '${p['title'] ?? ''}',
        subtitle: 'act_tour_stop'.trParams({'num': '${p['n'] ?? 1}', 'total': '${p['total'] ?? 1}', 'place': '${p['place'] ?? ''}'}), action: 'act_open'.tr),
    'tour_visit' => (icon: Icons.place_rounded, color: const Color(0xFF0E9F6E), title: 'act_tour_visit'.trParams({'place': '${p['place'] ?? ''}'}), subtitle: 'act_tour_visit_sub'.tr, action: 'act_open'.tr),
    'food_failed' => (icon: Icons.report_problem_rounded, color: food, title: 'act_food_failed'.trParams({'store': store}), subtitle: 'act_food_failed_sub'.tr, action: 'act_see'.tr),
    'bus_at_risk' => (icon: Icons.warning_amber_rounded, color: bus, title: 'act_bus_at_risk'.trParams({'city': '${p['city'] ?? ''}'}), subtitle: 'act_bus_at_risk_sub'.tr, action: 'act_see'.tr),
    'bus_moved' => (icon: Icons.swap_horiz_rounded, color: bus, title: 'act_bus_moved'.trParams({'city': '${p['city'] ?? ''}'}),
        subtitle: 'act_bus_leaves'.trParams({'agency': '${p['agency'] ?? ''}', 'time': _clock(p['time'])}), action: 'act_see'.tr),
    'bus_upcoming' => (icon: Icons.confirmation_number_rounded, color: bus, title: 'act_bus_ticket'.trParams({'city': '${p['city'] ?? ''}'}),
        subtitle: 'act_bus_leaves'.trParams({'agency': '${p['agency'] ?? ''}', 'time': _clock(p['time'])}), action: 'act_ticket'.tr),
    'bus_refund' => (icon: Icons.currency_exchange_rounded, color: bus, title: 'act_bus_refund'.trParams({'agency': '${p['agency'] ?? ''}'}),
        subtitle: 'act_refund_amount'.trParams({'total': _money(p['total'])}), action: 'act_open'.tr),
    'hotel_answered' => (icon: Icons.bed_rounded, color: hotel, title: 'act_hotel_answered'.trParams({'hotel': '${p['hotel'] ?? ''}'}), subtitle: '', action: 'act_open'.tr),
    'id_pending' => (icon: Icons.badge_rounded, color: other, title: 'act_id_pending'.tr, subtitle: 'act_id_pending_sub'.tr, action: 'act_open'.tr),
    'id_refused' => (icon: Icons.badge_rounded, color: const Color(0xFFDC2626), title: 'act_id_refused'.tr, subtitle: '${p['reason'] ?? ''}', action: 'act_try_again'.tr),
    'lost_waiting' => (icon: Icons.search_rounded, color: other, title: 'act_lost_waiting'.tr, subtitle: '${p['item'] ?? ''}', action: 'act_open'.tr),
    'lost_found' => (icon: Icons.check_circle_rounded, color: const Color(0xFF15803D), title: 'act_lost_found'.tr, subtitle: '${p['item'] ?? ''}', action: 'act_see'.tr),
    'lost_not_found' => (icon: Icons.search_off_rounded, color: other, title: 'act_lost_not_found'.tr, subtitle: '${p['item'] ?? ''}', action: 'act_see'.tr),
    'market_cart' => (icon: Icons.shopping_cart_rounded, color: other, title: 'act_market_cart'.trParams({'shop': '${p['shop'] ?? ''}'}),
        subtitle: '${_counted('act_items', p['count'])} · ${_money(p['total'])}', action: 'act_continue'.tr),
    'market_order_waiting' => (icon: Icons.hourglass_top_rounded, color: other, title: 'act_market_order_waiting'.trParams({'shop': '${p['shop'] ?? ''}'}), subtitle: '', action: 'act_open'.tr),
    'market_order_changes' => (icon: Icons.edit_note_rounded, color: other, title: 'act_market_order_changes'.trParams({'shop': '${p['shop'] ?? ''}'}), subtitle: 'act_food_changes_sub'.tr, action: 'act_see'.tr),
    'market_auction_pay' => (icon: Icons.emoji_events_rounded, color: const Color(0xFFB45309), title: 'act_market_auction_pay'.trParams({'shop': '${p['shop'] ?? ''}'}),
        subtitle: 'act_market_auction_pay_sub'.tr, action: 'act_open'.tr),
    'market_order_rate' => (icon: Icons.star_rounded, color: const Color(0xFFF5A623), title: 'act_market_order_rate'.trParams({'shop': '${p['shop'] ?? ''}'}), subtitle: '', action: 'act_rate'.tr),
    'market_sell_new' => (icon: Icons.storefront_rounded, color: other, title: 'act_market_sell_new'.trParams({'buyer': '${p['buyer'] ?? ''}'}),
        subtitle: _money(p['total']), action: 'act_reply'.tr),
    'market_sell_prepare' => (icon: Icons.inventory_rounded, color: other, title: 'act_market_sell_prepare'.trParams({'buyer': '${p['buyer'] ?? ''}'}), subtitle: 'act_market_sell_prepare_sub'.tr, action: 'act_open'.tr),
    'market_sell_wait_pay' => (icon: Icons.payments_rounded, color: other, title: 'act_market_sell_wait_pay'.trParams({'buyer': '${p['buyer'] ?? ''}'}), subtitle: '', action: 'act_open'.tr),
    'market_sell_handover' => (icon: Icons.handshake_rounded, color: other, title: 'act_market_sell_handover'.trParams({'buyer': '${p['buyer'] ?? ''}'}), subtitle: 'act_market_sell_handover_sub'.tr, action: 'act_open'.tr),
    'market_quote_answer' => (icon: Icons.request_quote_rounded, color: other, title: 'act_market_quote_answer'.trParams({'title': '${p['title'] ?? ''}'}),
        subtitle: _money(p['total']), action: 'act_see'.tr),
    'market_time_answer' => (icon: Icons.schedule_rounded, color: other, title: 'act_market_time_answer'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: _clock(p['time']), action: 'act_see'.tr),
    'market_booking_waiting' => (icon: Icons.hourglass_top_rounded, color: other, title: 'act_market_booking_waiting'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: '', action: 'act_open'.tr),
    'market_booking_rate' => (icon: Icons.star_rounded, color: const Color(0xFFF5A623), title: 'act_market_booking_rate'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: '', action: 'act_rate'.tr),
    'market_provider_request' => (icon: Icons.event_note_rounded, color: other, title: 'act_market_provider_request'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: _clock(p['time']), action: 'act_reply'.tr),
    'market_quote_request' => (icon: Icons.request_quote_rounded, color: other, title: 'act_market_quote_request'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: '', action: 'act_reply'.tr),
    'market_provider_upcoming' => (icon: Icons.event_available_rounded, color: other, title: 'act_market_provider_upcoming'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: _clock(p['time']), action: 'act_open'.tr),
    'market_auction_offer' => (icon: Icons.local_offer_rounded, color: const Color(0xFFB45309), title: 'act_market_auction_offer'.trParams({'title': '${p['title'] ?? ''}'}),
        subtitle: _money(p['total']), action: 'act_see'.tr),
    'market_auction_leading' => (icon: Icons.trending_up_rounded, color: const Color(0xFF15803D), title: 'act_market_auction_leading'.trParams({'title': '${p['title'] ?? ''}'}),
        subtitle: 'act_market_auction_ends'.trParams({'time': _clock(p['time'])}), action: 'act_open'.tr),
    'market_auction_outbid' => (icon: Icons.gavel_rounded, color: const Color(0xFFDC2626), title: 'act_market_auction_outbid'.trParams({'title': '${p['title'] ?? ''}'}),
        subtitle: '${_money(p['total'])} · ${'act_market_auction_ends'.trParams({'time': _clock(p['time'])})}', action: 'act_bid'.tr),
    'market_auction_unsold' => (icon: Icons.gavel_rounded, color: other, title: 'act_market_auction_unsold'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: 'act_market_auction_unsold_sub'.tr, action: 'act_see'.tr),
    'market_auction_selling' => (icon: Icons.gavel_rounded, color: other, title: 'act_market_auction_selling'.trParams({'title': '${p['title'] ?? ''}'}),
        subtitle: '${_counted('act_bids', p['count'])} · ${_money(p['total'])}', action: 'act_open'.tr),
    'market_shop_closed' => (icon: Icons.store_mall_directory_rounded, color: const Color(0xFFDC2626), title: 'act_market_shop_closed'.trParams({'shop': '${p['shop'] ?? ''}'}), subtitle: '${p['reason'] ?? ''}', action: 'act_see'.tr),
    'market_shop_checking' => (icon: Icons.verified_outlined, color: other, title: 'act_market_shop_checking'.trParams({'shop': '${p['shop'] ?? ''}'}), subtitle: '', action: 'act_open'.tr),
    'market_items_hidden' => (icon: Icons.visibility_off_rounded, color: const Color(0xFFDC2626), title: _counted('act_market_items_hidden', p['count']), subtitle: 'act_market_items_hidden_sub'.tr, action: 'act_see'.tr),
    'market_items_sold_out' => (icon: Icons.remove_shopping_cart_rounded, color: other, title: _counted('act_market_items_sold_out', p['count']), subtitle: 'act_market_items_sold_out_sub'.tr, action: 'act_open'.tr),
    'market_chat_unread' => (icon: Icons.mark_chat_unread_rounded, color: other, title: _counted('act_market_chat_unread', p['count']), subtitle: '', action: 'act_reply'.tr),
    'market_order' => (icon: Icons.shopping_bag_rounded, color: other, title: 'act_market_order'.trParams({'shop': '${p['shop'] ?? ''}'}),
        subtitle: 'act_market_status_${p['status'] ?? 'confirmed'}'.tr, action: 'act_open'.tr),
    'market_booking' => (icon: Icons.event_available_rounded, color: other, title: 'act_market_booking'.trParams({'title': '${p['title'] ?? ''}'}),
        subtitle: _clock(p['time']), action: 'act_open'.tr),
    'home_visit_proposed' => (icon: Icons.schedule_rounded, color: other, title: 'act_home_visit_proposed'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: _day(p['time']), action: 'act_see'.tr),
    'home_visit_outcome' => (icon: Icons.rate_review_rounded, color: other, title: 'act_home_visit_outcome'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: '', action: 'act_open'.tr),
    'home_reservation_pay' => (icon: Icons.payments_rounded, color: other, title: 'act_home_reservation_pay'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: 'act_pay_amount'.trParams({'total': _money(p['total'])}), action: 'act_pay'.tr),
    'home_reservation_waiting' => (icon: Icons.hourglass_top_rounded, color: other, title: 'act_home_reservation_waiting'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: '', action: 'act_open'.tr),
    'home_visit_request' => (icon: Icons.event_note_rounded, color: other, title: 'act_home_visit_request'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: _day(p['time']), action: 'act_reply'.tr),
    'home_taking' => (icon: Icons.key_rounded, color: other, title: 'act_home_taking'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: 'act_home_taking_sub'.tr, action: 'act_see'.tr),
    'home_reservation_accept' => (icon: Icons.key_rounded, color: other, title: 'act_home_reservation_accept'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: _money(p['total']), action: 'act_see'.tr),
    'home_listing_changes' => (icon: Icons.edit_note_rounded, color: other, title: 'act_home_listing_changes'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: 'act_job_sent_back_sub'.tr, action: 'act_see'.tr),
    'home_listing_confirm' => (icon: Icons.help_outline_rounded, color: other, title: 'act_home_listing_confirm'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: 'act_home_listing_confirm_sub'.tr, action: 'act_open'.tr),
    'job_next_step' => (icon: Icons.work_rounded, color: other, title: 'act_job_next_step'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: _clock(p['time']), action: 'act_see'.tr),
    'job_hired' => (icon: Icons.celebration_rounded, color: const Color(0xFF15803D), title: 'act_job_hired'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: 'act_job_hired_sub'.tr, action: 'act_open'.tr),
    'job_applied' => (icon: Icons.work_outline_rounded, color: other, title: _counted('act_job_applied', p['count']), subtitle: '', action: 'act_open'.tr),
    'job_applicants' => (icon: Icons.people_alt_rounded, color: other, title: _counted('act_job_applicants', p['count']), subtitle: '${p['title'] ?? ''}', action: 'act_see'.tr),
    'home_visit' => (icon: Icons.home_work_rounded, color: other, title: 'act_home_visit'.trParams({'title': '${p['title'] ?? ''}'}),
        subtitle: _day(p['time']), action: 'act_open'.tr),
    'home_reserved' => (icon: Icons.key_rounded, color: other, title: 'act_home_reserved'.trParams({'title': '${p['title'] ?? ''}'}),
        subtitle: p['time'] != null ? 'act_move_in'.trParams({'day': _day(p['time'])}) : '', action: 'act_open'.tr),
    'home_problem' => (icon: Icons.report_problem_rounded, color: const Color(0xFFDC2626), title: 'act_home_problem'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: '', action: 'act_see'.tr),
    'job_sent_back' => (icon: Icons.edit_note_rounded, color: other, title: 'act_job_sent_back'.trParams({'title': '${p['title'] ?? ''}'}), subtitle: 'act_job_sent_back_sub'.tr, action: 'act_see'.tr),
    'market_attention' => (icon: Icons.storefront_rounded, color: other, title: _counted('act_market', p['count']), subtitle: '', action: 'act_open'.tr),
    'jobs_attention' => (icon: Icons.work_outline_rounded, color: other, title: _counted('act_jobs', p['count']), subtitle: '', action: 'act_open'.tr),
    'homes_attention' => (icon: Icons.home_work_rounded, color: other, title: _counted('act_homes', p['count']), subtitle: '', action: 'act_open'.tr),
    _ => (icon: Icons.pending_actions_rounded, color: other, title: i.kind, subtitle: '', action: 'act_open'.tr),
  };
}

/// Closes the sheet and opens the screen where the customer acts.
Future<void> openActivity(ActivityItem i) async {
  if (Get.isBottomSheetOpen ?? false) Get.back();
  switch (i.kind) {
    case 'food_cart':
      Get.find<StoreController>().openCartStore();
      Get.to(() => const StoreMenuScreen());
    case 'food_waiting' || 'food_changes' || 'food_pay' || 'food_preparing' || 'food_rider' || 'food_on_the_way' || 'food_rate' || 'food_failed':
      Get.to(() => StoreOrderScreen(orderId: i.id));
    case 'bus_requested' || 'bus_pay' || 'bus_ticket' || 'bus_at_risk' || 'bus_moved' || 'bus_upcoming' || 'bus_refund':
      Get.to(() => BusBookingScreen(bookingId: i.id));
    case 'hotel_reply' || 'hotel_kept' || 'hotel_waiting' || 'hotel_answered':
      Get.to(() => HotelChatScreen(inquiryId: i.id));
    case 'ride_pending' || 'ride_coming' || 'ride_ongoing' || 'ride_scheduled' || 'ride_pay' || 'ride_deposit' || 'ride_offers':
      // The ride list resumes the ride on its own screen (offers, payment, deposit).
      Get.to(() => const RideListViewScreen());
    case 'ride_rate':
      Get.to(() => ReviewScreen(tripId: i.id));
    case 'parcel_active' || 'parcel_returning':
      Get.to(() => const ParcelListViewScreen(title: 'ongoing_parcel_list'));
    case 'parcel_pay':
      Get.to(() => const ParcelListViewScreen(title: 'act_unpaid_parcels', unpaid: true));
    case 'chat_unread':
      Get.to(() => const MessageListScreen());
    case 'tour_active' || 'tour_visit':
      Get.to(() => const TourStopScreen());
    case 'id_pending' || 'id_refused':
      Get.to(() => const IdVerificationScreen());
    case 'lost_waiting' || 'lost_found' || 'lost_not_found':
      // The lost item card lives on the trip's page.
      Get.to(() => TripDetailsScreen(tripId: i.id));
    case 'market_cart':
      Get.to(() => const MarketCartScreen());
    case 'market_order' || 'market_order_waiting' || 'market_order_changes' || 'market_auction_pay' || 'market_order_rate'
        || 'market_sell_new' || 'market_sell_prepare' || 'market_sell_wait_pay' || 'market_sell_handover':
      Get.to(() => MarketOrderScreen(orderId: i.id));
    case 'market_booking' || 'market_quote_answer' || 'market_time_answer' || 'market_booking_waiting' || 'market_booking_rate'
        || 'market_provider_request' || 'market_quote_request' || 'market_provider_upcoming':
      Get.to(() => MarketBookingScreen(bookingId: i.id));
    case 'market_auction_offer' || 'market_auction_leading' || 'market_auction_outbid' || 'market_auction_unsold' || 'market_auction_selling':
      Get.to(() => MarketItemScreen(code: i.id));
    case 'market_shop_closed' || 'market_shop_checking' || 'market_items_hidden' || 'market_items_sold_out':
      Get.to(() => const MyMarketShopScreen());
    case 'market_chat_unread':
      Get.to(() => const MarketChatsScreen());
    case 'home_visit' || 'home_reserved' || 'home_problem' || 'home_visit_proposed' || 'home_visit_outcome' || 'home_reservation_pay' || 'home_reservation_waiting':
      Get.to(() => const MyVisitsScreen());
    case 'home_visit_request' || 'home_taking' || 'home_reservation_accept' || 'home_listing_changes' || 'home_listing_confirm':
      Get.to(() => const MyListingsScreen());
    case 'job_sent_back':
      Get.to(() => const MyJobsScreen());
    case 'job_next_step' || 'job_hired':
      Get.to(() => JobApplicationScreen(id: i.id));
    case 'job_applied':
      Get.to(() => const MyApplicationsScreen());
    case 'job_applicants':
      Get.to(() => ApplicantsScreen(code: i.id, title: '${i.params['title'] ?? ''}'));
    case 'market_attention':
      Get.to(() => const MarketHomeScreen());
    case 'jobs_attention':
      Get.to(() => const JobsHomeScreen());
    case 'homes_attention':
      Get.to(() => const ListingHomeScreen());
  }
}
