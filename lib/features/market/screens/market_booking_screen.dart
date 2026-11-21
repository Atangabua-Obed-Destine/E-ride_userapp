import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_booking_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_chat_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_item_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_book_sheet.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_map_card.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_sell_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_service_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// One booking (or quote), for the client or the provider, with what each can do now.
class MarketBookingScreen extends StatefulWidget {
  final String bookingId;
  final bool justSent;
  const MarketBookingScreen({super.key, required this.bookingId, this.justSent = false});

  @override
  State<MarketBookingScreen> createState() => _MarketBookingScreenState();
}

class _MarketBookingScreenState extends State<MarketBookingScreen> with WidgetsBindingObserver {
  final TextEditingController _code = TextEditingController();
  final TextEditingController _finalPrice = TextEditingController();
  Timer? _poll;

  MarketBookingController get _c => Get.find<MarketBookingController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _c.load(widget.bookingId));
    // While it waits on someone, keep it fresh (pushes do the rest).
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      final b = _c.booking(widget.bookingId);
      if (b != null && b.isOpen && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) _c.load(widget.bookingId, quiet: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _c.load(widget.bookingId, quiet: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _code.dispose();
    _finalPrice.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- actions

  Future<String?> _askReason(String title, String hint, {bool required = false}) async {
    final ctrl = TextEditingController();
    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, maxLength: 300, minLines: 1, maxLines: 3,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('market_keep_it'.tr)),
        TextButton(onPressed: () => Get.back(result: true), child: Text('market_confirm'.tr)),
      ],
    ));
    if (ok != true) return null;
    if (required && ctrl.text.trim().isEmpty) {
      showCustomSnackBar('market_reason_needed'.tr);
      return null;
    }
    return ctrl.text.trim();
  }

  Future<void> _cancel(MarketBooking b) async {
    final late = !b.isProvider && b.status == MarketBooking.confirmed && !b.freeToChange;
    final reason = await _askReason('market_cancel_booking'.tr, (late ? 'market_cancel_late_hint' : 'market_cancel_reason_optional').tr);
    if (reason == null) return;
    await _c.act(b.id, 'cancel', body: {if (reason.isNotEmpty) 'reason': reason}, done: 'market_booking_cancelled_done');
  }

  Future<void> _decline(MarketBooking b) async {
    final reason = await _askReason('market_decline_booking'.tr, 'market_decline_booking_hint'.tr);
    if (reason == null) return;
    await _c.act(b.id, 'decline', body: {if (reason.isNotEmpty) 'reason': reason});
  }

  Future<void> _moveOrSuggest(MarketBooking b, MarketBookMode mode) async {
    if (b.itemCode == null) return;
    await showMarketBookSheet(itemCode: b.itemCode!, title: b.itemTitle, mode: mode, booking: b);
  }

  Future<void> _sendQuote(MarketBooking b) async {
    await Get.bottomSheet(_QuoteReplySheet(booking: b), isScrollControlled: true, ignoreSafeArea: false,
        backgroundColor: Get.theme.cardColor, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))));
  }

  Future<void> _complete(MarketBooking b) async {
    final code = _code.text.trim();
    if (code.length != 4) return showCustomSnackBar('market_code_4'.tr);
    final price = _finalPrice.text.replaceAll(RegExp(r'[^0-9]'), '');
    final done = await _c.act(b.id, 'complete', body: {'code': code, if (price.isNotEmpty) 'final_price': price}, done: 'market_job_done');
    if (done != null) _code.clear();
  }

  Future<void> _noShow(MarketBooking b) async {
    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text('market_no_show_q2'.tr),
      content: Text('market_no_show_body2'.tr),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('cancel'.tr)),
        TextButton(onPressed: () => Get.back(result: true), child: Text('market_mark_no_show'.tr)),
      ],
    ));
    if (ok == true) await _c.act(b.id, 'no-show');
  }

  Future<void> _rate(MarketBooking b) async {
    await Get.bottomSheet(_RateSheet(booking: b), isScrollControlled: true, ignoreSafeArea: false,
        backgroundColor: Get.theme.cardColor, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))));
  }

  // ---------------------------------------------------------------- page

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<MarketBookingController>(builder: (c) {
      final b = c.booking(widget.bookingId);
      if (b == null) {
        return Scaffold(appBar: AppBar(), body: c.loading
            ? const Center(child: CircularProgressIndicator())
            : MarketEmpty(icon: Icons.event_busy_outlined, title: c.error ?? 'market_booking_gone'.tr));
      }
      return Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
          title: Text(b.isQuote && b.startsAt == null || b.status == MarketBooking.quoteRequested || b.status == MarketBooking.quoted ? 'market_quote_title'.tr : 'market_booking_title'.tr),
          actions: [
            if (b.conversationId != null)
              IconButton(tooltip: 'market_chat'.tr, icon: const Icon(Icons.chat_bubble_outline_rounded),
                  onPressed: () => Get.to(() => MarketChatScreen(chatId: b.conversationId!))),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => c.load(b.id, quiet: true),
          child: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
            _Header(booking: b),
            const SizedBox(height: Dimensions.paddingSizeDefault),
            if (!b.isProvider && b.status == MarketBooking.confirmed && b.receiveCode != null) ...[
              _Code(code: b.receiveCode!, shop: b.shopName),
              const SizedBox(height: Dimensions.paddingSizeDefault),
            ],
            if (b.isProvider && b.status == MarketBooking.confirmed) ...[
              _Box(children: [
                Text('market_finish_job'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
                const SizedBox(height: 4),
                Text('market_finish_job_hint'.trParams({'name': b.clientName ?? ''}),
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
                const SizedBox(height: 10),
                TextField(
                  controller: _finalPrice,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                  decoration: InputDecoration(isDense: true, labelText: 'market_final_price'.tr, hintText: b.price != null ? b.price!.round().toString() : '',
                      suffixText: 'FCFA', border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault))),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: textBold.copyWith(fontSize: 24, letterSpacing: 12, color: textColor),
                    decoration: InputDecoration(counterText: '', hintText: '• • • •',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault))),
                  )),
                  const SizedBox(width: 10),
                  SizedBox(height: 56, child: FilledButton(onPressed: c.acting ? null : () => _complete(b), child: Text('market_done'.tr))),
                ]),
                if (b.canNoShow) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(onPressed: () => _noShow(b), icon: const Icon(Icons.person_off_outlined, size: 18), label: Text('market_mark_no_show'.tr)),
                ],
              ]),
              const SizedBox(height: Dimensions.paddingSizeDefault),
            ],
            _Details(booking: b),
            const SizedBox(height: Dimensions.paddingSizeDefault),
            _Where(booking: b),
            if (!b.isProvider && b.status == MarketBooking.confirmed) ...[
              const SizedBox(height: Dimensions.paddingSizeDefault),
              MarketScamNotice(text: 'market_pay_provider_after'.tr),
            ],
            if (b.reviewStars != null) ...[
              const SizedBox(height: Dimensions.paddingSizeDefault),
              _Box(children: [
                Row(children: [
                  for (int i = 0; i < 5; i++) Icon(Icons.star_rounded, size: 20, color: i < b.reviewStars! ? const Color(0xFFF5A524) : theme.hintColor.withValues(alpha: 0.3)),
                  const SizedBox(width: 8),
                  Text((b.isProvider ? 'market_client_rated' : 'market_you_rated').tr, style: textSemiBold.copyWith(color: textColor)),
                ]),
                if (b.reviewTags.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(b.reviewTags.map((t) => 'market_st_$t'.tr).join(' · '),
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
                if (b.reviewComment != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('"${b.reviewComment}"', style: textRegular.copyWith(color: textColor))),
              ]),
            ],
            const SizedBox(height: 100),
          ]),
        ),
        bottomNavigationBar: _actions(context, b, c),
      );
    });
  }

  Widget? _actions(BuildContext context, MarketBooking b, MarketBookingController c) {
    final theme = Theme.of(context);
    Widget bar(List<Widget> children, {Widget? top}) => SafeArea(child: Container(
          padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 10, Dimensions.paddingSizeDefault, 10),
          decoration: BoxDecoration(color: theme.cardColor, border: Border(top: BorderSide(color: theme.hintColor.withValues(alpha: 0.12)))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [if (top != null) top, Row(children: children)]),
        ));
    Widget primary(String label, VoidCallback? onTap, {IconData? icon}) => Expanded(child: SizedBox(height: 50, child: FilledButton.icon(
          onPressed: c.acting ? null : onTap,
          icon: c.acting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icon ?? Icons.check_rounded),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        )));
    Widget secondary(String label, VoidCallback? onTap) => Expanded(child: SizedBox(height: 50, child: OutlinedButton(
        onPressed: c.acting ? null : onTap, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis))));
    Widget gap() => const SizedBox(width: 10);
    Widget hint(String text) => Padding(padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, textAlign: TextAlign.center, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)));

    if (b.isProvider) {
      switch (b.status) {
        case MarketBooking.requested:
          return bar([
            secondary('market_decline'.tr, () => _decline(b)), gap(),
            secondary('market_other_time'.tr, () => _moveOrSuggest(b, MarketBookMode.suggest)), gap(),
            primary('market_accept'.tr, () => c.act(b.id, 'accept', done: 'market_booking_accepted')),
          ]);
        case MarketBooking.quoteRequested:
          return bar([
            secondary('market_decline'.tr, () => _decline(b)), gap(),
            primary('market_send_price'.tr, () => _sendQuote(b), icon: Icons.request_quote_outlined),
          ]);
        case MarketBooking.confirmed:
          return bar([secondary('market_cancel_booking'.tr, () => _cancel(b))]);
        default:
          return null;
      }
    }
    switch (b.status) {
      case MarketBooking.requested:
        return bar([
          secondary('market_change_time'.tr, () => _moveOrSuggest(b, MarketBookMode.reschedule)), gap(),
          secondary('market_cancel'.tr, () => _cancel(b)),
        ]);
      case MarketBooking.suggested:
        return bar([
          secondary('market_no_thanks'.tr, () => c.act(b.id, 'refuse')), gap(),
          secondary('market_other_time'.tr, () => _moveOrSuggest(b, MarketBookMode.reschedule)), gap(),
          primary('market_accept'.tr, () => c.act(b.id, 'agree', done: 'market_booking_confirmed_done')),
        ]);
      case MarketBooking.quoteRequested:
        return bar([secondary('market_cancel_request'.tr, () => _cancel(b))]);
      case MarketBooking.quoted:
        return bar([
          secondary('market_no_thanks'.tr, () => c.act(b.id, 'refuse')), gap(),
          primary('market_accept_price'.trParams({'price': PriceConverter.convertPrice(b.quotePrice ?? 0)}),
              () => c.act(b.id, 'agree', done: 'market_booking_confirmed_done')),
        ]);
      case MarketBooking.confirmed:
        final free = b.freeToChange;
        return bar([
          if (!b.isQuote) ...[secondary('market_change_time'.tr, free ? () => _moveOrSuggest(b, MarketBookMode.reschedule) : null), gap()],
          secondary('market_cancel'.tr, () => _cancel(b)),
        ], top: hint(free && b.cancelFreeUntil != null
            ? 'market_free_cancel_until'.trParams({'time': marketWhen(b.cancelFreeUntil)})
            : 'market_late_cancel_note'.tr));
      case MarketBooking.completed:
        if (b.canReview) return bar([primary('market_rate_it'.tr, () => _rate(b), icon: Icons.star_outline_rounded)]);
        return b.itemCode == null ? null : bar([primary('market_book_again'.tr, () => Get.to(() => MarketItemScreen(code: b.itemCode!)), icon: Icons.event_repeat_outlined)]);
      case MarketBooking.declined:
      case MarketBooking.expired:
        return b.itemCode == null ? null : bar([primary('market_choose_other_time'.tr, () => Get.off(() => MarketItemScreen(code: b.itemCode!)), icon: Icons.event_outlined)]);
      default:
        return null;
    }
  }
}

// ---------------------------------------------------------------- parts

class _Box extends StatelessWidget {
  final List<Widget> children;
  const _Box({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: 0.12))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

/// What is happening now, in one sentence, with the timer when someone has to answer.
class _Header extends StatelessWidget {
  final MarketBooking booking;
  const _Header({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final theme = Theme.of(context);
    final (_, fg, bg) = marketBookingStatus(b);
    final who = b.isProvider ? (b.clientName ?? '') : b.shopName;
    final (IconData icon, String title, String? body) = switch (b.status) {
      MarketBooking.requested => b.isProvider
          ? (Icons.notifications_active_outlined, 'market_h_req_p'.trParams({'name': who, 'when': marketWhen(b.startsAt)}), 'market_h_req_p_body'.tr)
          : (Icons.hourglass_top_rounded, 'market_h_req_c'.trParams({'name': who}), 'market_h_req_c_body'.tr),
      MarketBooking.suggested => b.isProvider
          ? (Icons.schedule_rounded, 'market_h_sug_p'.trParams({'when': marketWhen(b.suggestedStartsAt)}), 'market_h_sug_p_body'.trParams({'name': who}))
          : (Icons.schedule_rounded, 'market_h_sug_c'.trParams({'name': who, 'when': marketWhen(b.suggestedStartsAt)}), 'market_h_sug_c_body'.tr),
      MarketBooking.quoteRequested => b.isProvider
          ? (Icons.request_quote_outlined, 'market_h_qreq_p'.trParams({'name': who}), 'market_h_qreq_p_body'.tr)
          : (Icons.hourglass_top_rounded, 'market_h_qreq_c'.trParams({'name': who}), 'market_h_qreq_c_body'.tr),
      MarketBooking.quoted => b.isProvider
          ? (Icons.request_quote_outlined, 'market_h_quoted_p'.trParams({'price': PriceConverter.convertPrice(b.quotePrice ?? 0)}), 'market_h_quoted_p_body'.trParams({'name': who}))
          : (Icons.request_quote_outlined, 'market_h_quoted_c'.trParams({'name': who, 'price': PriceConverter.convertPrice(b.quotePrice ?? 0)}),
              b.quoteNote ?? 'market_h_quoted_c_body'.tr),
      MarketBooking.confirmed => (Icons.event_available_rounded, 'market_h_conf'.trParams({'when': marketWhen(b.startsAt)}),
          (b.isProvider ? 'market_h_conf_p_body' : 'market_h_conf_c_body').trParams({'name': who})),
      MarketBooking.completed => (Icons.check_circle_outline_rounded, 'market_h_done'.tr,
          b.finalPrice != null ? 'market_h_done_body'.trParams({'price': PriceConverter.convertPrice(b.finalPrice!)}) : null),
      MarketBooking.declined => (Icons.event_busy_outlined, 'market_h_declined'.trParams({'name': b.isProvider ? 'market_you'.tr : who}), b.declineReason),
      MarketBooking.expired => (Icons.timer_off_outlined, 'market_h_expired'.tr, (b.isProvider ? 'market_h_expired_p_body' : 'market_h_expired_c_body').tr),
      MarketBooking.noShow => (Icons.person_off_outlined, 'market_h_noshow'.tr, (b.isProvider ? 'market_h_noshow_p_body' : 'market_h_noshow_c_body').tr),
      _ => (Icons.event_busy_outlined, 'market_h_cancelled'.trParams({'name': b.cancelledBy == (b.isProvider ? 'provider' : 'client') ? 'market_you'.tr : who}),
          b.cancelReason),
    };
    final timer = switch (b.status) {
      MarketBooking.requested || MarketBooking.quoteRequested || MarketBooking.suggested => b.respondBy,
      MarketBooking.quoted => b.quoteExpiresAt,
      _ => null,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: fg, size: 26),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: fg, height: 1.25)),
          if (body != null && body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(body, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: fg, height: 1.4)),
          ],
          if (timer != null && timer.isAfter(DateTime.now())) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: theme.cardColor.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.timer_outlined, size: 14, color: fg),
                const SizedBox(width: 4),
                Text('${(b.status == MarketBooking.quoted ? 'market_open_for' : 'market_time_to_answer').tr} ', style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: fg)),
                MarketTimeLeft(until: timer, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: fg)),
              ]),
            ),
          ],
        ])),
      ]),
    );
  }
}

class _Code extends StatelessWidget {
  final String code;
  final String shop;
  const _Code({required this.code, required this.shop});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF1D2D2B), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text('market_your_code_service'.trParams({'name': shop}), textAlign: TextAlign.center,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white70)),
          const SizedBox(height: 6),
          Text(code.split('').join(' '), style: textBold.copyWith(fontSize: 30, letterSpacing: 6, color: Colors.white)),
        ]),
      );
}

class _Details extends StatelessWidget {
  final MarketBooking booking;
  const _Details({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    Widget line(IconData icon, String text, {bool strong = false}) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: theme.primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: (strong ? textSemiBold : textRegular).copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor, height: 1.35))),
          ]),
        );
    final start = b.status == MarketBooking.suggested && !b.isProvider ? b.startsAt : b.startsAt;
    return _Box(children: [
      InkWell(
        onTap: b.itemCode == null ? null : () => Get.to(() => MarketItemScreen(code: b.itemCode!)),
        child: Row(children: [
          b.cover != null
              ? ImageWidget(image: b.cover!, width: 52, height: 52, radius: 10, fit: BoxFit.cover)
              : Container(width: 52, height: 52, decoration: BoxDecoration(color: marketServiceBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.event_available_outlined, color: marketServiceFg)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.itemTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
            Text(b.isProvider ? 'market_client_x'.trParams({'name': b.clientName ?? ''}) : b.shopName,
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ])),
          MarketBookingStatusChip(booking: b),
        ]),
      ),
      if (start != null) line(Icons.event_outlined, marketWhenRange(b.startsAt, b.endsAt), strong: true),
      if (b.startsAt == null && b.whenText != null) line(Icons.event_outlined, 'market_when_suits_x'.trParams({'when': b.whenText!})),
      if (b.status == MarketBooking.suggested && b.suggestedStartsAt != null)
        line(Icons.schedule_rounded, 'market_suggested_x'.trParams({'when': marketWhen(b.suggestedStartsAt)}), strong: true),
      if (b.price != null || b.priceType == 'quote')
        line(Icons.payments_outlined, b.price != null
            ? '${marketServicePrice(b.price, b.status == MarketBooking.quoted || b.isQuote ? 'fixed' : (b.priceType ?? 'fixed'))} · ${'market_paid_after'.tr}'
            : 'market_price_to_come'.tr),
      for (final e in b.extras) line(Icons.add_circle_outline_rounded, e.price > 0 ? '${e.name} +${PriceConverter.convertPrice(e.price)}' : e.name),
      if (b.note != null) line(Icons.notes_rounded, '"${b.note}"'),
      if (b.photos.isNotEmpty) ...[
        const SizedBox(height: 8),
        SizedBox(height: 64, child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: b.photos.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => Get.to(() => MarketPhotoViewer(photos: b.photos, initial: i)),
            child: ImageWidget(image: b.photos[i], width: 64, height: 64, radius: 10, fit: BoxFit.cover),
          ),
        )),
      ],
      if (b.isProvider && (b.clientKept > 0 || b.clientMissed > 0))
        line(Icons.verified_user_outlined, (b.clientKept == 1 ? 'market_client_record_one' : 'market_client_record').trParams({'kept': '${b.clientKept}', 'missed': '${b.clientMissed}'})),
      if (b.isProvider && b.clientKept == 0 && b.clientMissed == 0) line(Icons.fiber_new_outlined, 'market_client_new'.tr),
    ]);
  }
}

/// Where it happens: the provider's place (Directions, Ride there), the client's place, or online.
class _Where extends StatelessWidget {
  final MarketBooking booking;
  const _Where({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final p = b.place;
    final title = switch (b.location) {
      'client' => b.isProvider ? 'market_at_client'.trParams({'name': b.clientName ?? ''}) : 'market_at_your_place'.tr,
      'online' => 'market_online'.tr,
      _ => b.isProvider ? 'market_at_your_shop'.tr : 'market_at_x'.trParams({'name': b.shopName}),
    };
    final String? hidden = b.areaOnly
        ? (b.location == 'client' ? 'market_place_after_confirm_p'.tr : 'market_place_after_confirm_c'.tr)
        : null;
    final canGo = p != null && p.hasPoint && !b.areaOnly && b.isOpen;
    // Who travels: the client to the provider's place, the provider to the client's place.
    final iTravel = (b.location == 'place' && !b.isProvider) || (b.location == 'client' && b.isProvider);
    return _Box(children: [
      Row(children: [
        Icon(marketWhereIcon(b.location), color: theme.primaryColor),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor))),
      ]),
      if (p?.address != null) Padding(padding: const EdgeInsets.only(left: 32, top: 4),
          child: Text(p!.address!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor))),
      if (p?.note != null) Padding(padding: const EdgeInsets.only(left: 32, top: 2),
          child: Text(p!.note!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
      if (hidden != null) Padding(padding: const EdgeInsets.only(left: 32, top: 4),
          child: Text(hidden, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
      if (b.location == 'online') Padding(padding: const EdgeInsets.only(left: 32, top: 4),
          child: Text('market_online_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
      if (canGo && iTravel) ...[
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => marketDirections(p.lat!, p.lng!),
              icon: const Icon(Icons.directions_rounded, size: 18), label: Text('directions'.tr))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton.icon(onPressed: () => marketRideThere(p.lat!, p.lng!, p.address ?? title),
              icon: const Icon(Icons.local_taxi_outlined, size: 18), label: Text('market_ride_there'.tr))),
        ]),
      ],
    ]);
  }
}

/// The provider's price and time for a quote request.
class _QuoteReplySheet extends StatefulWidget {
  final MarketBooking booking;
  const _QuoteReplySheet({required this.booking});

  @override
  State<_QuoteReplySheet> createState() => _QuoteReplySheetState();
}

class _QuoteReplySheetState extends State<_QuoteReplySheet> {
  final TextEditingController _price = TextEditingController();
  final TextEditingController _note = TextEditingController();
  DateTime? _at;
  late int _duration;

  @override
  void initState() {
    super.initState();
    _duration = widget.booking.durationMinutes;
  }

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final day = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 60)), initialDate: now.add(const Duration(days: 1)));
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0),
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!));
    if (time == null) return;
    setState(() => _at = DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  Future<void> _send() async {
    final price = _price.text.replaceAll(RegExp(r'[^0-9]'), '');
    if ((int.tryParse(price) ?? 0) <= 0) return showCustomSnackBar('market_give_price'.tr);
    if (_at == null) return showCustomSnackBar('market_pick_time'.tr);
    final done = await Get.find<MarketBookingController>().act(widget.booking.id, 'send-quote', body: {
      'price': price, 'starts_at': marketApiTime(_at!), 'duration_minutes': _duration, if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
    }, done: 'market_price_sent');
    if (done != null && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => MarketChips(child: Builder(builder: _chipsBuild));

  Widget _chipsBuild(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final durations = Get.find<MarketController>().meta?.serviceRules.durations ?? const MarketServiceRules().durations;
    return Padding(
      padding: EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 12, Dimensions.paddingSizeLarge, 16),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        Text('market_send_price_to'.trParams({'name': widget.booking.clientName ?? ''}), style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor)),
        const SizedBox(height: 12),
        TextField(controller: _price, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
            decoration: InputDecoration(labelText: 'market_your_price'.tr, suffixText: 'FCFA', isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)))),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickTime,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Dimensions.radiusDefault), border: Border.all(color: theme.hintColor.withValues(alpha: 0.4))),
            child: Row(children: [
              Icon(Icons.event_outlined, color: theme.primaryColor),
              const SizedBox(width: 8),
              Expanded(child: Text(_at == null ? 'market_pick_day_time'.tr : marketWhen(_at), style: textRegular.copyWith(color: _at == null ? theme.hintColor : textColor))),
              Text('market_choose'.tr, style: textSemiBold.copyWith(color: theme.primaryColor)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Text('market_takes_about'.tr, style: textSemiBold.copyWith(color: textColor)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in durations) ChoiceChip(label: Text(marketDuration(d)), selected: _duration == d, showCheckmark: false, onSelected: (_) => setState(() => _duration = d)),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _note, maxLength: 400, minLines: 1, maxLines: 3, textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: 'market_quote_message_hint'.tr, isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)))),
        Text('market_quote_rule'.trParams({'hours': '${Get.find<MarketController>().meta?.serviceRules.quoteHours ?? 24}'}),
            style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor, height: 1.4)),
        const SizedBox(height: 12),
        GetBuilder<MarketBookingController>(builder: (c) => SizedBox(width: double.infinity, height: 52, child: FilledButton(
          onPressed: c.acting ? null : _send,
          child: c.acting ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('market_send_price'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
        ))),
      ])),
    );
  }
}

class _RateSheet extends StatefulWidget {
  final MarketBooking booking;
  const _RateSheet({required this.booking});

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  int _stars = 5;
  final Set<String> _tags = {};
  final TextEditingController _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final done = await Get.find<MarketBookingController>().act(widget.booking.id, 'review', body: {
      'stars': _stars, 'tags': _tags.join(','), if (_comment.text.trim().isNotEmpty) 'comment': _comment.text.trim(),
    }, done: 'market_review_thanks');
    if (done != null && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => MarketChips(child: Builder(builder: _chipsBuild));

  Widget _chipsBuild(BuildContext context) {
    final theme = Theme.of(context);
    final tags = Get.find<MarketController>().meta?.serviceRules.reviewTags ?? const MarketServiceRules().reviewTags;
    return Padding(
      padding: EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 12, Dimensions.paddingSizeLarge, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        Text('market_how_was_it'.trParams({'name': widget.booking.shopName}), textAlign: TextAlign.center,
            style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (int i = 1; i <= 5; i++)
            IconButton(onPressed: () => setState(() => _stars = i), iconSize: 38,
                icon: Icon(Icons.star_rounded, color: i <= _stars ? const Color(0xFFF5A524) : theme.hintColor.withValues(alpha: 0.3))),
        ]),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          for (final t in tags.where((t) => _stars >= 4 ? t != 'problem' : true))
            FilterChip(label: Text('market_st_$t'.tr), selected: _tags.contains(t), onSelected: (on) => setState(() => on ? _tags.add(t) : _tags.remove(t))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _comment, maxLength: 500, minLines: 1, maxLines: 3, textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: 'market_tell_others'.tr, isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)))),
        const SizedBox(height: 8),
        GetBuilder<MarketBookingController>(builder: (c) => SizedBox(width: double.infinity, height: 52, child: FilledButton(
          onPressed: c.acting ? null : _send,
          child: Text('market_send_rating'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
        ))),
      ]),
    );
  }
}
