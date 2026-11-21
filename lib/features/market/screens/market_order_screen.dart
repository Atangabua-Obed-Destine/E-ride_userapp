import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_order_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/helpers/market_delivery.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_chat_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_home_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_item_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_sell_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_order_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/features/trip/screens/trip_details_screen.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:url_launcher/url_launcher.dart';

/// One order, for the buyer or the seller. Like the partner portal, the seller accepts or
/// declines (here line by line); unlike it, E-Ride never takes the money: the buyer pays the
/// seller and closes the order with a 4-digit code.
class MarketOrderScreen extends StatefulWidget {
  final String orderId;
  final bool justSent;
  const MarketOrderScreen({super.key, required this.orderId, this.justSent = false});

  @override
  State<MarketOrderScreen> createState() => _MarketOrderScreenState();
}

class _MarketOrderScreenState extends State<MarketOrderScreen> with WidgetsBindingObserver {
  final Map<int, int> _qty = {};
  final Map<int, TextEditingController> _notes = {};
  final TextEditingController _code = TextEditingController();
  Timer? _poll;
  String? _answerFor;

  MarketOrderController get _orders => Get.find<MarketOrderController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _orders.load(widget.orderId));
    // While an order waits on someone, keep it fresh (pushes do the rest).
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      final o = _orders.order(widget.orderId);
      if (o != null && o.isOpen && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _orders.load(widget.orderId, quiet: true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _orders.load(widget.orderId, quiet: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _code.dispose();
    for (final c in _notes.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// The seller's answer starts from what is in stock.
  void _prepareAnswer(MarketOrder o) {
    if (_answerFor == o.id) return;
    _answerFor = o.id;
    for (final l in o.lines) {
      _qty[l.id] = (l.inStock == null ? l.qty : (l.inStock! < l.qty ? l.inStock! : l.qty)).clamp(0, l.qty);
      _notes[l.id] ??= TextEditingController();
    }
  }

  int get _confirmedLines => _qty.values.where((q) => q > 0).length;

  double _answerTotal(MarketOrder o) => o.lines.fold(0.0, (t, l) => t + l.unitPrice * (_qty[l.id] ?? 0));

  Future<void> _respond(MarketOrder o) async {
    if (_confirmedLines == 0) {
      _decline(o);
      return;
    }
    await _orders.respond(o.id, Map.of(_qty), {for (final e in _notes.entries) e.key: e.value.text});
  }

  Future<void> _decline(MarketOrder o) async {
    final reasons = Get.find<MarketController>().meta?.declineReasons ?? const ['sold_out', 'no_delivery_area', 'price_changed', 'closed_today', 'other'];
    await Get.bottomSheet(_DeclineSheet(order: o, reasons: reasons), isScrollControlled: true);
  }

  Future<void> _cancel(MarketOrder o) async {
    final reason = TextEditingController();
    final needsReason = o.isHeld;
    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text('market_cancel_order'.tr),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((needsReason ? (o.isSeller ? 'market_cancel_held_seller' : 'market_cancel_held_buyer') : 'market_cancel_free').tr),
        const SizedBox(height: 10),
        TextField(controller: reason, maxLength: 300, decoration: InputDecoration(
            hintText: (needsReason ? 'market_cancel_reason' : 'market_cancel_reason_optional').tr, border: const OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('market_keep_order'.tr)),
        TextButton(onPressed: () => Get.back(result: true), child: Text('market_cancel_order'.tr)),
      ],
    ));
    if (ok != true) return;
    if (needsReason && reason.text.trim().isEmpty) {
      showCustomSnackBar('market_cancel_reason'.tr);
      return;
    }
    await _orders.cancel(o.id, reason.text.trim());
  }

  Future<void> _complete(MarketOrder o) async {
    final code = _code.text.trim();
    if (code.length != 4) {
      showCustomSnackBar('market_code_4'.tr);
      return;
    }
    final done = await _orders.complete(o.id, code);
    if (done != null) _code.clear();
  }

  Future<void> _sendWithEride(MarketOrder o) async {
    final drop = o.drop;
    if (drop == null) return;
    await startMarketDelivery(
      chatId: o.conversationId,
      orderId: o.id,
      lat: drop.lat,
      lng: drop.lng,
      address: drop.address,
      receiverName: o.receiver?.name.isNotEmpty == true ? o.receiver!.name : (o.buyerName ?? ''),
      receiverPhone: o.receiver?.phone,
    );
  }

  /// The winner did not arrange payment in time: a strike for them, and the item can go to the next bidder.
  Future<void> _noShow(MarketOrder o) async {
    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text('market_no_show_q'.tr),
      content: Text('market_no_show_body'.tr),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('cancel'.tr)),
        TextButton(onPressed: () => Get.back(result: true), child: Text('market_no_show'.tr)),
      ],
    ));
    if (ok != true) return;
    final code = await _orders.noShow(o.id);
    if (code != null) Get.off(() => MarketItemScreen(code: code));
  }

  void _openMaps(MarketPoint p) {
    launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${p.lat},${p.lng}'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<MarketOrderController>(builder: (c) {
      final o = c.order(widget.orderId);
      if (o == null) {
        return Scaffold(
          appBar: AppBar(),
          body: c.loading ? const Center(child: CircularProgressIndicator()) : MarketEmpty(icon: Icons.receipt_long_outlined, title: c.error ?? 'market_order_gone'.tr),
        );
      }
      final sellerAnswering = o.isSeller && o.status == MarketOrder.requested;
      if (sellerAnswering) _prepareAnswer(o);
      return Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
          title: Text('market_order_title'.trParams({'code': o.code})),
          actions: [
            if (o.conversationId != null)
              IconButton(tooltip: 'market_chat'.tr, icon: const Icon(Icons.chat_bubble_outline_rounded),
                  onPressed: () => Get.to(() => MarketChatScreen(chatId: o.conversationId!))),
            if ((!o.isSeller && o.isOpen) || (o.isSeller && o.isHeld))
              PopupMenuButton<String>(
                color: theme.cardColor,
                onSelected: (v) {
                  if (v == 'cancel') _cancel(o);
                },
                itemBuilder: (_) => [PopupMenuItem(value: 'cancel', child: Text('market_cancel_order'.tr))],
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => c.load(o.id, quiet: true),
          child: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
            _StatusCard(order: o),
            const SizedBox(height: Dimensions.paddingSizeDefault),
            if (o.fromAuction && o.isOpen) ...[
              _AuctionPayment(order: o, acting: c.acting, onArranged: () => c.paymentArranged(o.id), onNoShow: () => _noShow(o)),
              const SizedBox(height: Dimensions.paddingSizeDefault),
            ],
            if (o.isOpen || o.status == MarketOrder.completed) ...[
              _Timeline(order: o),
              const SizedBox(height: Dimensions.paddingSizeDefault),
            ],
            _Box(children: [
              Row(children: [
                Expanded(child: Text(o.isSeller ? (o.buyerName ?? '') : (o.shop?.name ?? ''),
                    style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor))),
                if (sellerAnswering) Text('market_answer_each'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              ]),
              const SizedBox(height: 4),
              for (final l in o.lines)
                sellerAnswering
                    ? _AnswerLine(
                        line: l,
                        qty: _qty[l.id] ?? 0,
                        note: _notes[l.id]!,
                        onQty: (q) => setState(() => _qty[l.id] = q),
                      )
                    : _ShowLine(line: l, answered: o.status != MarketOrder.requested),
              const Divider(height: 18),
              if (sellerAnswering) ...[
                MarketMoneyRow(label: 'market_buyer_asked'.tr, amount: o.requestedTotal),
                MarketMoneyRow(label: 'market_you_confirm'.tr, amount: _answerTotal(o), strong: true),
              ] else
                MarketMoneyRow(label: o.confirmedTotal != null ? 'market_total'.tr : 'market_total_asked'.tr, amount: o.total, strong: true,
                    before: o.confirmedTotal != null ? o.requestedTotal : null),
            ]),
            const SizedBox(height: Dimensions.paddingSizeDefault),
            _Box(children: [
              Row(children: [
                Icon(marketFulfilmentIcon(o.fulfilment), color: theme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('market_fulfilment_${o.fulfilment}'.tr, style: textSemiBold.copyWith(color: textColor))),
              ]),
              if (o.drop?.address != null) Padding(
                padding: const EdgeInsets.only(left: 28, top: 2),
                child: Text(o.drop!.address!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              ),
              if (o.pickup != null) Padding(
                padding: const EdgeInsets.only(left: 28, top: 4),
                child: Row(children: [
                  Expanded(child: Text(o.pickup!.address ?? '', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor))),
                  TextButton.icon(onPressed: () => _openMaps(o.pickup!), icon: const Icon(Icons.directions_outlined, size: 18), label: Text('market_directions'.tr)),
                ]),
              ),
              if (o.trip != null) Padding(
                padding: const EdgeInsets.only(left: 28, top: 4),
                child: InkWell(
                  onTap: o.isSeller ? () => Get.to(() => TripDetailsScreen(tripId: o.trip!.tripId)) : null,
                  child: Text('${o.trip!.refId != null ? '#${o.trip!.refId} · ' : ''}${'market_delivery_status_${o.trip!.status ?? 'pending'}'.tr}',
                      style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.payments_outlined, color: theme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('market_pay_${o.payMethod}'.tr, style: textSemiBold.copyWith(color: textColor))),
              ]),
              if (o.note != null) ...[
                const SizedBox(height: 8),
                Text('market_buyer_note'.trParams({'note': o.note!}),
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: marketWarnFg)),
              ],
            ]),
            if (!o.isSeller && o.isHeld && o.receiveCode != null) ...[
              const SizedBox(height: Dimensions.paddingSizeDefault),
              _ReceiveCode(code: o.receiveCode!),
            ],
            if (o.isSeller && o.isHeld) ...[
              const SizedBox(height: Dimensions.paddingSizeDefault),
              _Box(children: [
                Text('market_close_order'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
                const SizedBox(height: 4),
                Text('market_close_order_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
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
                  SizedBox(height: 56, child: FilledButton(onPressed: c.acting ? null : () => _complete(o), child: Text('market_close'.tr))),
                ]),
              ]),
            ],
            if (!o.isSeller && o.isHeld) ...[
              const SizedBox(height: Dimensions.paddingSizeDefault),
              MarketScamNotice(text: 'market_pay_safely'.tr),
            ],
            if (o.reviewStars != null) ...[
              const SizedBox(height: Dimensions.paddingSizeDefault),
              _Box(children: [
                Row(children: [
                  for (int i = 0; i < 5; i++) Icon(Icons.star_rounded, size: 20, color: i < o.reviewStars! ? const Color(0xFFF5A524) : theme.hintColor.withValues(alpha: 0.3)),
                  const SizedBox(width: 8),
                  Text((o.isSeller ? 'market_buyer_rated' : 'market_you_rated').tr, style: textSemiBold.copyWith(color: textColor)),
                ]),
                if (o.reviewTags.isNotEmpty) Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(o.reviewTags.map((t) => 'market_tag_$t'.tr).join(' · '), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                ),
                if (o.reviewComment != null) Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('"${o.reviewComment}"', style: textRegular.copyWith(color: textColor)),
                ),
              ]),
            ],
            const SizedBox(height: 100),
          ]),
        ),
        bottomNavigationBar: _actions(context, o, c),
      );
    });
  }

  Widget? _actions(BuildContext context, MarketOrder o, MarketOrderController c) {
    final theme = Theme.of(context);
    Widget bar(List<Widget> children) => SafeArea(child: Container(
          padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 10, Dimensions.paddingSizeDefault, 10),
          decoration: BoxDecoration(color: theme.cardColor, border: Border(top: BorderSide(color: theme.hintColor.withValues(alpha: 0.12)))),
          child: Row(children: children),
        ));
    Widget primary(String label, VoidCallback? onTap, {IconData? icon}) => Expanded(child: SizedBox(height: 52, child: FilledButton.icon(
          onPressed: c.acting ? null : onTap,
          icon: c.acting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icon ?? Icons.check_rounded),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        )));
    Widget secondary(String label, VoidCallback? onTap) => SizedBox(height: 52, child: OutlinedButton(onPressed: c.acting ? null : onTap, child: Text(label)));

    if (o.isSeller) {
      if (o.status == MarketOrder.requested) {
        return bar([
          secondary('market_decline'.tr, () => _decline(o)),
          const SizedBox(width: 10),
          primary(_confirmedLines == 0 ? 'market_decline'.tr : 'market_confirm_items'.trParams({'count': '$_confirmedLines'}), () => _respond(o)),
        ]);
      }
      if (o.status == MarketOrder.confirmed && o.fulfilment == 'eride' && o.drop != null) {
        return bar([primary('market_send_with_eride'.tr, () => _sendWithEride(o), icon: Icons.delivery_dining_rounded)]);
      }
      if (o.status == MarketOrder.confirmed) {
        return bar([primary((o.fulfilment == 'pickup' ? 'market_mark_ready_pickup' : 'market_mark_ready_delivery').tr, () => c.ready(o.id), icon: Icons.inventory_2_outlined)]);
      }
      return null;
    }
    if (o.status == MarketOrder.changes) {
      return bar([
        secondary('market_cancel'.tr, () => _cancel(o)),
        const SizedBox(width: 10),
        primary('market_agree_total'.trParams({'total': PriceConverter.convertPrice(o.total)}), () => c.agree(o.id)),
      ]);
    }
    if (o.canReview) {
      return bar([primary('market_rate_shop'.tr, () => Get.bottomSheet(_RateSheet(order: o), isScrollControlled: true), icon: Icons.star_outline_rounded)]);
    }
    if (o.status == MarketOrder.declined || o.status == MarketOrder.expired) {
      return bar([primary('market_find_similar'.tr, () => Get.off(() => const MarketHomeScreen()), icon: Icons.search_rounded)]);
    }
    return null;
  }
}

/// An auction order: the winner arranges payment with the seller before a deadline.
class _AuctionPayment extends StatelessWidget {
  final MarketOrder order;
  final bool acting;
  final VoidCallback onArranged;
  final VoidCallback onNoShow;
  const _AuctionPayment({required this.order, required this.acting, required this.onArranged, required this.onNoShow});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final due = o.paymentDueAt;
    final overdue = due != null && due.isBefore(DateTime.now());
    final Color fg = o.paymentArranged ? const Color(0xFF166534) : (overdue ? marketDangerFg : marketWarnFg);
    final Color bg = o.paymentArranged ? const Color(0xFFDCFCE7) : (overdue ? marketDangerBg : marketWarnBg);
    final String title;
    final String body;
    if (o.paymentArranged) {
      title = 'market_payment_arranged'.tr;
      body = (o.isSeller ? 'market_payment_arranged_seller' : 'market_payment_arranged_buyer').tr;
    } else if (overdue) {
      title = 'market_payment_overdue'.tr;
      body = (o.isSeller ? 'market_payment_overdue_seller' : 'market_payment_overdue_buyer').tr;
    } else {
      title = 'market_auction_won_order'.tr;
      body = (o.isSeller ? 'market_payment_due_seller' : 'market_payment_due_buyer').trParams({'name': o.buyerName ?? 'market_buyer'.tr});
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(o.paymentArranged ? Icons.check_circle_outline_rounded : Icons.gavel_rounded, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: fg))),
          if (!o.paymentArranged && due != null && !overdue)
            MarketTimeLeft(until: due, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: fg)),
        ]),
        const SizedBox(height: 4),
        Text(body, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: fg, height: 1.4)),
        if (o.isSeller && !o.paymentArranged) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: FilledButton(onPressed: acting ? null : onArranged, child: Text('market_payment_arranged_btn'.tr))),
            if (overdue) ...[
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: acting ? null : onNoShow, child: Text('market_no_show'.tr))),
            ],
          ]),
        ],
      ]),
    );
  }
}

class _Box extends StatelessWidget {
  final List<Widget> children;
  const _Box({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.hintColor.withValues(alpha: 0.12))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

/// What is happening now, in one sentence, with the deadline that matters.
class _StatusCard extends StatelessWidget {
  final MarketOrder order;
  const _StatusCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final role = o.isSeller ? 'seller' : 'buyer';
    final params = {'shop': o.shop?.name ?? '', 'buyer': o.buyerName ?? ''};
    String title = 'market_st_${role}_${o.status}'.trParams(params);
    String body = 'market_st_${role}_${o.status}_body'.trParams(params);
    if (o.status == MarketOrder.declined && o.declineReason != null) {
      body = 'market_decline_${o.declineReason}'.tr + (o.declineNote != null ? ': ${o.declineNote}' : '');
    }
    if (o.status == MarketOrder.cancelled) {
      final by = o.cancelledBy == 'timeout' ? 'market_cancelled_timeout'.tr : (o.cancelledBy == role ? 'market_cancelled_by_you'.tr : 'market_cancelled_by_other'.tr);
      body = o.cancelReason != null ? '$by: ${o.cancelReason}' : by;
    }
    final (IconData icon, Color fg, Color bg) = switch (o.status) {
      MarketOrder.requested => (Icons.schedule_rounded, marketWarnFg, marketWarnBg),
      MarketOrder.changes => (Icons.rule_rounded, marketWarnFg, marketWarnBg),
      MarketOrder.confirmed || MarketOrder.completed => (Icons.check_circle_outline_rounded, marketGreen, marketGreenBg),
      MarketOrder.ready => (Icons.inventory_2_outlined, marketVerified, marketBlueBg),
      MarketOrder.onTheWay => (Icons.delivery_dining_rounded, marketVerified, marketBlueBg),
      _ => (Icons.cancel_outlined, marketDangerFg, marketDangerBg),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: fg, size: 26),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: fg)),
          const SizedBox(height: 2),
          Text(body, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: fg, height: 1.4)),
          if (o.deadline != null) ...[
            const SizedBox(height: 8),
            MarketCountdown(until: o.deadline, prefix: '${'market_time_left'.tr} '),
          ],
        ])),
      ]),
    );
  }
}

class _Timeline extends StatelessWidget {
  final MarketOrder order;
  const _Timeline({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = order;
    final delivery = o.fulfilment == 'pickup' ? 'market_tl_pickup' : (o.fulfilment == 'eride' ? 'market_tl_eride' : 'market_tl_seller');
    final steps = <(String, int)>[
      ('market_tl_sent', 0),
      ('market_tl_answer', 1),
      ('market_tl_confirmed', 2),
      (delivery, 3),
      ('market_tl_received', 4),
    ];
    final int at = switch (o.status) {
      MarketOrder.requested => 1,
      MarketOrder.changes => 2,
      MarketOrder.confirmed => 3,
      MarketOrder.ready || MarketOrder.onTheWay => 4,
      MarketOrder.completed => 5,
      _ => 0,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.hintColor.withValues(alpha: 0.12))),
      child: Column(children: [
        for (final (key, i) in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: i < at ? marketGreenBg : (i == at ? theme.primaryColor.withValues(alpha: 0.12) : theme.hintColor.withValues(alpha: 0.1))),
                alignment: Alignment.center,
                child: i < at
                    ? const Icon(Icons.check_rounded, size: 14, color: marketGreen)
                    : Text('${i + 1}', style: textBold.copyWith(fontSize: 11, color: i == at ? theme.primaryColor : theme.hintColor)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(key.tr, style: (i == at ? textBold : textRegular).copyWith(
                  fontSize: Dimensions.fontSizeDefault, color: i > at ? theme.hintColor : theme.textTheme.bodyLarge?.color))),
            ]),
          ),
      ]),
    );
  }
}

class _ShowLine extends StatelessWidget {
  final MarketOrderLine line;
  final bool answered;
  const _ShowLine({required this.line, required this.answered});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final none = answered && line.qtyConfirmed == 0;
    return Opacity(
      opacity: none ? 0.55 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Photo(url: line.photo),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(line.title, style: textSemiBold.copyWith(color: textColor, decoration: none ? TextDecoration.lineThrough : null)),
            if (line.choice.isNotEmpty) Text(line.choice, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            if (none)
              Text('market_line_none'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: marketDangerFg))
            else if (line.changed)
              Text('market_line_fewer'.trParams({'asked': '${line.qty}', 'count': '${line.qtyConfirmed}'}),
                  style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: marketWarnFg))
            else
              Text('× ${line.finalQty}${line.wholesale ? ' · ${'market_wholesale'.tr}' : ''}',
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            if (line.sellerNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('"${line.sellerNote}"', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor, fontStyle: FontStyle.italic)),
              ),
          ])),
          Text(PriceConverter.convertPrice(line.unitPrice * line.finalQty), style: textSemiBold.copyWith(color: textColor,
              decoration: none ? TextDecoration.lineThrough : null)),
        ]),
      ),
    );
  }
}

/// The seller's answer for one line: available or not, how many, and a note.
class _AnswerLine extends StatelessWidget {
  final MarketOrderLine line;
  final int qty;
  final TextEditingController note;
  final ValueChanged<int> onQty;
  const _AnswerLine({required this.line, required this.qty, required this.note, required this.onQty});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final available = qty > 0;
    final String state = !available ? 'market_line_none'.tr : (qty < line.qty ? 'market_line_only'.trParams({'count': '$qty', 'asked': '${line.qty}'}) : 'market_line_available'.tr);
    final Color stateColor = !available ? marketDangerFg : (qty < line.qty ? marketWarnFg : marketGreen);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Opacity(opacity: available ? 1 : 0.5, child: _Photo(url: line.photo)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(line.title, style: textSemiBold.copyWith(color: textColor)),
            Text([if (line.choice.isNotEmpty) line.choice, 'market_asked_qty'.trParams({'count': '${line.qty}'}), PriceConverter.convertPrice(line.unitPrice)].join(' · '),
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            if (line.inStock != null)
              Text('market_in_stock'.trParams({'count': '${line.inStock}'}),
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: theme.hintColor)),
          ])),
          Switch(
            value: available,
            onChanged: (on) => onQty(on ? line.qty : 0),
          ),
        ]),
        Row(children: [
          const SizedBox(width: 62),
          Expanded(child: Text(state, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: stateColor))),
          if (available) MarketQtyStepper(value: qty, max: line.qty, small: true, onChanged: onQty),
        ]),
        if (qty < line.qty)
          Padding(
            padding: const EdgeInsets.only(left: 62, top: 6),
            child: TextField(
              controller: note,
              maxLength: 200,
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                hintText: 'market_line_note_hint'.tr,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Photo extends StatelessWidget {
  final String? url;
  const _Photo({this.url});

  @override
  Widget build(BuildContext context) => url != null
      ? ImageWidget(image: url!, width: 52, height: 52, radius: 10, fit: BoxFit.cover)
      : Container(width: 52, height: 52, decoration: BoxDecoration(color: Theme.of(context).hintColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)));
}

class _ReceiveCode extends StatelessWidget {
  final String code;
  const _ReceiveCode({required this.code});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.primaryColor, width: 1.5),
      ),
      child: Column(children: [
        Text('market_your_code'.tr.toUpperCase(), style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, letterSpacing: 1)),
        const SizedBox(height: 6),
        Semantics(
          label: 'market_your_code'.tr,
          value: code.split('').join(' '),
          child: Text(code.split('').join(' '), style: textBold.copyWith(fontSize: 36, letterSpacing: 6, color: theme.primaryColor)),
        ),
        const SizedBox(height: 6),
        Text('market_your_code_hint'.tr, textAlign: TextAlign.center,
            style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
      ]),
    );
  }
}

class _DeclineSheet extends StatefulWidget {
  final MarketOrder order;
  final List<String> reasons;
  const _DeclineSheet({required this.order, required this.reasons});

  @override
  State<_DeclineSheet> createState() => _DeclineSheetState();
}

class _DeclineSheetState extends State<_DeclineSheet> {
  late String _reason = widget.reasons.first;
  bool _soldOut = true;
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(top: false, child: SingleChildScrollView(
        padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('market_decline_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor)),
          const SizedBox(height: 4),
          Text('market_decline_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v ?? _reason),
            child: Column(children: [
              for (final r in widget.reasons)
                RadioListTile<String>(value: r, dense: true, contentPadding: EdgeInsets.zero, title: Text('market_decline_$r'.tr)),
            ]),
          ),
          TextField(controller: _note, maxLength: 300, decoration: InputDecoration(hintText: 'market_decline_note'.tr,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)))),
          CheckboxListTile(
            value: _soldOut,
            onChanged: (v) => setState(() => _soldOut = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text('market_mark_lines_sold_out'.tr),
          ),
          Row(children: [
            Expanded(child: SizedBox(height: 50, child: OutlinedButton(onPressed: () => Get.back(), child: Text('market_back'.tr)))),
            const SizedBox(width: 10),
            Expanded(child: GetBuilder<MarketOrderController>(builder: (c) => SizedBox(height: 50, child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: textColor),
              onPressed: c.acting ? null : () async {
                final done = await c.decline(widget.order.id, _reason, _note.text.trim(), _soldOut);
                // Navigator, not Get.back: Get.back would close the "declined" snackbar instead of the sheet.
                if (done != null && context.mounted) Navigator.of(context).pop();
              },
              child: Text('market_decline_order'.tr, style: TextStyle(color: theme.cardColor)),
            )))),
          ]),
        ]),
      )),
    );
  }
}

class _RateSheet extends StatefulWidget {
  final MarketOrder order;
  const _RateSheet({required this.order});

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  int _stars = 0;
  final Set<String> _tags = {};
  final TextEditingController _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final tags = Get.find<MarketController>().meta?.reviewTags ?? const ['as_described', 'fast_reply', 'good_price', 'well_packed', 'problem'];
    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(top: false, child: SingleChildScrollView(
        padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('market_how_was'.trParams({'shop': widget.order.shop?.name ?? ''}),
              style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor)),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int i = 1; i <= 5; i++)
              IconButton(
                tooltip: 'market_stars'.trParams({'count': '$i'}),
                iconSize: 40,
                onPressed: () => setState(() => _stars = i),
                icon: Icon(i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i <= _stars ? const Color(0xFFF5A524) : theme.hintColor),
              ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            for (final t in tags)
              FilterChip(
                label: Text('market_tag_$t'.tr),
                selected: _tags.contains(t),
                onSelected: (on) => setState(() => on ? _tags.add(t) : _tags.remove(t)),
                selectedColor: theme.primaryColor.withValues(alpha: 0.12),
                checkmarkColor: theme.primaryColor,
                labelStyle: textMedium.copyWith(color: _tags.contains(t) ? theme.primaryColor : textColor),
              ),
          ]),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          TextField(controller: _comment, maxLength: 500, minLines: 2, maxLines: 4, decoration: InputDecoration(
              hintText: 'market_review_hint'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)))),
          Text('market_review_rule'.tr, textAlign: TextAlign.center,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          GetBuilder<MarketOrderController>(builder: (c) => SizedBox(width: double.infinity, height: 52, child: FilledButton(
            onPressed: _stars == 0 || c.acting ? null : () async {
              final done = await c.review(widget.order.id, _stars, _tags.toList(), _comment.text.trim());
              if (done != null && context.mounted) Navigator.of(context).pop();
            },
            child: Text('market_send_rating'.tr),
          ))),
        ]),
      )),
    );
  }
}
