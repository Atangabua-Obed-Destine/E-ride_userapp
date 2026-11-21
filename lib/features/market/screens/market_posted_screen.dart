import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_service_widgets.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_item_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// The share sheet with the link (WhatsApp makes the preview from the page's tags).
Future<void> shareMarketLink(String link, String title) async {
  if (link.isEmpty) return;
  await SharePlus.instance.share(ShareParams(text: '$title\n$link'));
}

/// "Your item is live": the picture for a WhatsApp status, send to a group, copy the link.
/// Also the seller's "Share" for an item already posted ([justPosted] false).
class MarketPostedScreen extends StatefulWidget {
  final MarketItem item;
  final bool justPosted;
  const MarketPostedScreen({super.key, required this.item, this.justPosted = true});

  @override
  State<MarketPostedScreen> createState() => _MarketPostedScreenState();
}

class _MarketPostedScreenState extends State<MarketPostedScreen> {
  final GlobalKey _card = GlobalKey();
  bool _busy = false;

  String get _text => widget.item.isAuction
      ? '${widget.item.title} · ${'market_auction_starts_at'.trParams({'price': marketPrice(widget.item.auction!.price)})}\n${'market_share_text'.tr}\n${widget.item.link}'
      : widget.item.isService && widget.item.service != null
          ? '${widget.item.title} · ${marketServicePrice(widget.item.price, widget.item.service!.priceType)}\n${'market_share_text_book'.tr}\n${widget.item.link}'
          : '${widget.item.title} · ${marketPrice(widget.item.price)}\n${'market_share_text'.tr}\n${widget.item.link}';

  Future<File?> _picture() async {
    try {
      final boundary = _card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final double ratio = 1080 / boundary.size.width;
      final ui.Image image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/eride_market_${widget.item.code}.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareStatus() async {
    if (_busy) return;
    setState(() => _busy = true);
    final file = await _picture();
    if (mounted) setState(() => _busy = false);
    if (file == null) {
      showCustomSnackBar('market_picture_failed'.tr);
      return;
    }
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')], text: _text));
  }

  Future<void> _sendWhatsApp() async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_text)}');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!opened) await SharePlus.instance.share(ShareParams(text: _text));
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.item.link));
    showCustomSnackBar('market_link_copied'.tr, isError: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final item = widget.item;
    final shop = Get.find<MarketController>().myShop;
    final bool live = item.isPublic;
    return Scaffold(
      backgroundColor: theme.cardColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
        title: Text((widget.justPosted ? (live ? (widget.item.isService ? 'market_service_live' : 'market_item_live') : 'market_item_not_live') : (widget.item.isService ? 'market_share_service' : 'market_share_item')).tr),
      ),
      body: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeLarge), children: [
        if (!live) ...[
          Container(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            decoration: BoxDecoration(color: marketDangerBg, borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
            child: Text(item.status == MarketItem.blocked && item.blockedWord != null
                ? 'market_blocked_word'.trParams({'word': item.blockedWord!})
                : (item.statusNote ?? 'market_status_${item.status}_body'.tr),
                style: textRegular.copyWith(color: marketDangerFg, height: 1.45)),
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),
          SizedBox(height: 50, child: OutlinedButton(
            onPressed: () => Get.off(() => MarketItemScreen(code: item.code, initial: item)),
            child: Text('market_view_item'.tr),
          )),
        ] else ...[
          if (widget.justPosted)
            Text((widget.item.isService ? 'market_service_live_body' : 'market_item_live_body').tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.hintColor, height: 1.45)),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Center(child: SizedBox(
            width: 240,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: RepaintBoundary(
                key: _card,
                child: MarketStatusCard(item: item, shopName: shop?.name ?? item.shop?.name ?? '', verified: shop?.verified ?? item.shop?.verified ?? false),
              ),
            ),
          )),
          const SizedBox(height: Dimensions.paddingSizeLarge),
          SizedBox(height: 52, child: FilledButton.icon(
            onPressed: _busy ? null : _shareStatus,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.amp_stories_outlined),
            label: Text('market_share_status'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
          )),
          const SizedBox(height: 4),
          Text('market_share_status_hint'.tr, textAlign: TextAlign.center,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          SizedBox(height: 50, child: OutlinedButton.icon(
            onPressed: _sendWhatsApp,
            icon: const Icon(Icons.groups_outlined),
            label: Text('market_send_group'.tr),
          )),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Dimensions.radiusDefault), border: Border.all(color: theme.hintColor.withValues(alpha: 0.25))),
            child: Row(children: [
              Expanded(child: Text(item.link, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor))),
              TextButton.icon(onPressed: _copy, icon: const Icon(Icons.copy_rounded, size: 16), label: Text('market_copy'.tr)),
            ]),
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),
          Text('market_share_tip'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.45)),
        ],
      ]),
      bottomNavigationBar: widget.justPosted ? SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 4, Dimensions.paddingSizeLarge, 12),
        child: TextButton(onPressed: () => Get.back(), child: Text('market_done'.tr)),
      )) : null,
    );
  }
}
