import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ride_sharing_user_app/features/deposit/controllers/deposit_controller.dart';
import 'package:ride_sharing_user_app/features/deposit/domain/models/trip_deposit_model.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/trip_details_model.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

String _clock(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// "14:30" today, else "Fri 20 Nov, 14:30", in the phone's time.
String _at(DateTime when) {
  final local = when.toLocal();
  final now = DateTime.now();
  final today = local.year == now.year && local.month == now.month && local.day == now.day;
  return today ? DateFormat('HH:mm').format(local) : DateFormat('EEE d MMM, HH:mm', Get.locale?.languageCode).format(local);
}

/// A ride booked ahead.
bool _isScheduled(TripDetails trip) => trip.type == 'scheduled_request';

/// A ride booked ahead that no driver has taken yet (its deposit is paid when booking).
bool _isBooking(TripDetails trip) => _isScheduled(trip) && trip.currentStatus == 'pending';

String _pickupTime(TripDetails trip) {
  final at = DateTime.tryParse(trip.scheduledAt ?? '');
  return at == null ? '' : _at(at);
}

/// Ticks once a second while it is on screen (for the countdowns).
mixin _Ticking<T extends StatefulWidget> on State<T> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
      onTick();
    });
  }

  void onTick() {}

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Shown after a driver accepts. Waiting: asks for the deposit, with the time
/// left and a button per payment method. Paid: a short confirmation, with
/// the free-cancellation time left. Nothing for trips without a deposit.
class DepositCard extends StatefulWidget {
  final TripDetails trip;
  const DepositCard({super.key, required this.trip});

  @override
  State<DepositCard> createState() => _DepositCardState();
}

class _DepositCardState extends State<DepositCard> with _Ticking {
  bool _refreshedAtZero = false;
  bool _showRules = false;

  @override
  void initState() {
    super.initState();
    if (widget.trip.deposit?.isAwaiting ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<DepositController>().prepare());
    }
  }

  @override
  void onTick() {
    final deposit = widget.trip.deposit;
    // Time ran out: ask the server (it cancels the trip within a few seconds).
    if (deposit != null && deposit.isAwaiting && deposit.timeLeft == Duration.zero && !_refreshedAtZero) {
      _refreshedAtZero = true;
      Get.find<DepositController>().reload(widget.trip.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deposit = widget.trip.deposit;
    if (deposit == null) return const SizedBox();
    if (deposit.isPaid) return _paid(context, deposit);
    if (!deposit.isAwaiting) return const SizedBox();
    return _awaiting(context, deposit);
  }

  Widget _paid(BuildContext context, TripDeposit deposit) {
    final theme = Theme.of(context);
    final freeLeft = deposit.freeCancelLeft;
    final trip = widget.trip;
    // A ride booked ahead: free cancellation runs until a time of day, not a countdown.
    final String note = _isScheduled(trip) && deposit.cancelFreeReason == 'before_pickup' && deposit.freeCancelUntil != null
        ? 'deposit_scheduled_free_until'.trParams({'time': _at(deposit.freeCancelUntil!)})
        : _isBooking(trip)
        ? 'deposit_booking_paid_note'.tr
        : freeLeft > Duration.zero && deposit.cancelFreeReason == 'free_window' && !_isScheduled(trip)
        ? 'deposit_free_cancel_left'.trParams({'time': _clock(freeLeft)})
        : trip.isMove ? 'move_deposit_paid_note'.tr
        : _isScheduled(trip) ? 'deposit_rule_counts'.tr : 'deposit_counts_toward_fare'.tr;
    return Container(
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(Dimensions.paddingSize),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Row(children: [
        Icon(Icons.verified_rounded, color: theme.primaryColor, size: 22),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('deposit_paid_title'.trParams({'amount': PriceConverter.convertPrice(deposit.amount)}),
              style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
          Text(note, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ])),
      ]),
    );
  }

  Widget _awaiting(BuildContext context, TripDeposit deposit) {
    final theme = Theme.of(context);
    final left = deposit.timeLeft;
    final urgent = left.inSeconds <= 45;
    final driver = (widget.trip.driver?.firstName ?? '').trim();
    final booking = _isBooking(widget.trip);
    final scheduled = _isScheduled(widget.trip);
    final String title = booking ? 'deposit_booking_title'.tr : 'deposit_confirm_title'.tr;
    final String body = booking
        ? 'deposit_booking_body'.trParams({'amount': PriceConverter.convertPrice(deposit.amount), 'time': _pickupTime(widget.trip)})
        : scheduled
        ? (Get.find<ConfigController>().config?.bookingDepositScheduledTiming == 'accept'
            ? (driver.isEmpty ? 'deposit_scheduled_accept_body_no_name' : 'deposit_scheduled_accept_body')
            : (driver.isEmpty ? 'deposit_scheduled_due_body_no_name' : 'deposit_scheduled_due_body')).trParams({
            'amount': PriceConverter.convertPrice(deposit.amount), 'driver': driver, 'time': _pickupTime(widget.trip)})
        : (widget.trip.isMove
            ? (driver.isEmpty ? 'move_deposit_confirm_body_no_name' : 'move_deposit_confirm_body')
            : (driver.isEmpty ? 'deposit_confirm_body_no_name' : 'deposit_confirm_body')).trParams({
            'amount': PriceConverter.convertPrice(deposit.amount),
            'driver': driver,
          });
    final List<String> rules = widget.trip.isMove
        ? ['move_rule_fee'.tr, 'deposit_rule_unpaid'.tr, 'deposit_rule_driver_cancels'.tr, 'move_rule_no_agreement'.tr]
        : scheduled
        ? ['deposit_rule_counts'.tr, (booking ? 'deposit_rule_unpaid_booking' : 'deposit_rule_unpaid_scheduled').tr,
            'deposit_rule_scheduled_cancel'.trParams({'minutes': '${Get.find<ConfigController>().config?.bookingDepositScheduledFreeCancelMinutes ?? 60}'}),
            'deposit_rule_scheduled_driver_cancels'.tr]
        : ['deposit_rule_counts'.tr, 'deposit_rule_unpaid'.tr, 'deposit_rule_driver_cancels'.tr, 'deposit_rule_late_cancel'.tr];
    return GetBuilder<DepositController>(builder: (controller) {
      final balance = controller.walletBalance;
      final walletShort = balance == null || balance + 0.001 < deposit.amount;
      return Container(
        margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border: Border.all(color: theme.primaryColor, width: 1.5),
          boxShadow: [BoxShadow(color: theme.primaryColor.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: 2),
              Text(
                body,
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.35),
              ),
            ])),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Semantics(
              label: 'deposit_time_left'.trParams({'time': _clock(left)}),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeExtraSmall),
                decoration: BoxDecoration(
                  color: (urgent ? theme.colorScheme.error : theme.primaryColor).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timer_outlined, size: 16, color: urgent ? theme.colorScheme.error : theme.primaryColor),
                  const SizedBox(width: 4),
                  Text(_clock(left), style: textRobotoBold.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    color: urgent ? theme.colorScheme.error : theme.primaryColor,
                  )),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: Dimensions.paddingSize),

          // The wallet only when the admin offers it (Trip management > Ways to pay).
          if (Get.find<ConfigController>().config?.paymentWalletStatus ?? true)
          _PayButton(
            label: 'deposit_pay_wallet'.trParams({'amount': PriceConverter.convertPrice(deposit.amount)}),
            sublabel: balance == null ? null : '${'balance'.tr}: ${PriceConverter.convertPrice(balance)}${walletShort ? '  ·  ${'not_enough'.tr}' : ''}',
            icon: Icons.account_balance_wallet_rounded,
            primary: true,
            busy: controller.payingWith == 'wallet',
            enabled: !controller.paying && !walletShort && left > Duration.zero,
            onTap: () => controller.payWithWallet(widget.trip.id!),
          ),
          for (final g in controller.gateways) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            _PayButton(
              label: 'deposit_pay_with'.trParams({'method': g.gatewayTitle ?? g.gateway ?? ''}),
              icon: Icons.phone_android_rounded,
              primary: walletShort || !(Get.find<ConfigController>().config?.paymentWalletStatus ?? true),
              busy: controller.payingWith == g.gateway,
              enabled: !controller.paying && left > Duration.zero,
              onTap: () => controller.payWithGateway(widget.trip.id!, g.gateway ?? ''),
            ),
          ],
          const SizedBox(height: Dimensions.paddingSizeSmall),

          InkWell(
            onTap: () => setState(() => _showRules = !_showRules),
            borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeExtraSmall),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 16, color: theme.hintColor),
                const SizedBox(width: 6),
                Expanded(child: Text('deposit_how_it_works'.tr,
                    style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
                Icon(_showRules ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: theme.hintColor),
              ]),
            ),
          ),
          if (_showRules)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final rule in rules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('•  $rule', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color, height: 1.35)),
                  ),
              ]),
            ),
        ]),
      );
    });
  }
}

class _PayButton extends StatelessWidget {
  final String label;
  final String? sublabel;
  final IconData icon;
  final bool primary;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;
  const _PayButton({required this.label, this.sublabel, required this.icon, required this.primary, required this.busy, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = primary ? Colors.white : theme.primaryColor;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.45,
      child: Material(
        color: primary ? theme.primaryColor : theme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSize, vertical: Dimensions.paddingSizeSmall),
              child: Row(children: [
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(label, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: fg)),
                  if (sublabel != null)
                    Text(sublabel!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: fg.withValues(alpha: 0.85))),
                ])),
                if (busy)
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                else
                  Icon(Icons.arrow_forward_rounded, color: fg, size: 18),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// What cancelling now does to the deposit, or null when there is none.
/// The bool is true when the customer would lose it.
(String, bool)? depositCancelMessage(TripDeposit? deposit) {
  if (deposit == null || !(deposit.isAwaiting || deposit.isPaid)) return null;
  final amount = PriceConverter.convertPrice(deposit.amount);
  final freeLeft = deposit.freeCancelLeft;
  if (deposit.isAwaiting) return ('deposit_cancel_unpaid'.tr, false);
  // A ride booked ahead: free while no driver has it, and until a set time before the pickup.
  if (deposit.cancelFreeReason == 'no_driver_yet') return ('deposit_cancel_no_driver'.trParams({'amount': amount}), false);
  if (deposit.cancelFreeReason == 'before_pickup' && deposit.freeCancelUntil != null) {
    return ('deposit_cancel_before_pickup'.trParams({'amount': amount, 'time': _at(deposit.freeCancelUntil!)}), false);
  }
  if (freeLeft > Duration.zero) return ('deposit_cancel_free_window'.trParams({'amount': amount, 'time': _clock(freeLeft)}), false);
  if (deposit.cancelFreeReason == 'driver_late') return ('deposit_cancel_driver_late'.trParams({'amount': amount}), false);
  if (deposit.cancelIsFree) return ('deposit_cancel_refund'.trParams({'amount': amount}), false);
  return ('deposit_cancel_forfeit'.trParams({'amount': amount}), true);
}

/// Above the cancel buttons: what cancelling now does to the deposit.
class DepositCancelNote extends StatefulWidget {
  final TripDeposit? deposit;
  const DepositCancelNote({super.key, required this.deposit});

  @override
  State<DepositCancelNote> createState() => _DepositCancelNoteState();
}

class _DepositCancelNoteState extends State<DepositCancelNote> with _Ticking {
  @override
  Widget build(BuildContext context) {
    final message = depositCancelMessage(widget.deposit);
    if (message == null) return const SizedBox();
    final theme = Theme.of(context);
    final (text, warning) = message;
    final color = warning ? theme.colorScheme.error : theme.primaryColor;
    return Container(
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(Dimensions.paddingSize),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(warning ? Icons.warning_amber_rounded : Icons.info_outline_rounded, color: color, size: 20),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Expanded(child: Text(text, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color, height: 1.35))),
      ]),
    );
  }
}

/// After the driver cancelled: what happened to the deposit, and a way to report.
/// A ride booked ahead is offered to other drivers, with its deposit.
Future<void> showDriverCancelledSheet(String tripId, {bool scheduled = false}) async {
  final controller = Get.find<DepositController>();
  if (!controller.firstAnnouncement(tripId)) return;
  final response = await controller.depositServiceInterface.getDeposit(tripId);
  final deposit = response.statusCode == 200 ? TripDeposit.fromJson(response.body['data']?['deposit']) : null;
  final refunded = deposit?.status == TripDeposit.refunded;
  final noAgreement = deposit?.status == TripDeposit.forfeited;
  await _sheet(
    icon: noAgreement ? Icons.handshake_outlined : Icons.directions_car_filled_rounded,
    title: noAgreement ? 'move_no_agreement_title'.tr : 'driver_cancelled_title'.tr,
    body: noAgreement
        ? 'move_driver_no_agreement_body'.trParams({'amount': PriceConverter.convertPrice(deposit!.amount)})
        : scheduled && !refunded
        ? 'driver_cancelled_scheduled_body'.tr
        : refunded
        ? 'driver_cancelled_refunded'.trParams({'amount': PriceConverter.convertPrice(deposit!.refundedAmount)})
        : 'driver_cancelled_body'.tr,
    actions: (close) => [
      TextButton(
        onPressed: () { close(); showReportDriverSheet(tripId); },
        child: Text('report_driver'.tr),
      ),
      FilledButton(onPressed: close, child: Text('ok'.tr)),
    ],
  );
}

/// The deposit was not paid in time.
Future<void> showDepositExpiredSheet(String tripId) async {
  if (!Get.find<DepositController>().firstAnnouncement(tripId)) return;
  // A ride booked ahead whose deposit was due when booking: it was simply not booked.
  final trip = Get.find<RideController>().tripDetails;
  final booking = trip?.id == tripId && trip?.type == 'scheduled_request' && trip?.driver == null;
  await _sheet(
    icon: Icons.timer_off_outlined,
    title: booking ? 'deposit_expired_booking_title'.tr : 'deposit_expired_title'.tr,
    body: booking ? 'deposit_expired_booking_body'.tr : 'deposit_expired_body'.tr,
    actions: (close) => [FilledButton(onPressed: close, child: Text('ok'.tr))],
  );
}

Future<void> _sheet({required IconData icon, required String title, required String body, required List<Widget> Function(VoidCallback close) actions}) async {
  final context = Get.context;
  if (context == null) return;
  await Get.bottomSheet(
    Builder(builder: (context) {
      final theme = Theme.of(context);
      return Container(
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, Dimensions.paddingSizeLarge, Dimensions.paddingSizeLarge, Dimensions.paddingSizeLarge),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Dimensions.radiusExtraLarge)),
        ),
        child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 36, color: theme.primaryColor),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(title, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text(body, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.hintColor, height: 1.4)),
          const SizedBox(height: Dimensions.paddingSizeLarge),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            for (final a in actions(() => Get.back())) Padding(padding: const EdgeInsets.only(left: 8), child: a),
          ]),
        ])),
      );
    }),
    isScrollControlled: true,
  );
}

/// The customer reports the driver of a trip: a reason and an optional comment.
Future<void> showReportDriverSheet(String tripId) async {
  final controller = Get.find<DepositController>();
  controller.loadReasons();
  await Get.bottomSheet(_ReportDriverSheet(tripId: tripId), isScrollControlled: true);
}

class _ReportDriverSheet extends StatefulWidget {
  final String tripId;
  const _ReportDriverSheet({required this.tripId});

  @override
  State<_ReportDriverSheet> createState() => _ReportDriverSheetState();
}

class _ReportDriverSheetState extends State<_ReportDriverSheet> {
  String? _reason;
  final TextEditingController _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Dimensions.radiusExtraLarge)),
      ),
      child: SafeArea(top: false, child: GetBuilder<DepositController>(builder: (controller) {
        final reasons = controller.reasons;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('report_driver'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
            const SizedBox(height: 4),
            Text('report_driver_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            if (reasons == null)
              const Padding(padding: EdgeInsets.all(Dimensions.paddingSizeLarge), child: Center(child: CircularProgressIndicator()))
            else
              RadioGroup<String>(
                groupValue: _reason,
                onChanged: (value) => setState(() => _reason = value),
                child: Column(children: [
                  for (final r in reasons)
                    RadioListTile<String>(
                      value: r.key,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.label, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
                    ),
                ]),
              ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            TextField(
              controller: _comment,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'report_driver_comment_hint'.tr,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _reason == null || controller.reporting
                    ? null
                    : () async {
                        final sent = await controller.reportDriver(widget.tripId, _reason!, _comment.text);
                        // Navigator, not Get.back: that would close the
                        // "report sent" snackbar instead of this sheet.
                        if (sent && context.mounted) Navigator.of(context).pop();
                      },
                child: controller.reporting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('send_report'.tr),
              ),
            ),
          ]),
        );
      })),
    );
  }
}
