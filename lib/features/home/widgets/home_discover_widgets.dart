import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/home/widgets/explore_carousel.dart';
import 'package:ride_sharing_user_app/features/home/widgets/home_services_row.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/explore/controllers/explore_controller.dart';
import 'package:ride_sharing_user_app/features/explore/domain/models/explore_place_model.dart';
import 'package:ride_sharing_user_app/features/explore/screens/explore_screen.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_model.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_order_model.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_list_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_menu_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_order_screen.dart';
import 'package:ride_sharing_user_app/features/store/widgets/store_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Food orders in progress, at the top of home: one tap back to the order.
class HomeActiveOrders extends StatelessWidget {
  const HomeActiveOrders({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(Get.find<ConfigController>().config?.storeOrderingStatus ?? false)) return const SizedBox.shrink();
    return GetBuilder<StoreController>(builder: (controller) {
      final List<StoreOrderModel> active = (controller.orders ?? []).where((o) => o.isActive).toList();
      if (active.isEmpty) return const SizedBox.shrink();
      final ThemeData theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault),
        child: Column(children: [
          for (final StoreOrderModel order in active.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
              child: Material(
                color: theme.primaryColor,
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                  onTap: () => Get.to(() => StoreOrderScreen(orderId: order.id)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSize),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                        child: Icon(OrderStatusChip.orderIcon(order), color: Colors.white),
                      ),
                      const SizedBox(width: Dimensions.paddingSize),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('home_your_order_from'.trParams({'store': order.storeName ?? ''}), maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeDefault)),
                        Text(OrderStatusChip.orderLine(order), maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: textRegular.copyWith(color: Colors.white.withValues(alpha: 0.85), fontSize: Dimensions.fontSizeSmall)),
                      ])),
                      Text(OrderStatusChip.orderAction(order), style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeSmall)),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      );
    });
  }
}

/// "Order from our partners": open stores as cards, straight from home.
class HomeFoodStrip extends StatelessWidget {
  const HomeFoodStrip({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(Get.find<ConfigController>().config?.storeOrderingStatus ?? false)) return const SizedBox.shrink();
    return GetBuilder<StoreController>(builder: (controller) {
      final List<StoreModel> stores = controller.stores ?? [];
      if (stores.isEmpty) return const SizedBox.shrink();
      final ThemeData theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraLarge),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          HomeSectionHeader(
            title: 'home_order_from_partners'.tr,
            trailing: InkWell(
              onTap: () => Get.to(() => const StoreListScreen()),
              child: Text('see_all'.tr, style: textMedium.copyWith(color: theme.primaryColor, fontSize: Dimensions.fontSizeSmall)),
            ),
          ),
          SizedBox(
            // Cards with a cover photo are tall; without one they stay compact.
            height: stores.any((s) => s.cover != null) ? 196 : 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
              itemCount: stores.length,
              separatorBuilder: (_, __) => const SizedBox(width: Dimensions.paddingSize),
              itemBuilder: (_, i) => _StoreCard(store: stores[i], single: stores.length == 1),
            ),
          ),
        ]),
      );
    });
  }
}

class _StoreCard extends StatelessWidget {
  final StoreModel store;
  final bool single;
  const _StoreCard({required this.store, this.single = false});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double width = single ? MediaQuery.of(context).size.width - Dimensions.paddingSizeDefault * 2 : 230;
    // Wider than a cover card: the logo leaves too little room for open state and rating.
    if (store.cover == null) return _CompactStoreCard(store: store, width: single ? width : 270);
    return SizedBox(
      width: width,
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Get.find<StoreController>().openStore(store);
            Get.to(() => const StoreMenuScreen());
          },
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              border: Border.all(color: theme.hintColor.withValues(alpha: 0.18)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                height: 112,
                width: double.infinity,
                child: Stack(fit: StackFit.expand, children: [
                  if (store.cover != null)
                    ImageWidget(image: store.cover!, fit: BoxFit.cover)
                  else
                    // No cover photo yet: a warm panel with the food bag.
                    Container(
                      color: const Color(0xFFFFEFD6).withValues(alpha: Get.isDarkMode ? 0.12 : 1),
                      padding: const EdgeInsets.all(14),
                      child: Image.asset(Images.foodTile, fit: BoxFit.contain),
                    ),
                  if (!store.openNow)
                    Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      alignment: Alignment.center,
                      child: Text(store.opensAt != null ? '${'closed_opens_at'.tr} ${store.opensAt}' : 'closed_now'.tr,
                          style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeSmall)),
                    ),
                  if (store.rating != null && store.ratingCount > 0)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A623)),
                          const SizedBox(width: 2),
                          Text(store.rating!.toStringAsFixed(1), style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
                        ]),
                      ),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Dimensions.paddingSize, Dimensions.paddingSizeSmall, Dimensions.paddingSize, 0),
                child: Row(children: [
                  StoreLogo(url: store.logo, size: 34, isShop: store.isShop),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(store.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
                    Text(
                      [
                        '${store.prepMinutes} ${'min'.tr}',
                        if (store.distanceKm != null) '${store.distanceKm!.toStringAsFixed(1)} km',
                      ].join('  ·  '),
                      maxLines: 1,
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor),
                    ),
                  ])),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A store without a cover photo: logo, name, open state, rating and time on
/// one row, so the strip does not fill with placeholder art.
class _CompactStoreCard extends StatelessWidget {
  final StoreModel store;
  final double width;
  const _CompactStoreCard({required this.store, required this.width});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Get.find<StoreController>().openStore(store);
            Get.to(() => const StoreMenuScreen());
          },
          child: Ink(
            padding: const EdgeInsets.all(Dimensions.paddingSize),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              border: Border.all(color: theme.hintColor.withValues(alpha: 0.18)),
            ),
            child: Row(children: [
              StoreLogo(url: store.logo, size: 60, isShop: store.isShop),
              const SizedBox(width: Dimensions.paddingSize),
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(store.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
                const SizedBox(height: 2),
                Row(children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(
                    shape: BoxShape.circle, color: store.openNow ? const Color(0xFF12A150) : theme.hintColor,
                  )),
                  const SizedBox(width: 5),
                  Flexible(child: Text(store.openNow ? 'open_now'.tr : 'closed_now'.tr, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: store.openNow ? const Color(0xFF12A150) : theme.hintColor))),
                  if (store.rating != null && store.ratingCount > 0) ...[
                    Text('  ·  ', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A623)),
                    Text(' ${store.rating!.toStringAsFixed(1)}', style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
                  ],
                ]),
                Text(
                  ['${store.prepMinutes} ${'min'.tr}', if (store.distanceKm != null) '${store.distanceKm!.toStringAsFixed(1)} km'].join('  ·  '),
                  maxLines: 1,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor),
                ),
              ])),
              Icon(Icons.chevron_right_rounded, color: theme.hintColor),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Explore Bamenda on home: the categories as small tiles, one tap from a
/// pharmacy, hospital, bank, bus agency or hotel. Loading categories costs
/// nothing; the Google search runs when a category opens.
class HomeExploreSection extends StatelessWidget {
  const HomeExploreSection({super.key});

  @override
  Widget build(BuildContext context) {
    final config = Get.find<ConfigController>().config;
    if (!(config?.exploreStatus ?? config?.stayStatus ?? false)) return const SizedBox.shrink();
    return GetBuilder<ExploreController>(builder: (controller) {
      final List<ExploreCategory> categories = controller.categories ?? [];
      if (categories.isEmpty) return const SizedBox.shrink();
      final ThemeData theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraLarge),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          HomeSectionHeader(
            title: controller.label,
            trailing: InkWell(
              onTap: () => Get.to(() => const ExploreScreen()),
              child: Text('see_all'.tr, style: textMedium.copyWith(color: theme.primaryColor, fontSize: Dimensions.fontSizeSmall)),
            ),
          ),
          ExploreCarousel(categories: categories),
        ]),
      );
    });
  }
}
