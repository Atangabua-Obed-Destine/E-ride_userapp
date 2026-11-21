import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_order_model.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Before an order is sent: everything in it, once more, to accept or go back
/// and change. True when the customer accepts.
Future<bool> showOrderPreview(BuildContext context, StoreController c, StoreQuote quote) async {
  final bool? ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (_) => _OrderPreview(c: c, quote: quote),
  );
  return ok == true;
}

class _OrderPreview extends StatelessWidget {
  final StoreController c;
  final StoreQuote quote;
  const _OrderPreview({required this.c, required this.quote});

  String _clock(DateTime at) {
    final DateTime now = DateTime.now();
    final bool today = at.day == now.day && at.month == now.month && at.year == now.year;
    return '${today ? 'today'.tr : 'tomorrow'.tr} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color? text = theme.textTheme.bodyLarge?.color;
    final store = c.cartStore ?? c.store;
    final String storeName = [store?.name, if ((store?.branchName ?? '').isNotEmpty) store!.branchName].whereType<String>().join(' · ');
    final String way = c.way;
    final String? gateway = c.gateways.firstWhereOrNull((g) => g.gateway == c.paymentMethod)?.gatewayTitle;

    Widget row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: theme.primaryColor),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          Text(value, style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: text)),
        ])),
      ]),
    );

    Widget money(String label, double amount, {bool bold = false}) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: (bold ? textBold : textRegular).copyWith(fontSize: Dimensions.fontSizeDefault, color: text))),
        Text(PriceConverter.convertPrice(amount), style: (bold ? textBold : textMedium).copyWith(fontSize: Dimensions.fontSizeDefault, color: text)),
      ]),
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, 4, 0),
            child: Row(children: [
              Expanded(child: Text('order_preview_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: text))),
              IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close_rounded), tooltip: 'close'.tr),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
            child: Text('order_preview_sub'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ),
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              row(Icons.storefront_rounded, 'order_preview_from'.tr, [storeName, if ((store?.address ?? '').isNotEmpty) store!.address!].join('\n')),
              if (way == 'delivery') ...[
                row(Icons.delivery_dining_rounded, 'order_way_delivery'.tr, c.dropAddress),
                if (quote.durationMin != null)
                  row(Icons.schedule_rounded, 'order_preview_arrives'.tr, 'order_preview_about_min'.trParams({'n': '${(store?.prepMinutes ?? 0) + quote.durationMin!}'})),
              ] else ...[
                row(way == 'dine_in' ? Icons.restaurant_rounded : Icons.shopping_bag_rounded,
                    way == 'dine_in' ? 'order_way_dine_in'.tr : 'order_way_pickup'.tr,
                    [
                      if (c.arriveAt != null) _clock(c.arriveAt!),
                      if (way == 'dine_in') 'order_n_people'.trParams({'n': '${c.guests}'}),
                    ].join('  ·  ')),
              ],
              if (c.note.trim().isNotEmpty) row(Icons.edit_note_rounded, 'order_preview_note'.tr, c.note.trim()),
              Divider(color: theme.hintColor.withValues(alpha: 0.2), height: 20),
              for (final line in c.cartLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 34, child: Text('${line.quantity}×', style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.primaryColor))),
                    Expanded(child: Text(line.item.name, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: text))),
                    Text(PriceConverter.convertPrice(line.item.price * line.quantity), style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: text)),
                  ]),
                ),
              Divider(color: theme.hintColor.withValues(alpha: 0.2), height: 20),
              money('order_preview_items'.tr, quote.itemsSubtotal),
              if (way == 'delivery') money('delivery_fee'.tr, quote.deliveryFee),
              money('total'.tr, quote.total, bold: true),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.verified_user_outlined, size: 18, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'order_preview_pay'.trParams({'method': gateway ?? 'mobile_money'.tr, 'store': store?.name ?? ''}),
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: text),
                  )),
                ]),
              ),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                child: Text('order_preview_change'.tr),
              )),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: theme.primaryColor, minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                child: Text('order_preview_send'.tr, style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeDefault)),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}
