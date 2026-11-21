import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_model.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_checkout_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/shop_screen.dart';
import 'package:ride_sharing_user_app/features/store/widgets/store_branch_widgets.dart';
import 'package:ride_sharing_user_app/features/store/widgets/store_widgets.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class StoreMenuScreen extends StatefulWidget {
  /// A search to start with (from searching every store).
  final String? query;
  const StoreMenuScreen({super.key, this.query});

  @override
  State<StoreMenuScreen> createState() => _StoreMenuScreenState();
}

class _StoreMenuScreenState extends State<StoreMenuScreen> {
  late final TextEditingController _search = TextEditingController(text: widget.query ?? '');
  late String _query = (widget.query ?? '').trim();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.query;
    final theme = Theme.of(context);
    // Shops and supermarkets: aisles, shelves and a search, not a menu list.
    final current = Get.find<StoreController>().store;
    if (current != null && current.isShop) return ShopView(initialQuery: query);
    return Scaffold(
      backgroundColor: theme.cardColor,
      body: GetBuilder<StoreController>(builder: (controller) {
        final store = controller.store;
        if (store == null) return const SizedBox.shrink();
        final showCart = !controller.cartIsEmpty && controller.cartStoreId == store.id;
        return Stack(children: [
          CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 190,
              backgroundColor: theme.scaffoldBackgroundColor,
              foregroundColor: Colors.white,
              actions: [
                if (store.link != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: IconButton(
                        tooltip: 'store_share'.tr,
                        icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                        onPressed: () => shareStoreLink(store),
                      ),
                    ),
                  ),
              ],
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    tooltip: 'back'.tr,
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    onPressed: () => Get.back(),
                  ),
                ),
              ),
              title: Text(store.name ?? '', style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeLarge)),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  store.cover != null
                      ? ImageWidget(image: store.cover!, fit: BoxFit.cover)
                      : Container(color: theme.primaryColor),
                  const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent, Colors.black54],
                  ))),
                ]),
              ),
            ),
            SliverToBoxAdapter(child: _StoreHeader(store: store)),
            // A brand with branches: which branch cooks, why, and a clear way to choose another.
            SliverToBoxAdapter(child: StoreBranchBanner(controller: controller)),
            if (controller.menuLoading)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())))
            else if (controller.menu.isEmpty)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('menu_empty'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(color: theme.hintColor)),
              ))
            else ...[
              // Search the menu, like in a shop.
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, 0),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'shop_search_in'.trParams({'store': store.name ?? ''}),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'clear'.tr, onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    }),
                    filled: true,
                    fillColor: theme.hintColor.withValues(alpha: 0.08),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              )),
              if (_query.isNotEmpty && matchProducts(controller.menu, _query).isEmpty)
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text('shop_not_here'.trParams({'query': _query, 'store': store.name ?? ''}), textAlign: TextAlign.center,
                      style: textRegular.copyWith(color: theme.hintColor)),
                )),
              for (final section in _filtered(controller.menu)) ...[
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeLarge, Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall),
                  child: section.isNotToday
                      // Dishes for another day or time: quieter, with a line saying so.
                      ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Divider(height: Dimensions.paddingSizeLarge, color: theme.hintColor.withValues(alpha: 0.25)),
                          Row(children: [
                            Icon(Icons.schedule_rounded, size: 20, color: theme.hintColor),
                            const SizedBox(width: 6),
                            Expanded(child: Text(section.name, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.hintColor))),
                          ]),
                          const SizedBox(height: 2),
                          Text('not_served_now_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                        ])
                      : Text(section.name, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyMedium?.color)),
                )),
                SliverList.separated(
                  itemCount: section.items.length,
                  separatorBuilder: (_, __) => Divider(height: 1, indent: Dimensions.paddingSizeDefault, endIndent: Dimensions.paddingSizeDefault, color: theme.hintColor.withValues(alpha: 0.15)),
                  itemBuilder: (_, i) => _MenuItemTile(item: section.items[i], storeOpen: store.openNow),
                ),
              ],
            ],
            SliverToBoxAdapter(child: SizedBox(height: showCart ? 120 : 40)),
          ]),
          if (showCart)
            Positioned(
              left: Dimensions.paddingSizeDefault,
              right: Dimensions.paddingSizeDefault,
              bottom: MediaQuery.paddingOf(context).bottom + Dimensions.paddingSizeDefault,
              child: _CartBar(count: controller.cartCount, subtotal: controller.cartSubtotal),
            ),
        ]);
      }),
    );
  }
}

extension on _StoreMenuScreenState {
  /// The menu, or only what matches the search (sections without a match are left out).
  List<MenuSection> _filtered(List<MenuSection> menu) {
    if (_query.isEmpty) return menu;
    final words = _query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return [
      for (final s in menu)
        if (s.items.any((i) => words.every('${i.name} ${i.description ?? ''} ${s.name}'.toLowerCase().contains)))
          MenuSection(id: s.id, name: s.name, kind: s.kind,
              items: s.items.where((i) => words.every('${i.name} ${i.description ?? ''} ${s.name}'.toLowerCase().contains)).toList()),
    ];
  }
}

class _StoreHeader extends StatelessWidget {
  final StoreModel store;
  const _StoreHeader({required this.store});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StoreLogo(url: store.logo, size: 52, isShop: store.isShop),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(store.name ?? '', style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyMedium?.color)),
            if (store.description != null && store.description!.isNotEmpty)
              Text(store.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: muted),
          ])),
        ]),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Pill(
            icon: Icons.circle,
            iconColor: store.openNow ? const Color(0xFF12A150) : theme.hintColor,
            text: store.openNow
                ? (store.closesAt != null ? '${'open_until'.tr} ${store.closesAt}' : 'open_now'.tr)
                : (store.opensAt != null ? '${'closed_opens_at'.tr} ${store.opensAt}' : 'closed_now'.tr),
          ),
          _Pill(icon: Icons.timer_outlined, text: '${store.prepMinutes} ${'min'.tr}'),
          if (store.distanceKm != null) _Pill(icon: Icons.place_outlined, text: '${store.distanceKm!.toStringAsFixed(1)} km'),
          if (store.minOrderAmount > 0) _Pill(icon: Icons.shopping_bag_outlined, text: '${'minimum'.tr} ${PriceConverter.convertPrice(store.minOrderAmount)}'),
          // How to have it: delivery, eat there, collect.
          if (store.ways.contains('delivery')) _Pill(icon: Icons.delivery_dining_rounded, text: 'order_way_delivery'.tr),
          if (store.offersDineIn) _Pill(icon: Icons.restaurant_rounded, text: 'order_way_dine_in'.tr),
          if (store.offersPickup) _Pill(icon: Icons.shopping_bag_rounded, text: 'order_way_pickup'.tr),
        ]),
        if (!store.openNow)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: Dimensions.paddingSizeDefault),
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
            child: Text('store_closed_browse_only'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color)),
          ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;
  const _Pill({required this.icon, required this.text, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(Dimensions.radiusOverLarge)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: icon == Icons.circle ? 9 : 15, color: iconColor ?? theme.hintColor),
        const SizedBox(width: 6),
        Text(text, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color)),
      ]),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  final MenuItem item;
  final bool storeOpen;
  const _MenuItemTile({required this.item, required this.storeOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<StoreController>();
    final quantity = controller.cartStoreId == controller.store?.id ? controller.quantityOf(item.id) : 0;
    final canAdd = storeOpen && item.isAvailable;
    final stepper = QuantityStepper(
      quantity: quantity,
      enabled: canAdd,
      itemName: item.name,
      onAdd: () => _add(context, controller),
      onRemove: () => controller.removeItem(item.id),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeDefault),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Opacity(
        opacity: item.isAvailable ? 1 : 0.5,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyMedium?.color)),
            if (item.description != null && item.description!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(item.description!, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ],
            const SizedBox(height: 6),
            Row(children: [
              Text(PriceConverter.convertPrice(item.price),
                  style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyMedium?.color)),
              if (item.unavailableNote != null) ...[
                const SizedBox(width: 8),
                Flexible(child: Text(item.unavailableNote!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall,
                        color: item.state == 'sold_out' ? theme.primaryColor : theme.textTheme.bodyMedium?.color))),
              ],
            ]),
          ])),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          // With a photo, the stepper sits on its bottom edge so it stays tied to the item.
          if (item.image != null)
            SizedBox(
              width: 112,
              height: 96 + 20,
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
                ImageWidget(image: item.image!, width: 112, height: 96, radius: Dimensions.radiusDefault),
                Positioned(bottom: 0, child: stepper),
              ]),
            )
          else
            stepper,
        ]),
        ),
        // Not here right now, but another open branch has it.
        if (item.elsewhere != null) MenuElsewhereLine(elsewhere: item.elsewhere!, controller: controller),
      ]),
    );
  }

  void _add(BuildContext context, StoreController controller) {
    if (!controller.needsCartSwitch(controller.store!.id!)) {
      controller.addItem(item);
      return;
    }
    Get.dialog(AlertDialog(
      title: Text('start_new_cart'.tr),
      content: Text('start_new_cart_hint'.tr),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
        TextButton(
          onPressed: () {
            Get.back();
            controller.clearCart();
            controller.addItem(item);
          },
          child: Text('start_new_cart_confirm'.tr, style: TextStyle(color: Theme.of(context).primaryColor)),
        ),
      ],
    ));
  }
}

class _CartBar extends StatelessWidget {
  final int count;
  final double subtotal;
  const _CartBar({required this.count, required this.subtotal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.primaryColor,
      elevation: 8,
      shadowColor: theme.primaryColor.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(Dimensions.radiusOverLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimensions.radiusOverLarge),
        onTap: () => Get.to(() => const StoreCheckoutScreen()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(20)),
              child: Text('$count', style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeDefault)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('view_cart'.tr, style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeLarge))),
            Text(PriceConverter.convertPrice(subtotal), style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeLarge)),
          ]),
        ),
      ),
    );
  }
}
