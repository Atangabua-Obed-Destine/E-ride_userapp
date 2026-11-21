import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_model.dart';
import 'package:ride_sharing_user_app/features/store/domain/services/store_service_interface.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_list_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_menu_screen.dart';
import 'package:ride_sharing_user_app/features/store/widgets/shop_widgets.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// E-Ride partner stores (Food & Shops) inside the Market: the stores when
/// nothing is searched, the products that match when something is.

bool get _partnersOn => Get.find<ConfigController>().config?.storeOrderingStatus ?? false;

void _openStore(StoreModel store, {String? query}) {
  Get.find<StoreController>().openStore(store);
  Get.to(() => StoreMenuScreen(query: query));
}

Widget _header(BuildContext context, String title, String subtitle, {VoidCallback? onAll}) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall, 4, 6),
    child: Row(children: [
      Icon(Icons.verified_rounded, size: 18, color: theme.primaryColor),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
      ])),
      if (onAll != null) TextButton(onPressed: onAll, child: Text('see_all'.tr)),
    ]),
  );
}

/// The partner stores near the customer, open ones first.
class MarketPartnerStores extends StatefulWidget {
  const MarketPartnerStores({super.key});

  @override
  State<MarketPartnerStores> createState() => _MarketPartnerStoresState();
}

class _MarketPartnerStoresState extends State<MarketPartnerStores> {
  @override
  void initState() {
    super.initState();
    if (_partnersOn && Get.find<StoreController>().stores == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<StoreController>().loadStores());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_partnersOn) return const SizedBox.shrink();
    return GetBuilder<StoreController>(builder: (c) {
      final List<StoreModel> stores = [...(c.stores ?? const <StoreModel>[])]
        ..sort((a, b) => (b.openNow ? 1 : 0) - (a.openNow ? 1 : 0));
      if (stores.isEmpty) return const SizedBox.shrink();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(context, 'mkp_stores_title'.tr, 'mkp_stores_sub'.tr, onAll: () => Get.to(() => const StoreListScreen())),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
            itemCount: stores.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _StoreCard(store: stores[i]),
          ),
        ),
      ]);
    });
  }
}

class _StoreCard extends StatelessWidget {
  final StoreModel store;
  const _StoreCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color kind = store.isShop ? const Color(0xFF15803D) : const Color(0xFFE8590C);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(shopRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(shopRadius),
        onTap: () => _openStore(store),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(shopRadius), border: Border.all(color: theme.hintColor.withValues(alpha: 0.15))),
          child: Opacity(
            opacity: store.openNow ? 1 : 0.6,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 44, height: 44,
                  child: store.logo != null
                      ? ImageWidget(image: store.logo!, fit: BoxFit.cover)
                      : Container(color: kind.withValues(alpha: 0.1),
                          child: Icon(store.isShop ? Icons.local_grocery_store_rounded : Icons.restaurant_rounded, color: kind, size: 24)),
                ),
              ),
              const SizedBox(height: 6),
              Text(store.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: 2),
              Row(children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: store.openNow ? const Color(0xFF12A150) : theme.hintColor, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Flexible(child: Text(
                  '${store.isShop ? 'shop_kind_shop'.tr : 'shop_kind_restaurant'.tr} · ${store.openNow ? 'open_now'.tr : 'closed_now'.tr}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// What the partner stores have for a Market search: one card per product.
class MarketPartnerMatches extends StatefulWidget {
  final String query;
  const MarketPartnerMatches({super.key, required this.query});

  @override
  State<MarketPartnerMatches> createState() => _MarketPartnerMatchesState();
}

class _MarketPartnerMatchesState extends State<MarketPartnerMatches> {
  List<StoreSearchGroup> _groups = const [];
  String _for = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MarketPartnerMatches old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _load();
  }

  Future<void> _load() async {
    final String q = widget.query.trim();
    if (!_partnersOn || q.length < 2 || q == _for) return;
    _for = q;
    final here = Get.find<StoreController>().here;
    final Response r = await Get.find<StoreServiceInterface>().searchStores(q, latitude: here.lat, longitude: here.lng);
    if (!mounted || _for != q) return;
    setState(() {
      _groups = r.statusCode == 200 && r.body is Map
          ? (((r.body['data'] ?? {})['results'] as List?) ?? []).whereType<Map>()
              .map((e) => StoreSearchGroup.fromJson(Map<String, dynamic>.from(e))).where((g) => g.items.isNotEmpty).toList()
          : const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_groups.isEmpty || _for != widget.query.trim()) return const SizedBox.shrink();
    final products = [for (final g in _groups) for (final item in g.items) (group: g, item: item)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header(context, 'mkp_matches_title'.tr, 'mkp_matches_sub'.tr),
      SizedBox(
        height: 206,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _ProductCard(group: products[i].group, item: products[i].item, query: _for),
        ),
      ),
    ]);
  }
}

class _ProductCard extends StatelessWidget {
  final StoreSearchGroup group;
  final MenuItem item;
  final String query;
  const _ProductCard({required this.group, required this.item, required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final StoreModel store = group.store;
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(shopRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openStore(store, query: query),
        child: Container(
          width: 140,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(shopRadius), border: Border.all(color: theme.hintColor.withValues(alpha: 0.15))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(height: 100, width: double.infinity, child: ShopProductImage(item: item, aisle: group.sections[item.id] ?? '', iconSize: 34)),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(PriceConverter.convertPrice(item.price), style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.primaryColor)),
                Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color, height: 1.2)),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(store.isShop ? Icons.local_grocery_store_rounded : Icons.restaurant_rounded, size: 12, color: theme.hintColor),
                  const SizedBox(width: 3),
                  Expanded(child: Text(store.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor))),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
