import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_share_shop_screen.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_booking_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_order_controller.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_order_widgets.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_bookings_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_chats_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_service_settings_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_service_widgets.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_item_form_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_item_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_posted_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_order_settings_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_orders_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_shop_form_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_start_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_sell_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The seller's own shop: what it brought (visits, chats, new E-Ride users,
/// followers), E-Ride Verified, post an item, share the shop, and every item
/// with its status.
class MyMarketShopScreen extends StatefulWidget {
  final bool justOpened;
  const MyMarketShopScreen({super.key, this.justOpened = false});

  @override
  State<MyMarketShopScreen> createState() => _MyMarketShopScreenState();
}

class _MyMarketShopScreenState extends State<MyMarketShopScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final market = Get.find<MarketController>();
      market.loadMyShop();
      // Fresh counts: requests to answer and orders may have come in since the Market opened.
      market.loadMeta(force: true).then(Get.find<MarketBookingController>().takeCounts);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<MarketController>(builder: (market) {
      final shop = market.myShop;
      if (shop == null) {
        return Scaffold(
          appBar: AppBar(),
          body: market.myLoading
              ? const Center(child: CircularProgressIndicator())
              : MarketEmpty(icon: Icons.storefront_outlined, title: 'market_no_shop_yet'.tr, action: 'market_open_shop'.tr,
                  onAction: () => Get.off(() => const MarketStartScreen())),
        );
      }
      final closed = shop.status == 'closed';
      final stats = shop.stats ?? const MarketShopStats();
      final private = shop.isPrivate;
      final digitalAllowed = (market.meta?.digitalAllowed ?? true) && !private;
      final maxItems = market.meta?.privateMaxItems ?? 10;
      final listed = market.myItems.where((i) => i.status != MarketItem.removed).length;
      return Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
          title: Text((private ? 'market_my_items' : 'market_my_shop').tr),
          actions: [
            IconButton(tooltip: 'market_chats'.tr, icon: const Icon(Icons.chat_bubble_outline_rounded),
                onPressed: () => Get.to(() => const MarketChatsScreen())),
            IconButton(tooltip: (private ? 'market_edit_profile' : 'market_edit_shop').tr, icon: const Icon(Icons.edit_outlined),
                onPressed: closed ? null : () => Get.to(() => MarketShopFormScreen(shop: shop))),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: market.loadMyShop,
          child: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
            if (widget.justOpened && market.myItems.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Icon(Icons.celebration_outlined, color: theme.primaryColor),
                  const SizedBox(width: 10),
                  Expanded(child: Text('market_shop_open_welcome'.tr, style: textMedium.copyWith(color: textColor, height: 1.4))),
                ]),
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
            ],
            if (closed) ...[
              Container(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                decoration: BoxDecoration(color: marketDangerBg, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('market_shop_closed'.tr, style: textBold.copyWith(color: marketDangerFg)),
                  const SizedBox(height: 4),
                  Text(shop.closedReason ?? 'market_shop_closed_body'.tr, style: textRegular.copyWith(color: marketDangerFg, height: 1.4)),
                ]),
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
            ],
            _Card(child: Row(children: [
              MarketShopAvatar(name: shop.name, logo: shop.logo, size: 56),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(shop.name, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor))),
                  if (shop.verified) ...[const SizedBox(width: 4), const MarketVerifiedBadge()],
                ]),
                if (private) ...[
                  const SizedBox(height: 3),
                  const MarketPrivateTag(),
                ] else
                  Text([if (shop.categories.isNotEmpty) marketCategories(shop.categories), if (shop.area != null) shop.area!].join(' · '),
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              ])),
              if (!closed)
                IconButton(tooltip: 'market_share'.tr, icon: const Icon(Icons.share_outlined),
                    onPressed: () => private ? shareMarketLink(shop.link, shop.name) : Get.to(() => const MarketShareShopScreen())),
            ])),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Row(children: [
              _Stat(value: stats.visits, label: 'market_stat_visits'.tr),
              _Stat(value: stats.chats, label: 'market_stat_chats'.tr),
              _Stat(value: stats.newUsers, label: 'market_stat_new_users'.tr),
              _Stat(value: stats.followers, label: 'market_stat_followers'.tr),
            ]),
            // Share the shop on WhatsApp Status: people see the catalogue and install E-Ride.
            if (!closed && !private) ...[
              const SizedBox(height: Dimensions.paddingSizeSmall),
              _Card(child: InkWell(
                onTap: () => Get.to(() => const MarketShareShopScreen()),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: const Color(0xFF25D366).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.campaign_rounded, color: Color(0xFF128C7E)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('share_shop_card_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
                    Text('share_shop_card_sub'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: theme.hintColor),
                ]),
              )),
            ],
            if (!closed && !private) ...[
              const SizedBox(height: Dimensions.paddingSizeSmall),
              _OrdersCard(shop: shop),
            ],
            if (!closed && private) ...[
              const SizedBox(height: Dimensions.paddingSizeSmall),
              // Auction wins become orders: the private seller follows them here.
              _Card(child: InkWell(
                onTap: () => Get.to(() => const MarketOrdersScreen(role: 'selling')),
                child: Row(children: [
                  Icon(Icons.receipt_long_outlined, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text('market_orders'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor))),
                  if ((market.meta?.sellingNew ?? 0) > 0)
                    Text('market_new_count'.trParams({'count': '${market.meta!.sellingNew}'}),
                        style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
                  Icon(Icons.chevron_right_rounded, color: theme.hintColor),
                ]),
              )),
            ],
            const SizedBox(height: Dimensions.paddingSizeSmall),
            if (!closed && !private) _Verification(shop: shop),
            if (!closed && private) _GrowCard(shop: shop, listed: listed, max: maxItems),
            if (!closed && shop.hasServices) ...[
              const SizedBox(height: Dimensions.paddingSizeSmall),
              _BookingsCard(shop: shop),
            ],
            const SizedBox(height: Dimensions.paddingSizeDefault),
            if (!closed)
              Row(children: [
                Expanded(child: SizedBox(height: 50, child: FilledButton.icon(
                  onPressed: private && listed >= maxItems
                      ? null
                      : () => Get.to(() => private ? const MarketItemFormScreen(privateSeller: true) : const MarketItemFormScreen()),
                  icon: const Icon(Icons.add_rounded),
                  label: Text((private ? 'market_sell_something' : 'market_post_item').tr),
                ))),
                if (digitalAllowed) ...[
                  const SizedBox(width: 8),
                  Expanded(child: SizedBox(height: 50, child: OutlinedButton.icon(
                    onPressed: () => Get.to(() => const MarketItemFormScreen(digital: true)),
                    icon: const Icon(Icons.description_outlined),
                    label: Text('market_post_digital'.tr),
                  ))),
                ],
              ]),
            if (!closed) ...[
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(
                onPressed: private && listed >= maxItems ? null : () => Get.to(() => MarketItemFormScreen(service: true, privateSeller: private)),
                icon: const Icon(Icons.event_available_outlined),
                label: Text('market_offer_service'.tr),
              )),
            ],
            const SizedBox(height: Dimensions.paddingSizeLarge),
            Text(private
                    ? 'market_items_of_max'.trParams({'count': '$listed', 'max': '$maxItems'})
                    : 'market_your_items'.trParams({'count': '${market.myItems.length}'}),
                style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            if (market.myItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('market_no_items_yet'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(color: theme.hintColor)),
              )
            else
              for (final item in market.myItems) _MyItemRow(item: item),
            const SizedBox(height: 40),
          ]),
        ),
      );
    });
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color? color;
  const _Card({required this.child, this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: 0.12)),
        ),
        child: child,
      );
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.hintColor.withValues(alpha: 0.12))),
      child: Column(children: [
        Text('$value', style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
      ]),
    ));
  }
}

/// Services: requests to answer, the bookings, and when the shop takes them.
class _BookingsCard extends StatelessWidget {
  final MarketShop shop;
  const _BookingsCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<MarketBookingController>(builder: (c) {
      final waiting = Get.find<MarketController>().meta?.providerRequests ?? c.providerRequests;
      return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.event_available_outlined, color: marketServiceFg),
          const SizedBox(width: 8),
          Expanded(child: Text('market_bookings'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor))),
          if (waiting > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(12)),
              child: Text('market_to_answer_n'.trParams({'count': '$waiting'}), style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white)),
            ),
        ]),
        const SizedBox(height: 6),
        Text((shop.takingBookings ? 'market_bookings_card_on' : 'market_bookings_card_off').trParams({'count': '${shop.bookingsCompleted}'}),
            style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: FilledButton(onPressed: () => Get.to(() => const MarketProviderBookingsScreen()), child: Text('market_open_bookings'.tr))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: () => Get.to(() => const MarketServiceSettingsScreen()), child: Text('market_when_free'.tr))),
        ]),
      ]));
    });
  }
}

/// A private seller: how many items they can list, and "Turn into a shop" (no conditions).
class _GrowCard extends StatelessWidget {
  final MarketShop shop;
  final int listed;
  final int max;
  const _GrowCard({required this.shop, required this.listed, required this.max});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final full = listed >= max;
    return _Card(color: full ? marketWarnBg : null, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.storefront_rounded, color: full ? marketWarnFg : theme.primaryColor),
        const SizedBox(width: 8),
        Expanded(child: Text((full ? 'market_private_full' : 'market_selling_a_lot').tr,
            style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: full ? marketWarnFg : textColor))),
      ]),
      const SizedBox(height: 6),
      Text('market_turn_into_shop_hint'.trParams({'max': '$max'}),
          style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: full ? marketWarnFg : theme.hintColor, height: 1.4)),
      const SizedBox(height: 8),
      Align(alignment: Alignment.centerLeft, child: OutlinedButton(
        onPressed: () => Get.to(() => MarketShopFormScreen(shop: shop, turnIntoShop: true)),
        child: Text('market_turn_into_shop'.tr),
      )),
    ]));
  }
}

class _Verification extends StatelessWidget {
  final MarketShop shop;
  const _Verification({required this.shop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    if (shop.verified) {
      return _Card(color: marketVerified.withValues(alpha: 0.06), child: Row(children: [
        const MarketVerifiedBadge(size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text('market_you_are_verified'.tr, style: textMedium.copyWith(color: textColor))),
      ]));
    }
    return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.verified_outlined, color: marketVerified),
        const SizedBox(width: 8),
        Expanded(child: Text('market_get_verified'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor))),
      ]),
      const SizedBox(height: 6),
      Text((shop.verificationRequested ? 'market_verification_pending' : (shop.venue != null ? 'venue_get_verified_body' : 'market_get_verified_body')).tr,
          style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
      if (!shop.verificationRequested) ...[
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: OutlinedButton(
          onPressed: () => Get.find<MarketController>().requestVerification(),
          child: Text('market_ask_verification'.tr),
        )),
      ],
    ]));
  }
}

class _MyItemRow extends StatelessWidget {
  final MarketItem item;
  const _MyItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool live = item.status == MarketItem.live;
    final Color statusColor = live ? const Color(0xFF15803D) : (item.status == MarketItem.soldOut ? marketWarnFg : marketDangerFg);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Get.to(() => MarketItemScreen(code: item.code, initial: item)),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              item.cover != null
                  ? ImageWidget(image: item.cover!, width: 60, height: 60, radius: 10, fit: BoxFit.cover)
                  : Container(width: 60, height: 60, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(item.isDigital ? Icons.description_outlined : Icons.image_outlined, color: theme.hintColor)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
                Row(children: [
                  if (item.isAuction) ...[Icon(Icons.gavel_rounded, size: 13, color: theme.primaryColor), const SizedBox(width: 3)],
                  Text(item.isService && item.service != null ? marketServicePrice(item.price, item.service!.priceType) : marketPrice(item.isAuction ? item.auction!.price : item.price),
                      style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
                  if (item.isAuction) ...[
                    const SizedBox(width: 6),
                    Flexible(child: Text(
                      [
                        item.auction!.bidCount == 1 ? 'market_one_bid'.tr : 'market_n_bids'.trParams({'count': '${item.auction!.bidCount}'}),
                        if (item.auction!.live) marketTimeLeft(item.auction!.endsAt) else 'market_auction_status_${item.auction!.status}'.tr,
                      ].join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor),
                    )),
                  ],
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('market_status_${item.status}'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: statusColor)),
                  const SizedBox(width: 10),
                  Icon(Icons.visibility_outlined, size: 12, color: theme.hintColor),
                  Text(' ${item.visits}', style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
                  const SizedBox(width: 8),
                  Icon(Icons.chat_bubble_outline_rounded, size: 12, color: theme.hintColor),
                  Text(' ${item.chats}', style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
                ]),
              ])),
              if (item.isPublic)
                IconButton(
                  tooltip: 'market_share'.tr,
                  icon: const Icon(Icons.share_outlined, size: 20),
                  onPressed: () => Get.to(() => MarketPostedScreen(item: item, justPosted: false)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Orders: what is waiting, the "Taking orders" switch, and the way in to the inbox and settings.
class _OrdersCard extends StatelessWidget {
  final MarketShop shop;
  const _OrdersCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<MarketOrderController>(builder: (c) {
      final waiting = Get.find<MarketController>().meta?.sellingNew ?? c.sellingNew;
      return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.receipt_long_outlined, color: theme.primaryColor),
          const SizedBox(width: 8),
          Expanded(child: Text('market_orders'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor))),
          if (waiting > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(12)),
              child: Text('market_new_count'.trParams({'count': '$waiting'}), style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white)),
            ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text(
            shop.takingOrdersSwitch ? 'market_taking_orders_on_hint'.tr : 'market_taking_orders_off_hint'.tr,
            style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4),
          )),
          Switch(
            value: shop.takingOrdersSwitch,
            onChanged: c.acting ? null : (on) => c.saveSettings({'taking_orders': on ? 1 : 0},
                done: on ? 'market_taking_orders_on' : 'market_taking_orders_off'),
          ),
        ]),
        if (shop.ratingCount > 0 || shop.ordersCompleted > 0 || shop.replyMinutes != null) ...[
          MarketShopTrust(rating: shop.rating, ratingCount: shop.ratingCount, orders: shop.ordersCompleted, replyMinutes: shop.replyMinutes),
          const SizedBox(height: 8),
        ],
        Row(children: [
          Expanded(child: SizedBox(height: 44, child: FilledButton(
            onPressed: () => Get.to(() => MarketOrdersScreen(role: 'selling', tab: waiting > 0 ? 'new' : 'confirmed')),
            child: Text('market_open_orders'.tr),
          ))),
          const SizedBox(width: 8),
          Expanded(child: SizedBox(height: 44, child: OutlinedButton(
            onPressed: () => Get.to(() => const MarketOrderSettingsScreen()),
            child: Text('market_order_settings_short'.tr),
          ))),
        ]),
      ]));
    });
  }
}
