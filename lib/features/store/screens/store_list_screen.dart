import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_order_model.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_menu_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_order_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_orders_screen.dart';
import 'package:ride_sharing_user_app/features/store/widgets/store_widgets.dart';
import 'package:ride_sharing_user_app/features/store/widgets/shop_widgets.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_search_screen.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_model.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class StoreListScreen extends StatefulWidget {
  const StoreListScreen({super.key});

  @override
  State<StoreListScreen> createState() => _StoreListScreenState();
}

/// Which stores the list shows.
enum _Kind { all, restaurants, shops }

class _StoreListScreenState extends State<StoreListScreen> {
  _Kind _kind = _Kind.all;

  @override
  void initState() {
    super.initState();
    final controller = Get.find<StoreController>();
    // After the first frame: home also listens to this controller, and an
    // update while this route is being built is not allowed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadStores();
      controller.loadOrders();
    });
  }

  void _open(StoreModel store) {
    Get.find<StoreController>().openStore(store);
    Get.to(() => const StoreMenuScreen());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: GetBuilder<StoreController>(builder: (controller) {
        final all = controller.stores;
        final active = (controller.orders ?? []).where((o) => o.isActive).toList();
        final stores = (all ?? []).where((s) => _kind == _Kind.all || (_kind == _Kind.shops) == s.isShop).toList();
        final open = stores.where((s) => s.openNow).toList();
        final closed = stores.where((s) => !s.openNow).toList();
        final bool hasShops = (all ?? []).any((s) => s.isShop);
        final bool hasRestaurants = (all ?? []).any((s) => !s.isShop);
        return BodyWidget(
          appBar: AppBarWidget(title: controller.serviceLabel, showBackButton: true),
          body: RefreshIndicator(
            color: theme.primaryColor,
            onRefresh: () async {
              await Future.wait([controller.loadStores(), controller.loadOrders()]);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, 120),
              children: [
                // Search every store: food, groceries, a store's name.
                Material(
                  color: theme.hintColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(shopRadius),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(shopRadius),
                    onTap: () => Get.to(() => const StoreSearchScreen()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Row(children: [
                        Icon(Icons.search_rounded, color: theme.hintColor),
                        const SizedBox(width: 10),
                        Expanded(child: Text('shop_search_everything'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.hintColor))),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSize),
                for (final order in active) _ActiveOrderBanner(order: order),

                // Restaurants or shops.
                Row(children: [
                  Expanded(child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _KindChip(label: 'shop_kind_all'.tr, icon: Icons.apps_rounded, on: _kind == _Kind.all, onTap: () => setState(() => _kind = _Kind.all)),
                      if (hasRestaurants)
                        _KindChip(label: 'shop_kind_restaurants'.tr, icon: Icons.restaurant_rounded, on: _kind == _Kind.restaurants, onTap: () => setState(() => _kind = _Kind.restaurants)),
                      if (hasShops)
                        _KindChip(label: 'shop_kind_shops'.tr, icon: Icons.local_grocery_store_rounded, on: _kind == _Kind.shops, onTap: () => setState(() => _kind = _Kind.shops)),
                    ]),
                  )),
                  IconButton(
                    onPressed: () => Get.to(() => const StoreOrdersScreen()),
                    tooltip: 'my_orders'.tr,
                    icon: Icon(Icons.receipt_long_rounded, color: theme.primaryColor),
                  ),
                ]),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                if (all == null || (controller.storesLoading && all.isEmpty))
                  ...List.generate(4, (_) => const _StoreSkeleton())
                else if (stores.isEmpty)
                  _Empty(onRetry: controller.loadStores)
                else ...[
                  if (open.isNotEmpty) ...[
                    _Heading(text: 'shop_open_now'.tr, count: open.length),
                    for (final s in open) _StoreRow(store: s, onTap: () => _open(s)),
                  ],
                  if (closed.isNotEmpty) ...[
                    _Heading(text: 'shop_closed_now'.tr, count: closed.length),
                    for (final s in closed) _StoreRow(store: s, onTap: () => _open(s)),
                  ],
                ],
                const SizedBox(height: Dimensions.paddingSizeDefault),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.verified_user_outlined, size: 16, color: theme.hintColor),
                  const SizedBox(width: 6),
                  Expanded(child: Text('store_list_pay_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
                ]),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _KindChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;
  const _KindChip({required this.label, required this.icon, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color fg = on ? Colors.white : (theme.textTheme.bodyLarge?.color ?? Colors.black);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: on ? theme.primaryColor : theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: on ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.3))),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(label, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: fg)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  final int count;
  const _Heading({required this.text, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Dimensions.paddingSizeDefault, bottom: Dimensions.paddingSizeSmall),
      child: Text('$text  ·  $count', style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
    );
  }
}

/// A store as one compact row: photo or logo, what it is, open or not, time, distance, rating.
class _StoreRow extends StatelessWidget {
  final StoreModel store;
  final VoidCallback onTap;
  const _StoreRow({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool open = store.openNow;
    final Color kindColor = store.isShop ? const Color(0xFF15803D) : const Color(0xFFE8590C);
    final String meta = [
      '${store.prepMinutes} ${'min'.tr}',
      if (store.distanceKm != null) '${store.distanceKm!.toStringAsFixed(1)} km',
      if (store.branchCount > 1) 'n_branches'.trParams({'n': '${store.branchCount}'}),
    ].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(shopRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(shopRadius),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(shopRadius), border: Border.all(color: theme.hintColor.withValues(alpha: 0.15))),
            child: Opacity(
              opacity: open ? 1 : 0.6,
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 76, height: 76,
                    child: store.cover != null
                        ? ImageWidget(image: store.cover!, fit: BoxFit.cover)
                        : store.logo != null
                            ? ImageWidget(image: store.logo!, fit: BoxFit.cover)
                            : Container(
                                color: kindColor.withValues(alpha: 0.1),
                                child: Icon(store.isShop ? Icons.local_grocery_store_rounded : Icons.restaurant_rounded, color: kindColor, size: 34),
                              ),
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSize),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(store.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault + 1, color: theme.textTheme.bodyLarge?.color)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: kindColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(store.isShop ? 'shop_kind_shop'.tr : 'shop_kind_restaurant'.tr,
                          style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: kindColor)),
                    ),
                    const SizedBox(width: 6),
                    if (store.rating != null && store.ratingCount > 0) ...[
                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A623)),
                      Text(' ${store.rating!.toStringAsFixed(1)} (${store.ratingCount})',
                          style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color)),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: open ? const Color(0xFF12A150) : theme.hintColor, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Flexible(child: Text(
                      open
                          ? (store.closesAt != null ? '${'open_until'.tr} ${store.closesAt}' : 'open_now'.tr)
                          : (store.opensAt != null ? '${'closed_opens_at'.tr} ${store.opensAt}' : 'closed_now'.tr),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: open ? const Color(0xFF12A150) : theme.hintColor),
                    )),
                  ]),
                  const SizedBox(height: 2),
                  Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                ])),
                Icon(Icons.chevron_right_rounded, color: theme.hintColor),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveOrderBanner extends StatelessWidget {
  final StoreOrderModel order;
  const _ActiveOrderBanner({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      child: Material(
        color: theme.primaryColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        child: InkWell(
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          onTap: () => Get.to(() => StoreOrderScreen(orderId: order.id)),
          child: Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: Row(children: [
              Icon(OrderStatusChip.orderIcon(order), color: Colors.white, size: 28),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.storeName ?? '', style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeDefault)),
                Text(OrderStatusChip.orderLine(order), style: textRegular.copyWith(color: Colors.white70, fontSize: Dimensions.fontSizeSmall)),
              ])),
              Text(OrderStatusChip.orderAction(order), style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeSmall)),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ]),
          ),
        ),
      ),
    );
  }
}

class _StoreSkeleton extends StatelessWidget {
  const _StoreSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).hintColor.withValues(alpha: 0.12);
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      child: Row(children: [
        Container(width: 96, height: 96, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 14, width: 160, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 8),
          Container(height: 10, width: 110, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
        ])),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onRetry;
  const _Empty({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(children: [
        Icon(Icons.storefront_outlined, size: 56, color: theme.hintColor),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Text('no_stores_nearby'.tr, textAlign: TextAlign.center,
            style: textMedium.copyWith(color: theme.textTheme.bodyMedium?.color, fontSize: Dimensions.fontSizeDefault)),
        TextButton(onPressed: onRetry, child: Text('try_again'.tr, style: textMedium.copyWith(color: theme.primaryColor))),
      ]),
    );
  }
}
