import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_model.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_search_screen.dart';
import 'package:ride_sharing_user_app/features/store/widgets/shop_widgets.dart';
import 'package:ride_sharing_user_app/features/store/widgets/store_branch_widgets.dart';
import 'package:ride_sharing_user_app/features/store/widgets/store_widgets.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// A shop or supermarket: walk in, search, pick an aisle, take from the shelves.
/// (Restaurants keep the menu list in StoreMenuScreen.)
class ShopView extends StatefulWidget {
  final String? initialQuery;
  const ShopView({super.key, this.initialQuery});

  @override
  State<ShopView> createState() => _ShopViewState();
}

/// Products matching every word of a search, with their aisle.
List<({MenuItem item, String aisle})> matchProducts(List<MenuSection> menu, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return [];
  return [
    for (final s in menu)
      for (final i in s.items)
        if (words.every('${i.name} ${i.description ?? ''} ${s.name}'.toLowerCase().contains)) (item: i, aisle: s.name),
  ];
}

class _ShopViewState extends State<ShopView> {
  late final TextEditingController _search = TextEditingController(text: widget.initialQuery ?? '');
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? '';
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.cardColor,
      bottomNavigationBar: const ShopBasketBar(),
      body: GetBuilder<StoreController>(builder: (c) {
        final StoreModel? store = c.store;
        if (store == null) return const SizedBox.shrink();
        final List<MenuSection> aisles = c.menu.where((s) => s.items.isNotEmpty).toList();
        final results = matchProducts(c.menu, _query);
        return CustomScrollView(slivers: [
          _ShopHeader(store: store),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SearchHeader(
              child: _SearchField(
                controller: _search,
                hint: 'shop_search_in'.trParams({'store': store.name ?? ''}),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
              color: theme.cardColor,
            ),
          ),
          if (_query.isNotEmpty) ...[
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall, Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall),
              child: Text(results.length == 1 ? 'shop_one_result'.tr : 'shop_n_results'.trParams({'n': '${results.length}'}),
                  style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            )),
            if (results.isEmpty)
              SliverToBoxAdapter(child: _NotHere(query: _query, store: store))
            else
              _ProductGrid(products: results, storeOpen: store.openNow),
          ] else ...[
            SliverToBoxAdapter(child: _StoreFacts(store: store)),
            SliverToBoxAdapter(child: StoreBranchBanner(controller: c)),
            if (c.menuLoading)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())))
            else if (aisles.isEmpty)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('menu_empty'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(color: theme.hintColor)),
              ))
            else ...[
              // The aisles, at a glance.
              SliverToBoxAdapter(child: _Title(text: 'shop_aisles'.tr)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                sliver: SliverGrid.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: Dimensions.paddingSizeSmall,
                  crossAxisSpacing: Dimensions.paddingSizeSmall,
                  childAspectRatio: 0.95,
                  children: [
                    for (int i = 0; i < aisles.length; i++)
                      _AisleTile(section: aisles[i], onTap: () => Get.to(() => AisleScreen(aisles: aisles, index: i))),
                  ],
                ),
              ),
              // Then each aisle's shelf.
              for (int i = 0; i < aisles.length; i++) ...[
                SliverToBoxAdapter(child: _Title(
                  text: aisles[i].name,
                  icon: aisleStyle(aisles[i].name).icon,
                  color: aisleStyle(aisles[i].name).color,
                  onSeeAll: () => Get.to(() => AisleScreen(aisles: aisles, index: i)),
                  count: aisles[i].items.length,
                )),
                SliverToBoxAdapter(child: SizedBox(
                  height: 204,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                    itemCount: aisles[i].items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: Dimensions.paddingSizeSmall),
                    itemBuilder: (_, k) => ShopProductCard(item: aisles[i].items[k], aisle: aisles[i].name, storeOpen: store.openNow, width: 148),
                  ),
                )),
              ],
            ],
          ],
          const SliverToBoxAdapter(child: SizedBox(height: Dimensions.paddingSizeExtraLarge * 2)),
        ]);
      }),
    );
  }
}

/// The shop front: cover or a dark band, the logo, the name, open or not.
class _ShopHeader extends StatelessWidget {
  final StoreModel store;
  const _ShopHeader({required this.store});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      expandedHeight: 168,
      backgroundColor: theme.scaffoldBackgroundColor,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(store.name ?? '', style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeLarge)),
      actions: [
        if (store.link != null)
          IconButton(tooltip: 'store_share'.tr, icon: const Icon(Icons.share_rounded, color: Colors.white), onPressed: () => shareStoreLink(store)),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Stack(fit: StackFit.expand, children: [
          if (store.cover != null) ImageWidget(image: store.cover!, fit: BoxFit.cover),
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: store.cover != null ? [Colors.black54, Colors.black26, Colors.black87] : [theme.scaffoldBackgroundColor, theme.scaffoldBackgroundColor],
          ))),
          Positioned(
            left: Dimensions.paddingSizeDefault, right: Dimensions.paddingSizeDefault, bottom: Dimensions.paddingSizeDefault,
            child: Row(children: [
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white, width: 2)),
                child: StoreLogo(url: store.logo, size: 56, isShop: true),
              ),
              const SizedBox(width: Dimensions.paddingSize),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(store.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeExtraLarge)),
                const SizedBox(height: 2),
                Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: store.openNow ? const Color(0xFF22C55E) : Colors.white54, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(
                    store.openNow
                        ? (store.closesAt != null ? '${'open_until'.tr} ${store.closesAt}' : 'open_now'.tr)
                        : (store.opensAt != null ? '${'closed_opens_at'.tr} ${store.opensAt}' : 'closed_now'.tr),
                    style: textMedium.copyWith(color: Colors.white.withValues(alpha: 0.9), fontSize: Dimensions.fontSizeSmall),
                  )),
                ]),
              ])),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Delivery time, distance, minimum, and a word when it is closed.
class _StoreFacts extends StatelessWidget {
  final StoreModel store;
  const _StoreFacts({required this.store});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    Widget fact(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: theme.hintColor),
          const SizedBox(width: 4),
          Text(text, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color)),
        ]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 14, runSpacing: 6, children: [
          fact(Icons.timer_outlined, '${store.prepMinutes} ${'min'.tr}'),
          if (store.distanceKm != null) fact(Icons.place_outlined, '${store.distanceKm!.toStringAsFixed(1)} km'),
          // How to have it: delivery (unless turned off) and collect.
          if (store.ways.contains('delivery')) fact(Icons.delivery_dining_rounded, 'order_way_delivery'.tr),
          if (store.offersPickup) fact(Icons.shopping_bag_rounded, 'order_way_pickup'.tr),
          if (store.rating != null) fact(Icons.star_rounded, '${store.rating!.toStringAsFixed(1)} (${store.ratingCount})'),
          if (store.minOrderAmount > 0) fact(Icons.shopping_bag_outlined, '${'minimum'.tr} ${PriceConverter.convertPrice(store.minOrderAmount)}'),
        ]),
        if (!store.openNow)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: Dimensions.paddingSizeSmall),
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(shopRadius)),
            child: Text('store_closed_browse_only'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color)),
          ),
      ]),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onSeeAll;
  final int? count;
  const _Title({required this.text, this.icon, this.color, this.onSeeAll, this.count});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeLarge, Dimensions.paddingSizeSmall, Dimensions.paddingSizeSmall),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, size: 20, color: color), const SizedBox(width: 6)],
        Expanded(child: Text(text, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color))),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: Text(count != null ? 'shop_see_all_n'.trParams({'n': '$count'}) : 'see_all'.tr,
                style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
          ),
      ]),
    );
  }
}

class _AisleTile extends StatelessWidget {
  final MenuSection section;
  final VoidCallback onTap;
  const _AisleTile({required this.section, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final style = aisleStyle(section.name);
    return Material(
      color: style.color.withValues(alpha: Get.isDarkMode ? 0.2 : 0.09),
      borderRadius: BorderRadius.circular(shopRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(shopRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: style.color, borderRadius: BorderRadius.circular(10)),
              child: Icon(style.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 6),
            Text(section.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, height: 1.15, color: theme.textTheme.bodyLarge?.color)),
            Text('shop_n_products'.trParams({'n': '${section.items.length}'}),
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
          ]),
        ),
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  final List<({MenuItem item, String aisle})> products;
  final bool storeOpen;
  const _ProductGrid({required this.products, required this.storeOpen});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: Dimensions.paddingSizeSmall, crossAxisSpacing: Dimensions.paddingSizeSmall, mainAxisExtent: 226),
        delegate: SliverChildBuilderDelegate(
          (_, i) => ShopProductCard(item: products[i].item, aisle: products[i].aisle, storeOpen: storeOpen),
          childCount: products.length,
        ),
      ),
    );
  }
}

/// Nothing here for the search: say so, and offer every other store.
class _NotHere extends StatelessWidget {
  final String query;
  final StoreModel store;
  const _NotHere({required this.query, required this.store});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
      child: Column(children: [
        Icon(Icons.search_off_rounded, size: 48, color: theme.hintColor.withValues(alpha: 0.6)),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Text('shop_not_here'.trParams({'query': query, 'store': store.name ?? ''}), textAlign: TextAlign.center,
            style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyMedium?.color)),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        OutlinedButton.icon(
          onPressed: () => Get.to(() => StoreSearchScreen(initialQuery: query)),
          icon: const Icon(Icons.travel_explore_rounded, size: 18),
          label: Text('shop_search_everywhere'.tr),
          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shopRadius))),
        ),
      ]),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, v, __) => v.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'clear'.tr,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                    FocusScope.of(context).unfocus();
                  },
                ),
        ),
        filled: true,
        fillColor: theme.hintColor.withValues(alpha: 0.08),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(shopRadius), borderSide: BorderSide.none),
      ),
    );
  }
}

class _SearchHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Color color;
  _SearchHeader({required this.child, required this.color});

  @override
  double get minExtent => 68;
  @override
  double get maxExtent => 68;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(
        color: color,
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 10, Dimensions.paddingSizeDefault, 10),
        child: child,
      );

  @override
  bool shouldRebuild(covariant _SearchHeader old) => old.child != child || old.color != color;
}

/// One aisle, all of it: the other aisles a tap away, a search, the products in a grid.
class AisleScreen extends StatefulWidget {
  final List<MenuSection> aisles;
  final int index;
  const AisleScreen({super.key, required this.aisles, required this.index});

  @override
  State<AisleScreen> createState() => _AisleScreenState();
}

class _AisleScreenState extends State<AisleScreen> {
  late int _index = widget.index;
  String _query = '';
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MenuSection aisle = widget.aisles[_index];
    final style = aisleStyle(aisle.name);
    return Scaffold(
      backgroundColor: theme.cardColor,
      bottomNavigationBar: const ShopBasketBar(),
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Row(children: [
          Icon(style.icon, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(aisle.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeLarge))),
        ]),
      ),
      body: GetBuilder<StoreController>(builder: (c) {
        final bool open = c.store?.openNow ?? false;
        final List<({MenuItem item, String aisle})> products = _query.isEmpty
            ? [for (final i in aisle.items) (item: i, aisle: aisle.name)]
            : matchProducts([aisle], _query);
        return CustomScrollView(slivers: [
          // Switch aisle without going back.
          SliverToBoxAdapter(child: SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 10, Dimensions.paddingSizeDefault, 6),
              itemCount: widget.aisles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = aisleStyle(widget.aisles[i].name);
                final bool on = i == _index;
                return ChoiceChip(
                  avatar: Icon(s.icon, size: 16, color: on ? Colors.white : s.color),
                  label: Text(widget.aisles[i].name),
                  selected: on,
                  showCheckmark: false,
                  selectedColor: s.color,
                  labelStyle: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: on ? Colors.white : theme.textTheme.bodyLarge?.color),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onSelected: (_) => setState(() {
                    _index = i;
                    _query = '';
                    _search.clear();
                  }),
                );
              },
            ),
          )),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 4, Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall),
            child: _SearchField(
              controller: _search,
              hint: 'shop_search_aisle'.trParams({'aisle': aisle.name}),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          )),
          if (products.isEmpty)
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text('shop_nothing_in_aisle'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(color: theme.hintColor)),
            ))
          else
            _ProductGrid(products: products, storeOpen: open),
          const SliverToBoxAdapter(child: SizedBox(height: Dimensions.paddingSizeExtraLarge * 2)),
        ]);
      }),
    );
  }
}
