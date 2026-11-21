import 'package:url_launcher/url_launcher.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/set_destination/screens/set_destination_screen.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/location/view/pick_map_screen.dart';
import 'package:ride_sharing_user_app/features/assistant/widgets/help_button.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/call_options_sheet.dart';
import 'package:ride_sharing_user_app/common_widgets/unread_badge.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/map/screens/map_screen.dart';
import 'package:ride_sharing_user_app/features/message/controllers/chat_inbox_controller.dart';
import 'package:ride_sharing_user_app/features/message/controllers/message_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/payment/controllers/payment_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_order_model.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_checkout_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_payment_screen.dart';
import 'package:ride_sharing_user_app/features/store/widgets/store_rating_sheet.dart';
import 'package:ride_sharing_user_app/features/store/widgets/store_widgets.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class StoreOrderScreen extends StatefulWidget {
  final String orderId;
  final bool justPlaced;
  const StoreOrderScreen({super.key, required this.orderId, this.justPlaced = false});

  @override
  State<StoreOrderScreen> createState() => _StoreOrderScreenState();
}

class _StoreOrderScreenState extends State<StoreOrderScreen> {
  late final StoreController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<StoreController>();
    if (_controller.order?.id != widget.orderId) _controller.order = null;
    _controller.watchOrder(widget.orderId);
    // Ready to pay once the restaurant confirms: gateways and the wallet balance.
    if (Get.find<PaymentController>().paymentGateways?.isEmpty ?? true) Get.find<PaymentController>().getPaymentGetWayList();
    Get.find<ProfileController>().getProfileInfo();
  }

  String? _preparedPaymentFor;

  /// The payment choice starts as the one made at checkout.
  void _preparePayment(StoreOrderModel o) {
    if (_preparedPaymentFor == o.id || !o.isConfirmedUnpaid) return;
    _preparedPaymentFor = o.id;
    // The gateway chosen at checkout; anything else reads as the first one offered.
    if (o.paymentMethod != null) _controller.paymentMethod = o.paymentMethod!;
  }

  Future<void> _pay(StoreOrderModel o) async {
    final result = await _controller.payConfirmed(o);
    if (result.payUrl != null) {
      await Get.to<bool>(() => StorePaymentScreen(url: result.payUrl!));
    }
    _controller.loadOrder(o.id);
  }

  Future<void> _answer(StoreOrderModel o, bool accept) async {
    if (!accept) {
      final sure = await Get.dialog<bool>(AlertDialog(
        title: Text('cancel_order_question'.tr),
        content: Text('cancel_order_unpaid_hint'.tr),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text('keep_order'.tr)),
          TextButton(onPressed: () => Get.back(result: true), child: Text('cancel_order'.tr, style: TextStyle(color: Theme.of(context).primaryColor))),
        ],
      ));
      if (sure != true) return;
    }
    await _controller.answerChanges(o.id, accept);
  }

  @override
  void dispose() {
    _controller.stopWatching();
    super.dispose();
  }

  String _clock(DateTime? t) => t == null ? '' : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// "13:51" today, "Yesterday 13:51", or "2 Nov 13:51": an order can span days.
  String _stamp(DateTime? t) {
    if (t == null) return '';
    final DateTime now = DateTime.now();
    final DateTime day = DateTime(t.year, t.month, t.day);
    final int daysAgo = DateTime(now.year, now.month, now.day).difference(day).inDays;
    if (daysAgo == 0) return _clock(t);
    if (daysAgo == 1) return '${'yesterday'.tr}\n${_clock(t)}';
    // Default locale on purpose: the app does not load intl's French date data.
    return '${DateFormat('d MMM').format(t)}\n${_clock(t)}';
  }

  /// Opens the rating sheet by itself once, the first time a delivered order shows.
  void _maybePromptRating(StoreOrderModel o) {
    if (!_controller.shouldPromptRating(o)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Get.isBottomSheetOpen != true) StoreRatingSheet.show(o);
    });
  }

  ({IconData icon, String title, String subtitle}) _hero(StoreOrderModel o) {
    final store = o.storeName ?? '';
    if (o.isConfirmedUnpaid) {
      return (icon: Icons.verified_rounded, title: 'order_confirmed_title'.trParams({'store': store}),
          subtitle: o.byStore ? 'order_confirmed_staff_hint'.tr : 'order_confirmed_hint'.tr);
    }
    // The shop's own staff bring it (a customer close by): no rider to find or follow.
    if (o.byStore && o.status == StoreOrderModel.accepted) {
      return (
        icon: Icons.soup_kitchen_rounded,
        title: 'order_preparing_title'.trParams({'store': store}),
        subtitle: o.readyAt != null ? 'order_staff_ready_about'.trParams({'time': _clock(o.readyAt)}) : 'order_staff_will_bring'.tr,
      );
    }
    if (o.byStore && o.status == StoreOrderModel.pickedUp) {
      return (icon: Icons.directions_walk_rounded, title: 'order_on_the_way_title'.tr, subtitle: 'order_staff_on_the_way_hint'.trParams({'store': store}));
    }
    // Eat there or collect, paid: when it will be ready, then "it is ready".
    if (!o.isDelivery && o.status == StoreOrderModel.accepted) {
      final String time = o.arriveAt != null ? _stamp(o.arriveAt) : '';
      return o.readyTold
          ? (icon: Icons.room_service_rounded, title: 'order_here_ready_title'.trParams({'store': store}), subtitle: 'order_here_show_code'.tr)
          : (icon: o.isDineIn ? Icons.restaurant_rounded : Icons.shopping_bag_rounded,
              title: (o.isDineIn ? 'order_here_table_title' : 'order_here_collect_title').trParams({'store': store, 'time': time}),
              subtitle: 'order_here_show_code'.tr);
    }
    if (!o.isDelivery && o.status == StoreOrderModel.delivered) {
      return (icon: Icons.check_circle_rounded, title: 'order_here_done_title'.tr, subtitle: 'order_delivered_hint'.tr);
    }
    return switch (o.status) {
      StoreOrderModel.awaitingConfirmation => (icon: Icons.hourglass_top_rounded, title: 'order_waiting_confirm_title'.trParams({'store': store}), subtitle: 'order_waiting_confirm_hint'.tr),
      StoreOrderModel.changesProposed => (icon: Icons.edit_note_rounded, title: 'order_changes_title'.trParams({'store': store}), subtitle: 'order_changes_hint'.tr),
      StoreOrderModel.awaitingPayment => (icon: Icons.payments_outlined, title: 'order_awaiting_payment'.tr, subtitle: 'order_awaiting_payment_hint'.tr),
      StoreOrderModel.placed => (icon: Icons.storefront_rounded, title: 'order_waiting_store_title'.trParams({'store': store}), subtitle: 'order_waiting_store_hint'.tr),
      StoreOrderModel.accepted => (
          icon: Icons.soup_kitchen_rounded,
          title: 'order_preparing_title'.trParams({'store': store}),
          subtitle: o.readyAt != null ? 'order_ready_about'.trParams({'time': _clock(o.readyAt)}) : 'order_preparing'.tr,
        ),
      StoreOrderModel.riderRequested => o.riderName != null
          ? (icon: Icons.two_wheeler_rounded, title: 'order_rider_to_store'.trParams({'rider': o.riderName!, 'store': store}), subtitle: 'order_rider_to_store_hint'.tr)
          : (icon: Icons.search_rounded, title: 'order_finding_rider'.tr, subtitle: 'order_finding_rider_hint'.tr),
      StoreOrderModel.pickedUp => (icon: Icons.delivery_dining_rounded, title: 'order_on_the_way_title'.tr, subtitle: 'order_on_the_way_hint'.trParams({'rider': o.riderName ?? ''})),
      StoreOrderModel.delivered => (icon: Icons.check_circle_rounded, title: 'order_delivered_title'.tr, subtitle: 'order_delivered_hint'.tr),
      StoreOrderModel.deliveryFailed => (icon: Icons.report_gmailerrorred_rounded, title: 'order_not_delivered'.tr, subtitle: 'order_not_delivered_hint'.tr),
      StoreOrderModel.expired => (icon: Icons.timer_off_outlined, title: 'order_expired'.tr, subtitle: 'order_expired_hint'.tr),
      _ => (
          icon: Icons.cancel_outlined,
          title: o.status == StoreOrderModel.rejected ? 'order_declined_title'.trParams({'store': store}) : 'order_cancelled'.tr,
          subtitle: o.refundedAmount > 0
              ? 'order_refunded_hint'.trParams({'amount': PriceConverter.convertPrice(o.refundedAmount)})
              // Cancelled after payment with refunds off: no refund promised, E-Ride follows up.
              : o.paymentStatus == 'paid'
                  ? [if (o.cancelReason?.isNotEmpty ?? false) o.cancelReason!, 'order_paid_contact_hint'.tr].join(' · ')
                  : (o.cancelReason ?? ''),
        ),
    };
  }

  Future<void> _track(StoreOrderModel o) async {
    final ride = Get.find<RideController>();
    final response = await ride.getRideDetails(o.tripRequestId!);
    if (response.statusCode != 200) return;
    Get.find<ParcelController>().updateParcelState(
      ride.tripDetails?.currentStatus == 'ongoing' ? ParcelDeliveryState.parcelOngoing : ParcelDeliveryState.otpSent,
    );
    ride.startLocationRecord();
    Get.find<MapController>().notifyMapController();
    MapScreen.open(MapScreen(fromScreen: MapScreenType.parcel, title: '${'order'.tr} #${o.ref ?? ''}'));
  }

  /// "The shop brings it": the customer has their order. Asked once more, since it closes the order.
  Future<void> _received(StoreOrderModel o) async {
    final sure = await Get.dialog<bool>(AlertDialog(
      title: Text('order_received_question'.tr),
      content: Text('order_received_hint'.trParams({'store': o.storeName ?? ''})),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('not_yet'.tr)),
        TextButton(onPressed: () => Get.back(result: true), child: Text('order_received_yes'.tr, style: TextStyle(color: Theme.of(context).primaryColor))),
      ],
    ));
    if (sure == true) await _controller.confirmReceived(o.id);
  }

  Future<void> _payAgain(StoreOrderModel o) async {
    final gateways = _controller.gateways;
    final method = o.paymentMethod != null && o.paymentMethod != 'wallet' ? o.paymentMethod! : (gateways.isNotEmpty ? gateways.first.gateway : null);
    if (method == null) return;
    await Get.to<bool>(() => StorePaymentScreen(url: _controller.payUrlFor(o, method)));
    _controller.loadOrder(o.id);
  }

  void _confirmCancel(StoreOrderModel o) {
    Get.dialog(AlertDialog(
      title: Text('cancel_order_question'.tr),
      content: Text(o.paymentStatus == 'paid' ? 'cancel_order_refund_hint'.tr : 'cancel_order_unpaid_hint'.tr),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text('keep_order'.tr)),
        TextButton(
          onPressed: () async {
            Get.back();
            await _controller.cancelOrder(o.id);
          },
          child: Text('cancel_order'.tr, style: TextStyle(color: Theme.of(context).primaryColor)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color;
    return Scaffold(
      body: GetBuilder<StoreController>(builder: (controller) {
        final o = controller.order;
        if (o != null && o.id == widget.orderId) {
          _maybePromptRating(o);
          _preparePayment(o);
        }
        return BodyWidget(
          appBar: AppBarWidget(title: o?.ref != null ? '${'order'.tr} #${o!.ref}' : 'order'.tr, showBackButton: true),
          body: o == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  color: theme.primaryColor,
                  onRefresh: () async => controller.loadOrder(o.id),
                  child: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
                    _HeroCard(
                      hero: _hero(o),
                      active: o.isActive || o.status == StoreOrderModel.awaitingPayment,
                      done: o.status == StoreOrderModel.delivered,
                      // Who has to act, and the time left.
                      deadline: o.respondBy ?? o.answerBy ?? o.payBy,
                      deadlineLabel: o.respondBy != null ? 'store_answers_within'.tr : (o.answerBy != null ? 'answer_within'.tr : 'pay_within'.tr),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeDefault),
                    if (o.isDelivery && !o.isClosedUnhappily && o.status != StoreOrderModel.awaitingPayment && !o.isBeforePayment) _Steps(order: o, clock: _stamp),

                    // Eat there or collect: the code to show, the way there, and "deliver it instead".
                    if (!o.isDelivery) _HereCard(order: o, clock: _stamp),

                    // The shop's own staff bring it: who comes, the code for the door, "I have it".
                    if (o.byStore && (o.isConfirmedUnpaid || o.status == StoreOrderModel.accepted || o.status == StoreOrderModel.pickedUp))
                      _StaffCard(order: o, busy: controller.confirmingReceived, onReceived: () => _received(o)),

                    if (o.status == StoreOrderModel.changesProposed && o.proposal != null)
                      _ChangesCard(order: o, onAccept: () => _answer(o, true), onCancel: () => _answer(o, false)),

                    if (o.isConfirmedUnpaid)
                      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('pay_with'.tr, style: textBold.copyWith(color: textColor, fontSize: Dimensions.fontSizeDefault))),
                          const HelpButton(helpKey: 'payments', size: 18),
                        ]),
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                        if (o.payBy != null && DateTime.now().isAfter(o.payBy!))
                          // The time is over: no payment can start (the server refuses too).
                          Text('pay_time_over'.tr, style: textMedium.copyWith(color: theme.colorScheme.error, fontSize: Dimensions.fontSizeDefault))
                        else ...[
                          StorePaymentChoices(controller: controller, total: o.total),
                          const SizedBox(height: 4),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: theme.primaryColor, minimumSize: const Size.fromHeight(52)),
                            onPressed: controller.paying || !_walletCovers(controller, o) ? null : () => _pay(o),
                            child: controller.paying
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : Text('${'pay_now'.tr} · ${PriceConverter.convertPrice(o.total)}', style: textBold.copyWith(color: Colors.white)),
                          ),
                        ],
                      ])),

                    if (o.riderName != null && (o.status == StoreOrderModel.riderRequested || o.status == StoreOrderModel.pickedUp))
                      _Card(child: Row(children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                          child: o.riderImage != null
                              ? ClipOval(child: ImageWidget(image: o.riderImage!, width: 44, height: 44))
                              : Icon(Icons.person_rounded, color: theme.primaryColor),
                        ),
                        const SizedBox(width: Dimensions.paddingSizeSmall),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(o.riderName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: textBold.copyWith(color: textColor, fontSize: Dimensions.fontSizeDefault)),
                          Text('your_rider'.tr, style: textRegular.copyWith(color: theme.hintColor, fontSize: Dimensions.fontSizeSmall)),
                        ])),
                        if (o.riderId != null && o.tripRequestId != null)
                          GetBuilder<ChatInboxController>(builder: (inbox) => UnreadBadge(
                            count: inbox.unreadForTrip(o.tripRequestId),
                            offset: const Offset(-4, -2),
                            child: _RoundAction(
                              tooltip: 'message'.tr,
                              icon: Icons.chat_bubble_rounded,
                              onTap: () => Get.find<MessageController>().createChannel(o.riderId!, o.tripRequestId),
                            ),
                          )),
                        if (o.riderPhone != null) ...[
                          const SizedBox(width: 6),
                          _RoundAction(
                            tooltip: 'call'.tr,
                            icon: Icons.call_rounded,
                            onTap: () => CallOptionsSheet.show(phone: o.riderPhone, name: o.riderName),
                          ),
                        ],
                        if (o.canTrack) ...[
                          const SizedBox(width: 6),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: theme.primaryColor),
                            onPressed: () => _track(o),
                            icon: const Icon(Icons.map_rounded, size: 18),
                            label: Text('track'.tr),
                          ),
                        ],
                      ])),

                    if (o.canReview) _RateCard(order: o),
                    if (o.review != null) _RatedCard(order: o),

                    _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        StoreLogo(url: o.storeLogo, size: 36),
                        const SizedBox(width: Dimensions.paddingSizeSmall),
                        Expanded(child: Text(o.storeName ?? '', style: textBold.copyWith(color: textColor, fontSize: Dimensions.fontSizeDefault))),
                        if (o.storePhone != null && (o.isActive || o.isBeforePayment))
                          IconButton(tooltip: 'call'.tr, onPressed: () => CallOptionsSheet.show(phone: o.storePhone, name: o.storeName), icon: Icon(Icons.call_outlined, color: theme.primaryColor)),
                      ]),
                      const Divider(),
                      for (final line in o.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            SizedBox(width: 30, child: Text('${line.quantity}x', style: textBold.copyWith(color: textColor, fontSize: Dimensions.fontSizeDefault))),
                            Expanded(child: Text(line.name, style: textRegular.copyWith(color: textColor, fontSize: Dimensions.fontSizeDefault))),
                            Text(PriceConverter.convertPrice(line.lineTotal), style: textRegular.copyWith(color: textColor, fontSize: Dimensions.fontSizeDefault)),
                          ]),
                        ),
                      if (o.note != null && o.note!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('"${o.note}"', style: textRegular.copyWith(color: theme.hintColor, fontSize: Dimensions.fontSizeSmall, fontStyle: FontStyle.italic)),
                        ),
                      const Divider(),
                      PriceRow(label: 'items_subtotal'.tr, amount: o.itemsSubtotal),
                      if (o.isDelivery) PriceRow(label: o.byStore ? 'delivery_by_shop_fee'.tr : 'delivery_fee'.tr, amount: o.deliveryFee),
                      PriceRow(label: 'total'.tr, amount: o.total, bold: true),
                      if (o.refundedAmount > 0)
                        Text('${'refunded_to_wallet'.tr}: ${PriceConverter.convertPrice(o.refundedAmount)}',
                            style: textMedium.copyWith(color: const Color(0xFF12A150), fontSize: Dimensions.fontSizeSmall)),
                    ])),

                    if (o.isDelivery)
                    _Card(child: Row(children: [
                      Icon(Icons.location_on_rounded, color: theme.primaryColor),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Expanded(child: Text(o.dropAddress ?? '', style: textRegular.copyWith(color: textColor, fontSize: Dimensions.fontSizeDefault))),
                    ])),

                    // Older pay-first orders whose gateway payment did not finish.
                    if (o.status == StoreOrderModel.awaitingPayment && !o.isConfirmedUnpaid && controller.gateways.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: theme.primaryColor, minimumSize: const Size.fromHeight(52)),
                          onPressed: () => _payAgain(o),
                          child: Text('${'complete_payment'.tr} · ${PriceConverter.convertPrice(o.total)}', style: textBold.copyWith(color: Colors.white)),
                        ),
                      ),
                    if (o.canCancel && o.status != StoreOrderModel.changesProposed)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), side: BorderSide(color: theme.hintColor.withValues(alpha: 0.4))),
                        onPressed: () => _confirmCancel(o),
                        child: Text('cancel_order'.tr, style: textMedium.copyWith(color: textColor)),
                      ),
                  ]),
                ),
        );
      }),
    );
  }

  bool _walletCovers(StoreController c, StoreOrderModel o) {
    // Mobile Money only: usable once a gateway is offered.
    return c.paymentMethod.isNotEmpty;
  }
}

/// Eat there or collect: when, for how many, the code to show, the way there,
/// and "Deliver it instead" while the order is open.
class _HereCard extends StatelessWidget {
  final StoreOrderModel order;
  final String Function(DateTime?) clock;
  const _HereCard({required this.order, required this.clock});

  Future<void> _deliverInstead(BuildContext context) async {
    final StoreController c = Get.find<StoreController>();
    Get.to(() => PickMapScreen(
      type: LocationType.location,
      onLocationPicked: (position, address) async {
        final preview = await c.deliverInstead(order, position.latitude, position.longitude, address, preview: true);
        if (!preview.ok || preview.fee == null) return;
        final bool? go = await Get.dialog<bool>(AlertDialog(
          title: Text('order_deliver_instead'.tr),
          content: Text((preview.paid ? 'order_deliver_confirm_paid' : 'order_deliver_confirm').trParams({
            'fee': PriceConverter.convertPrice(preview.fee!),
            'address': address,
          })),
          actions: [
            TextButton(onPressed: () => Get.back(result: false), child: Text('cancel'.tr)),
            TextButton(onPressed: () => Get.back(result: true), child: Text(preview.paid ? 'order_deliver_pay_fee'.tr : 'order_deliver_yes'.tr)),
          ],
        ));
        if (go != true) return;
        final r = await c.deliverInstead(order, position.latitude, position.longitude, address);
        if (r.ok && r.payUrl != null) {
          await Get.to<bool>(() => StorePaymentScreen(url: r.payUrl!));
        }
        c.loadOrder(order.id);
      },
    ));
  }

  Future<void> _directions() async {
    if (order.storeLatitude == null) return;
    final Uri uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${order.storeLatitude},${order.storeLongitude}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _rideThere() {
    if (order.storeLatitude == null) return;
    Get.to(() => SetDestinationScreen(address: Address(
      latitude: order.storeLatitude,
      longitude: order.storeLongitude,
      address: '${order.storeName ?? ''}, ${order.storeAddress ?? ''}',
      addressLabel: 'others',
    )));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final bool open = order.isActive || order.isBeforePayment || order.status == StoreOrderModel.awaitingPayment;
    return Container(
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(color: theme.hintColor.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(order.isDineIn ? Icons.restaurant_rounded : Icons.shopping_bag_rounded, color: theme.primaryColor),
          const SizedBox(width: 8),
          Expanded(child: Text(
            [
              order.isDineIn ? 'order_way_dine_in'.tr : 'order_way_pickup'.tr,
              if (order.arriveAt != null) clock(order.arriveAt),
              if (order.isDineIn && order.guests != null) 'order_n_people'.trParams({'n': '${order.guests}'}),
            ].join('  ·  '),
            style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor),
          )),
        ]),
        if (order.storeAddress != null) ...[
          const SizedBox(height: 4),
          Text(order.storeAddress!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ],
        // The code, big, once paid.
        if (order.collectCode != null) ...[
          const SizedBox(height: Dimensions.paddingSize),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              Text('order_your_code'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              const SizedBox(height: 4),
              Text(order.collectCode!, style: textBold.copyWith(fontSize: 36, letterSpacing: 10, color: theme.primaryColor)),
              Text('order_code_hint'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ]),
          ),
        ],
        if (open && order.storeLatitude != null) ...[
          const SizedBox(height: Dimensions.paddingSize),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _directions,
              icon: const Icon(Icons.directions_rounded, size: 18),
              label: Text('directions'.tr),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            )),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(
              onPressed: _rideThere,
              icon: const Icon(Icons.local_taxi_rounded, size: 18),
              label: Text('ride_there'.tr),
              style: FilledButton.styleFrom(backgroundColor: theme.primaryColor, minimumSize: const Size.fromHeight(44)),
            )),
          ]),
        ],
        // Changed their mind: a rider brings it instead.
        if (order.deliveryChangeFee != null) ...[
          const SizedBox(height: Dimensions.paddingSize),
          Text('order_deliver_waiting_fee'.trParams({'fee': PriceConverter.convertPrice(order.deliveryChangeFee!)}),
              style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.colorScheme.error)),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Get.find<StoreController>().keepWay(order),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: Text(order.isDineIn ? 'order_keep_dine_in'.tr : 'order_keep_pickup'.tr, textAlign: TextAlign.center),
            )),
            if (order.deliveryChangePayUrl != null) ...[
              const SizedBox(width: 8),
              Expanded(child: FilledButton(
                onPressed: () async {
                  await Get.to<bool>(() => StorePaymentScreen(url: order.deliveryChangePayUrl!));
                  Get.find<StoreController>().loadOrder(order.id);
                },
                style: FilledButton.styleFrom(backgroundColor: theme.primaryColor, minimumSize: const Size.fromHeight(44)),
                child: Text('order_deliver_pay_fee'.tr),
              )),
            ],
          ]),
        ] else if (order.canDeliver) ...[
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Center(child: TextButton.icon(
            onPressed: () => _deliverInstead(context),
            icon: const Icon(Icons.delivery_dining_rounded),
            label: Text('order_deliver_instead'.tr),
          )),
        ],
      ]),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final ({IconData icon, String title, String subtitle}) hero;
  final bool active;
  final bool done;
  final DateTime? deadline;
  final String? deadlineLabel;
  const _HeroCard({required this.hero, required this.active, required this.done, this.deadline, this.deadlineLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = done ? const Color(0xFF12A150) : (active ? theme.primaryColor : theme.hintColor);
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
      ),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(hero.icon, color: Colors.white, size: 30),
        ),
        const SizedBox(width: Dimensions.paddingSizeDefault),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hero.title, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyMedium?.color)),
          if (hero.subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(hero.subtitle, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ],
          if (deadline != null) ...[
            const SizedBox(height: 6),
            _Countdown(deadline: deadline!, label: deadlineLabel ?? '', color: color),
          ],
        ])),
      ]),
    );
  }
}

/// "Pay within 9:12", ticking every second.
class _Countdown extends StatefulWidget {
  final DateTime deadline;
  final String label;
  final Color color;
  const _Countdown({required this.deadline, required this.label, required this.color});

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.deadline.difference(DateTime.now());
    final s = left.isNegative ? 0 : left.inSeconds;
    final text = '${widget.label} ${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Dimensions.radiusOverLarge)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer_outlined, size: 15, color: widget.color),
        const SizedBox(width: 4),
        Text(text, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: widget.color, fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}

/// The restaurant's suggested changes: what changes, the note, the new total, accept or cancel.
class _ChangesCard extends StatelessWidget {
  final StoreOrderModel order;
  final VoidCallback onAccept;
  final VoidCallback onCancel;
  const _ChangesCard({required this.order, required this.onAccept, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color;
    final p = order.proposal!;
    final muted = textRegular.copyWith(color: theme.hintColor, fontSize: Dimensions.fontSizeDefault, decoration: TextDecoration.lineThrough);
    final normal = textRegular.copyWith(color: textColor, fontSize: Dimensions.fontSizeDefault);
    Widget tag(String key, Color color) => Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Dimensions.radiusOverLarge)),
          child: Text(key.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: color)),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.4), width: 1.5),
        color: theme.primaryColor.withValues(alpha: 0.04),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('suggested_changes'.tr, style: textBold.copyWith(color: textColor, fontSize: Dimensions.fontSizeLarge)),
        if (p.note != null && p.note!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('"${p.note}"', style: textMedium.copyWith(color: textColor, fontSize: Dimensions.fontSizeDefault, fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: Dimensions.paddingSizeSmall),
        for (final l in p.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text.rich(TextSpan(children: [
                if (l.change == 'swapped') ...[
                  TextSpan(text: '${l.wasQuantity}x ${l.wasName}', style: muted),
                  TextSpan(text: '\n${l.quantity}x ${l.name}', style: normal),
                ] else if (l.change == 'removed')
                  TextSpan(text: '${l.wasQuantity}x ${l.name}', style: muted)
                else if (l.change == 'same')
                  TextSpan(text: '${l.quantity}x ${l.name}', style: normal)
                else ...[
                  TextSpan(text: '${l.wasQuantity}x', style: muted),
                  TextSpan(text: ' ${l.quantity}x ${l.name}', style: normal),
                ],
              ]))),
              if (l.change == 'removed') tag('change_removed', theme.colorScheme.error),
              if (l.change == 'reduced') tag('change_fewer', const Color(0xFFB45309)),
              if (l.change == 'increased') tag('change_more', const Color(0xFFB45309)),
              if (l.change == 'swapped') tag('change_instead', const Color(0xFF1D4ED8)),
              if (l.change != 'removed') ...[
                const SizedBox(width: 8),
                Text(PriceConverter.convertPrice(l.lineTotal), style: normal),
              ],
            ]),
          ),
        const Divider(),
        PriceRow(label: 'items_subtotal'.tr, amount: p.itemsSubtotal),
        PriceRow(label: 'delivery_fee'.tr, amount: order.deliveryFee),
        PriceRow(label: 'new_total'.tr, amount: p.total, bold: true),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: theme.primaryColor, minimumSize: const Size.fromHeight(50)),
          onPressed: onAccept,
          child: Text('accept_changes'.tr, style: textBold.copyWith(color: Colors.white)),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), side: BorderSide(color: theme.hintColor.withValues(alpha: 0.4))),
          onPressed: onCancel,
          child: Text('cancel_order'.tr, style: textMedium.copyWith(color: textColor)),
        ),
      ]),
    );
  }
}

class _Steps extends StatelessWidget {
  final StoreOrderModel order;
  final String Function(DateTime?) clock;
  const _Steps({required this.order, required this.clock});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const order0 = [StoreOrderModel.placed, StoreOrderModel.accepted, StoreOrderModel.riderRequested, StoreOrderModel.pickedUp, StoreOrderModel.delivered];
    final reached = order0.indexOf(order.status);
    final steps = [
      ('order_step_sent'.tr, order.placedAt, 0),
      ('order_step_preparing'.tr, order.acceptedAt, 1),
      ('order_step_on_the_way'.tr, order.pickedUpAt, 3),
      ('order_step_delivered'.tr, order.deliveredAt, 4),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      child: Row(children: [
        for (int i = 0; i < steps.length; i++) ...[
          Expanded(child: Column(children: [
            Row(children: [
              Expanded(child: Container(height: 3, color: i == 0 ? Colors.transparent : (reached >= steps[i].$3 ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.25)))),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: reached >= steps[i].$3 ? theme.primaryColor : theme.cardColor,
                  border: Border.all(color: reached >= steps[i].$3 ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.4), width: 2),
                ),
                child: reached >= steps[i].$3 ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
              ),
              Expanded(child: Container(height: 3, color: i == steps.length - 1 ? Colors.transparent : (reached >= steps[i + 1].$3 ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.25)))),
            ]),
            const SizedBox(height: 6),
            Text(steps[i].$1, textAlign: TextAlign.center, maxLines: 2,
                style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: reached >= steps[i].$3 ? theme.textTheme.bodyMedium?.color : theme.hintColor)),
            if (steps[i].$2 != null)
              Text(clock(steps[i].$2), textAlign: TextAlign.center, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
          ])),
        ],
      ]),
    );
  }
}

/// "The shop brings it": the customer is close by, so the shop's own staff
/// come instead of a rider. Says so, shows the code to give at the door once
/// paid, and lets the customer say they have their order once it is on the way.
class _StaffCard extends StatelessWidget {
  final StoreOrderModel order;
  final bool busy;
  final VoidCallback onReceived;
  const _StaffCard({required this.order, required this.busy, required this.onReceived});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color;
    return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.directions_walk_rounded, color: theme.primaryColor),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('order_staff_title'.trParams({'store': order.storeName ?? ''}), style: textBold.copyWith(color: textColor, fontSize: Dimensions.fontSizeDefault)),
          const SizedBox(height: 2),
          Text('order_staff_hint'.tr, style: textRegular.copyWith(color: theme.hintColor, fontSize: Dimensions.fontSizeSmall)),
        ])),
      ]),
      if (order.collectCode != null) ...[
        const SizedBox(height: Dimensions.paddingSize),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Text('order_your_code'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            const SizedBox(height: 4),
            Text(order.collectCode!, style: textBold.copyWith(fontSize: 36, letterSpacing: 10, color: theme.primaryColor)),
            Text('order_staff_code_hint'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ]),
        ),
      ],
      if (order.canConfirmReceived) ...[
        const SizedBox(height: Dimensions.paddingSize),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: theme.primaryColor, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: busy ? null : onReceived,
          icon: busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Icon(Icons.check_circle_outline_rounded, size: 20),
          label: Text('order_received_button'.tr, style: textBold.copyWith(color: Colors.white)),
        ),
      ],
    ]));
  }
}

/// Delivered and not rated yet: stars that open the sheet with that rating.
class _RateCard extends StatelessWidget {
  final StoreOrderModel order;
  const _RateCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: const Color(0xFFF5A623).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
      ),
      child: Column(children: [
        Text('how_was_your_order'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 2),
        Text((Get.find<ConfigController>().config?.reviewStatus ?? false) ? 'rate_card_hint'.tr : 'rate_card_hint_food'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        StarPicker(rating: 0, size: 38, onRate: (v) => StoreRatingSheet.show(order, initialStoreRating: v)),
      ]),
    );
  }
}

/// The rating the customer gave.
class _RatedCard extends StatelessWidget {
  final StoreOrderModel order;
  const _RatedCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final review = order.review!;
    final textColor = theme.textTheme.bodyMedium?.color;
    return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('your_rating'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      Row(children: [
        Expanded(child: Text(order.storeName ?? 'food'.tr, style: textRegular.copyWith(color: textColor, fontSize: Dimensions.fontSizeDefault))),
        StarsView(rating: review.storeRating),
      ]),
      if (review.storeComment != null && review.storeComment!.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('"${review.storeComment}"', style: textRegular.copyWith(color: theme.hintColor, fontSize: Dimensions.fontSizeSmall, fontStyle: FontStyle.italic)),
        ),
      if (review.riderRating != null) ...[
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text(order.riderFirstName ?? 'your_rider'.tr, style: textRegular.copyWith(color: textColor, fontSize: Dimensions.fontSizeDefault))),
          StarsView(rating: review.riderRating!),
        ]),
      ],
      const SizedBox(height: 6),
      Text('thanks_for_rating'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: const Color(0xFF12A150))),
    ]));
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: 0.18)),
      ),
      child: child,
    );
  }
}

/// Round icon button for the rider card: solid tint so it reads as tappable.
class _RoundAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  const _RoundAction({required this.tooltip, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, color: color, size: 22)),
        ),
      ),
    );
  }
}
