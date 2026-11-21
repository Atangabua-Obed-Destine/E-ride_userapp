import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_cart_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_item_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_send_order_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_order_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The cart, one block per shop: each shop gets its own order request.
class MarketCartScreen extends StatefulWidget {
  const MarketCartScreen({super.key});

  @override
  State<MarketCartScreen> createState() => _MarketCartScreenState();
}

class _MarketCartScreenState extends State<MarketCartScreen> {
  @override
  void initState() {
    super.initState();
    Get.find<MarketCartController>().load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<MarketCartController>(builder: (cart) {
      final shops = cart.byShop;
      return Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
          title: Text('market_my_cart'.tr),
          actions: [
            if (shops.length > 1)
              Padding(
                padding: const EdgeInsets.only(right: Dimensions.paddingSizeDefault),
                child: Center(child: Text('market_cart_shops'.trParams({'count': '${shops.length}'}),
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
              ),
          ],
        ),
        body: shops.isEmpty
            ? MarketEmpty(icon: Icons.shopping_cart_outlined, title: 'market_cart_empty'.tr, body: 'market_cart_empty_body'.tr,
                action: 'market_browse'.tr, onAction: () => Get.back())
            : ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
                MarketScamNotice(text: 'market_cart_notice'.tr),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                for (final entry in shops.entries) ...[
                  _ShopBlock(slug: entry.key, lines: entry.value, cart: cart, primary: entry.key == shops.keys.first),
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                ],
              ]),
      );
    });
  }
}

class _ShopBlock extends StatelessWidget {
  final String slug;
  final List<MarketCartLine> lines;
  final MarketCartController cart;
  final bool primary;
  const _ShopBlock({required this.slug, required this.lines, required this.cart, required this.primary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final first = lines.first;
    final pieces = cart.piecesOf(slug);
    return Container(
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.hintColor.withValues(alpha: 0.15))),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          MarketShopAvatar(name: first.shopName, logo: first.shopLogo, size: 28),
          const SizedBox(width: 8),
          Expanded(child: Text(first.shopName, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor))),
        ]),
        const Divider(height: 20),
        for (final line in lines) _Line(line: line, cart: cart),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text('market_subtotal_pieces'.trParams({'count': '$pieces'}),
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor))),
          Text(PriceConverter.convertPrice(cart.subtotal(slug)), style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, height: 48, child: primary
            ? FilledButton(onPressed: () => Get.to(() => MarketSendOrderScreen(shopSlug: slug)),
                child: Text('market_send_order_to'.trParams({'shop': first.shopName})))
            : OutlinedButton(onPressed: () => Get.to(() => MarketSendOrderScreen(shopSlug: slug)),
                child: Text('market_send_order_to'.trParams({'shop': first.shopName})))),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  final MarketCartLine line;
  final MarketCartController cart;
  const _Line({required this.line, required this.cart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final unit = cart.unitPrice(line);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => Get.to(() => MarketItemScreen(code: line.itemCode)),
          child: line.photo != null
              ? ImageWidget(image: line.photo!, width: 60, height: 60, radius: 10, fit: BoxFit.cover)
              : Container(width: 60, height: 60, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(line.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: textSemiBold.copyWith(color: textColor))),
            IconButton(
              tooltip: 'market_remove'.tr,
              visualDensity: VisualDensity.compact,
              onPressed: () => cart.remove(line),
              icon: Icon(Icons.delete_outline_rounded, size: 20, color: theme.hintColor),
            ),
          ]),
          if (line.choice.isNotEmpty)
            Text(line.choice, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          if (cart.isWholesale(line))
            Text('market_wholesale_applied'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: marketGreen)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: Text(PriceConverter.convertPrice(unit * line.qty),
                style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor))),
            MarketQtyStepper(value: line.qty, max: line.maxQty, small: true, onChanged: (q) => cart.setQty(line, q)),
          ]),
        ])),
      ]),
    );
  }
}
