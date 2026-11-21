import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_model.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_order_model.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// A store in the list: cover, logo, name, open state, prep time, distance.
class StoreCard extends StatelessWidget {
  final StoreModel store;
  final VoidCallback onTap;
  const StoreCard({super.key, required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '${store.name}, ${store.openNow ? 'open_now'.tr : 'closed_now'.tr}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            border: Border.all(color: theme.hintColor.withValues(alpha: 0.18)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              AspectRatio(
                aspectRatio: 2.6,
                child: store.cover != null
                    ? ImageWidget(image: store.cover!, fit: BoxFit.cover)
                    : Container(
                        color: theme.primaryColor.withValues(alpha: 0.08),
                        alignment: Alignment.center,
                        child: Icon(store.isShop ? Icons.storefront_rounded : Icons.restaurant_rounded, size: 40, color: theme.primaryColor.withValues(alpha: 0.6)),
                      ),
              ),
              if (!store.openNow)
                Positioned.fill(child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  alignment: Alignment.center,
                  child: Text(
                    store.opensAt != null ? '${'closed_opens_at'.tr} ${store.opensAt}' : 'closed_now'.tr,
                    style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeDefault),
                  ),
                )),
            ]),
            Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              child: Row(children: [
                StoreLogo(url: store.logo, size: 44, isShop: store.isShop),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(store.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyMedium?.color)),
                  const SizedBox(height: 2),
                  if (store.openNow)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF12A150), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('open_now'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: const Color(0xFF12A150))),
                      ]),
                    ),
                  Row(children: [
                    if (store.rating != null && store.ratingCount > 0) ...[
                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5A623)),
                      const SizedBox(width: 2),
                      Text(store.rating!.toStringAsFixed(1), style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color)),
                      Text(' (${store.ratingCount})  ·  ', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                    ],
                    Expanded(child: Text(
                    [
                      '${store.prepMinutes} ${'min'.tr}',
                      // A brand with branches: the distance is to the branch that would cook.
                      if (store.distanceKm != null) store.branchCount > 1 && store.branchName != null
                          ? '${store.distanceKm!.toStringAsFixed(1)} km (${store.branchName})'
                          : '${store.distanceKm!.toStringAsFixed(1)} km',
                      if (store.branchCount > 1) 'n_branches'.trParams({'n': '${store.branchCount}'}),
                      if (store.description != null && store.description!.isNotEmpty) store.description!,
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor),
                  )),
                  ]),
                ])),
                Icon(Icons.chevron_right_rounded, color: theme.hintColor),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class StoreLogo extends StatelessWidget {
  final String? url;
  final double size;
  final bool isShop;
  const StoreLogo({super.key, this.url, this.size = 44, this.isShop = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null
          ? ImageWidget(image: url!, fit: BoxFit.cover)
          : Icon(isShop ? Icons.storefront_rounded : Icons.restaurant_rounded, color: theme.primaryColor, size: size * 0.5),
    );
  }
}

/// "Add" button that becomes a  -  2  +  stepper once the item is in the cart.
class QuantityStepper extends StatelessWidget {
  final int quantity;
  final bool enabled;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final String itemName;
  const QuantityStepper({super.key, required this.quantity, required this.onAdd, required this.onRemove, required this.itemName, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    if (quantity == 0) {
      return Semantics(
        button: true,
        label: '${'add'.tr} $itemName',
        child: Material(
          color: enabled ? primary : Theme.of(context).disabledColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusOverLarge),
          child: InkWell(
            borderRadius: BorderRadius.circular(Dimensions.radiusOverLarge),
            onTap: enabled ? onAdd : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('add'.tr, style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeDefault)),
            ),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: primary),
        borderRadius: BorderRadius.circular(Dimensions.radiusOverLarge),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _round(context, Icons.remove_rounded, onRemove, '${'remove'.tr} $itemName'),
        SizedBox(
          width: 26,
          child: Text('$quantity', textAlign: TextAlign.center,
              style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: primary),
              semanticsLabel: '$quantity $itemName'),
        ),
        _round(context, Icons.add_rounded, enabled ? onAdd : null, '${'add'.tr} $itemName'),
      ]),
    );
  }

  Widget _round(BuildContext context, IconData icon, VoidCallback? onTap, String label) => Semantics(
        button: true,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 20, color: Theme.of(context).primaryColor)),
        ),
      );
}

class PriceRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;
  const PriceRow({super.key, required this.label, required this.amount, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.bodyMedium?.color;
    final style = (bold ? textBold : textRegular).copyWith(fontSize: bold ? Dimensions.fontSizeLarge : Dimensions.fontSizeDefault, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: style)),
        Text(PriceConverter.convertPrice(amount), style: style),
      ]),
    );
  }
}

/// Coloured status chip for an order.
class OrderStatusChip extends StatelessWidget {
  final String status;
  const OrderStatusChip({super.key, required this.status});

  static String label(String status) => switch (status) {
        StoreOrderModel.awaitingConfirmation => 'order_waiting_confirm'.tr,
        StoreOrderModel.changesProposed => 'order_changes'.tr,
        StoreOrderModel.awaitingPayment => 'order_awaiting_payment'.tr,
        StoreOrderModel.placed => 'order_waiting_store'.tr,
        StoreOrderModel.accepted => 'order_preparing'.tr,
        StoreOrderModel.riderRequested => 'order_rider'.tr,
        StoreOrderModel.pickedUp => 'order_on_the_way'.tr,
        StoreOrderModel.delivered => 'order_delivered'.tr,
        StoreOrderModel.rejected => 'order_declined'.tr,
        StoreOrderModel.cancelled => 'order_cancelled'.tr,
        StoreOrderModel.expired => 'order_expired'.tr,
        StoreOrderModel.deliveryFailed => 'order_not_delivered'.tr,
        _ => status,
      };

  /// One line for an order in a banner: eat there and collect say how and when.
  static String orderLine(StoreOrderModel o) {
    if (o.isDelivery || o.status != StoreOrderModel.accepted) return label(o.status);
    if (o.readyTold) return 'order_line_ready'.tr;
    final DateTime? t = o.arriveAt?.toLocal();
    final String time = t == null ? '' : '  ·  ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${o.isDineIn ? 'order_way_dine_in'.tr : 'order_way_pickup'.tr}$time';
  }

  static IconData orderIcon(StoreOrderModel o) =>
      o.isDineIn ? Icons.restaurant_rounded : o.isPickup ? Icons.shopping_bag_rounded : Icons.delivery_dining_rounded;

  /// "Track" for a delivery, "Open" otherwise.
  static String orderAction(StoreOrderModel o) => o.isDelivery ? 'track'.tr : 'act_open'.tr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color color = switch (status) {
      StoreOrderModel.delivered => const Color(0xFF12A150),
      StoreOrderModel.rejected || StoreOrderModel.cancelled || StoreOrderModel.expired || StoreOrderModel.deliveryFailed => theme.hintColor,
      _ => theme.primaryColor,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Dimensions.radiusOverLarge)),
      child: Text(label(status), style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: color)),
    );
  }
}


/// Shares a partner store's public page: the menu or shelves, opened in the app or on the web.
Future<void> shareStoreLink(StoreModel store) async {
  if (store.link == null) return;
  await SharePlus.instance.share(ShareParams(text: 'store_share_text'.trParams({'store': store.name ?? '', 'link': store.link!})));
}
