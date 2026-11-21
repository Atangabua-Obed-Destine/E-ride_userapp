import 'package:ride_sharing_user_app/features/assistant/widgets/help_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/location/view/pick_map_screen.dart';
import 'package:ride_sharing_user_app/features/payment/controllers/payment_controller.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_order_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_payment_screen.dart';
import 'package:ride_sharing_user_app/features/store/widgets/store_widgets.dart';
import 'package:ride_sharing_user_app/features/store/widgets/order_preview_sheet.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class StoreCheckoutScreen extends StatefulWidget {
  const StoreCheckoutScreen({super.key});

  @override
  State<StoreCheckoutScreen> createState() => _StoreCheckoutScreenState();
}

class _StoreCheckoutScreenState extends State<StoreCheckoutScreen> {
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final controller = Get.find<StoreController>();
    _note = TextEditingController(text: controller.note);
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.prepareCheckout());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _place(StoreController controller) async {
    controller.note = _note.text;
    // Everything once more before it goes to the store.
    final quote = controller.quote;
    if (quote == null || !await showOrderPreview(context, controller, quote)) return;
    final result = await controller.placeOrder();
    final order = result.order;
    if (order == null) return;
    if (result.payUrl != null) {
      final paid = await Get.to<bool>(() => StorePaymentScreen(url: result.payUrl!)) ?? false;
      if (!paid) {
        // The order waits for payment; it can be paid or cancelled from its screen.
        Get.until((route) => route.isFirst);
        Get.to(() => StoreOrderScreen(orderId: order.id));
        return;
      }
    }
    Get.until((route) => route.isFirst);
    Get.to(() => StoreOrderScreen(orderId: order.id, justPlaced: true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color;
    return Scaffold(
      body: GetBuilder<StoreController>(builder: (controller) {
        final quote = controller.quote;
        final lines = controller.cartLines;
        return BodyWidget(
          appBar: AppBarWidget(title: 'checkout'.tr, showBackButton: true),
          body: Column(children: [
            Expanded(child: ListView(
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              children: [
                // Delivery, eat there or collect: only what this store offers.
                if (controller.ways.length > 1)
                  _Section(title: 'order_way_title'.tr, child: _WayPicker(controller: controller)),

                if (controller.way == 'delivery')
                _Section(title: 'deliver_to'.tr, child: Row(children: [
                  Icon(Icons.location_on_rounded, color: theme.primaryColor),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Expanded(child: Text(
                    controller.dropAddress.isEmpty ? 'choose_delivery_address'.tr : controller.dropAddress,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: textMedium.copyWith(color: textColor, fontSize: Dimensions.fontSizeDefault),
                  )),
                  TextButton(
                    onPressed: () => Get.to(() => PickMapScreen(
                      type: LocationType.location,
                      onLocationPicked: (position, address) => controller.setDrop(position.latitude, position.longitude, address),
                    )),
                    child: Text('change'.tr, style: textBold.copyWith(color: theme.primaryColor)),
                  ),
                ]))
                else
                  _Section(
                    title: controller.way == 'dine_in' ? 'order_way_dine_in_title'.tr : 'order_way_pickup_title'.tr,
                    child: _WhenPicker(controller: controller),
                  ),

                _Section(title: controller.store?.name ?? 'your_order'.tr, child: Column(children: [
                  // Which branch cooks it, so nobody is surprised.
                  if (controller.branch != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Icon(Icons.storefront_rounded, size: 16, color: theme.primaryColor),
                        const SizedBox(width: 6),
                        Expanded(child: Text('cooked_at'.trParams({'branch': controller.store?.displayName ?? ''}),
                            style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor))),
                      ]),
                    ),
                  for (final line in lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(line.item.name, style: textMedium.copyWith(color: textColor, fontSize: Dimensions.fontSizeDefault)),
                          Text(PriceConverter.convertPrice(line.item.price * line.quantity),
                              style: textRegular.copyWith(color: theme.hintColor, fontSize: Dimensions.fontSizeSmall)),
                        ])),
                        QuantityStepper(
                          quantity: line.quantity,
                          itemName: line.item.name,
                          onAdd: () { controller.addItem(line.item); controller.requestQuoteSoon(); },
                          onRemove: () {
                            controller.removeItem(line.item.id);
                            if (controller.cartIsEmpty) {
                              Get.back();
                            } else {
                              controller.requestQuoteSoon();
                            }
                          },
                        ),
                      ]),
                    ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _note,
                    maxLength: 300,
                    maxLines: 2,
                    minLines: 1,
                    onChanged: (v) => controller.note = v,
                    decoration: InputDecoration(
                      hintText: 'order_note_hint'.tr,
                      counterText: '',
                      isDense: true,
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
                    ),
                  ),
                ])),

                _Section(title: 'pay_with'.tr, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // The restaurant confirms first (or suggests changes), then the customer pays.
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.verified_outlined, size: 18, color: theme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(child: Text('pay_after_confirm_hint'.trParams({'store': controller.store?.name ?? ''}),
                          style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor))),
                      const HelpButton(helpKey: 'food_pay', size: 18),
                    ]),
                  ),
                  StorePaymentChoices(controller: controller, total: quote?.total),
                ])),

                _Section(title: 'summary'.tr, child: Column(children: [
                  PriceRow(label: 'items_subtotal'.tr, amount: quote?.itemsSubtotal ?? controller.cartSubtotal),
                  if (controller.way == 'delivery')
                  Row(children: [
                    Expanded(child: Text(
                      quote?.distanceKm != null ? '${'delivery_fee'.tr} (${quote!.distanceKm!.toStringAsFixed(1)} km)' : 'delivery_fee'.tr,
                      style: textRegular.copyWith(color: textColor, fontSize: Dimensions.fontSizeDefault),
                    )),
                    controller.quoting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(quote != null && quote.deliveryFee > 0 ? PriceConverter.convertPrice(quote.deliveryFee) : '-',
                            style: textRegular.copyWith(color: textColor, fontSize: Dimensions.fontSizeDefault)),
                  ]),
                  const Divider(),
                  PriceRow(label: 'total'.tr, amount: quote?.total ?? controller.cartSubtotal, bold: true),
                ])),

                if (quote != null && !quote.ok)
                  Container(
                    padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                    decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (final p in quote.problems)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(Icons.error_outline_rounded, size: 18, color: theme.primaryColor),
                            const SizedBox(width: 6),
                            Expanded(child: Text(p, style: textMedium.copyWith(color: textColor, fontSize: Dimensions.fontSizeSmall))),
                          ]),
                        ),
                    ]),
                  ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                Text(controller.way == 'delivery' ? 'prepaid_delivery_hint'.tr : 'order_way_here_hint'.tr,
                    style: textRegular.copyWith(color: theme.hintColor, fontSize: Dimensions.fontSizeSmall)),
              ],
            )),

            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      disabledBackgroundColor: theme.disabledColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusOverLarge)),
                    ),
                    onPressed: (quote?.ok ?? false) && !controller.placing && !controller.quoting && _paymentUsable(controller, quote!.total)
                        ? () => _place(controller)
                        : null,
                    child: controller.placing
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(
                            quote?.ok ?? false ? '${'send_order'.tr} · ${PriceConverter.convertPrice(quote!.total)}' : 'send_order'.tr,
                            style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeLarge),
                          ),
                  ),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }

  bool _paymentUsable(StoreController controller, double total) {
    // Mobile Money only: usable once a gateway is offered.
    return controller.paymentMethod.isNotEmpty;
  }
}

/// Delivery, eat there or collect, as three cards.
class _WayPicker extends StatelessWidget {
  final StoreController controller;
  const _WayPicker({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget card(String way, IconData icon, String title, String sub) {
      final bool on = controller.way == way;
      return Expanded(child: Semantics(
        button: true,
        selected: on,
        label: title,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => controller.setWay(way),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: on ? theme.primaryColor.withValues(alpha: 0.08) : null,
              border: Border.all(color: on ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.25), width: on ? 1.6 : 1),
            ),
            child: Column(children: [
              Icon(icon, color: on ? theme.primaryColor : theme.hintColor),
              const SizedBox(height: 4),
              Text(title, textAlign: TextAlign.center, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
              Text(sub, textAlign: TextAlign.center, maxLines: 2, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
            ]),
          ),
        ),
      ));
    }
    final List<Widget> cards = [
      card('delivery', Icons.delivery_dining_rounded, 'order_way_delivery'.tr, 'order_way_delivery_sub'.tr),
      if (controller.ways.contains('dine_in')) card('dine_in', Icons.restaurant_rounded, 'order_way_dine_in'.tr, 'order_way_dine_in_sub'.tr),
      if (controller.ways.contains('pickup')) card('pickup', Icons.shopping_bag_rounded, 'order_way_pickup'.tr, 'order_way_pickup_sub'.tr),
    ];
    return Row(children: [
      for (int i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(width: 8), cards[i]],
    ]);
  }
}

/// Eat there or collect: the time they come (today or tomorrow), and for eating there how many people.
class _WhenPicker extends StatelessWidget {
  final StoreController controller;
  const _WhenPicker({required this.controller});

  Future<void> _pickTime(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime current = controller.arriveAt ?? now.add(const Duration(minutes: 30));
    final TimeOfDay? t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (t == null) return;
    DateTime chosen = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    // A time already past today means tomorrow.
    if (chosen.isBefore(now)) chosen = chosen.add(const Duration(days: 1));
    controller.setArriveAt(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final DateTime? at = controller.arriveAt;
    final DateTime now = DateTime.now();
    final bool tomorrow = at != null && (at.day != now.day || at.month != now.month);
    final String when = at == null
        ? 'order_way_pick_time'.tr
        : '${tomorrow ? 'tomorrow'.tr : 'today'.tr} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _pickTime(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.hintColor.withValues(alpha: 0.25))),
          child: Row(children: [
            Icon(Icons.schedule_rounded, color: theme.primaryColor),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(controller.way == 'dine_in' ? 'order_way_we_arrive'.tr : 'order_way_i_collect'.tr,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              Text(when, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
            ])),
            Text('change'.tr, style: textBold.copyWith(color: theme.primaryColor)),
          ]),
        ),
      ),
      if (controller.way == 'dine_in') ...[
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Row(children: [
          Icon(Icons.group_rounded, color: theme.primaryColor),
          const SizedBox(width: 10),
          Expanded(child: Text('order_way_people'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color))),
          IconButton(onPressed: controller.guests > 1 ? () => controller.setGuests(controller.guests - 1) : null, icon: const Icon(Icons.remove_circle_outline_rounded), tooltip: 'remove'.tr),
          Text('${controller.guests}', style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
          IconButton(onPressed: () => controller.setGuests(controller.guests + 1), icon: const Icon(Icons.add_circle_outline_rounded), tooltip: 'add'.tr),
        ]),
      ],
      const SizedBox(height: 4),
      Row(children: [
        Icon(Icons.place_outlined, size: 16, color: theme.hintColor),
        const SizedBox(width: 4),
        Expanded(child: Text((controller.cartStore ?? controller.store)?.address ?? '', maxLines: 2,
            style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
      ]),
    ]);
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(color: theme.hintColor.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyMedium?.color)),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        child,
      ]),
    );
  }
}

/// Wallet (when the balance covers it) or a payment gateway: at checkout, and
/// on the order screen once the restaurant confirms.
class StorePaymentChoices extends StatelessWidget {
  final StoreController controller;
  final double? total;
  const StorePaymentChoices({super.key, required this.controller, this.total});

  @override
  Widget build(BuildContext context) {
    // Mobile Money only (MTN MoMo or Orange Money): no wallet here.
    return GetBuilder<PaymentController>(builder: (_) {
      if (controller.gateways.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))),
        );
      }
      return Column(children: [
        for (final g in controller.gateways)
          _choice(
            context,
            value: g.gateway ?? '',
            title: g.gatewayTitle ?? g.gateway ?? '',
            leading: SizedBox(
              width: 34,
              height: 24,
              child: ImageWidget(
                image: '${AppConstants.baseUrl}/storage/app/public/payment_modules/gateway_image/${g.gatewayImage ?? ''}',
                fit: BoxFit.contain,
              ),
            ),
          ),
      ]);
    });
  }

  Widget _choice(BuildContext context, {required String value, required String title, String? subtitle, required Widget leading, bool enabled = true}) {
    final theme = Theme.of(context);
    final selected = controller.paymentMethod == value;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        onTap: enabled ? () => controller.setPaymentMethod(value) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            border: Border.all(color: selected ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.25), width: selected ? 1.6 : 1),
            color: selected ? theme.primaryColor.withValues(alpha: 0.06) : null,
          ),
          child: Row(children: [
            leading,
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyMedium?.color)),
              if (subtitle != null) Text(subtitle, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ])),
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? theme.primaryColor : theme.hintColor),
          ]),
        ),
      ),
    );
  }
}
