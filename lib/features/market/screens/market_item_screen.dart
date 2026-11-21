import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_home_screen.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_cart_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_chat_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_cart_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_chat_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_item_form_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_posted_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_shop_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_order_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_auction_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_order_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_sell_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_service_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_book_sheet.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_booking_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_quote_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// One item: photos, price, the shop, what it is, how it gets to you, the scam
/// notice, and "Chat with the seller". The seller sees edit, share and sold out instead.
class MarketItemScreen extends StatefulWidget {
  final String code;
  final MarketItem? initial;
  const MarketItemScreen({super.key, required this.code, this.initial});

  @override
  State<MarketItemScreen> createState() => _MarketItemScreenState();
}

class _MarketItemScreenState extends State<MarketItemScreen> {
  int _photo = 0;
  bool _opening = false;
  final PageController _pages = PageController();
  String? _colour;
  String? _size;
  int _qty = 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _pickColour(MarketItem item, MarketColour colour) {
    setState(() {
      _colour = colour.name;
      if (_size != null && item.stockFor(_colour, _size) < 1) _size = null;
      _qty = 1;
    });
    final photos = item.photos;
    final i = photos.indexWhere((p) => p.id == colour.photoId);
    if (i >= 0 && _pages.hasClients) _pages.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  /// Pieces left of the current choice (null while a needed option is not picked yet).
  int? _left(MarketItem item) {
    if (item.colours.isNotEmpty && _colour == null) return null;
    if (item.sizes.isNotEmpty && _size == null) return null;
    return item.stockFor(_colour, _size);
  }

  Future<void> _addToCart(MarketItem item) async {
    if (item.colours.isNotEmpty && _colour == null) return showCustomSnackBar('market_pick_colour'.tr);
    if (item.sizes.isNotEmpty && _size == null) return showCustomSnackBar('market_pick_size'.tr);
    final left = _left(item) ?? 0;
    if (left < 1) return showCustomSnackBar('market_choice_sold_out'.tr);
    final already = Get.find<MarketCartController>().choicePieces(item.code, _colour, _size);
    if (already >= left) return showCustomSnackBar('market_all_in_cart'.tr);
    final shop = item.shop!;
    final colourPhoto = item.colours.where((c) => c.name == _colour).map((c) => c.photo).firstWhere((p) => p != null, orElse: () => null);
    final cart = Get.find<MarketCartController>();
    final inCart = await cart.add(MarketCartLine(
      shopSlug: shop.slug, shopName: shop.name, shopLogo: shop.logo, itemCode: item.code, title: item.title,
      photo: colourPhoto ?? item.cover, colour: _colour, size: _size, price: item.price ?? 0,
      wholesalePrice: item.wholesalePrice, wholesaleMin: item.wholesaleMin, maxQty: left, qty: _qty.clamp(1, left - already),
    ));
    if (mounted) setState(() => _qty = 1);
    if (!mounted) return;
    await showMarketAddedSheet(item: item, shopSlug: shop.slug, choice: [if (_colour != null) _colour!, if (_size != null) _size!].join(' · '), qty: inCart);
  }

  @override
  void initState() {
    super.initState();
    Get.find<MarketCartController>().load();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final market = Get.find<MarketController>();
      market.loadMeta();
      final item = await market.loadItem(widget.code);
      if (item?.isAuction ?? widget.initial?.isAuction ?? false) market.loadBids(widget.code);
    });
  }

  Future<void> _chat(MarketItem item) async {
    if (_opening) return;
    final go = await showMarketSafetySheet(digital: item.isDigital, service: item.isService);
    if (!go) return;
    setState(() => _opening = true);
    final chatId = await Get.find<MarketChatController>().startChat(item.code);
    if (mounted) setState(() => _opening = false);
    if (chatId != null) Get.to(() => MarketChatScreen(chatId: chatId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GetBuilder<MarketController>(builder: (market) {
      final MarketItem? item = market.itemFor(widget.code) ?? widget.initial;
      if (item == null) {
        return Scaffold(
          appBar: AppBar(),
          body: market.itemLoading
              ? const Center(child: CircularProgressIndicator())
              : MarketEmpty(icon: Icons.remove_shopping_cart_outlined, title: market.itemError ?? 'market_item_gone'.tr),
        );
      }
      final full = market.itemFor(widget.code) != null;
      final photos = [...item.photos, if (item.photos.isEmpty && item.cover != null) MarketPhoto(id: 0, url: item.cover!)];
      final textColor = theme.textTheme.bodyLarge?.color;
      return Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
        body: CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: photos.isEmpty ? 0 : 340,
            pinned: true,
            backgroundColor: theme.cardColor,
            foregroundColor: textColor,
            // Round light backings so the icons stay visible over any photo.
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: IconButton(style: _onPhoto(theme), icon: const Icon(Icons.arrow_back), onPressed: () => Get.back()),
            ),
            actions: [
              if (!item.mine)
                GetBuilder<MarketCartController>(builder: (cart) => IconButton(
                  style: _onPhoto(theme),
                  tooltip: 'market_cart'.tr,
                  onPressed: () => Get.to(() => const MarketCartScreen()),
                  icon: Badge(isLabelVisible: cart.count > 0, label: Text('${cart.count}'), child: const Icon(Icons.shopping_cart_outlined)),
                )),
              IconButton(style: _onPhoto(theme), tooltip: 'market_share'.tr, icon: const Icon(Icons.share_outlined),
                  onPressed: () => shareMarketLink(item.link, item.title)),
              if (!item.mine && item.shop != null)
                PopupMenuButton<String>(
                color: Theme.of(context).cardColor,
                  style: _onPhoto(theme),
                  onSelected: (v) {
                    if (v == 'report') showMarketReportSheet(code: item.code, shopSlug: item.shop!.slug);
                    if (v == 'block') _confirmBlock(item.shop!);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'report', child: Text('market_report_item'.tr)),
                    PopupMenuItem(value: 'block', child: Text('market_block_shop'.tr)),
                  ],
                ),
            ],
            flexibleSpace: photos.isEmpty ? null : FlexibleSpaceBar(background: _Photos(
              photos: photos, index: _photo, controller: _pages, onChanged: (i) => setState(() => _photo = i))),
          ),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (item.mine && item.status != MarketItem.live) ...[
                _OwnerStatus(item: item),
                const SizedBox(height: Dimensions.paddingSizeDefault),
              ],
              Text(item.title, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor)),
              const SizedBox(height: 4),
              if (item.isService && item.service != null)
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Flexible(child: Text(marketServicePrice(item.price, item.service!.priceType),
                      style: textBold.copyWith(fontSize: Dimensions.fontSizeOverLarge, color: theme.primaryColor))),
                  const SizedBox(width: 8),
                  Icon(Icons.schedule_rounded, size: 16, color: theme.hintColor),
                  const SizedBox(width: 3),
                  Text('market_about_x'.trParams({'time': marketDuration(item.service!.durationMinutes)}),
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                ])
              else if (!item.isAuction)
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text(marketPrice(item.price), style: textBold.copyWith(fontSize: Dimensions.fontSizeOverLarge, color: theme.primaryColor)),
                  if (item.negotiable && item.price != null) ...[
                    const SizedBox(width: 8),
                    Text('market_open_to_offers'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                  ],
                ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (item.isService) const MarketServiceTag(),
                if (item.fromPrivateSeller && !item.isService) const MarketPrivateTag(),
                if (item.isService && item.service?.kind != null) _Pill(text: 'market_sk_${item.service!.kind}'.tr)
                else if (!item.isService) _Pill(text: item.isDigital ? 'market_digital'.tr : marketConditionLabel(item.condition, item.usedGrade)),
                if (item.digitalKind != null) _Pill(text: 'market_kind_${item.digitalKind}'.tr),
                if (item.category != null && !item.isService && !(item.isDigital && item.category == 'digital')) _Pill(text: marketCategory(item.category)),
                if (item.status == MarketItem.soldOut) _Pill(text: 'market_sold_out'.tr, strong: true),
              ]),
              const SizedBox(height: Dimensions.paddingSizeDefault),

              if (item.isAuction) ...[
                MarketAuctionPanel(item: item),
                const SizedBox(height: Dimensions.paddingSizeDefault),
              ],

              if (item.isService && item.service != null) ...[
                _ServicePanel(item: item, onBook: () => _book(item)),
                const SizedBox(height: Dimensions.paddingSizeDefault),
              ],

              if (!item.mine && item.orderable) ...[
                _InCart(code: item.code),
                GetBuilder<MarketCartController>(builder: (cart) => _OrderChoices(
                  item: item,
                  colour: _colour,
                  size: _size,
                  qty: _qty,
                  left: _left(item),
                  inCart: cart.choicePieces(item.code, _colour, _size),
                  onColour: (c) => _pickColour(item, c),
                  onSize: (v) => setState(() {
                    _size = v;
                    _qty = 1;
                  }),
                  onQty: (q) => setState(() => _qty = q),
                )),
                const SizedBox(height: Dimensions.paddingSizeDefault),
              ],

              if (item.shop != null) _ShopRow(item: item),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              if (item.fromPrivateSeller && !item.mine) ...[
                MarketPrivateExplainer(service: item.isService),
                const SizedBox(height: Dimensions.paddingSizeSmall),
              ],

              if (item.strongWarning) ...[const MarketDigitalWarning(), const SizedBox(height: Dimensions.paddingSizeSmall)],
              MarketScamNotice(text: item.isService ? 'market_scam_notice_service'.tr : null),

              if (item.description != null) ...[
                const SizedBox(height: Dimensions.paddingSizeLarge),
                Text((item.isService ? 'market_about_service' : 'market_about_item').tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
                const SizedBox(height: 6),
                Text(item.description!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, height: 1.5, color: textColor)),
              ],

              // Tags: tap one to see similar posts.
              if (item.tags.isNotEmpty) ...[
                const SizedBox(height: Dimensions.paddingSize),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final String t in item.tags)
                    ActionChip(
                      label: Text('#$t'),
                      onPressed: () => Get.to(() => MarketHomeScreen(query: t), preventDuplicates: false),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      side: BorderSide(color: Theme.of(context).hintColor.withValues(alpha: 0.3)),
                      labelStyle: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor),
                      visualDensity: VisualDensity.compact,
                    ),
                ]),
              ],

              if (item.isDigital && item.previews.isNotEmpty) ...[
                const SizedBox(height: Dimensions.paddingSizeLarge),
                Text('market_previews'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
                const SizedBox(height: 4),
                Text('market_previews_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                const SizedBox(height: 8),
                SizedBox(height: 150, child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: item.previews.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _openViewer(item.previews, i),
                    child: ImageWidget(image: item.previews[i].url, width: 110, height: 150, radius: 10, fit: BoxFit.cover),
                  ),
                )),
              ],

              if (!item.isDigital && !item.isService) ...[
                const SizedBox(height: Dimensions.paddingSizeLarge),
                Text('market_getting_it'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
                const SizedBox(height: 6),
                if (item.pickup) _Way(icon: Icons.storefront_outlined, text: 'market_way_pickup'.tr),
                if (item.erideDelivery) _Way(icon: Icons.delivery_dining_outlined, text: 'market_way_eride'.tr),
                if (item.sellerDelivers) _Way(icon: Icons.local_shipping_outlined, text: 'market_way_seller'.tr),
              ],

              if (!full && market.itemLoading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              const SizedBox(height: 100),
            ]),
          )),
        ]),
        bottomNavigationBar: SafeArea(child: Container(
          padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 10, Dimensions.paddingSizeDefault, 10),
          decoration: BoxDecoration(color: theme.cardColor, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))]),
          child: item.mine ? _OwnerActions(item: item) : (item.isService && item.service != null) ? Row(children: [
            SizedBox(width: 56, height: 52, child: OutlinedButton(
              onPressed: _opening ? null : () => _chat(item),
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              child: _opening
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.chat_bubble_outline_rounded, semanticLabel: 'market_chat_seller'.tr),
            )),
            const SizedBox(width: 10),
            Expanded(child: SizedBox(height: 52, child: FilledButton.icon(
              onPressed: item.service!.takingBookings && item.status == MarketItem.live ? () => _book(item) : null,
              icon: Icon(item.service!.isQuote ? Icons.request_quote_outlined : Icons.event_available_outlined),
              label: Text((!item.service!.takingBookings ? 'market_not_taking_bookings' : (item.service!.isQuote ? 'market_ask_quote' : 'market_book_time')).tr,
                  style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: item.service!.takingBookings ? Colors.white : null)),
            ))),
          ]) : (item.isAuction && (item.auction!.live || (item.auction!.won && item.auction!.orderId != null))) ? Row(children: [
            SizedBox(width: 56, height: 52, child: OutlinedButton(
              onPressed: _opening ? null : () => _chat(item),
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              child: _opening
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.chat_bubble_outline_rounded, semanticLabel: 'market_chat_seller'.tr),
            )),
            const SizedBox(width: 10),
            Expanded(child: SizedBox(height: 52, child: item.auction!.live
                ? FilledButton.icon(
                    // The highest bidder waits to be outbid (the server refuses a bid against yourself).
                    onPressed: item.auction!.leading ? null : () {
                      final reason = market.meta?.auctionRules.cannotBidReason;
                      if (reason != null) return showCustomSnackBar(reason);
                      showMarketBidSheet(item);
                    },
                    icon: Icon(item.auction!.leading ? Icons.trending_up_rounded : Icons.gavel_rounded,
                        color: item.auction!.leading ? const Color(0xFF166534) : null),
                    style: item.auction!.leading ? FilledButton.styleFrom(disabledBackgroundColor: const Color(0xFFDCFCE7)) : null,
                    label: Text((item.auction!.leading ? 'market_you_lead' : 'market_place_bid').tr,
                        style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: item.auction!.leading ? const Color(0xFF166534) : Colors.white)),
                  )
                : FilledButton.icon(
                    onPressed: () => Get.to(() => MarketOrderScreen(orderId: item.auction!.orderId!)),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text('market_open_my_order'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
                  ))),
          ]) : item.orderable ? Row(children: [
            SizedBox(width: 56, height: 52, child: OutlinedButton(
              onPressed: _opening ? null : () => _chat(item),
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              child: _opening
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.chat_bubble_outline_rounded, semanticLabel: 'market_chat_seller'.tr),
            )),
            const SizedBox(width: 10),
            Expanded(child: SizedBox(height: 52, child: GetBuilder<MarketCartController>(builder: (cart) => FilledButton.icon(
              onPressed: () => _addToCart(item),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: Text((cart.choicePieces(item.code, _colour, _size) > 0 ? 'market_add_more' : 'market_add_to_cart').tr,
                  style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
            )))),
          ]) : SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: item.status == MarketItem.live && !_opening ? () => _chat(item) : null,
              icon: _opening
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.chat_bubble_outline_rounded),
              label: Text((item.status == MarketItem.soldOut ? 'market_sold_out' : 'market_chat_seller').tr,
                  style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
            ),
          ),
        )),
      );
    });
  }

  /// Book a time (then the booking), or ask for a quote.
  Future<void> _book(MarketItem item) async {
    final reason = Get.find<MarketController>().meta?.serviceRules.cannotBookReason;
    if (reason != null) return showCustomSnackBar(reason);
    if (item.service!.isQuote) {
      Get.to(() => MarketQuoteScreen(item: item));
      return;
    }
    final booking = await showMarketBookSheet(itemCode: item.code, title: item.title, service: item.service, price: item.price);
    if (booking != null) Get.to(() => MarketBookingScreen(bookingId: booking.id, justSent: true));
  }

  void _openViewer(List<MarketPhoto> photos, int index) {
    Get.to(() => MarketPhotoViewer(photos: [for (final p in photos) p.url], initial: index));
  }

  Future<void> _confirmBlock(MarketItemShop shop) async {
    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text('market_block_shop'.tr),
      content: Text('market_block_shop_body'.trParams({'shop': shop.name})),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('cancel'.tr)),
        TextButton(onPressed: () => Get.back(result: true), child: Text('market_block'.tr)),
      ],
    ));
    if (ok == true && await Get.find<MarketController>().block(shop.slug, true) && mounted) Navigator.of(context).pop();
  }
}

ButtonStyle _onPhoto(ThemeData theme) => IconButton.styleFrom(
      backgroundColor: theme.cardColor.withValues(alpha: 0.85),
      foregroundColor: theme.textTheme.bodyLarge?.color,
    );

class _Photos extends StatelessWidget {
  final List<MarketPhoto> photos;
  final int index;
  final PageController? controller;
  final ValueChanged<int> onChanged;
  const _Photos({required this.photos, required this.index, required this.onChanged, this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      PageView.builder(
        controller: controller,
        itemCount: photos.length,
        onPageChanged: onChanged,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => Get.to(() => MarketPhotoViewer(photos: [for (final p in photos) p.url], initial: i)),
          child: ImageWidget(image: photos[i].url, fit: BoxFit.cover),
        ),
      ),
      if (photos.length > 1)
        Positioned(
          right: 12, bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
            child: Text('${index + 1}/${photos.length}', style: textMedium.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeSmall)),
          ),
        ),
    ]);
  }
}

/// Full screen photos with pinch to zoom.
class MarketPhotoViewer extends StatelessWidget {
  final List<String> photos;
  final int initial;
  const MarketPhotoViewer({super.key, required this.photos, this.initial = 0});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: PageView.builder(
        controller: PageController(initialPage: initial),
        itemCount: photos.length,
        itemBuilder: (_, i) => InteractiveViewer(maxScale: 4, child: Center(child: ImageWidget(image: photos[i], fit: BoxFit.contain))),
      ),
    );
  }
}

class _ShopRow extends StatelessWidget {
  final MarketItem item;
  const _ShopRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shop = item.shop!;
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Get.to(() => MarketShopScreen(slug: shop.slug)),
        child: Container(
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.hintColor.withValues(alpha: 0.15))),
          child: Row(children: [
            MarketShopAvatar(name: shop.name, logo: shop.logo, size: 44),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(shop.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color))),
                if (shop.verified) ...[const SizedBox(width: 4), const MarketVerifiedBadge()],
              ]),
              if (shop.isPrivate)
                Text([(item.isService ? 'market_independent' : 'market_private_seller').tr, if (shop.area != null) shop.area!].join(' · '),
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: marketPrivateFg))
              else
                Text(shop.verified ? 'market_verified_shop'.tr : (shop.area ?? 'market_not_verified'.tr),
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: shop.verified ? marketVerified : theme.hintColor)),
              if (item.shopOrders != null && (item.shopOrders!.ratingCount > 0 || item.shopOrders!.replyMinutes != null))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: MarketShopTrust(rating: item.shopOrders!.rating, ratingCount: item.shopOrders!.ratingCount,
                      orders: item.shopOrders!.ordersCompleted, replyMinutes: item.shopOrders!.replyMinutes),
                ),
            ])),
            if (!item.mine)
              TextButton(
                onPressed: () => marketFollowTap(slug: shop.slug, shopName: shop.name, following: item.following, notify: item.followNotify),
                child: Text((item.following ? 'market_following_on' : 'market_follow').tr),
              ),
            Icon(Icons.chevron_right_rounded, color: theme.hintColor),
          ]),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool strong;
  const _Pill({required this.text, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: strong ? theme.textTheme.bodyLarge?.color : theme.hintColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall,
          color: strong ? theme.cardColor : theme.textTheme.bodyLarge?.color)),
    );
  }
}

class _Way extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Way({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 20, color: theme.primaryColor),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color))),
      ]),
    );
  }
}

/// What the seller sees when their item is not live: why, and what to do.
class _OwnerStatus extends StatelessWidget {
  final MarketItem item;
  const _OwnerStatus({required this.item});

  @override
  Widget build(BuildContext context) {
    final bool soldOut = item.status == MarketItem.soldOut;
    final String body = item.status == MarketItem.blocked && item.blockedWord != null
        ? 'market_blocked_word'.trParams({'word': item.blockedWord!})
        : (item.statusNote ?? 'market_status_${item.status}_body'.tr);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall + 2),
      decoration: BoxDecoration(color: soldOut ? marketWarnBg : marketDangerBg, borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('market_status_${item.status}'.tr, style: textBold.copyWith(color: soldOut ? marketWarnFg : marketDangerFg)),
        const SizedBox(height: 2),
        Text(body, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: soldOut ? marketWarnFg : marketDangerFg, height: 1.4)),
      ]),
    );
  }
}

class _OwnerActions extends StatelessWidget {
  final MarketItem item;
  const _OwnerActions({required this.item});

  @override
  Widget build(BuildContext context) {
    final market = Get.find<MarketController>();
    final canEdit = item.status != MarketItem.removed;
    return Row(children: [
      Expanded(child: SizedBox(height: 50, child: OutlinedButton.icon(
        onPressed: canEdit ? () => Get.to(() => MarketItemFormScreen(item: item)) : null,
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text('market_edit'.tr),
      ))),
      const SizedBox(width: 8),
      if (item.isPublic)
        Expanded(child: SizedBox(height: 50, child: FilledButton.icon(
          onPressed: () => Get.to(() => MarketPostedScreen(item: item, justPosted: false)),
          icon: const Icon(Icons.share_outlined, size: 18),
          label: Text('market_share'.tr),
        ))),
      PopupMenuButton<String>(
                color: Theme.of(context).cardColor,
        onSelected: (v) async {
          if (v == 'sold') await market.setSoldOut(item.code, item.status != MarketItem.soldOut);
          if (v == 'delete') {
            final ok = await Get.dialog<bool>(AlertDialog(
              title: Text('market_delete_item'.tr),
              content: Text('market_delete_item_body'.tr),
              actions: [
                TextButton(onPressed: () => Get.back(result: false), child: Text('cancel'.tr)),
                TextButton(onPressed: () => Get.back(result: true), child: Text('market_delete'.tr)),
              ],
            ));
            if (ok == true && await market.deleteItem(item.code)) Get.back();
          }
        },
        itemBuilder: (_) => [
          if (item.status == MarketItem.live || item.status == MarketItem.soldOut)
            PopupMenuItem(value: 'sold', child: Text((item.status == MarketItem.soldOut ? 'market_back_in_stock' : 'market_mark_sold_out').tr)),
          PopupMenuItem(value: 'delete', child: Text('market_delete_item'.tr)),
        ],
      ),
    ]);
  }
}

/// Colour, size, quantity and the wholesale line, for an item a buyer can order.
class _OrderChoices extends StatelessWidget {
  final MarketItem item;
  final String? colour;
  final String? size;
  final int qty;
  final int? left;
  /// Pieces of the current choice already in the cart.
  final int inCart;
  final ValueChanged<MarketColour> onColour;
  final ValueChanged<String> onSize;
  final ValueChanged<int> onQty;
  const _OrderChoices({required this.item, required this.colour, required this.size, required this.qty, required this.left,
      this.inCart = 0, required this.onColour, required this.onSize, required this.onQty});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final label = textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor);
    final unit = item.unitPrice(qty);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (item.hasWholesale)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
          child: Row(children: [
            Icon(Icons.inventory_2_outlined, size: 18, color: textColor),
            const SizedBox(width: 8),
            Expanded(child: Text('market_wholesale_line'.trParams({'min': '${item.wholesaleMin}', 'price': PriceConverter.convertPrice(item.wholesalePrice!)}),
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor))),
          ]),
        ),
      if (item.colours.isNotEmpty) ...[
        Text.rich(TextSpan(children: [
          TextSpan(text: '${'market_colour'.tr}: ', style: label),
          TextSpan(text: colour ?? 'market_pick_one'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: colour == null ? theme.hintColor : textColor)),
        ])),
        const SizedBox(height: 8),
        SizedBox(height: 74, child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: item.colours.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final c = item.colours[i];
            final on = c.name == colour;
            final available = item.colourAvailable(c.name);
            return Semantics(
              button: true,
              selected: on,
              label: c.name,
              child: InkWell(
                onTap: available ? () => onColour(c) : null,
                borderRadius: BorderRadius.circular(12),
                child: Opacity(
                  opacity: available ? 1 : 0.4,
                  child: Container(
                    width: 62,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: on ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.25), width: on ? 2 : 1),
                    ),
                    child: Column(children: [
                      Expanded(child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                        child: c.photo != null
                            ? ImageWidget(image: c.photo!, width: 62, fit: BoxFit.cover)
                            : Container(color: theme.hintColor.withValues(alpha: 0.08), alignment: Alignment.center,
                                child: Text(c.name.characters.first.toUpperCase(), style: textBold.copyWith(color: textColor))),
                      )),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                        child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: textColor,
                                decoration: available ? null : TextDecoration.lineThrough)),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          },
        )),
        const SizedBox(height: Dimensions.paddingSizeDefault),
      ],
      if (item.sizes.isNotEmpty) ...[
        Text.rich(TextSpan(children: [
          TextSpan(text: '${'market_size'.tr}: ', style: label),
          TextSpan(text: size ?? 'market_pick_one'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: size == null ? theme.hintColor : textColor)),
        ])),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in item.sizes)
            Builder(builder: (_) {
              final on = v == size;
              final available = item.sizeAvailable(v, colour);
              return ChoiceChip(
                label: Text(v, style: textSemiBold.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: on ? theme.primaryColor : (available ? textColor : theme.hintColor),
                  decoration: available ? null : TextDecoration.lineThrough,
                )),
                selected: on,
                showCheckmark: false,
                onSelected: available ? (_) => onSize(v) : null,
                selectedColor: theme.primaryColor.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: BorderSide(color: on ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.3), width: on ? 2 : 1),
              );
            }),
        ]),
        const SizedBox(height: Dimensions.paddingSizeDefault),
      ],
      Row(children: [
        Text('market_quantity_short'.tr, style: label),
        const SizedBox(width: 12),
        MarketQtyStepper(value: qty, max: left == null ? 9999 : (left! - inCart < 1 ? 1 : left! - inCart), onChanged: onQty),
        const SizedBox(width: 12),
        Expanded(child: Text(
          left == null
              ? ''
              : (left! < 1 ? 'market_choice_sold_out'.tr : 'market_left'.trParams({'count': '$left'})),
          style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: left != null && left! < 1 ? marketDangerFg : const Color(0xFF15803D)),
        )),
      ]),
      if (inCart > 0)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Icon(Icons.shopping_cart_rounded, size: 15, color: theme.primaryColor),
            const SizedBox(width: 6),
            Expanded(child: Text(
              left != null && inCart >= left! ? 'market_choice_all_in_cart'.trParams({'count': '$inCart'}) : 'market_choice_in_cart'.trParams({'count': '$inCart'}),
              style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor),
            )),
          ]),
        ),
      if (qty > 1)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('$qty × ${PriceConverter.convertPrice(unit)} = ${PriceConverter.convertPrice(unit * qty)}${unit < (item.price ?? 0) ? ' · ${'market_wholesale'.tr}' : ''}',
              style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ),
    ]);
  }
}

/// "In your cart": each choice of this item already in the cart, so the buyer does not forget.
class _InCart extends StatelessWidget {
  final String code;
  const _InCart({required this.code});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<MarketCartController>(builder: (cart) {
      final lines = cart.itemLines(code);
      if (lines.isEmpty) return const SizedBox();
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.shopping_cart_rounded, size: 18, color: theme.primaryColor)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('market_in_your_cart'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
            const SizedBox(height: 2),
            for (final l in lines)
              Text('${l.choice.isEmpty ? 'market_this_item'.tr : l.choice} × ${l.qty}  ·  ${PriceConverter.convertPrice(cart.unitPrice(l) * l.qty)}',
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor)),
          ])),
          TextButton(onPressed: () => Get.to(() => const MarketCartScreen()), child: Text('market_view_cart'.tr)),
        ]),
      );
    });
  }
}


/// A service on its page: where it happens, extras, the next free time, the hours.
class _ServicePanel extends StatelessWidget {
  final MarketItem item;
  final VoidCallback onBook;
  const _ServicePanel({required this.item, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final sv = item.service!;
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final hours = sv.hours;
    String hoursLine() {
      final open = [for (int i = 1; i <= 7; i++) if (hours[['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'][i - 1]] != null) i];
      if (open.isEmpty) return '';
      final first = hours[['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'][open.first - 1]]!;
      return '${'market_wd_${open.first}'.tr} - ${'market_wd_${open.last}'.tr}, ${first[0]} - ${first[1]}';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!sv.isQuote)
        Material(
          color: marketServiceBg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: item.mine || !sv.takingBookings ? null : onBook,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const Icon(Icons.event_available_outlined, color: marketServiceFg),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  !sv.takingBookings ? 'market_not_taking_bookings'.tr
                      : (sv.nextFree != null ? 'market_next_free'.trParams({'when': marketWhen(sv.nextFree)}) : 'market_no_free_soon'.tr),
                  style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: marketServiceFg),
                )),
                if (!item.mine && sv.takingBookings) Text('market_see_times'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: marketServiceFg)),
              ]),
            ),
          ),
        )
      else
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: marketServiceBg, borderRadius: BorderRadius.circular(14)),
          child: Text('market_quote_how'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: marketServiceFg, height: 1.4)),
        ),
      const SizedBox(height: 12),
      for (final w in sv.where)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(marketWhereIcon(w), size: 20, color: theme.primaryColor),
            const SizedBox(width: 10),
            Expanded(child: Text(
              w == 'client' && sv.areas != null ? '${'market_where_client'.tr} · ${sv.areas}' : 'market_where_$w'.tr,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor),
            )),
          ]),
        ),
      if (sv.where.contains('client') && (sv.travelFee ?? 0) > 0)
        Padding(padding: const EdgeInsets.only(left: 30, bottom: 6),
            child: Text('market_travel_fee_x'.trParams({'price': marketServicePrice(sv.travelFee, 'fixed')}),
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
      if (hoursLine().isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(Icons.schedule_rounded, size: 20, color: theme.primaryColor),
            const SizedBox(width: 10),
            Expanded(child: Text(hoursLine(), style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor))),
          ]),
        ),
      if (sv.bookingsDone > 0)
        Row(children: [
          Icon(Icons.verified_outlined, size: 20, color: theme.primaryColor),
          const SizedBox(width: 10),
          Text((sv.bookingsDone == 1 ? 'market_bookings_done_one' : 'market_bookings_done').trParams({'count': '${sv.bookingsDone}'}), style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
        ]),
      if (sv.extras.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text('market_extras'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
        const SizedBox(height: 4),
        for (final e in sv.extras)
          Padding(padding: const EdgeInsets.only(top: 2), child: Text('· ${e.name}${e.price > 0 ? ' +${marketServicePrice(e.price, 'fixed')}' : ''}',
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor))),
      ],
    ]);
  }
}
