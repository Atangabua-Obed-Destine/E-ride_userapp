import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_venue_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Share your shop": a WhatsApp Status picture of the whole shop, or of what
/// is new this week, with the link in the caption; what the links brought.
class MarketShareShopScreen extends StatefulWidget {
  const MarketShareShopScreen({super.key});

  @override
  State<MarketShareShopScreen> createState() => _MarketShareShopScreenState();
}

class _MarketShareShopScreenState extends State<MarketShareShopScreen> {
  final GlobalKey _card = GlobalKey();
  /// all: the whole shop; new: what's new this week; poster: a sign to print for the shed or counter.
  String _mode = 'all';
  bool get _whatsNew => _mode == 'new';
  bool get _poster => _mode == 'poster';
  bool _busy = false;

  List<MarketItem> get _live => Get.find<MarketController>().myItems.where((i) => i.isPublic).toList();

  /// Posted in the last 7 days, newest first.
  List<MarketItem> get _new {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final list = _live.where((i) => (DateTime.tryParse(i.createdAt ?? '') ?? DateTime(2000)).isAfter(since)).toList()
      ..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    return list;
  }

  String _text(MarketShop shop) => (_whatsNew ? 'share_shop_text_new' : 'share_shop_text').trParams({'shop': shop.name, 'link': shop.link});

  Future<File?> _picture(String slug) async {
    try {
      final boundary = _card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 1080 / boundary.size.width);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/eride_shop_${slug}_$_mode.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareStatus(MarketShop shop) async {
    if (_busy) return;
    setState(() => _busy = true);
    // The link goes in the caption: copied so it can be pasted on the Status.
    await Clipboard.setData(ClipboardData(text: shop.link));
    final file = await _picture(shop.slug);
    if (mounted) setState(() => _busy = false);
    if (file == null) {
      showCustomSnackBar('market_picture_failed'.tr);
      return;
    }
    showCustomSnackBar('share_shop_link_copied'.tr, isError: false);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')], text: _text(shop)));
  }

  Future<void> _sendWhatsApp(MarketShop shop) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_text(shop))}');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!opened) await SharePlus.instance.share(ShareParams(text: _text(shop)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color? text = theme.textTheme.bodyLarge?.color;
    return GetBuilder<MarketController>(builder: (market) {
      final shop = market.myShop;
      if (shop == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final stats = shop.stats;
      final fresh = _new;
      final bool canNew = fresh.isNotEmpty;
      if (!canNew && _whatsNew) _mode = 'all';
      return Scaffold(
        backgroundColor: theme.cardColor,
        appBar: AppBar(
          backgroundColor: theme.cardColor, foregroundColor: text, surfaceTintColor: Colors.transparent,
          title: Text('share_shop_title'.tr),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 4, Dimensions.paddingSizeDefault, 24), children: [
          // What the links brought.
          if (stats != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                _Count(value: stats.visits, label: 'share_shop_visits'.tr),
                _Count(value: stats.newUsers, label: 'share_shop_installs'.tr),
                _Count(value: stats.followers, label: 'market_stat_followers'.tr),
              ]),
            ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'all', label: Text('share_shop_all'.tr)),
              ButtonSegment(value: 'new', label: Text('share_shop_new'.tr), enabled: canNew),
              ButtonSegment(value: 'poster', label: Text('share_shop_poster'.tr)),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: theme.primaryColor,
              selectedForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
          if (!canNew)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('share_shop_new_none'.tr,
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor))),
          const SizedBox(height: 12),
          Center(child: SizedBox(
            width: _poster ? 290 : 260,
            child: RepaintBoundary(
              key: _card,
              child: _poster
                  ? _PosterCard(shop: shop)
                  : _whatsNew ? _WhatsNewCard(shop: shop, items: fresh) : _ShopCard(shop: shop, items: _live),
            ),
          )),
          const SizedBox(height: 16),
          Text((_poster ? 'share_shop_poster_how' : 'share_shop_how').tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
          const SizedBox(height: 10),
          SizedBox(height: 52, child: FilledButton.icon(
            onPressed: _busy ? null : () => _shareStatus(shop),
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.image_rounded),
            label: Text((_poster ? 'share_shop_poster_save' : 'share_shop_status').tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
          )),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _sendWhatsApp(shop),
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: Text('share_shop_whatsapp'.tr, maxLines: 1, overflow: TextOverflow.ellipsis),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: shop.link));
                showCustomSnackBar('market_link_copied'.tr, isError: false);
              },
              icon: const Icon(Icons.link_rounded, size: 18),
              label: Text('share_shop_copy'.tr, maxLines: 1, overflow: TextOverflow.ellipsis),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            )),
          ]),
          const SizedBox(height: 10),
          Text('share_shop_why'.tr, textAlign: TextAlign.center,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
        ]),
      );
    });
  }
}

class _Count extends StatelessWidget {
  final int value;
  final String label;
  const _Count({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(child: Column(children: [
      Text('$value', style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
      Text(label, textAlign: TextAlign.center, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
    ]));
  }
}

const Color _red = Color(0xFFE02020);

/// The whole shop on a Status: the shopfront or logo, name, where, four items, the link.
class _ShopCard extends StatelessWidget {
  final MarketShop shop;
  final List<MarketItem> items;
  const _ShopCard({required this.shop, required this.items});

  @override
  Widget build(BuildContext context) {
    final String link = shop.link.replaceFirst(RegExp(r'^https?://'), '');
    final String? hero = shop.venue?.shopfront;
    final String where = shop.venue != null ? '${shop.venue!.name} · ${shedWords(shop.venue!)}' : (shop.area ?? '');
    final shown = items.take(4).toList();
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        color: _red,
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Top(verified: shop.verified),
          const SizedBox(height: 8),
          // The shopfront, or the logo on white.
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(height: 108, width: double.infinity, child: hero != null
                ? ImageWidget(image: hero, fit: BoxFit.cover)
                : Container(color: Colors.white, alignment: Alignment.center,
                    child: MarketShopAvatar(name: shop.name, logo: shop.logo, size: 76))),
          ),
          const SizedBox(height: 8),
          Text(shop.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textBold.copyWith(fontSize: 17, color: Colors.white, height: 1.15)),
          if (where.isNotEmpty)
            Text(where, maxLines: 1, overflow: TextOverflow.ellipsis, style: textMedium.copyWith(fontSize: 10, color: Colors.white.withValues(alpha: 0.92))),
          const SizedBox(height: 8),
          Expanded(child: shown.isEmpty
              // No items yet: what the shop sells, in buyers' words.
              ? Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Centred: what the shop sells.
                  Text('share_shop_we_sell'.tr, textAlign: TextAlign.center, style: textBold.copyWith(fontSize: 12, color: Colors.white)),
                  const SizedBox(height: 8),
                  Wrap(alignment: WrapAlignment.center, spacing: 5, runSpacing: 5, children: [
                    for (final s in (shop.sells.isNotEmpty ? shop.sells : shop.categories.map(marketCategory).toList()).take(8))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                        child: Text(s, style: textSemiBold.copyWith(fontSize: 10, color: _red)),
                      ),
                  ]),
                ])
              : GridView.count(
                  crossAxisCount: 2, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 0.92,
                  physics: const NeverScrollableScrollPhysics(), padding: EdgeInsets.zero,
                  children: [for (final i in shown) _Tile(item: i)],
                )),
          const SizedBox(height: 8),
          _Tap(title: 'share_shop_tap'.tr, link: link, url: shop.link),
        ]),
      ),
    );
  }
}

/// What is new this week: the newest items, big.
class _WhatsNewCard extends StatelessWidget {
  final MarketShop shop;
  final List<MarketItem> items;
  const _WhatsNewCard({required this.shop, required this.items});

  @override
  Widget build(BuildContext context) {
    final String link = shop.link.replaceFirst(RegExp(r'^https?://'), '');
    final shown = items.take(4).toList();
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        color: _red,
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Top(verified: shop.verified),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
            child: Text('share_shop_new_badge'.tr, style: textBold.copyWith(fontSize: 11, color: _red, letterSpacing: .5)),
          ),
          const SizedBox(height: 6),
          Text('share_shop_new_at'.trParams({'shop': shop.name}), maxLines: 2, overflow: TextOverflow.ellipsis,
              style: textBold.copyWith(fontSize: 18, color: Colors.white, height: 1.15)),
          const SizedBox(height: 8),
          Expanded(child: shown.length == 1
              ? _Tile(item: shown.first, big: true)
              : GridView.count(
                  crossAxisCount: 2, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: shown.length <= 2 ? 0.6 : 0.78,
                  physics: const NeverScrollableScrollPhysics(), padding: EdgeInsets.zero,
                  children: [for (final i in shown) _Tile(item: i)],
                )),
          const SizedBox(height: 8),
          _Tap(title: 'share_shop_tap_new'.tr, link: link, url: shop.link),
        ]),
      ),
    );
  }
}

class _Top extends StatelessWidget {
  final bool verified;
  const _Top({required this.verified});

  @override
  Widget build(BuildContext context) => Row(children: [
        Text('E-RIDE ', style: textBold.copyWith(fontSize: 12, color: Colors.white, letterSpacing: .5)),
        Text('MARKET', style: textMedium.copyWith(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
        const Spacer(),
        if (verified)
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.verified_rounded, size: 12, color: Colors.white),
            const SizedBox(width: 3),
            Text('market_verified_shop'.tr, style: textMedium.copyWith(fontSize: 9, color: Colors.white)),
          ]),
      ]);
}

class _Tile extends StatelessWidget {
  final MarketItem item;
  final bool big;
  const _Tile({required this.item, this.big = false});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.all(4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: item.cover != null
                ? ImageWidget(image: item.cover!, width: double.infinity, fit: BoxFit.cover)
                : Container(color: const Color(0xFFF4F6F6), child: const Center(child: Icon(Icons.image_outlined, color: Color(0xFF9AA5A4)))),
          )),
          const SizedBox(height: 3),
          Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: textMedium.copyWith(fontSize: big ? 13 : 9, color: const Color(0xFF1D2D2B))),
          Text(item.price != null ? marketPrice(item.price) : 'market_ask_the_seller'.tr, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: textBold.copyWith(fontSize: big ? 16 : 11, color: _red)),
        ]),
      );
}

class _Tap extends StatelessWidget {
  final String title;
  final String link;
  final String url;
  const _Tap({required this.title, required this.link, required this.url});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: textBold.copyWith(fontSize: 11, color: const Color(0xFF1D2D2B))),
            Text('share_shop_scan_or_tap'.tr, style: textSemiBold.copyWith(fontSize: 9, color: _red)),
            Text(link, maxLines: 1, overflow: TextOverflow.ellipsis, style: textRegular.copyWith(fontSize: 8, color: const Color(0xFF48615E))),
          ])),
          const SizedBox(width: 6),
          QrImageView(data: url, size: 52, padding: EdgeInsets.zero, backgroundColor: Colors.white),
        ]),
      );
}

/// A sign to print for the shed or the counter: the name, where, a big QR code.
class _PosterCard extends StatelessWidget {
  final MarketShop shop;
  const _PosterCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    final String link = shop.link.replaceFirst(RegExp(r'^https?://'), '');
    final v = shop.venue;
    return AspectRatio(
      aspectRatio: 1 / 1.414,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE8ECEB))),
        child: Column(children: [
          Container(
            width: double.infinity,
            color: _red,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(children: [
              Text('E-RIDE ', style: textBold.copyWith(fontSize: 12, color: Colors.white, letterSpacing: .5)),
              Text('MARKET', style: textMedium.copyWith(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
              const Spacer(),
              if (shop.verified)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.verified_rounded, size: 12, color: Colors.white),
                  const SizedBox(width: 3),
                  Text('market_verified_shop'.tr, style: textMedium.copyWith(fontSize: 9, color: Colors.white)),
                ]),
            ]),
          ),
          const SizedBox(height: 10),
          MarketShopAvatar(name: shop.name, logo: shop.logo, size: 44),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(shop.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: textBold.copyWith(fontSize: 17, color: const Color(0xFF1D2D2B), height: 1.15)),
          ),
          if (v != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text([v.name, shedWords(v)].join('\n'), textAlign: TextAlign.center,
                  style: textBold.copyWith(fontSize: 11, color: marketVenueColor, height: 1.3)),
            ),
          const SizedBox(height: 8),
          Text('share_shop_poster_scan'.tr, textAlign: TextAlign.center, style: textBold.copyWith(fontSize: 13, color: _red)),
          const SizedBox(height: 6),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: Center(child: AspectRatio(aspectRatio: 1, child: QrImageView(data: shop.link, padding: EdgeInsets.zero, backgroundColor: Colors.white))),
          )),
          const SizedBox(height: 8),
          Text(link, style: textSemiBold.copyWith(fontSize: 9, color: const Color(0xFF1D2D2B))),
          const SizedBox(height: 2),
          Text('share_shop_poster_no_app'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(fontSize: 8, color: const Color(0xFF6B7675))),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }
}
