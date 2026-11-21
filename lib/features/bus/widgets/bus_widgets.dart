import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/bus/domain/models/bus_models.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

// ------------------------------------------------------------------ formats

String busMoney(double? v) => v == null ? '' : PriceConverter.convertPrice(v);

String _two(int n) => n.toString().padLeft(2, '0');

String busTime(DateTime? d) => d == null ? '' : '${_two(d.hour)}:${_two(d.minute)}';

/// "Today", "Tomorrow", or "Wed 18 Nov".
String busDay(DateTime? d, {bool cap = true}) {
  if (d == null) return '';
  final now = DateTime.now();
  final diff = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (diff == 0) return 'market_today_cap'.tr;
  if (diff == 1) return 'market_tomorrow'.tr;
  return '${'market_wd_${d.weekday}'.tr} ${d.day} ${'market_mo_${d.month}'.tr}';
}

String busWhen(DateTime? d) => d == null ? '' : '${busDay(d)}, ${busTime(d)}';

/// "about 5 h 30".
String busDuration(int? minutes) {
  if (minutes == null || minutes <= 0) return '';
  final h = minutes ~/ 60, m = minutes % 60;
  return 'bus_about_duration'.trParams({'d': h == 0 ? '$m min' : (m == 0 ? '$h h' : '$h h ${_two(m)}')});
}

String mmss(int seconds) => '${seconds ~/ 60}:${_two(seconds % 60)}';

// ------------------------------------------------------------------ colours

const Color busSeatFree = Color(0xFF22C55E);
const Color busSeatTaken = Color(0xFF7C8786);
const Color busSeatMine = Color(0xFF2563EB);
const Color busSeatCounter = Color(0xFF6B7280);

// ------------------------------------------------------------------ pieces

/// The agency's logo, or its initials on a deep blue tile.
class BusAgencyLogo extends StatelessWidget {
  final BusAgency? agency;
  final double size;
  const BusAgencyLogo({super.key, required this.agency, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final a = agency;
    if (a?.logo != null) return ImageWidget(image: a!.logo!, width: size, height: size, radius: size * 0.25, fit: BoxFit.cover);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: const Color(0xFF1E3A8A), borderRadius: BorderRadius.circular(size * 0.25)),
      alignment: Alignment.center,
      child: Text(a?.initials ?? '?', style: textBold.copyWith(color: Colors.white, fontSize: size * 0.34)),
    );
  }
}

class BusTag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const BusTag(this.text, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 3)],
          Text(text, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: color)),
        ]),
      );
}

/// A departure in the results: time, how long, agency and class, price, seats left.
class BusDepartureCard extends StatelessWidget {
  final BusDeparture departure;
  final VoidCallback onTap;
  final VoidCallback? onWaitlist;
  const BusDepartureCard({super.key, required this.departure, required this.onTap, this.onWaitlist});

  @override
  Widget build(BuildContext context) {
    final d = departure;
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final hint = theme.hintColor;
    final dim = !d.bookable;
    final taken = d.seatsTotal - d.seatsLeft;
    return Opacity(
      opacity: dim && !d.full ? 0.6 : 1,
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: hint.withValues(alpha: 0.15))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 70, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.whenFull ? '${busTime(d.leavesAt)}+' : busTime(d.leavesAt), style: textBold.copyWith(fontSize: Dimensions.fontSizeTwenty, color: textColor)),
                  if (d.delayed) Text('bus_delayed'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.orange.shade800)),
                  if (!d.delayed && d.durationMinutes != null)
                    Text(busDuration(d.durationMinutes), style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: hint)),
                ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${d.agency?.name ?? ''} · ${d.classLabel}', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
                  Text([if (d.busName != null) d.busName!, 'bus_seats_n'.trParams({'n': '${d.seatsTotal}'}), ...d.amenities.take(2).map((a) => 'bus_amenity_$a'.tr)].join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: hint)),
                  if (d.to != null) Text('${'bus_to'.tr} ${d.to}', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: hint)),
                ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(busMoney(d.fromFare), style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
                  if (d.dropPoints.length > 1) Text('bus_from_price'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: hint)),
                ]),
              ]),
              if (d.whenFull && d.seatsTotal > 0) ...[
                const SizedBox(height: 10),
                ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
                    value: taken / d.seatsTotal, minHeight: 6, backgroundColor: hint.withValues(alpha: 0.15), color: Colors.orange.shade600)),
                const SizedBox(height: 4),
                Text('bus_when_full_progress'.trParams({'taken': '$taken', 'total': '${d.seatsTotal}'}),
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: hint)),
              ],
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                BusTag('bus_verified'.tr, color: const Color(0xFF15803D), icon: Icons.verified_rounded),
                if (d.full)
                  BusTag('bus_full'.tr, color: Colors.red.shade700)
                else if (d.bookable)
                  BusTag(d.seatsLeft <= 5 ? 'bus_seats_left_few'.trParams({'n': '${d.seatsLeft}'}) : 'bus_seats_left'.trParams({'n': '${d.seatsLeft}'}),
                      color: d.seatsLeft <= 5 ? Colors.orange.shade800 : hint),
                if (d.instant && d.bookable) BusTag('bus_instant'.tr, color: busSeatMine, icon: Icons.bolt_rounded),
                if (!d.bookable && !d.full && d.closedReason != null) BusTag('bus_closed_online'.tr, color: hint),
                if (d.full && onWaitlist != null)
                  TextButton.icon(onPressed: onWaitlist, icon: const Icon(Icons.notifications_active_outlined, size: 16), label: Text('bus_tell_me'.tr),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The bus seen from above, with each seat's state. Free seats can be tapped.
class BusSeatMapView extends StatelessWidget {
  final BusSeatMap map;
  final List<String> picked;
  final void Function(String seat)? onTap;
  const BusSeatMapView({super.key, required this.map, this.picked = const [], this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = theme.hintColor;
    return Column(children: [
      for (final deck in map.decks) ...[
        if (map.decks.length > 1)
          Padding(padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(deck.deck == 'upper' ? 'bus_upper_deck'.tr : 'bus_lower_deck'.tr, style: textSemiBold.copyWith(color: hint))),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border.all(color: hint.withValues(alpha: 0.25), width: 2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(34), bottom: Radius.circular(14)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (deck.cabin)
              Container(
                width: 220, margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: hint.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('bus_driver'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: hint)),
                  Text('bus_door'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: busSeatMine)),
                ]),
              ),
            for (final row in deck.rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(mainAxisSize: MainAxisSize.min, children: [for (final c in row) _cell(context, c)]),
              ),
          ]),
        ),
      ],
    ]);
  }

  Widget _cell(BuildContext context, BusSeatCell c) {
    const double w = 40, h = 38, gap = 3;
    final hint = Theme.of(context).hintColor;
    switch (c.t) {
      case 'aisle':
        return const SizedBox(width: 18, height: h);
      case 'driver':
        return Padding(padding: const EdgeInsets.symmetric(horizontal: gap),
            child: Container(width: w, height: h, alignment: Alignment.center,
                decoration: BoxDecoration(color: hint.withValues(alpha: 0.5), shape: BoxShape.circle),
                child: Semantics(label: 'bus_driver'.tr, child: const Icon(Icons.trip_origin_rounded, color: Colors.white, size: 20))));
      case 'door':
        final double width = c.span * w + (c.span - 1) * gap * 2;
        return Padding(padding: const EdgeInsets.symmetric(horizontal: gap),
            child: Container(width: width, height: h, alignment: Alignment.center,
                decoration: BoxDecoration(color: busSeatMine.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('bus_door'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: busSeatMine))));
      case 'seat':
        final n = c.n ?? '';
        final mine = picked.contains(n) || c.state == 'mine';
        final free = c.state == 'free';
        final Color bg = mine ? busSeatMine : free ? busSeatFree : c.state == 'counter' ? busSeatCounter.withValues(alpha: 0.35) : busSeatTaken;
        final String label = '${'bus_seat'.tr} $n${c.window ? ', ${'bus_window'.tr}' : ''}, '
            '${mine ? 'bus_seat_yours'.tr : free ? 'bus_seat_free'.tr : c.state == 'counter' ? 'bus_seat_counter'.tr : 'bus_seat_taken'.tr}';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: gap),
          child: Semantics(
            button: free || picked.contains(n), selected: mine, label: label,
            child: InkWell(
              onTap: (free || picked.contains(n)) && onTap != null ? () => onTap!(n) : null,
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: w, height: h, alignment: Alignment.center,
                decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(10), bottom: Radius.circular(6)),
                    boxShadow: mine ? [BoxShadow(color: busSeatMine.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))] : null),
                child: ExcludeSemantics(child: free || mine
                    ? Text(n, style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeSmall))
                    : Icon(c.state == 'counter' ? Icons.storefront_outlined : Icons.person_rounded, color: Colors.white, size: 18)),
              ),
            ),
          ),
        );
      default:
        return const SizedBox(width: w + gap * 2, height: h);
    }
  }
}

class BusSeatLegend extends StatelessWidget {
  const BusSeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    Widget dot(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 5),
          Text(t, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: hint)),
        ]);
    return Wrap(spacing: 14, runSpacing: 6, alignment: WrapAlignment.center, children: [
      dot(busSeatFree, 'bus_seat_free'.tr),
      dot(busSeatMine, 'bus_seat_yours'.tr),
      dot(busSeatTaken, 'bus_seat_taken'.tr),
      dot(busSeatCounter.withValues(alpha: 0.35), 'bus_seat_counter'.tr),
    ]);
  }
}

/// A countdown to a deadline, as a ring that empties; rebuilds itself every second.
class BusCountdownRing extends StatefulWidget {
  final DateTime deadline;
  final int totalSeconds;
  final double size;
  final String caption;
  final VoidCallback? onZero;
  const BusCountdownRing({super.key, required this.deadline, required this.totalSeconds, this.size = 150, required this.caption, this.onZero});

  @override
  State<BusCountdownRing> createState() => _BusCountdownRingState();
}

class _BusCountdownRingState extends State<BusCountdownRing> {
  Timer? _timer;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!_fired && _left == 0) {
        _fired = true;
        widget.onZero?.call();
      }
    });
  }

  int get _left => math.max(0, widget.deadline.difference(DateTime.now()).inSeconds);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final left = _left;
    final frac = widget.totalSeconds <= 0 ? 0.0 : (left / widget.totalSeconds).clamp(0.0, 1.0);
    final color = left < 120 ? Colors.red.shade600 : theme.primaryColor;
    return Semantics(
      label: '${mmss(left)} ${widget.caption}',
      child: SizedBox(width: widget.size, height: widget.size, child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(child: CircularProgressIndicator(value: frac, strokeWidth: 10, color: color, backgroundColor: theme.hintColor.withValues(alpha: 0.15),
            strokeCap: StrokeCap.round)),
        ExcludeSemantics(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(mmss(left), style: textBold.copyWith(fontSize: widget.size * 0.22, color: theme.textTheme.bodyLarge?.color,
              fontFeatures: const [FontFeature.tabularFigures()])),
          Text(widget.caption, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ])),
      ])),
    );
  }
}

/// A status in a list: waiting, to pay, ticket, ended.
class BusStatusChip extends StatelessWidget {
  final BusBooking booking;
  const BusStatusChip({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final (String text, Color color) = switch (b.status) {
      BusBooking.requested => ('bus_status_waiting'.tr, Colors.orange.shade800),
      BusBooking.accepted => ('bus_status_to_pay'.tr, Theme.of(context).primaryColor),
      BusBooking.paid => b.departed ? ('bus_status_departed'.tr, Theme.of(context).hintColor) : ('bus_status_ticket'.tr, const Color(0xFF15803D)),
      BusBooking.declined => ('bus_status_declined'.tr, Colors.red.shade700),
      BusBooking.expired => ('bus_status_expired'.tr, Theme.of(context).hintColor),
      _ => ('bus_status_cancelled'.tr, Theme.of(context).hintColor),
    };
    return BusTag(text, color: color);
  }
}

/// A lockdown or ghost town an agency declared.
class BusNoticeCard extends StatelessWidget {
  final BusNotice notice;
  const BusNoticeCard({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = notice;
    final color = n.atRisk ? Colors.orange.shade800 : Colors.red.shade700;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.35))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(n.atRisk ? Icons.warning_amber_rounded : Icons.block_rounded, color: color),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${n.kind}${n.agency != null ? ' · ${n.agency}' : ''}', style: textBold.copyWith(color: color)),
          Text(n.when, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
          if (n.note != null) Text(n.note!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          Text(n.atRisk ? 'bus_notice_at_risk'.tr : 'bus_notice_closed'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ])),
      ]),
    );
  }
}

/// Tickets printed at the agency: the code (and its QR) to show at the counter, then "collected".
class BusCollectCard extends StatelessWidget {
  final BusBooking booking;
  const BusCollectCard({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final agency = b.agency?.name ?? '';
    if (b.collected) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF15803D).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Icon(Icons.print_rounded, color: Color(0xFF15803D), size: 30),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('bus_collected_title'.tr, style: textBold.copyWith(color: const Color(0xFF15803D), fontSize: Dimensions.fontSizeLarge)),
            Text('bus_collected_body'.trParams({'time': busTime(b.collectedAt)}), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor)),
          ])),
        ]),
      );
    }
    final by = b.leavesAt?.subtract(const Duration(minutes: 30));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.4), width: 1.5)),
      child: Column(children: [
        Row(children: [
          Icon(Icons.storefront_rounded, color: theme.primaryColor),
          const SizedBox(width: 8),
          Expanded(child: Text('bus_collect_title'.trParams({'agency': agency}), style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor))),
        ]),
        const SizedBox(height: 4),
        Text(by != null ? 'bus_collect_body'.trParams({'time': busTime(by)}) : 'bus_collect_body_any'.tr, textAlign: TextAlign.center,
            style: textRegular.copyWith(color: theme.hintColor)),
        const SizedBox(height: 12),
        if (b.collectQr != null)
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Semantics(label: 'bus_collect_qr_label'.tr, child: QrImageView(data: b.collectQr!, size: 170, backgroundColor: Colors.white))),
        const SizedBox(height: 6),
        SelectableText(b.collectCode ?? '', style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, letterSpacing: 4, color: textColor)),
        Text('bus_collect_bring_id'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
      ]),
    );
  }
}

/// One ticket: the route, seat, passenger and the QR the boarding agent scans. Works offline.
class BusTicketCard extends StatelessWidget {
  final BusBooking booking;
  final BusTicket ticket;
  const BusTicketCard({super.key, required this.booking, required this.ticket});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final hint = theme.hintColor;
    final b = booking;
    Widget field(String k, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k.toUpperCase(), style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: hint, letterSpacing: 0.6)),
          const SizedBox(height: 2),
          Text(v, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
        ]));
    final boarded = ticket.status == 'boarded';
    return Container(
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 4))]),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(color: Color(0xFF1D2D2B), borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.from ?? '', style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeLarge)),
              Text(busTime(b.leavesAt), style: textRegular.copyWith(color: Colors.white70)),
            ])),
            const Icon(Icons.directions_bus_rounded, color: Colors.white70),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(b.to ?? '', style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeLarge)),
              Text(b.dropPoint ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: textRegular.copyWith(color: Colors.white70)),
            ])),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [field('bus_date'.tr, busDay(b.leavesAt)), field('bus_seat'.tr, ticket.seat), field('bus_class'.tr, b.classLabel)]),
            const SizedBox(height: 12),
            Row(children: [field('bus_passenger'.tr, ticket.passengerName), field('bus_bags'.tr, '${ticket.bags}')]),
            const SizedBox(height: 14),
            if (ticket.qr != null)
              Stack(alignment: Alignment.center, children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Semantics(label: 'bus_qr_label'.tr, child: QrImageView(data: ticket.qr!, size: 190, backgroundColor: Colors.white)),
                ),
                if (boarded)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFF15803D), borderRadius: BorderRadius.circular(20)),
                      child: Text('bus_on_board'.tr, style: textBold.copyWith(color: Colors.white))),
              ]),
            const SizedBox(height: 6),
            SelectableText(ticket.code, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, letterSpacing: 3, color: textColor)),
            Text(b.collectAtCounter ? 'bus_ticket_printed_hint'.tr : 'bus_ticket_show'.tr, textAlign: TextAlign.center,
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: hint)),
          ]),
        ),
      ]),
    );
  }
}
