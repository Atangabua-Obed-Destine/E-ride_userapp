import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_cart_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_cart_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_item_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

const Color marketGreen = Color(0xFF15803D);
const Color marketGreenBg = Color(0xFFE9F7EF);
const Color marketBlueBg = Color(0xFFE8EEFC);

/// − 2 + with a ceiling.
class MarketQtyStepper extends StatelessWidget {
  final int value;
  final int max;
  final int min;
  final ValueChanged<int> onChanged;
  final bool small;
  const MarketQtyStepper({super.key, required this.value, required this.onChanged, this.max = 9999, this.min = 1, this.small = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double h = small ? 32 : 38;
    Widget button(IconData icon, String label, VoidCallback? onTap) => SizedBox(
          width: h + 4,
          height: h,
          child: IconButton(
            onPressed: onTap,
            padding: EdgeInsets.zero,
            tooltip: label,
            icon: Icon(icon, size: small ? 16 : 18),
          ),
        );
    return Container(
      height: h,
      decoration: BoxDecoration(border: Border.all(color: theme.hintColor.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        button(Icons.remove_rounded, 'market_less'.tr, value > min ? () => onChanged(value - 1) : null),
        SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.center,
            style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color))),
        button(Icons.add_rounded, 'market_more'.tr, value < max ? () => onChanged(value + 1) : null),
      ]),
    );
  }
}

/// ★ 4.8 · 126 orders · replies in about 20 min
class MarketShopTrust extends StatelessWidget {
  final double? rating;
  final int ratingCount;
  final int orders;
  final int? replyMinutes;
  const MarketShopTrust({super.key, this.rating, this.ratingCount = 0, this.orders = 0, this.replyMinutes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: theme.hintColor);
    final parts = <String>[
      if (orders > 0) orders == 1 ? 'market_one_order'.tr : 'market_orders_done'.trParams({'count': '$orders'}),
      if (replyMinutes != null) 'market_replies_in'.trParams({'time': marketMinutes(replyMinutes!)}),
    ];
    return Row(children: [
      if (rating != null && ratingCount > 0) ...[
        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A524)),
        const SizedBox(width: 2),
        Text('${rating!.toStringAsFixed(1)} ($ratingCount)', style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: theme.textTheme.bodyLarge?.color)),
        if (parts.isNotEmpty) Text(' · ', style: style),
      ],
      Flexible(child: Text(parts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
    ]);
  }
}

/// "1 piece", "5 pieces".
String marketPieces(int n) => n == 1 ? 'market_one_piece'.tr : 'market_pieces'.trParams({'count': '$n'});

/// "20 min", "1 h 05".
String marketMinutes(int minutes) {
  if (minutes < 60) return '$minutes min';
  if (minutes % 60 == 0) return '${minutes ~/ 60} h';
  return '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}';
}

/// A time left that counts down every second (no colour when there is no deadline).
class MarketCountdown extends StatefulWidget {
  final DateTime? until;
  final String? prefix;
  const MarketCountdown({super.key, required this.until, this.prefix});

  @override
  State<MarketCountdown> createState() => _MarketCountdownState();
}

class _MarketCountdownState extends State<MarketCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final until = widget.until;
    if (until == null) return const SizedBox();
    final left = until.difference(DateTime.now());
    final minutes = left.inMinutes;
    final urgent = minutes < 20;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: urgent ? marketDangerBg : marketWarnBg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.schedule_rounded, size: 13, color: urgent ? marketDangerFg : marketWarnFg),
        const SizedBox(width: 4),
        Text(left.isNegative ? 'market_time_up'.tr : '${widget.prefix ?? ''}${marketMinutes(minutes < 1 ? 1 : minutes)}',
            style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: urgent ? marketDangerFg : marketWarnFg)),
      ]),
    );
  }
}

/// The order's state as a coloured tag.
class MarketOrderTag extends StatelessWidget {
  final MarketOrder order;
  const MarketOrderTag({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (order.status) {
      MarketOrder.requested => (const Color(0xFF6B7675), const Color(0xFFF1F3F3)),
      MarketOrder.changes => (marketWarnFg, marketWarnBg),
      MarketOrder.confirmed || MarketOrder.completed => (marketGreen, marketGreenBg),
      MarketOrder.ready || MarketOrder.onTheWay => (marketVerified, marketBlueBg),
      _ => (marketDangerFg, marketDangerBg),
    };
    final String key = order.status == MarketOrder.requested && order.isSeller ? 'market_order_new' : 'market_order_${order.status}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(key.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: fg)),
    );
  }
}

/// "Added to your cart": keep shopping, view the cart, and more from the same shop.
Future<void> showMarketAddedSheet({required MarketItem item, required String shopSlug, required String choice, required int qty}) async {
  final market = Get.find<MarketController>();
  if (market.shopItemsFor(shopSlug).isEmpty) market.loadShop(shopSlug);
  await Get.bottomSheet(_AddedSheet(item: item, shopSlug: shopSlug, choice: choice, qty: qty), isScrollControlled: true);
}

class _AddedSheet extends StatelessWidget {
  final MarketItem item;
  final String shopSlug;
  final String choice;
  final int qty;
  const _AddedSheet({required this.item, required this.shopSlug, required this.choice, required this.qty});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Container(
      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 12, Dimensions.paddingSizeLarge, Dimensions.paddingSizeLarge),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(top: false, child: GetBuilder<MarketCartController>(builder: (cart) {
        final inShop = cart.shopLines(shopSlug).length;
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Row(children: [
            Container(width: 32, height: 32, decoration: const BoxDecoration(color: marketGreenBg, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: marketGreen, size: 20)),
            const SizedBox(width: 10),
            Text('market_added_to_cart'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
          ]),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Row(children: [
            if (item.cover != null) ImageWidget(image: item.cover!, width: 56, height: 56, radius: 10, fit: BoxFit.cover),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: textSemiBold.copyWith(color: textColor)),
              Text([if (choice.isNotEmpty) choice, '${'market_qty'.tr} $qty'].join(' · '),
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ])),
          ]),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
            child: Text('market_cart_shop_hint'.trParams({'count': '$inShop', 'shop': item.shop?.name ?? ''}),
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor, height: 1.4)),
          ),
          GetBuilder<MarketController>(builder: (market) {
            final more = market.shopItemsFor(shopSlug).where((i) => i.code != item.code && i.status == MarketItem.live).take(6).toList();
            if (more.isEmpty) return const SizedBox(height: Dimensions.paddingSizeDefault);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: Dimensions.paddingSizeDefault),
              Text('market_more_from'.trParams({'shop': item.shop?.name ?? ''}), style: textSemiBold.copyWith(color: textColor)),
              const SizedBox(height: 8),
              SizedBox(height: 128, child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: more.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => InkWell(
                  onTap: () {
                    Get.back();
                    Get.off(() => MarketItemScreen(code: more[i].code, initial: more[i]), preventDuplicates: false);
                  },
                  child: SizedBox(width: 100, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    more[i].cover != null
                        ? ImageWidget(image: more[i].cover!, width: 100, height: 82, radius: 10, fit: BoxFit.cover)
                        : Container(width: 100, height: 82, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 4),
                    Text(more[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: textColor)),
                    Text(marketPrice(more[i].price), style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
                  ])),
                ),
              )),
              const SizedBox(height: Dimensions.paddingSizeSmall),
            ]);
          }),
          Row(children: [
            Expanded(child: SizedBox(height: 50, child: OutlinedButton(onPressed: () => Get.back(), child: Text('market_keep_shopping'.tr)))),
            const SizedBox(width: 10),
            Expanded(child: SizedBox(height: 50, child: FilledButton(
              onPressed: () {
                Get.back();
                Get.to(() => const MarketCartScreen());
              },
              child: Text('market_view_cart'.tr),
            ))),
          ]),
        ]);
      })),
    );
  }
}

/// "Pickup", "E-Ride delivery", "Seller delivers" with an icon.
IconData marketFulfilmentIcon(String f) => switch (f) {
      'eride' => Icons.delivery_dining_rounded,
      'seller' => Icons.local_shipping_outlined,
      _ => Icons.storefront_outlined,
    };

/// A money line: label on the left, amount on the right.
class MarketMoneyRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool strong;
  final double? before;
  const MarketMoneyRow({super.key, required this.label, required this.amount, this.strong = false, this.before});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: (strong ? textBold : textRegular).copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor))),
        if (before != null && before != amount) ...[
          Text(PriceConverter.convertPrice(before!), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor,
              decoration: TextDecoration.lineThrough)),
          const SizedBox(width: 6),
        ],
        Text(PriceConverter.convertPrice(amount), style: (strong ? textBold : textSemiBold).copyWith(
            fontSize: strong ? Dimensions.fontSizeLarge : Dimensions.fontSizeDefault, color: textColor)),
      ]),
    );
  }
}
