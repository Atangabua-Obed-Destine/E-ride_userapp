import 'package:ride_sharing_user_app/features/assistant/widgets/help_button.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/call_options_sheet.dart';
import 'package:ride_sharing_user_app/common_widgets/chat_kit.dart';
import 'package:ride_sharing_user_app/features/bus/widgets/bus_widgets.dart';
import 'package:ride_sharing_user_app/features/hotel/controllers/hotel_controller.dart';
import 'package:ride_sharing_user_app/features/hotel/domain/models/hotel_models.dart';
import 'package:ride_sharing_user_app/features/hotel/screens/hotel_screen.dart';
import 'package:ride_sharing_user_app/features/hotel/widgets/hotel_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_map_card.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The chat with a hotel's reception: the question, answers, a price, a kept room (with a ride there).
class HotelChatScreen extends StatefulWidget {
  final String inquiryId;
  const HotelChatScreen({super.key, required this.inquiryId});

  @override
  State<HotelChatScreen> createState() => _HotelChatScreenState();
}

class _HotelChatScreenState extends State<HotelChatScreen> {
  HotelController get _c => Get.find<HotelController>();
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _c.openChat(widget.inquiryId));
  }

  @override
  void dispose() {
    _c.closeChat();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final t = _text.text;
    if (t.trim().isEmpty) return;
    _text.clear();
    final ok = await _c.send(t);
    if (!ok) _text.text = t;
  }

  Future<void> _release() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('hotel_release_title'.tr),
        content: Text('hotel_release_body'.tr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('hotel_keep_it'.tr)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('hotel_release_yes'.tr)),
        ],
      ),
    );
    if (yes == true) await _c.release();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GetBuilder<HotelController>(builder: (c) {
      final q = c.chat != null && c.chat!.id == widget.inquiryId ? c.chat : null;
      if (q != null && q.messages.length != _seen) {
        _seen = q.messages.length;
        _toBottom();
      }
      return Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : const Color(0xFFEEF1F1),
        body: Column(children: [
          ChatHeader(
            name: q?.hotel.name ?? '',
            subtitle: q == null ? '' : (hotelAnswerText(q.hotel.answerMinutes) ?? 'hotel_reception'.tr),
            imageUrl: q?.hotel.photo,
            onBack: () => Get.back(),
            onCall: q?.hotel.receptionPhone == null ? null : () => CallOptionsSheet.show(phone: q!.hotel.receptionPhone, name: q.hotel.name),
          ),
          if (q == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else ...[
            _Summary(q: q, onRelease: q.status == 'open' || q.status == 'answered' || q.status == 'kept' ? _release : null),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                itemCount: q.messages.length + (q.isKept ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == q.messages.length) return _KeptCard(q: q, onRelease: _release);
                  return _Message(m: q.messages[i], q: q);
                },
              ),
            ),
            if (q.isActive)
              SafeArea(
                top: false,
                child: Container(
                  color: theme.cardColor,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 1000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'hotel_message_reception'.tr,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: theme.primaryColor, minimumSize: const Size(48, 48)),
                      onPressed: c.sending ? null : _send,
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      tooltip: 'hotel_send'.tr,
                    ),
                  ]),
                ),
              )
            else
              SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  color: theme.cardColor,
                  padding: const EdgeInsets.all(14),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('hotel_chat_closed'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(color: theme.hintColor)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Get.off(() => HotelScreen(id: q.hotel.id, name: q.hotel.name)),
                      child: Text('hotel_ask_again'.tr),
                    ),
                  ]),
                ),
              ),
          ],
        ]),
      );
    });
  }
}

/// What was asked, at the top of the chat.
class _Summary extends StatelessWidget {
  final HotelInquiry q;
  final VoidCallback? onRelease;
  const _Summary({required this.q, this.onRelease});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.cardColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text([q.roomTypeName ?? '', (q.rooms == 1 ? 'hotel_one_room' : 'hotel_n_rooms').trParams({'n': '${q.rooms}'})].where((s) => s.isNotEmpty).join(' · '),
              style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
          Text(hotelDates(q.checkIn, q.checkOut), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ])),
        if (onRelease != null)
          PopupMenuButton<String>(
            tooltip: 'hotel_more'.tr,
            onSelected: (_) => onRelease!(),
            itemBuilder: (_) => [PopupMenuItem(value: 'release', child: Text('hotel_no_longer_need'.tr))],
          ),
      ]),
    );
  }
}

class _Message extends StatelessWidget {
  final HotelMessage m;
  final HotelInquiry q;
  const _Message({required this.m, required this.q});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final d = m.data;
    final time = m.at == null ? '' : busTime(m.at!);
    Widget card({required Widget child, Color? border, Color? background, bool right = false}) => Align(
          alignment: right ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: background ?? theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border ?? theme.hintColor.withValues(alpha: 0.15), width: 1.5),
            ),
            child: child,
          ),
        );
    Widget system(String text) => Center(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
            child: Text(text, textAlign: TextAlign.center, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor)),
          ),
        );
    switch (m.kind) {
      case 'request':
        final nights = int.tryParse('${d['nights']}') ?? 1;
        final rooms = int.tryParse('${d['rooms']}') ?? 1;
        final guests = int.tryParse('${d['guests']}') ?? 1;
        final from = DateTime.tryParse('${d['check_in']}');
        final to = DateTime.tryParse('${d['check_out']}');
        return card(right: true, border: theme.primaryColor, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('hotel_room_request'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.primaryColor, letterSpacing: .3)),
          const SizedBox(height: 2),
          Text('${d['room_type'] ?? ''} · ${(rooms == 1 ? 'hotel_one_room' : 'hotel_n_rooms').trParams({'n': '$rooms'})}', style: textBold.copyWith(color: textColor)),
          if (from != null && to != null) Text(hotelDates(from, to), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor)),
          Text((guests == 1 ? 'hotel_one_guest' : 'hotel_n_guests').trParams({'n': '$guests'}) + (d['arrival'] != null ? ' · ${hotelArrival('${d['arrival']}')}' : ''),
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor)),
          if (m.body != null) ...[const SizedBox(height: 4), Text(m.body!, style: textRegular.copyWith(color: textColor))],
          if (nights > 0) Align(alignment: Alignment.centerRight, child: Text(time, style: textRegular.copyWith(fontSize: 11, color: theme.hintColor))),
        ]));
      case 'price':
        final amount = int.tryParse('${d['amount']}');
        final nights = int.tryParse('${d['nights']}') ?? 1;
        return card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('hotel_price_for_dates'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor, letterSpacing: .3)),
          const SizedBox(height: 2),
          Text(hotelMoney(amount), style: textBold.copyWith(fontSize: 20, color: theme.primaryColor)),
          Text('${(nights == 1 ? 'hotel_one_night' : 'hotel_n_nights').trParams({'n': '$nights'})} · ${'hotel_paid_at_hotel'.tr}',
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          Align(alignment: Alignment.centerRight, child: Text(time, style: textRegular.copyWith(fontSize: 11, color: theme.hintColor))),
        ]));
      case 'kept':
        final until = DateTime.tryParse('${d['until']}')?.toLocal();
        return card(border: const Color(0xFFE8B562), background: hotelAmberBg, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('hotel_kept_until'.trParams({'time': until == null ? '' : busWhen(until)}), style: textBold.copyWith(color: hotelAmber))),
            const HelpButton(helpKey: 'hotel_kept', size: 18, color: hotelAmber),
          ]),
          Text('${d['room_type'] ?? ''}', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: hotelAmber)),
          Align(alignment: Alignment.centerRight, child: Text(time, style: textRegular.copyWith(fontSize: 11, color: hotelAmber))),
        ]));
      case 'released':
        final r = '${d['reason']}';
        return system(r == 'guest' ? 'hotel_sys_released_guest'.tr : r == 'expired' ? 'hotel_sys_released_expired'.tr : 'hotel_sys_released_didnt'.tr);
      case 'arrived':
        return system('hotel_sys_arrived'.tr);
      case 'closed':
        return system('${d['reason']}' == 'full' ? 'hotel_sys_full'.tr : 'hotel_sys_closed'.tr);
      default:
        final mine = m.mine;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            constraints: const BoxConstraints(maxWidth: 290),
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
            decoration: BoxDecoration(
              color: mine ? theme.primaryColor : theme.cardColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14), topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(mine ? 14 : 4), bottomRight: Radius.circular(mine ? 4 : 14),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Align(alignment: Alignment.centerLeft, child: Text(m.body ?? '', style: textRegular.copyWith(color: mine ? Colors.white : textColor))),
              const SizedBox(height: 2),
              Text(time, style: textRegular.copyWith(fontSize: 11, color: mine ? Colors.white70 : theme.hintColor)),
            ]),
          ),
        );
    }
  }
}

/// The room kept for you: time left, a ride there, or let it go.
class _KeptCard extends StatefulWidget {
  final HotelInquiry q;
  final VoidCallback onRelease;
  const _KeptCard({required this.q, required this.onRelease});

  @override
  State<_KeptCard> createState() => _KeptCardState();
}

class _KeptCardState extends State<_KeptCard> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = widget.q;
    final left = q.keptUntil!.difference(DateTime.now());
    final h = left.inHours;
    final m = left.inMinutes % 60;
    final leftText = left.isNegative ? 'hotel_time_passed'.tr : (h > 0 ? 'hotel_left_hm' : 'hotel_left_m').trParams({'h': '$h', 'm': '$m'});
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: hotelAmberBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE8B562), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.hotel_rounded, color: hotelAmber, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('hotel_kept_for_you'.trParams({'time': busTime(q.keptUntil!)}), style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: const Color(0xFF6B3F00)))),
        ]),
        const SizedBox(height: 4),
        Text('$leftText · ${'hotel_kept_hint'.tr}', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: const Color(0xFF6B3F00))),
        if (q.onTheWay) ...[
          const SizedBox(height: 6),
          HotelChip(text: 'hotel_on_the_way'.tr, color: const Color(0xFF1D4ED8), icon: Icons.local_taxi_rounded),
        ],
        const SizedBox(height: 10),
        Row(children: [
          if (q.hotel.hasLocation)
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => marketRideThere(q.hotel.latitude!, q.hotel.longitude!, [q.hotel.name, if (q.hotel.address != null) q.hotel.address!].join(', ')),
                  child: Text('hotel_ride_to_hotel'.tr, style: textBold.copyWith(color: Colors.white)),
                ),
              ),
            ),
          const SizedBox(width: 8),
          SizedBox(
            height: 46,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(backgroundColor: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: widget.onRelease,
              child: Text('hotel_let_go'.tr, style: textSemiBold.copyWith(color: theme.textTheme.bodyLarge?.color)),
            ),
          ),
        ]),
      ]),
    );
  }
}
