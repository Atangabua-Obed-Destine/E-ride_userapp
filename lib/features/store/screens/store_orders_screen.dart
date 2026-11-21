import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_order_screen.dart';
import 'package:ride_sharing_user_app/features/store/widgets/store_widgets.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class StoreOrdersScreen extends StatefulWidget {
  const StoreOrdersScreen({super.key});

  @override
  State<StoreOrdersScreen> createState() => _StoreOrdersScreenState();
}

class _StoreOrdersScreenState extends State<StoreOrdersScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame: home's active-order banner listens to this controller.
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<StoreController>().loadOrders());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color;
    return Scaffold(
      body: GetBuilder<StoreController>(builder: (controller) {
        final orders = controller.orders;
        return BodyWidget(
          appBar: AppBarWidget(title: 'my_orders'.tr, showBackButton: true),
          body: orders == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  color: theme.primaryColor,
                  onRefresh: controller.loadOrders,
                  child: orders.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 120),
                          Icon(Icons.receipt_long_outlined, size: 56, color: theme.hintColor),
                          const SizedBox(height: 8),
                          Text('no_orders_yet'.tr, textAlign: TextAlign.center, style: textMedium.copyWith(color: textColor)),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                          itemCount: orders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: Dimensions.paddingSizeSmall),
                          itemBuilder: (_, i) {
                            final o = orders[i];
                            return InkWell(
                              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                              onTap: () => Get.to(() => StoreOrderScreen(orderId: o.id)),
                              child: Container(
                                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                                  border: Border.all(color: theme.hintColor.withValues(alpha: 0.18)),
                                ),
                                child: Row(children: [
                                  StoreLogo(url: o.storeLogo, size: 44),
                                  const SizedBox(width: Dimensions.paddingSizeSmall),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(o.storeName ?? '', style: textBold.copyWith(color: textColor, fontSize: Dimensions.fontSizeDefault)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '#${o.ref ?? ''} · ${o.itemsCount} ${o.itemsCount == 1 ? 'item'.tr : 'items'.tr} · ${PriceConverter.convertPrice(o.total)}',
                                      style: textRegular.copyWith(color: theme.hintColor, fontSize: Dimensions.fontSizeSmall),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(children: [
                                      OrderStatusChip(status: o.status),
                                      // Delivered but not rated yet: a nudge, the order screen asks.
                                      if (o.canReview) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5A623)),
                                        const SizedBox(width: 2),
                                        Text('rate_order'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
                                      ] else if (o.review != null) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5A623)),
                                        const SizedBox(width: 2),
                                        Text('${o.review!.storeRating}', style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                                      ],
                                    ]),
                                  ])),
                                  Icon(Icons.chevron_right_rounded, color: theme.hintColor),
                                ]),
                              ),
                            );
                          },
                        ),
                ),
        );
      }),
    );
  }
}
