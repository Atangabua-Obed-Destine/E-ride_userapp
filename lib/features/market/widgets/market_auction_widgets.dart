import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_order_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_sell_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The auction on an item page: the price now, time left, bids, and what this person can do
/// (bid, answer an offer, open the order they won). The seller sees their own controls.
class MarketAuctionPanel extends StatelessWidget {
  final MarketItem item;
  const MarketAuctionPanel({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final a = item.auction!;
    final theme = Theme.of(context);
    final bids = Get.find<MarketController>().bidsFor(item.code);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Head(auction: a),
      const SizedBox(height: 10),
      if (item.mine) _SellerState(item: item) else _BuyerState(item: item),
      if (bids.isNotEmpty) ...[
        const SizedBox(height: Dimensions.paddingSizeDefault),
        Text('market_bids'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 6),
        for (final b in bids.take(item.mine ? 10 : 5)) _BidRow(bid: b, top: identical(b, bids.first)),
        if (bids.length > (item.mine ? 10 : 5))
          Text('market_more_bids'.trParams({'count': '${bids.length - (item.mine ? 10 : 5)}'}),
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
      ],
    ]);
  }
}

/// Dark card: current bid (or starting price), bids, and the time left.
class _Head extends StatelessWidget {
  final MarketAuction auction;
  const _Head({required this.auction});

  @override
  Widget build(BuildContext context) {
    final a = auction;
    final white70 = textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white70);
    final ended = !a.live;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: marketAuctionBg, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.gavel_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(ended ? 'market_auction_status_${a.status}'.tr : 'market_auction'.tr,
              style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white)),
          const Spacer(),
          if (a.live) ...[
            const Icon(Icons.timer_outlined, size: 15, color: Colors.white70),
            const SizedBox(width: 4),
            MarketTimeLeft(until: a.endsAt, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white)),
          ],
        ]),
        const SizedBox(height: 10),
        Text((a.bidCount == 0 ? 'market_starting_price' : (ended ? 'market_final_bid' : 'market_current_bid')).tr, style: white70),
        Text(marketPrice(a.price), style: textBold.copyWith(fontSize: 26, color: Colors.white)),
        const SizedBox(height: 6),
        Wrap(spacing: 12, runSpacing: 4, children: [
          Text(a.bidCount == 1 ? 'market_one_bid'.tr : 'market_n_bids'.trParams({'count': '${a.bidCount}'}), style: white70),
          if (a.hasReserve)
            Text((a.reserveMet == true ? 'market_reserve_met' : 'market_reserve_not_met').tr,
                style: white70.copyWith(color: a.reserveMet == true ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D))),
          if (a.live && a.endsAt != null) Text('market_ends_at'.trParams({'time': _when(a.endsAt!)}), style: white70),
        ]),
      ]),
    );
  }
}

String _when(DateTime t) {
  final l = t.toLocal();
  final now = DateTime.now();
  final hm = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  if (l.year == now.year && l.month == now.month && l.day == now.day) return '${'market_today'.tr} $hm';
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')} $hm';
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Color fg;
  final Color bg;
  final Widget? action;
  const _Note({required this.icon, required this.title, this.body, required this.fg, required this.bg, this.action});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: fg)),
              if (body != null) ...[
                const SizedBox(height: 2),
                Text(body!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: fg, height: 1.4)),
              ],
            ])),
          ]),
          if (action != null) ...[const SizedBox(height: 10), action!],
        ]),
      );
}

const Color _okFg = Color(0xFF166534);
const Color _okBg = Color(0xFFDCFCE7);

/// What the buyer sees under the auction card.
class _BuyerState extends StatelessWidget {
  final MarketItem item;
  const _BuyerState({required this.item});

  @override
  Widget build(BuildContext context) {
    final a = item.auction!;
    final theme = Theme.of(context);
    final market = Get.find<MarketController>();
    final rules = market.meta?.auctionRules;
    final children = <Widget>[];

    if (a.hasOffer) {
      children.add(_Note(
        icon: Icons.local_offer_outlined, fg: marketPrivateFg, bg: marketPrivateBg,
        title: 'market_offer_title'.trParams({'price': marketPrice(a.offerPrice)}),
        body: 'market_offer_body'.trParams({'time': marketTimeLeft(a.offerExpiresAt), 'hours': '${rules?.payHours ?? 24}'}),
        action: Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => _answer(item, false), child: Text('market_no_thanks'.tr))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton(onPressed: () => _answer(item, true), child: Text('market_buy_it'.tr))),
        ]),
      ));
    }
    if (a.won && a.orderId != null) {
      children.add(_Note(
        icon: Icons.emoji_events_outlined, fg: _okFg, bg: _okBg,
        title: 'market_you_won'.trParams({'price': marketPrice(a.price)}),
        body: 'market_you_won_body'.trParams({'hours': '${rules?.payHours ?? 24}'}),
        action: FilledButton(onPressed: () => Get.to(() => MarketOrderScreen(orderId: a.orderId!)), child: Text('market_open_my_order'.tr)),
      ));
    } else if (a.live && a.leading) {
      children.add(_Note(icon: Icons.trending_up_rounded, fg: _okFg, bg: _okBg, title: 'market_you_lead'.tr, body: 'market_you_lead_body'.tr));
    } else if (a.live && a.myBid != null) {
      children.add(_Note(icon: Icons.trending_down_rounded, fg: marketWarnFg, bg: marketWarnBg,
          title: 'market_outbid'.tr, body: 'market_outbid_body'.trParams({'price': marketPrice(a.myBid)})));
    } else if (a.status == 'ending') {
      children.add(_Note(icon: Icons.hourglass_bottom_rounded, fg: theme.hintColor, bg: theme.hintColor.withValues(alpha: 0.08),
          title: 'market_auction_closing'.tr));
    } else if (!a.live && !a.hasOffer) {
      children.add(_Note(icon: Icons.flag_outlined, fg: theme.hintColor, bg: theme.hintColor.withValues(alpha: 0.08),
          title: 'market_auction_status_${a.status}'.tr, body: a.myBid != null ? 'market_auction_lost_body'.tr : null));
    }
    if (a.live) {
      children.add(Text('market_bid_rules'.trParams({'minutes': '${rules?.extendMinutes ?? 2}', 'hours': '${rules?.payHours ?? 24}'}),
          style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: theme.hintColor, height: 1.45)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Future<void> _answer(MarketItem item, bool accept) async {
    if (!accept) {
      final ok = await Get.dialog<bool>(AlertDialog(
        title: Text('market_offer_decline_q'.tr),
        content: Text('market_offer_decline_body'.tr),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text('cancel'.tr)),
          TextButton(onPressed: () => Get.back(result: true), child: Text('market_no_thanks'.tr)),
        ],
      ));
      if (ok != true) return;
    }
    final orderId = await Get.find<MarketController>().auctionAnswer(item.code, accept);
    if (accept && orderId != null) Get.to(() => MarketOrderScreen(orderId: orderId, justSent: false));
  }
}

/// What the seller sees: the winner and the deadline, or what to do when it did not sell.
class _SellerState extends StatelessWidget {
  final MarketItem item;
  const _SellerState({required this.item});

  @override
  Widget build(BuildContext context) {
    final a = item.auction!;
    final theme = Theme.of(context);
    final market = Get.find<MarketController>();
    final children = <Widget>[];
    final orderOpen = a.orderStatus != null && !const ['cancelled', 'completed', 'declined', 'expired'].contains(a.orderStatus);

    if (a.live) {
      children.add(_Note(
        icon: Icons.visibility_outlined, fg: theme.textTheme.bodyLarge?.color ?? Colors.black87, bg: theme.hintColor.withValues(alpha: 0.08),
        title: 'market_your_auction_live'.tr,
        body: a.reservePrice != null ? 'market_your_reserve'.trParams({'price': marketPrice(a.reservePrice)}) : 'market_no_reserve'.tr,
      ));
    } else if (a.status == 'ending') {
      children.add(_Note(icon: Icons.hourglass_bottom_rounded, fg: theme.hintColor, bg: theme.hintColor.withValues(alpha: 0.08),
          title: 'market_auction_closing'.tr));
    } else if (a.status == 'sold' && orderOpen) {
      final dueLeft = a.paymentDueAt;
      children.add(_Note(
        icon: Icons.emoji_events_outlined, fg: _okFg, bg: _okBg,
        title: 'market_sold_to'.trParams({'name': a.winnerName ?? 'market_buyer'.tr, 'price': marketPrice(a.winnerBid ?? a.price)}),
        body: dueLeft == null
            ? 'market_payment_arranged_note'.tr
            : (dueLeft.isAfter(DateTime.now())
                ? 'market_pay_due_seller'.trParams({'time': marketTimeLeft(dueLeft)})
                : 'market_pay_overdue_seller'.tr),
        action: a.orderId == null ? null : FilledButton(
          onPressed: () => Get.to(() => MarketOrderScreen(orderId: a.orderId!)),
          child: Text('market_open_order'.tr),
        ),
      ));
    } else if (a.status == 'sold' && a.orderStatus == 'completed') {
      children.add(_Note(icon: Icons.check_circle_outline_rounded, fg: _okFg, bg: _okBg,
          title: 'market_sold_to'.trParams({'name': a.winnerName ?? 'market_buyer'.tr, 'price': marketPrice(a.winnerBid ?? a.price)})));
    } else {
      // Did not sell, or the winner did not pay: offer it to the next bidder, or put it up again.
      final String title = a.status == 'sold' ? 'market_winner_no_pay' : 'market_auction_status_${a.status}';
      final String body = a.offered
          ? 'market_offer_waiting'.trParams({'time': marketTimeLeft(a.offerExpiresAt)})
          : (a.nextBidder ? 'market_next_bidder_hint'.tr : 'market_relist_hint'.tr);
      children.add(_Note(
        icon: Icons.replay_rounded, fg: marketWarnFg, bg: marketWarnBg, title: title.tr, body: body,
        action: a.offered ? null : Row(children: [
          if (a.nextBidder) ...[
            Expanded(child: FilledButton(onPressed: () => market.auctionOfferNext(item.code), child: Text('market_offer_next'.tr))),
            const SizedBox(width: 8),
          ],
          Expanded(child: OutlinedButton(onPressed: () => showMarketRelistSheet(item), child: Text('market_put_up_again'.tr))),
        ]),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _BidRow extends StatelessWidget {
  final MarketBid bid;
  final bool top;
  const _BidRow({required this.bid, required this.top});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.textTheme.bodyLarge?.color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: bid.mine ? theme.primaryColor.withValues(alpha: 0.15) : theme.hintColor.withValues(alpha: 0.12),
          child: Icon(Icons.person_outline_rounded, size: 16, color: bid.mine ? theme.primaryColor : theme.hintColor),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(bid.mine ? 'market_you'.tr : (bid.name ?? '***'),
            style: (bid.mine ? textSemiBold : textRegular).copyWith(fontSize: Dimensions.fontSizeDefault, color: color))),
        if (bid.createdAt != null)
          Text(_when(bid.createdAt!), style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: theme.hintColor)),
        const SizedBox(width: 10),
        Text(marketPrice(bid.amount), style: (top ? textBold : textMedium).copyWith(fontSize: Dimensions.fontSizeDefault,
            color: top ? theme.primaryColor : color)),
      ]),
    );
  }
}

/// "Place a bid": quick amounts from the minimum, a free amount, and what a bid means.
Future<void> showMarketBidSheet(MarketItem item) async {
  await Get.bottomSheet(_BidSheet(code: item.code), isScrollControlled: true, ignoreSafeArea: false, backgroundColor: Get.theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))));
}

class _BidSheet extends StatefulWidget {
  final String code;
  const _BidSheet({required this.code});

  @override
  State<_BidSheet> createState() => _BidSheetState();
}

class _BidSheetState extends State<_BidSheet> {
  final TextEditingController _amount = TextEditingController();
  double? _picked;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GetBuilder<MarketController>(builder: (market) {
      final item = market.itemFor(widget.code);
      final a = item?.auction;
      if (item == null || a == null) return const SizedBox(height: 120);
      final rules = market.meta?.auctionRules;
      final step = a.step > 0 ? a.step : 100;
      final quick = [a.minNext, a.minNext + step, a.minNext + step * 4];
      final typed = double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
      final amount = typed ?? _picked ?? a.minNext;
      final tooLow = amount < a.minNext;
      // The server refuses wild amounts (a typo with extra zeros): say it here, above the keyboard.
      final tooHigh = amount > a.minNext + 1000 * step;
      return Padding(
        padding: EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 12, Dimensions.paddingSizeLarge,
            Dimensions.paddingSizeLarge),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Text('market_place_bid'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: Text(
              '${(a.bidCount == 0 ? 'market_starting_price' : 'market_current_bid').tr}: ${marketPrice(a.price)}',
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor),
            )),
            const Icon(Icons.timer_outlined, size: 15),
            const SizedBox(width: 4),
            MarketTimeLeft(until: a.endsAt, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall)),
          ]),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final q in quick)
              ChoiceChip(
                label: Text(marketPrice(q)),
                selected: typed == null && amount == q,
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  _picked = q;
                  _amount.clear();
                }),
              ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'market_other_amount'.tr,
              suffixText: 'FCFA',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
              helperText: 'market_min_bid'.trParams({'price': marketPrice(a.minNext)}),
              errorText: typed != null && tooLow
                  ? 'market_bid_too_low'.trParams({'price': marketPrice(a.minNext)})
                  : (tooHigh ? 'market_bid_too_high'.tr : null),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: marketWarnBg, borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
            child: Text('market_bid_promise'.trParams({'hours': '${rules?.payHours ?? 24}'}),
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: marketWarnFg, height: 1.4)),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          SizedBox(width: double.infinity, height: 52, child: FilledButton(
            onPressed: market.bidding || tooLow || tooHigh || !a.live ? null : () async {
              final ok = await market.bid(widget.code, amount);
              if (!context.mounted) return;
              if (ok) {
                Navigator.of(context).pop();
                showCustomSnackBar('market_bid_placed'.tr, isError: false);
              }
            },
            child: market.bidding
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('market_bid_amount'.trParams({'price': marketPrice(amount)}),
                    style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
          )),
        ]),
      );
    });
  }
}

/// "Put it up again": how long; the same starting price, step and reserve.
Future<void> showMarketRelistSheet(MarketItem item) async {
  final max = Get.find<MarketController>().meta?.auctionRules.maxDays ?? 7;
  final days = await Get.bottomSheet<int>(SafeArea(child: Padding(
    padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('market_put_up_again'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge)),
      const SizedBox(height: 4),
      Text('market_relist_body'.trParams({'price': marketPrice(item.auction?.startPrice)}),
          style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Get.theme.hintColor, height: 1.4)),
      const SizedBox(height: Dimensions.paddingSizeDefault),
      for (final d in [1, 3, 7].where((d) => d <= max))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.timer_outlined),
          title: Text(d == 1 ? 'market_one_day'.tr : 'market_days'.trParams({'count': '$d'})),
          onTap: () => Get.back(result: d),
        ),
    ]),
  )), backgroundColor: Get.theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))));
  if (days != null) await Get.find<MarketController>().auctionRelist(item.code, days);
}
