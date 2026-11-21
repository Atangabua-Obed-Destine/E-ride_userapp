import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_booking_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_cart_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_order_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_bookings_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_cart_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_service_widgets.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_orders_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_chats_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_item_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_shop_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_sell_choice_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/my_market_shop_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_partner_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_venue_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// E-Ride Market: items near the rider, by category, from the shops they follow,
/// or by search. "Sell" opens the rider's own shop (or the way to open one).
class MarketHomeScreen extends StatefulWidget {
  /// Opens on a search already typed (from Home's smart search: "phone").
  final String? query;
  const MarketHomeScreen({super.key, this.query});

  @override
  State<MarketHomeScreen> createState() => _MarketHomeScreenState();
}

class _MarketHomeScreenState extends State<MarketHomeScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) Get.find<MarketController>().loadMore();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final market = Get.find<MarketController>();
      // Every visit starts from all items.
      market.resetForEntry();
      _search.clear();
      if ((widget.query ?? '').trim().isNotEmpty) {
        _search.text = widget.query!.trim();
        market.query = _search.text;
      }
      market.loadMeta(force: true).then((m) => Get.find<MarketOrderController>().takeCounts(m));
      market.loadFeed();
      Get.find<MarketCartController>().load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => Get.find<MarketController>().setQuery(value));
  }

  Future<void> _sell() async {
    final market = Get.find<MarketController>();
    final meta = await market.loadMeta(force: true);
    if (meta?.myShop != null) {
      Get.to(() => const MyMarketShopScreen());
    } else {
      // Something I own, or a shop: no conditions either way.
      Get.to(() => const MarketSellChoiceScreen());
    }
  }

  @override
  Widget build(BuildContext context) => MarketChips(child: Builder(builder: _chipsBuild));

  Widget _chipsBuild(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        foregroundColor: theme.textTheme.bodyLarge?.color,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(children: [
          Text('E-Ride ', style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.primaryColor)),
          Text('market'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
        ]),
        actions: [
          GetBuilder<MarketOrderController>(builder: (orders) => IconButton(
            tooltip: 'market_my_orders'.tr,
            onPressed: () async {
              await Get.to(() => const MarketOrdersScreen());
              Get.find<MarketController>().loadMeta(force: true).then(orders.takeCounts);
            },
            icon: Badge(isLabelVisible: orders.buyingAction > 0, label: Text('${orders.buyingAction}'), child: const Icon(Icons.receipt_long_outlined)),
          )),
          GetBuilder<MarketBookingController>(builder: (bookings) => IconButton(
            tooltip: 'market_my_bookings'.tr,
            onPressed: () async {
              await Get.to(() => const MarketMyBookingsScreen());
              Get.find<MarketController>().loadMeta(force: true).then(bookings.takeCounts);
            },
            icon: Badge(isLabelVisible: bookings.clientAction > 0, label: Text('${bookings.clientAction}'), child: const Icon(Icons.event_note_outlined)),
          )),
          GetBuilder<MarketCartController>(builder: (cart) => IconButton(
            tooltip: 'market_cart'.tr,
            onPressed: () => Get.to(() => const MarketCartScreen()),
            icon: Badge(isLabelVisible: cart.count > 0, label: Text('${cart.count}'), child: const Icon(Icons.shopping_cart_outlined)),
          )),
          GetBuilder<MarketController>(builder: (market) {
            final unread = market.meta?.unread ?? 0;
            return IconButton(
              tooltip: 'market_chats'.tr,
              onPressed: () async {
                await Get.to(() => const MarketChatsScreen());
                market.loadMeta(force: true);
              },
              icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.chat_bubble_outline_rounded)),
            );
          }),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: GetBuilder<MarketController>(builder: (m) => FloatingActionButton.extended(
        onPressed: _sell,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        icon: Badge(
          isLabelVisible: m.meta?.myShop != null && (m.meta?.sellingNew ?? 0) > 0,
          label: Text('${m.meta?.sellingNew ?? 0}'),
          child: const Icon(Icons.storefront_rounded),
        ),
        label: Text((m.meta?.myShop == null ? 'market_sell' : (m.meta!.myShop!.isPrivate ? 'market_my_items' : 'market_my_shop')).tr),
      )),
      body: GetBuilder<MarketController>(builder: (market) {
        final categories = market.meta?.categories ?? const <String>[];
        return RefreshIndicator(
          onRefresh: () async {
            await market.loadMeta(force: true);
            await market.loadFeed();
          },
          child: CustomScrollView(controller: _scroll, physics: const AlwaysScrollableScrollPhysics(), slivers: [
            SliverToBoxAdapter(child: Container(
              color: theme.cardColor,
              padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 4, Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall),
              child: Row(children: [Expanded(child: TextField(
                controller: _search,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  _debounce?.cancel();
                  market.setQuery(v);
                },
                decoration: InputDecoration(
                  hintText: 'market_search_hint'.tr,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () {
                    _search.clear();
                    market.setQuery('');
                  }),
                  isDense: true,
                  filled: true,
                  fillColor: theme.hintColor.withValues(alpha: 0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              )),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: market.extraFilters > 0,
                  label: Text('${market.extraFilters}'),
                  child: IconButton.outlined(
                    tooltip: 'market_filters'.tr,
                    onPressed: () => Get.bottomSheet(const _FilterSheet(), isScrollControlled: true),
                    style: IconButton.styleFrom(
                      side: BorderSide(color: market.extraFilters > 0 ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.3)),
                      foregroundColor: market.extraFilters > 0 ? theme.primaryColor : theme.textTheme.bodyLarge?.color,
                    ),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ),
              ]),
            )),
            SliverToBoxAdapter(child: SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: 8),
                children: [
                  _Chip(label: 'market_all'.tr, selected: market.category == null, onTap: () => market.setCategory(null)),
                  for (final c in categories)
                    _Chip(label: marketCategory(c), selected: market.category == c,
                        onTap: () => market.setCategory(market.category == c ? null : c)),
                ],
              ),
            )),
            // Services: the kinds, and "comes to me".
            if (market.category == 'services')
              SliverToBoxAdapter(child: SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault, 8),
                  children: [
                    Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(
                      avatar: const Icon(Icons.home_outlined, size: 16),
                      label: Text('market_comes_to_me'.tr),
                      selected: market.comesToMe,
                      onSelected: market.setComesToMe,
                    )),
                    for (final k in market.meta?.serviceRules.kinds ?? const MarketServiceRules().kinds)
                      Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                        avatar: Icon(marketServiceKindIcon(k), size: 16),
                        label: Text('market_sk_$k'.tr),
                        selected: market.serviceKind == k,
                        showCheckmark: false,
                        onSelected: (on) => market.setServiceKind(on ? k : null),
                      )),
                  ],
                ),
              )),
            if (market.extraFilters > 0)
              SliverToBoxAdapter(child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault, 8),
                  children: [
                    if (market.kind == 'wholesale')
                      _ActiveFilter(label: 'market_wholesale_offers'.tr, onRemove: () => market.setKind('retail')),
                    if (market.verifiedOnly)
                      _ActiveFilter(label: 'market_verified_shops'.tr, onRemove: () => market.setVerifiedOnly(false)),
                    if (market.followingOnly)
                      _ActiveFilter(label: 'market_shops_i_follow'.tr, onRemove: () => market.setFollowingOnly(false)),
                    if (market.auctionsOnly)
                      _ActiveFilter(label: 'market_auctions'.tr, onRemove: () => market.setAuctionsOnly(false)),
                    if (market.sellerKind != null)
                      _ActiveFilter(label: 'market_sold_by_${market.sellerKind}'.tr, onRemove: () => market.setSellerKind(null)),
                    TextButton(onPressed: market.clearFilters, child: Text('market_clear_all'.tr)),
                  ],
                ),
              )),
            if (market.followedShops.isNotEmpty && !market.anyFilter)
              SliverToBoxAdapter(child: SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                  itemCount: market.followedShops.length,
                  separatorBuilder: (_, __) => const SizedBox(width: Dimensions.paddingSizeDefault),
                  itemBuilder: (_, i) {
                    final s = market.followedShops[i];
                    return InkWell(
                      onTap: () => Get.to(() => MarketShopScreen(slug: s.slug)),
                      child: SizedBox(width: 64, child: Column(children: [
                        MarketShopAvatar(name: s.name, logo: s.logo, size: 56),
                        const SizedBox(height: 4),
                        Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                            style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.textTheme.bodyLarge?.color)),
                      ])),
                    );
                  },
                ),
              )),
            // E-Ride partner stores: what they have for the search, or the stores themselves.
            if (market.query.trim().length >= 2)
              SliverToBoxAdapter(child: MarketPartnerMatches(query: market.query.trim()))
            else if (!market.anyFilter) ...[
              const SliverToBoxAdapter(child: MarketPartnerStores()),
              // Markets (Bamenda Main Market...): find a shed and walk there.
              const SliverToBoxAdapter(child: MarketVenuesRow()),
            ],
            if (market.loading && market.items.isEmpty)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
            else if (market.failed && market.items.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: MarketEmpty(
                icon: Icons.wifi_off_rounded, title: 'market_load_failed'.tr, action: 'retry'.tr, onAction: market.loadFeed))
            else if (market.items.isEmpty && market.anyFilter)
              SliverFillRemaining(hasScrollBody: false, child: MarketEmpty(
                icon: Icons.filter_alt_off_outlined,
                title: 'market_no_match'.tr,
                body: 'market_no_match_body'.tr,
                action: 'market_see_everything'.tr,
                onAction: () {
                  _search.clear();
                  market.clearFilters();
                },
              ))
            else if (market.items.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: MarketEmpty(
                icon: Icons.storefront_outlined,
                title: 'market_feed_empty'.tr,
                body: 'market_feed_empty_body'.tr,
                action: 'market_sell'.tr,
                onAction: _sell,
              ))
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall, Dimensions.paddingSizeDefault, 0),
                sliver: SliverToBoxAdapter(child: MarketScamNotice(text: 'market_scam_notice_short'.tr)),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.70),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => MarketItemCard(item: market.items[i], onTap: () => Get.to(() => MarketItemScreen(code: market.items[i].code, initial: market.items[i]))),
                    childCount: market.items.length,
                  ),
                ),
              ),
              if (market.loadingMore)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(bottom: 24), child: Center(child: CircularProgressIndicator()))),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ]),
        );
      }),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: theme.primaryColor,
        labelStyle: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: selected ? Colors.white : theme.textTheme.bodyLarge?.color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: selected ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.25)),
      ),
    );
  }
}

/// An active filter, with × to remove it.
class _ActiveFilter extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveFilter({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
        onDeleted: onRemove,
        deleteIconColor: theme.primaryColor,
        deleteButtonTooltipMessage: 'market_remove_filter'.tr,
        backgroundColor: theme.primaryColor.withValues(alpha: 0.08),
        side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

/// The filters that are not categories: wholesale offers, verified shops, shops I follow.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final MarketController _market = Get.find<MarketController>();
  late bool _wholesale = _market.kind == 'wholesale';
  late bool _verified = _market.verifiedOnly;
  late bool _following = _market.followingOnly;
  late bool _auctions = _market.auctionsOnly;
  late String? _seller = _market.sellerKind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    Widget toggle(String title, String hint, IconData icon, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
          value: value,
          onChanged: onChanged,
          contentPadding: EdgeInsets.zero,
          secondary: Icon(icon, color: theme.primaryColor),
          title: Text(title, style: textSemiBold.copyWith(color: textColor)),
          subtitle: Text(hint, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        );
    return Container(
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 12, Dimensions.paddingSizeLarge, Dimensions.paddingSizeLarge),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3)))),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        Text('market_filters'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor)),
        const SizedBox(height: 4),
        Text('market_filters_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        const SizedBox(height: 8),
        toggle('market_wholesale_offers'.tr, 'market_wholesale_offers_hint'.tr, Icons.inventory_2_outlined, _wholesale, (v) => setState(() => _wholesale = v)),
        toggle('market_verified_shops'.tr, 'market_verified_shops_hint'.tr, Icons.verified_outlined, _verified, (v) => setState(() => _verified = v)),
        toggle('market_shops_i_follow'.tr, 'market_shops_i_follow_hint'.tr, Icons.favorite_border_rounded, _following, (v) => setState(() => _following = v)),
        toggle('market_auctions'.tr, 'market_auctions_hint'.tr, Icons.gavel_rounded, _auctions, (v) => setState(() => _auctions = v)),
        const SizedBox(height: 8),
        Text('market_sold_by'.tr, style: textSemiBold.copyWith(color: textColor)),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'all', label: Text('market_all'.tr)),
            ButtonSegment(value: 'private', icon: const Icon(Icons.person_outline_rounded, size: 16), label: Text('market_people'.tr)),
            ButtonSegment(value: 'shop', icon: const Icon(Icons.storefront_outlined, size: 16), label: Text('market_shops'.tr)),
          ],
          selected: {_seller ?? 'all'},
          onSelectionChanged: (v) => setState(() => _seller = v.first == 'all' ? null : v.first),
        )),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        Row(children: [
          Expanded(child: SizedBox(height: 50, child: OutlinedButton(
            onPressed: () => setState(() {
              _wholesale = _verified = _following = _auctions = false;
              _seller = null;
            }),
            child: Text('market_clear_all'.tr),
          ))),
          const SizedBox(width: 10),
          Expanded(child: SizedBox(height: 50, child: FilledButton(
            onPressed: () {
              _market.applyFilters(wholesale: _wholesale, verified: _verified, following: _following, auctions: _auctions, seller: _seller);
              Navigator.of(context).pop();
            },
            child: Text('market_show_items'.tr),
          ))),
        ]),
      ])),
    );
  }
}
