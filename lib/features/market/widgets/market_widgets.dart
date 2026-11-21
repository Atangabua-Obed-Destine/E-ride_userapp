import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_cart_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_sell_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_service_widgets.dart';

const Color marketWarnBg = Color(0xFFFFF4E5);
const Color marketWarnFg = Color(0xFF7A3E0B);
const Color marketDangerBg = Color(0xFFFDECEC);
const Color marketDangerFg = Color(0xFF7F1D1D);
const Color marketVerified = Color(0xFF1D4ED8);

/// "12 500 FCFA", or "Ask the seller" when there is no price.
String marketPrice(double? price) => price == null ? 'market_ask_price'.tr : PriceConverter.convertPrice(price);

String marketCategory(String? key) => key == null ? '' : 'market_category_$key'.tr;

/// "Fashion, Beauty, Phones +2"
String marketCategories(List<String> keys, {int max = 3}) {
  if (keys.isEmpty) return '';
  final shown = keys.take(max).map(marketCategory).join(', ');
  return keys.length > max ? '$shown +${keys.length - max}' : shown;
}

/// Follow or manage a follow. Not following: follows at once, then shows the sheet (alerts on, with
/// Undo for a mis-tap). Following: shows the sheet (alerts switch, Unfollow after a confirmation).
Future<void> marketFollowTap({required String slug, required String shopName, required bool following, required bool notify}) async {
  final market = Get.find<MarketController>();
  if (!following) {
    if (!await market.follow(slug, true, notify: true)) return;
    notify = true;
  }
  await Get.bottomSheet(_FollowSheet(slug: slug, shopName: shopName, notify: notify, justFollowed: !following));
}

class _FollowSheet extends StatefulWidget {
  final String slug;
  final String shopName;
  final bool notify;
  final bool justFollowed;
  const _FollowSheet({required this.slug, required this.shopName, required this.notify, required this.justFollowed});

  @override
  State<_FollowSheet> createState() => _FollowSheetState();
}

class _FollowSheetState extends State<_FollowSheet> {
  late bool _notify = widget.notify;
  bool _busy = false;

  MarketController get _market => Get.find<MarketController>();

  Future<void> _setNotify(bool value) async {
    setState(() {
      _notify = value;
      _busy = true;
    });
    final ok = await _market.follow(widget.slug, true, notify: value);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _notify = !value;
    });
  }

  Future<void> _unfollow({bool confirm = true}) async {
    if (confirm) {
      final sure = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: Text('market_unfollow_title'.trParams({'shop': widget.shopName})),
        content: Text('market_unfollow_body'.tr),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('market_keep_following'.tr)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('market_unfollow'.tr)),
        ],
      ));
      if (sure != true) return;
    }
    setState(() => _busy = true);
    final ok = await _market.follow(widget.slug, false);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Container(
      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 12, Dimensions.paddingSizeLarge, Dimensions.paddingSizeLarge),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3)))),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.favorite_rounded, size: 20, color: theme.primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('market_you_follow'.trParams({'shop': widget.shopName}),
              style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor))),
        ]),
        const SizedBox(height: 6),
        Text('market_follow_explain'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _notify,
          onChanged: _busy ? null : _setNotify,
          contentPadding: EdgeInsets.zero,
          secondary: Icon(_notify ? Icons.notifications_active_outlined : Icons.notifications_off_outlined, color: theme.primaryColor),
          title: Text('market_notify_new_posts'.tr, style: textSemiBold.copyWith(color: textColor)),
          subtitle: Text((_notify ? 'market_notify_on_hint' : 'market_notify_off_hint').tr,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Row(children: [
          if (widget.justFollowed)
            Expanded(child: SizedBox(height: 50, child: TextButton(
              onPressed: _busy ? null : () => _unfollow(confirm: false),
              child: Text('market_undo_follow'.tr),
            )))
          else
            Expanded(child: SizedBox(height: 50, child: OutlinedButton.icon(
              onPressed: _busy ? null : _unfollow,
              style: OutlinedButton.styleFrom(foregroundColor: marketDangerFg, side: const BorderSide(color: marketDangerFg)),
              icon: const Icon(Icons.heart_broken_outlined, size: 18),
              label: Text('market_unfollow'.tr),
            ))),
          const SizedBox(width: 10),
          Expanded(child: SizedBox(height: 50, child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('market_done'.tr),
          ))),
        ]),
      ])),
    );
  }
}

/// The orange note on every item: E-Ride does not hold the money.
class MarketScamNotice extends StatelessWidget {
  final String? text;
  const MarketScamNotice({super.key, this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall + 2),
      decoration: BoxDecoration(color: marketWarnBg, borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.shield_outlined, size: 18, color: Color(0xFFB45309)),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Expanded(child: Text(text ?? 'market_scam_notice'.tr,
            style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: marketWarnFg, height: 1.4))),
      ]),
    );
  }
}

/// The red warning on digital products of new, unverified shops.
class MarketDigitalWarning extends StatelessWidget {
  const MarketDigitalWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: marketDangerBg,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: const Color(0xFFF5B5B5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFF991B1B)),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(child: Text('market_digital_warning_title'.tr,
              style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: const Color(0xFF991B1B)))),
        ]),
        const SizedBox(height: 6),
        Text('market_digital_warning'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: marketDangerFg, height: 1.45)),
      ]),
    );
  }
}

class MarketVerifiedBadge extends StatelessWidget {
  final double size;
  const MarketVerifiedBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) =>
      Semantics(label: 'market_verified'.tr, child: Icon(Icons.verified_rounded, size: size, color: marketVerified));
}

/// A shop's logo, or its first letter.
class MarketShopAvatar extends StatelessWidget {
  final String name;
  final String? logo;
  final double size;
  const MarketShopAvatar({super.key, required this.name, this.logo, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (logo != null) return ImageWidget(image: logo!, width: size, height: size, radius: size * 0.28);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(size * 0.28)),
      child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: textBold.copyWith(fontSize: size * 0.42, color: theme.primaryColor)),
    );
  }
}

/// An item in a grid.
class MarketItemCard extends StatelessWidget {
  final MarketItem item;
  final VoidCallback onTap;
  final bool showShop;
  const MarketItemCard({super.key, required this.item, required this.onTap, this.showShop = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.hintColor.withValues(alpha: 0.15))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(fit: StackFit.expand, children: [
                item.cover != null
                    ? ImageWidget(image: item.cover!, fit: BoxFit.cover)
                    : Container(color: theme.hintColor.withValues(alpha: 0.1),
                        child: Icon(item.isDigital ? Icons.description_outlined : Icons.image_outlined, color: theme.hintColor)),
                if (item.isService)
                  const Positioned(left: 6, top: 6, child: MarketServiceTag(onPhoto: true))
                else if (item.isAuction)
                  Positioned(left: 6, top: 6, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: marketAuctionBg.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.gavel_rounded, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      item.auction!.live
                          ? MarketTimeLeft(until: item.auction!.endsAt, style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white))
                          : Text('market_ended'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white)),
                    ]),
                  ))
                else if (item.isDigital || item.status == MarketItem.soldOut)
                  Positioned(left: 6, top: 6, child: _Tag(item.status == MarketItem.soldOut ? 'market_sold_out'.tr : 'market_digital'.tr)),
                // Services: the next free time, on the photo.
                if (item.isService && item.service?.nextFree != null)
                  Positioned(left: 6, bottom: 6, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: marketServiceFg, borderRadius: BorderRadius.circular(8)),
                    child: Text('market_free_x'.trParams({'when': marketWhen(item.service!.nextFree)}),
                        style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white)),
                  )),
                // In the cart: how many, so the buyer does not forget.
                GetBuilder<MarketCartController>(builder: (cart) {
                  final n = cart.itemPieces(item.code);
                  if (n == 0) return const SizedBox();
                  return Positioned(left: 6, bottom: 6, child: Semantics(
                    label: 'market_in_cart_count'.trParams({'count': '$n'}),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(12)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.shopping_cart_rounded, size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('$n', style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white)),
                      ]),
                    ),
                  ));
                }),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
                const SizedBox(height: 2),
                if (item.isService && item.service != null)
                  Text(marketServicePrice(item.price, item.service!.priceType), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.primaryColor))
                else if (item.isAuction)
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text(marketPrice(item.auction!.price), style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.primaryColor)),
                    const SizedBox(width: 4),
                    Flexible(child: Text(
                      item.auction!.bidCount == 1 ? 'market_one_bid'.tr : 'market_n_bids'.trParams({'count': '${item.auction!.bidCount}'}),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor),
                    )),
                  ])
                else
                  Text(marketPrice(item.price), style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.primaryColor)),
                if (showShop && item.shop != null && item.shop!.isPrivate)
                  Row(children: [
                    const Icon(Icons.person_outline_rounded, size: 12, color: marketPrivateFg),
                    const SizedBox(width: 2),
                    Flexible(child: Text('${item.shop!.name} · ${(item.isService ? 'market_independent' : 'market_private').tr}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: marketPrivateFg))),
                  ])
                else if (showShop && item.shop != null)
                  Row(children: [
                    Flexible(child: Text(item.shop!.area != null ? '${item.shop!.name} · ${item.shop!.area}' : item.shop!.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor))),
                    if (item.shop!.verified) ...[const SizedBox(width: 3), const MarketVerifiedBadge(size: 12)],
                  ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xCC1D2D2B), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white)),
      );
}

class MarketEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;
  const MarketEmpty({super.key, required this.icon, required this.title, this.body, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Dimensions.paddingSizeExtraLarge),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 52, color: theme.hintColor.withValues(alpha: 0.6)),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        Text(title, textAlign: TextAlign.center,
            style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
        if (body != null) ...[
          const SizedBox(height: 6),
          Text(body!, textAlign: TextAlign.center, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ],
        if (action != null) ...[
          const SizedBox(height: Dimensions.paddingSizeDefault),
          FilledButton(onPressed: onAction, child: Text(action!)),
        ],
      ]),
    );
  }
}

/// Before the first chat (and before every chat about a digital product): stay safe.
/// True when the buyer goes on.
Future<bool> showMarketSafetySheet({bool digital = false, bool service = false}) async {
  final market = Get.find<MarketController>();
  if (!digital && await market.safetySeen()) return true;
  final bool? go = await Get.bottomSheet<bool>(_SafetySheet(digital: digital, service: service), isScrollControlled: true);
  if (go == true) await market.markSafetySeen();
  return go == true;
}

class _SafetySheet extends StatelessWidget {
  final bool digital;
  /// A service: the rules are about the job (agree first, pay after), not about checking an item.
  final bool service;
  const _SafetySheet({required this.digital, this.service = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rules = service
        ? ['market_rule_svc_agree', 'market_rule_svc_pay_after', 'market_rule_no_fee', 'market_rule_svc_ratings', 'market_rule_stay']
        : ['market_rule_check', 'market_rule_no_fee', 'market_rule_public', 'market_rule_stay', 'market_rule_too_cheap'];
    return Container(
      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 12, Dimensions.paddingSizeLarge, Dimensions.paddingSizeLarge),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(top: false, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3)))),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: marketWarnBg, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.shield_outlined, color: Color(0xFFB45309), size: 28),
        ),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        Text('market_safety_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 6),
        Text((service ? 'market_safety_body_service' : 'market_safety_body').tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.hintColor, height: 1.45)),
        if (digital) ...[const SizedBox(height: Dimensions.paddingSizeDefault), const MarketDigitalWarning()],
        const SizedBox(height: Dimensions.paddingSizeDefault),
        for (int i = 0; i < rules.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 22, child: Text('${i + 1}', style: textBold.copyWith(color: theme.primaryColor))),
              Expanded(child: Text(rules[i].tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, height: 1.4,
                  color: theme.textTheme.bodyLarge?.color))),
            ]),
          ),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        SizedBox(width: double.infinity, height: 52, child: FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('market_start_chat'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
        )),
      ]))),
    );
  }
}

/// Report an item ([code]) or a whole shop ([slug]); can also block the shop.
Future<void> showMarketReportSheet({String? code, String? slug, required String shopSlug}) async {
  final market = Get.find<MarketController>();
  final meta = await market.loadMeta();
  final reasons = meta?.reportReasons.isNotEmpty == true ? meta!.reportReasons : ['scam', 'fake', 'banned', 'stolen', 'other'];
  await Get.bottomSheet(_ReportSheet(code: code, slug: slug ?? shopSlug, reasons: reasons, isItem: code != null), isScrollControlled: true);
}

class _ReportSheet extends StatefulWidget {
  final String? code;
  final String slug;
  final List<String> reasons;
  final bool isItem;
  const _ReportSheet({this.code, required this.slug, required this.reasons, required this.isItem});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  bool _block = true;
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(top: false, child: GetBuilder<MarketController>(builder: (market) => SingleChildScrollView(
        padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text((widget.isItem ? 'market_report_item' : 'market_report_shop').tr,
              style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 4),
          Text('market_report_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v),
            child: Column(children: [
              for (final r in widget.reasons)
                RadioListTile<String>(
                  value: r,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('market_reason_$r'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
                ),
            ]),
          ),
          TextField(
            controller: _note,
            maxLength: 600,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(hintText: 'market_report_note_hint'.tr,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault))),
          ),
          CheckboxListTile(
            value: _block,
            onChanged: (v) => setState(() => _block = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text('market_also_block'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault)),
          ),
          SizedBox(width: double.infinity, height: 52, child: FilledButton(
            onPressed: _reason == null || market.reporting ? null : () async {
              final sent = await market.report(code: widget.code, slug: widget.code == null ? widget.slug : null,
                  reason: _reason!, note: _note.text.trim(), block: _block);
              if (sent && context.mounted) Navigator.of(context).pop();
            },
            child: market.reporting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('market_send_report'.tr),
          )),
        ]),
      ))),
    );
  }
}

/// The picture for a WhatsApp status: photo, price, shop, and where to tap.
class MarketStatusCard extends StatelessWidget {
  final MarketItem item;
  final String shopName;
  final bool verified;
  const MarketStatusCard({super.key, required this.item, required this.shopName, this.verified = false});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE02020);
    final link = item.link.replaceFirst(RegExp(r'^https?://'), '');
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        color: red,
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('E-RIDE ', style: textBold.copyWith(fontSize: 15, color: Colors.white, letterSpacing: .5)),
            Text('MARKET', style: textMedium.copyWith(fontSize: 15, color: Colors.white.withValues(alpha: 0.9))),
            const Spacer(),
            if (verified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.verified_rounded, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('market_verified_shop'.tr, style: textMedium.copyWith(fontSize: 10, color: Colors.white)),
                ]),
              ),
          ]),
          const SizedBox(height: 12),
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: item.cover != null
                ? ImageWidget(image: item.cover!, width: double.infinity, fit: BoxFit.cover)
                : Container(color: Colors.white24, child: const Center(child: Icon(Icons.image_outlined, color: Colors.white, size: 40))),
          )),
          const SizedBox(height: 12),
          Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: textBold.copyWith(fontSize: 20, color: Colors.white, height: 1.2)),
          const SizedBox(height: 4),
          if (item.isAuction)
            Text('market_auction_starts_at'.trParams({'price': marketPrice(item.auction!.price)}),
                style: textSemiBold.copyWith(fontSize: 15, color: Colors.white))
          else if (item.isService && item.service != null)
            Text(marketServicePrice(item.price, item.service!.priceType), style: textBold.copyWith(fontSize: 26, color: Colors.white))
          else
            Text(marketPrice(item.price), style: textBold.copyWith(fontSize: 26, color: Colors.white)),
          if (item.isAuction && item.auction!.endsAt != null)
            Text('market_auction_ends_on'.trParams({'time': marketDayTime(item.auction!.endsAt!)}),
                style: textBold.copyWith(fontSize: 20, color: Colors.white)),
          Text(shopName, style: textRegular.copyWith(fontSize: 13, color: Colors.white.withValues(alpha: 0.92))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((item.isService ? 'market_tap_link_book' : 'market_tap_link').tr, style: textBold.copyWith(fontSize: 13, color: const Color(0xFF1D2D2B))),
                Text('share_shop_scan_or_tap'.tr, style: textSemiBold.copyWith(fontSize: 10, color: red)),
                Text(link, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(fontSize: 11, color: const Color(0xFF48615E))),
              ])),
              const SizedBox(width: 8),
              QrImageView(data: item.link, size: 58, padding: EdgeInsets.zero, backgroundColor: Colors.white),
            ]),
          ),
        ]),
      ),
    );
  }
}
