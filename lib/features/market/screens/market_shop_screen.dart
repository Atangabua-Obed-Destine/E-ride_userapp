import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_item_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_posted_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/my_market_shop_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_venue_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_map_card.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_order_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_sell_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// A shop: who they are, verified or not, follow, and their items.
class MarketShopScreen extends StatefulWidget {
  final String slug;
  const MarketShopScreen({super.key, required this.slug});

  @override
  State<MarketShopScreen> createState() => _MarketShopScreenState();
}

class _MarketShopScreenState extends State<MarketShopScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<MarketController>().loadShop(widget.slug));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GetBuilder<MarketController>(builder: (market) {
      final MarketShop? shop = market.shopFor(widget.slug);
      final List<MarketItem> items = market.shopItemsFor(widget.slug);
      if (shop == null) {
        return Scaffold(
          appBar: AppBar(),
          body: market.shopLoading
              ? const Center(child: CircularProgressIndicator())
              : MarketEmpty(icon: Icons.store_mall_directory_outlined, title: market.shopError ?? 'market_shop_gone'.tr),
        );
      }
      final textColor = theme.textTheme.bodyLarge?.color;
      final private = shop.isPrivate;
      return Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.cardColor,
          foregroundColor: textColor,
          surfaceTintColor: Colors.transparent,
          title: Text(shop.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(tooltip: 'market_share'.tr, icon: const Icon(Icons.share_outlined), onPressed: () => shareMarketLink(shop.link, shop.name)),
            if (!shop.mine)
              PopupMenuButton<String>(
                color: Theme.of(context).cardColor,
                onSelected: (v) async {
                  if (v == 'report') showMarketReportSheet(slug: shop.slug, shopSlug: shop.slug);
                  if (v == 'block') {
                    if (await market.block(shop.slug, !shop.blocked)) market.loadShop(shop.slug);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'report', child: Text('market_report_shop'.tr)),
                  PopupMenuItem(value: 'block', child: Text((shop.blocked ? 'market_unblock_shop' : 'market_block_shop').tr)),
                ],
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => market.loadShop(shop.slug),
          child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
            SliverToBoxAdapter(child: Container(
              color: theme.cardColor,
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  MarketShopAvatar(name: shop.name, logo: shop.logo, size: 64),
                  const SizedBox(width: Dimensions.paddingSizeDefault),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(shop.name, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor))),
                      if (shop.verified) ...[const SizedBox(width: 4), const MarketVerifiedBadge(size: 20)],
                    ]),
                    const SizedBox(height: 2),
                    if (private) ...[
                      const MarketPrivateTag(),
                      if (shop.area != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(shop.area!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                        ),
                    ] else ...[
                      Text([
                        if (shop.categories.isNotEmpty) marketCategories(shop.categories),
                        if (shop.area != null) shop.area!,
                      ].join(' · '), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                      const SizedBox(height: 2),
                      Text(shop.verified ? 'market_verified_shop'.tr : (shop.isNew ? 'market_new_shop'.tr : 'market_not_verified'.tr),
                          style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: shop.verified ? marketVerified : theme.hintColor)),
                    ],
                    if (shop.ratingCount > 0 || shop.ordersCompleted > 0 || shop.replyMinutes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: MarketShopTrust(rating: shop.rating, ratingCount: shop.ratingCount, orders: shop.ordersCompleted, replyMinutes: shop.replyMinutes),
                      ),
                    if (!shop.mine && !shop.takingOrders && !private)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text('market_not_taking_orders'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: marketWarnFg)),
                      ),
                  ])),
                ]),
                if (shop.about != null) ...[
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Text(shop.about!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor, height: 1.45)),
                ],
                const SizedBox(height: Dimensions.paddingSizeDefault),
                if (shop.mine)
                  SizedBox(width: double.infinity, height: 46, child: OutlinedButton.icon(
                    onPressed: () => Get.off(() => const MyMarketShopScreen()),
                    icon: const Icon(Icons.storefront_rounded, size: 18),
                    label: Text((private ? 'market_manage_items' : 'market_manage_shop').tr),
                  ))
                else
                  SizedBox(width: double.infinity, height: 46, child: shop.following
                      ? OutlinedButton.icon(
                          onPressed: () => marketFollowTap(slug: shop.slug, shopName: shop.name, following: true, notify: shop.followNotify),
                          icon: Icon(shop.followNotify ? Icons.notifications_active_outlined : Icons.favorite_rounded, size: 18),
                          label: Text('market_following_on'.tr))
                      : FilledButton.icon(
                          onPressed: () => marketFollowTap(slug: shop.slug, shopName: shop.name, following: false, notify: false),
                          icon: const Icon(Icons.favorite_border_rounded, size: 18),
                          label: Text((private ? 'market_follow_seller' : 'market_follow_shop').tr))),
                if (private && !shop.mine) ...[
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  const MarketPrivateExplainer(),
                ] else if (!shop.verified) ...[
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  MarketScamNotice(text: 'market_unverified_notice'.tr),
                ],
                // In a market: the shed, the shopfront and "Walk there"; otherwise the small map.
                if (shop.venue != null && !private) ...[
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                  ShopShedCard(shop: shop),
                ] else if (shop.map != null && !private) ...[
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                  MarketMapCard(shopName: shop.name, point: shop.map!, note: shop.mapNote),
                ],
              ]),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, 0),
              child: Text('market_items_count'.trParams({'count': '${shop.itemsCount}'}),
                  style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
            )),
            if (items.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: MarketEmpty(icon: Icons.inventory_2_outlined, title: 'market_shop_no_items'.tr))
            else
              SliverPadding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.74),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => MarketItemCard(item: items[i], showShop: false,
                        onTap: () => Get.to(() => MarketItemScreen(code: items[i].code, initial: items[i]))),
                    childCount: items.length,
                  ),
                ),
              ),
          ]),
        ),
      );
    });
  }
}
