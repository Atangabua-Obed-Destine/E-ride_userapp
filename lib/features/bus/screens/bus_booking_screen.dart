import 'package:ride_sharing_user_app/features/assistant/widgets/help_button.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/bus/controllers/bus_controller.dart';
import 'package:ride_sharing_user_app/features/bus/domain/models/bus_models.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_results_screen.dart';
import 'package:ride_sharing_user_app/features/bus/widgets/bus_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_map_card.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_payment_screen.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// One seat request from start to the bus leaving:
/// waiting for the agency (a ring counting down) → pay within minutes → the tickets (QR, offline),
/// with the travel day on top (boarding, delay, departed). Or what happened when it ended.
class BusBookingScreen extends StatefulWidget {
  final String bookingId;
  const BusBookingScreen({super.key, required this.bookingId});

  @override
  State<BusBookingScreen> createState() => _BusBookingScreenState();
}

class _BusBookingScreenState extends State<BusBookingScreen> {
  BusController get _c => Get.find<BusController>();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.loadMeta();
      _c.loadBooking(widget.bookingId);
    });
    // Waiting and paying change by the minute; a ticket on travel day by the hour.
    _timer = Timer.periodic(const Duration(seconds: 5), (t) {
      final b = _c.booking(widget.bookingId);
      if (b == null) return;
      final travelDay = b.isPaid && !b.departed && b.leavesAt != null && b.leavesAt!.difference(DateTime.now()).inHours < 3;
      if (b.waiting || b.toPay || (travelDay && t.tick % 6 == 0)) _c.loadBooking(widget.bookingId, quiet: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pay(BusBooking b) async {
    final link = await _c.payLink(b.id);
    if (link == null) return;
    if (link.isNotEmpty) {
      await Get.to(() => StorePaymentScreen(url: link));
    }
    final fresh = await _c.loadBooking(b.id, quiet: true);
    if (fresh?.isPaid == true) {
      showCustomSnackBar('bus_paid_toast'.tr, isError: false);
      _c.loadList('upcoming');
    }
  }

  Future<void> _cancel(BusBooking b) async {
    final q = b.cancel;
    final String body = !b.isPaid
        ? 'bus_cancel_request_body'.tr
        : q != null && q.refund > 0
            ? 'bus_cancel_ticket_body'.trParams({'pct': '${q.percent}', 'amount': busMoney(q.refund), 'agency': b.agency?.name ?? ''})
            : 'bus_cancel_ticket_nothing'.tr;
    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text(b.isPaid ? 'bus_cancel_ticket'.tr : 'bus_cancel_request'.tr),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('bus_keep'.tr)),
        TextButton(onPressed: () => Get.back(result: true), child: Text('bus_yes_cancel'.tr, style: TextStyle(color: Colors.red.shade700))),
      ],
    ));
    if (ok == true) {
      final r = await _c.cancel(b.id);
      if (r != null) _c.loadList('upcoming');
    }
  }

  void _anotherDeparture(BusBooking b) {
    _c.setFrom(b.from);
    _c.setTo(b.to);
    if (b.leavesAt != null && !b.leavesAt!.isBefore(DateTime.now())) _c.setDate(b.leavesAt!);
    Get.off(() => const BusResultsScreen());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<BusController>(builder: (c) {
      final BusBooking? b = c.booking(widget.bookingId);
      final String title = b == null ? 'bus_trip'.tr : b.waiting ? 'bus_waiting_title'.tr : b.toPay ? 'bus_pay_title'.tr : b.isPaid ? 'bus_ticket_title'.tr : 'bus_trip'.tr;
      return Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
        appBar: AppBar(backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent, title: Text(title),
            actions: const [HelpButton(helpKey: 'bus_booking'), SizedBox(width: 6)]),
        body: b == null
            ? Center(child: c.bookingLoading ? const CircularProgressIndicator() : Text('bus_booking_gone'.tr))
            : RefreshIndicator(
                onRefresh: () => c.loadBooking(b.id, quiet: true),
                child: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
                  if (b.waiting) ..._waiting(context, c, b),
                  if (b.toPay) ..._toPay(context, c, b),
                  if (b.isPaid) ..._ticket(context, c, b),
                  if (b.ended) ..._ended(context, b),
                ]),
              ),
      );
    });
  }

  // ------------------------------------------------------------------ waiting

  List<Widget> _waiting(BuildContext context, BusController c, BusBooking b) {
    final theme = Theme.of(context);
    final agency = b.agency?.name ?? '';
    final total = (c.meta?.answerMinutes ?? 10) * 60;
    return [
      const SizedBox(height: 8),
      Center(child: BusCountdownRing(deadline: b.respondBy ?? DateTime.now(), totalSeconds: total, caption: 'bus_left_to_answer'.tr,
          onZero: () => c.loadBooking(b.id, quiet: true))),
      const SizedBox(height: 18),
      Text('bus_waiting_for'.trParams({'agency': agency}), textAlign: TextAlign.center,
          style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
      const SizedBox(height: 6),
      Text([
        if (b.agency?.answerMinutes != null) 'bus_usually_answers'.trParams({'n': '${b.agency!.answerMinutes}'}),
        'bus_seats_held_meanwhile'.trParams({'seats': b.seats.join(', ')}),
      ].join(' '), textAlign: TextAlign.center, style: textRegular.copyWith(color: theme.hintColor)),
      const SizedBox(height: 20),
      _Steps(current: 1, payMinutes: c.meta?.payMinutes ?? 15),
      const SizedBox(height: 14),
      _Summary(booking: b),
      const SizedBox(height: 10),
      Text('bus_if_declined'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
      const SizedBox(height: 8),
      TextButton(onPressed: c.acting ? null : () => _cancel(b), child: Text('bus_cancel_request'.tr, style: TextStyle(color: Colors.red.shade700))),
    ];
  }

  // ------------------------------------------------------------------ paying

  List<Widget> _toPay(BuildContext context, BusController c, BusBooking b) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final agency = b.agency?.name ?? '';
    final total = (c.meta?.payMinutes ?? 15) * 60;
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF15803D).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          BusCountdownRing(deadline: b.payBy ?? DateTime.now(), totalSeconds: total, size: 96, caption: 'bus_left_to_pay'.tr,
              onZero: () => c.loadBooking(b.id, quiet: true)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('bus_accepted_title'.trParams({'agency': agency, 'seats': b.seats.join(', ')}), style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
            const SizedBox(height: 4),
            Text('bus_pay_within'.trParams({'n': '${c.meta?.payMinutes ?? 15}'}), style: textRegular.copyWith(color: theme.hintColor)),
          ])),
        ]),
      ),
      const SizedBox(height: 14),
      _Summary(booking: b),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Icon(Icons.lock_outline_rounded, color: Color(0xFF15803D)),
          const SizedBox(width: 10),
          Expanded(child: Text('bus_paid_to_agency'.trParams({'agency': agency}), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
        ]),
      ),
      const SizedBox(height: 18),
      SizedBox(height: 54, child: ElevatedButton.icon(
        onPressed: c.acting || !b.canPay ? null : () => _pay(b),
        icon: c.acting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.phone_android_rounded),
        label: Text('bus_pay_amount'.trParams({'amount': busMoney(b.amount)}), style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
        style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      )),
      const SizedBox(height: 6),
      Text('bus_pay_how'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
      const SizedBox(height: 6),
      TextButton(onPressed: c.acting ? null : () => _cancel(b), child: Text('bus_cancel_request'.tr, style: TextStyle(color: Colors.red.shade700))),
    ];
  }

  // ------------------------------------------------------------------ ticket

  List<Widget> _ticket(BuildContext context, BusController c, BusBooking b) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final agency = b.agency;
    final live = b.tickets.where((t) => t.status != 'cancelled').toList();
    final beAt = b.leavesAt?.subtract(const Duration(minutes: 30));
    return [
      if (b.moved && !b.moveKept) ...[_MovedCard(booking: b, onKeep: () => c.keepMove(b.id), onCancel: () => _cancel(b)), const SizedBox(height: 14)],
      if (b.atRisk) ...[_AtRiskCard(booking: b, onCancel: () => _cancel(b)), const SizedBox(height: 14)],
      _TravelDay(booking: b),
      const SizedBox(height: 14),
      if (b.collectAtCounter) ...[BusCollectCard(booking: b), const SizedBox(height: 14)],
      if (live.length == 1)
        BusTicketCard(booking: b, ticket: live.first)
      else
        SizedBox(
          height: 560,
          child: PageView(
            controller: PageController(viewportFraction: 0.92),
            children: [for (final t in live) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: BusTicketCard(booking: b, ticket: t))],
          ),
        ),
      if (live.length > 1)
        Padding(padding: const EdgeInsets.only(top: 6), child: Text('bus_swipe_tickets'.trParams({'n': '${live.length}'}), textAlign: TextAlign.center,
            style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
      const SizedBox(height: 16),
      if (!b.departed && agency != null)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(beAt != null ? 'bus_be_there_by'.trParams({'time': busTime(beAt)}) : agency.name, style: textBold.copyWith(color: textColor)),
            const SizedBox(height: 2),
            Text([agency.name, if (agency.address != null) agency.address!].join(', '), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (agency.hasLocation)
                ElevatedButton.icon(
                  onPressed: () => marketRideThere(agency.lat!, agency.lng!, [agency.name, if (agency.address != null) agency.address!].join(', ')),
                  icon: const Icon(Icons.local_taxi_outlined, size: 18), label: Text('bus_ride_to_agency'.tr),
                  style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white),
                ),
              if (agency.phone != null)
                OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse('tel:${agency.phone}')), icon: const Icon(Icons.call_outlined, size: 18), label: Text('bus_call'.tr)),
              OutlinedButton.icon(onPressed: () => _share(b), icon: const Icon(Icons.share_outlined, size: 18), label: Text('bus_share_family'.tr)),
            ]),
          ]),
        ),
      if (b.refundStatus != null) ...[const SizedBox(height: 12), _RefundCard(booking: b)],
      if (b.cancel?.cancellable == true && !b.departed) ...[
        const SizedBox(height: 10),
        TextButton(onPressed: c.acting ? null : () => _cancel(b), child: Text('bus_cancel_ticket'.tr, style: TextStyle(color: Colors.red.shade700))),
        Text(b.cancel!.refund > 0 ? 'bus_cancel_now_gets'.trParams({'pct': '${b.cancel!.percent}'}) : 'bus_cancel_now_nothing'.tr,
            textAlign: TextAlign.center, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
      ],
    ];
  }

  Future<void> _share(BusBooking b) async {
    final text = 'bus_share_text'.trParams({
      'from': b.from ?? '', 'to': b.to ?? '', 'when': busWhen(b.leavesAt), 'agency': b.agency?.name ?? '',
      'seats': b.seats.join(', '), 'bus': b.busRegistration ?? '-', 'code': b.code,
    });
    await SharePlus.instance.share(ShareParams(text: text));
  }

  // ------------------------------------------------------------------ ended

  List<Widget> _ended(BuildContext context, BusBooking b) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final agency = b.agency?.name ?? '';
    final (IconData icon, String title, String body) = switch (b.status) {
      BusBooking.declined => (Icons.event_busy_outlined, 'bus_declined_title'.trParams({'agency': agency}),
          b.declineReason != null ? 'bus_declined_reason'.trParams({'reason': b.declineReason!}) : 'bus_declined_body'.tr),
      BusBooking.expired => (Icons.timer_off_outlined, b.respondBy != null && b.payBy == null ? 'bus_expired_answer_title'.trParams({'agency': agency}) : 'bus_expired_pay_title'.tr,
          'bus_expired_body'.tr),
      _ => (Icons.cancel_outlined, b.cancelledBy == 'passenger' ? 'bus_cancelled_by_you'.tr : 'bus_cancelled_by_agency'.trParams({'agency': agency}),
          b.departureCancelReason ?? ''),
    };
    return [
      const SizedBox(height: 30),
      Icon(icon, size: 60, color: theme.hintColor),
      const SizedBox(height: 12),
      Text(title, textAlign: TextAlign.center, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor)),
      if (body.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(body, textAlign: TextAlign.center, style: textRegular.copyWith(color: theme.hintColor)),
      ],
      const SizedBox(height: 14),
      _Summary(booking: b),
      if (b.refundStatus != null) ...[const SizedBox(height: 12), _RefundCard(booking: b)],
      const SizedBox(height: 20),
      SizedBox(height: 50, child: ElevatedButton(
        onPressed: () => _anotherDeparture(b),
        style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: Text('bus_find_another'.tr, style: textBold),
      )),
    ];
  }
}

/// What was asked for: route, time, seats, where they get off, the amount.
class _Summary extends StatelessWidget {
  final BusBooking booking;
  const _Summary({required this.booking});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final b = booking;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        BusAgencyLogo(agency: b.agency, size: 42),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${b.from ?? ''} → ${b.to ?? ''}', style: textBold.copyWith(color: textColor)),
          Text('${busWhen(b.leavesAt)} · ${b.agency?.name ?? ''} · ${b.classLabel}', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          Text([
            'bus_seats_picked'.trParams({'seats': b.seats.join(', ')}),
            if (b.dropPoint != null) b.dropPoint!,
          ].join(' · '), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ])),
        Text(busMoney(b.amount), style: textBold.copyWith(color: textColor)),
      ]),
    );
  }
}

/// 1 request sent, 2 the agency confirms, 3 you pay, 4 your ticket.
class _Steps extends StatelessWidget {
  final int current;
  final int payMinutes;
  const _Steps({required this.current, required this.payMinutes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = [
      ('bus_step_sent'.tr, 'bus_step_sent_sub'.tr),
      ('bus_step_confirm'.tr, 'bus_step_confirm_sub'.tr),
      ('bus_step_pay'.tr, 'bus_step_pay_sub'.trParams({'n': '$payMinutes'})),
      ('bus_step_ticket'.tr, 'bus_step_ticket_sub'.tr),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        for (int i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 26, height: 26, alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: i < current ? const Color(0xFF15803D) : i == current ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.2)),
                child: i < current ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : Text('${i + 1}', style: textBold.copyWith(color: i == current ? Colors.white : theme.hintColor, fontSize: Dimensions.fontSizeSmall)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(steps[i].$1, style: textSemiBold.copyWith(color: i <= current ? theme.textTheme.bodyLarge?.color : theme.hintColor)),
                Text(steps[i].$2, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              ])),
            ]),
          ),
      ]),
    );
  }
}

/// The travel day on top of the ticket: when it leaves, boarding, delays, departed.
class _TravelDay extends StatelessWidget {
  final BusBooking booking;
  const _TravelDay({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final theme = Theme.of(context);
    final (Color color, IconData icon, String title, String sub) = b.departed
        ? (theme.hintColor, Icons.flag_rounded, 'bus_departed_title'.tr, 'bus_departed_sub'.tr)
        : b.boarding
            ? (const Color(0xFF15803D), Icons.directions_bus_filled_rounded, 'bus_boarding_now'.tr,
                'bus_boarding_sub'.trParams({'bus': b.busRegistration ?? '', 'seats': b.seats.join(', '), 'time': busTime(b.leavesAt)}))
            : b.delayed
                ? (Colors.orange.shade800, Icons.schedule_rounded, 'bus_delayed_title'.trParams({'time': busTime(b.leavesAt)}), 'bus_delayed_sub'.tr)
                : (theme.primaryColor, Icons.event_available_rounded, 'bus_leaves_on'.trParams({'when': busWhen(b.leavesAt)}),
                    b.busRegistration != null ? 'bus_bus_is'.trParams({'bus': b.busRegistration!}) : 'bus_paid_ready'.tr);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: textBold.copyWith(color: color, fontSize: Dimensions.fontSizeLarge)),
          Text(sub, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
        ])),
      ]),
    );
  }
}

/// Moved because of a lockdown: why, from when, and the choice.
class _MovedCard extends StatelessWidget {
  final BusBooking booking;
  final VoidCallback onKeep;
  final VoidCallback onCancel;
  const _MovedCard({required this.booking, required this.onKeep, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final theme = Theme.of(context);
    final color = Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.event_repeat_rounded, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text('bus_moved_title'.trParams({'when': busWhen(b.leavesAt)}), style: textBold.copyWith(color: color, fontSize: Dimensions.fontSizeLarge))),
        ]),
        const SizedBox(height: 4),
        Text([if (b.movedReason != null) b.movedReason!, if (b.movedFrom != null) 'bus_moved_from'.trParams({'when': busWhen(b.movedFrom)})].join(' '),
            style: textRegular.copyWith(color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: ElevatedButton(onPressed: onKeep,
              style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white), child: Text('bus_keep_new_time'.tr))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: onCancel, child: Text('bus_cancel_full_refund'.tr, textAlign: TextAlign.center))),
        ]),
      ]),
    );
  }
}

/// The departure may not go ahead: the reason, when the agency decides, a free cancellation.
class _AtRiskCard extends StatelessWidget {
  final BusBooking booking;
  final VoidCallback onCancel;
  const _AtRiskCard({required this.booking, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final theme = Theme.of(context);
    final color = Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text('bus_at_risk_title'.tr, style: textBold.copyWith(color: color, fontSize: Dimensions.fontSizeLarge))),
        ]),
        const SizedBox(height: 4),
        Text([if ((b.atRiskReason ?? '').isNotEmpty) b.atRiskReason!,
          if (b.atRiskDecideBy != null) 'bus_at_risk_decide'.trParams({'agency': b.agency?.name ?? '', 'when': busWhen(b.atRiskDecideBy)})].join(' '),
            style: textRegular.copyWith(color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onCancel, child: Text('bus_cancel_full_refund'.tr)),
      ]),
    );
  }
}

class _RefundCard extends StatelessWidget {
  final BusBooking booking;
  const _RefundCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final theme = Theme.of(context);
    final sent = b.refundStatus == 'sent';
    final agency = b.agency?.name ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: (sent ? const Color(0xFF15803D) : Colors.orange).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(sent ? Icons.check_circle_outline : Icons.hourglass_bottom_rounded, color: sent ? const Color(0xFF15803D) : Colors.orange.shade800),
        const SizedBox(width: 10),
        Expanded(child: Text(
          sent
              ? 'bus_refund_sent'.trParams({'amount': busMoney(b.refundAmount), 'agency': agency, 'ref': b.refundReference ?? ''})
              : 'bus_refund_due'.trParams({'amount': busMoney(b.refundAmount), 'agency': agency, 'when': busWhen(b.refundDueBy)}),
          style: textRegular.copyWith(color: theme.textTheme.bodyLarge?.color),
        )),
      ]),
    );
  }
}
