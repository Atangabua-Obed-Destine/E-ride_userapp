import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_cart_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_order_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_order_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_order_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_point_sheet.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Sending one shop's cart as an order request: how the buyer gets it, where, how they
/// will pay the seller, and a note. Nothing is paid in the app.
class MarketSendOrderScreen extends StatefulWidget {
  final String shopSlug;
  const MarketSendOrderScreen({super.key, required this.shopSlug});

  @override
  State<MarketSendOrderScreen> createState() => _MarketSendOrderScreenState();
}

class _MarketSendOrderScreenState extends State<MarketSendOrderScreen> {
  final TextEditingController _note = TextEditingController();
  String? _fulfilment;
  String? _pay;
  Address? _drop;

  @override
  void initState() {
    super.initState();
    final saved = Get.find<LocationController>().getUserAddress();
    if (saved?.latitude != null && saved?.longitude != null) _drop = saved;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Get.find<MarketController>().loadShop(widget.shopSlug);
      _defaults();
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _defaults() {
    final shop = Get.find<MarketController>().shopFor(widget.shopSlug);
    if (shop == null || !mounted) return;
    setState(() {
      _fulfilment ??= shop.fulfilment.contains('eride') ? 'eride' : shop.fulfilment.first;
      _pay ??= shop.payMethods.contains('cash_delivery') ? 'cash_delivery' : shop.payMethods.first;
    });
  }

  Future<void> _changeDrop() async {
    final point = await pickMarketPoint(title: 'market_deliver_where'.tr);
    if (point != null && point.latitude != null) setState(() => _drop = point);
  }

  Future<void> _send(MarketShop shop) async {
    final cart = Get.find<MarketCartController>();
    if (_fulfilment == null || _pay == null) return;
    final needsPoint = _fulfilment == 'eride' || _fulfilment == 'seller';
    if (needsPoint && (_drop?.latitude == null || _drop?.longitude == null)) {
      showCustomSnackBar('market_choose_drop'.tr);
      return;
    }
    final order = await Get.find<MarketOrderController>().place({
      'shop': widget.shopSlug,
      'lines': jsonEncode(cart.orderLines(widget.shopSlug)),
      'fulfilment': _fulfilment,
      'pay_method': _pay,
      if (needsPoint) ...{'drop_lat': _drop!.latitude, 'drop_lng': _drop!.longitude, 'drop_address': _drop!.address ?? ''},
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
    });
    if (order == null) return;
    await cart.clearShop(widget.shopSlug);
    Get.off(() => MarketOrderScreen(orderId: order.id, justSent: true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<MarketController>(builder: (market) {
      final shop = market.shopFor(widget.shopSlug);
      final cart = Get.find<MarketCartController>();
      final lines = cart.shopLines(widget.shopSlug);
      return Scaffold(
        backgroundColor: theme.cardColor,
        appBar: AppBar(
          backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
          title: Text('market_send_order_to'.trParams({'shop': shop?.name ?? (lines.isNotEmpty ? lines.first.shopName : '')})),
        ),
        body: shop == null
            ? Center(child: market.shopLoading ? const CircularProgressIndicator() : Text(market.shopError ?? 'market_shop_gone'.tr))
            : !shop.takingOrders
                ? MarketEmpty(icon: Icons.pause_circle_outline_rounded, title: 'market_not_taking_orders'.tr, body: 'market_not_taking_orders_body'.tr)
                : ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
                    _Summary(lines: lines, cart: cart, slug: widget.shopSlug),
                    const SizedBox(height: Dimensions.paddingSizeLarge),
                    Text('market_how_get'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
                    const SizedBox(height: 8),
                    RadioGroup<String>(
                      groupValue: _fulfilment,
                      onChanged: (v) => setState(() => _fulfilment = v),
                      child: Column(children: [
                        for (final f in shop.fulfilment)
                          RadioListTile<String>(
                            value: f,
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(marketFulfilmentIcon(f), color: theme.primaryColor),
                            title: Text('market_fulfilment_$f'.tr, style: textSemiBold.copyWith(color: textColor)),
                            subtitle: Text(
                              f == 'pickup'
                                  ? 'market_fulfilment_pickup_hint'.trParams({'area': shop.area ?? shop.name})
                                  : 'market_fulfilment_${f}_hint'.tr,
                              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor),
                            ),
                          ),
                      ]),
                    ),
                    if (_fulfilment == 'eride' || _fulfilment == 'seller')
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
                        child: Row(children: [
                          Icon(Icons.location_on_rounded, color: theme.primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_drop?.address ?? 'market_choose_drop'.tr, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: textRegular.copyWith(color: _drop == null ? theme.hintColor : textColor))),
                          TextButton(onPressed: _changeDrop, child: Text(_drop == null ? 'market_choose'.tr : 'market_change'.tr)),
                        ]),
                      ),
                    const SizedBox(height: Dimensions.paddingSizeLarge),
                    Text('market_how_pay'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final p in shop.payMethods)
                        ChoiceChip(
                          label: Text('market_pay_$p'.tr),
                          selected: _pay == p,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _pay = p),
                          selectedColor: textColor,
                          labelStyle: textMedium.copyWith(color: _pay == p ? theme.cardColor : textColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    Text(_pay == 'before' ? 'market_pay_before_warning'.tr : 'market_pay_hint'.tr,
                        style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: _pay == 'before' ? marketDangerFg : theme.hintColor)),
                    const SizedBox(height: Dimensions.paddingSizeLarge),
                    Text('market_note_for_seller'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _note,
                      maxLength: 500,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(hintText: 'market_note_hint'.tr,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault))),
                    ),
                    if (shop.minOrder != null && cart.subtotal(widget.shopSlug) < shop.minOrder!)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('market_min_order'.trParams({'amount': PriceConverter.convertPrice(shop.minOrder!)}),
                            style: textMedium.copyWith(color: marketDangerFg)),
                      ),
                    const SizedBox(height: 90),
                  ]),
        bottomNavigationBar: shop == null || !shop.takingOrders ? null : SafeArea(child: Container(
          padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 8, Dimensions.paddingSizeDefault, 10),
          decoration: BoxDecoration(color: theme.cardColor, border: Border(top: BorderSide(color: theme.hintColor.withValues(alpha: 0.12)))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.schedule_rounded, size: 14, color: theme.hintColor),
              const SizedBox(width: 4),
              Flexible(child: Text(
                shop.openNow
                    ? 'market_answer_within'.trParams({'shop': shop.name, 'time': marketMinutes(market.meta?.answerMinutes ?? 120)})
                    : 'market_shop_closed_now'.trParams({'time': shop.openFrom ?? ''}),
                textAlign: TextAlign.center,
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor),
              )),
            ]),
            const SizedBox(height: 8),
            GetBuilder<MarketOrderController>(builder: (orders) => SizedBox(width: double.infinity, height: 52, child: FilledButton(
              onPressed: orders.acting || lines.isEmpty ? null : () => _send(shop),
              child: orders.acting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('market_send_request'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
            ))),
          ]),
        )),
      );
    });
  }
}

class _Summary extends StatelessWidget {
  final List<MarketCartLine> lines;
  final MarketCartController cart;
  final String slug;
  const _Summary({required this.lines, required this.cart, required this.slug});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.hintColor.withValues(alpha: 0.15))),
      child: Row(children: [
        SizedBox(width: 64, height: 48, child: Stack(children: [
          for (int i = 0; i < lines.length && i < 3; i++)
            Positioned(left: i * 10.0, child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.cardColor, width: 2)),
              child: lines[i].photo != null
                  ? ImageWidget(image: lines[i].photo!, width: 44, height: 44, radius: 8, fit: BoxFit.cover)
                  : Container(width: 44, height: 44, color: theme.hintColor.withValues(alpha: 0.1)),
            )),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${marketPieces(cart.piecesOf(slug))} · ${PriceConverter.convertPrice(cart.subtotal(slug))}',
              style: textBold.copyWith(color: textColor)),
          Text(lines.map((l) => l.qty > 1 ? '${l.title} ×${l.qty}' : l.title).join(', '), maxLines: 2, overflow: TextOverflow.ellipsis,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ])),
        TextButton(onPressed: () => Get.back(), child: Text('market_edit'.tr)),
      ]),
    );
  }
}
