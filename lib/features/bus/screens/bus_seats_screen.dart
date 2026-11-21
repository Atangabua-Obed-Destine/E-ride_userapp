import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/bus/controllers/bus_controller.dart';
import 'package:ride_sharing_user_app/features/bus/domain/models/bus_models.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_booking_screen.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_travellers_screen.dart';
import 'package:ride_sharing_user_app/features/bus/widgets/bus_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The live seat map of one departure. Seats sold at the counter or asked for in the app
/// disappear while the passenger looks (refreshed every few seconds).
class BusSeatsScreen extends StatefulWidget {
  final String departureId;
  const BusSeatsScreen({super.key, required this.departureId});

  @override
  State<BusSeatsScreen> createState() => _BusSeatsScreenState();
}

class _BusSeatsScreenState extends State<BusSeatsScreen> {
  BusController get _c => Get.find<BusController>();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.loadMeta();
      _load();
    });
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _load(quiet: true));
  }

  Future<void> _load({bool quiet = false}) async {
    final before = [..._c.picked];
    await _c.loadDeparture(widget.departureId, quiet: quiet);
    final gone = before.where((s) => !_c.picked.contains(s)).toList();
    if (gone.isNotEmpty && mounted) showCustomSnackBar('bus_seat_just_taken'.trParams({'seat': gone.join(', ')}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<BusController>(builder: (c) {
      final BusDeparture? d = c.departure(widget.departureId);
      return Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('bus_pick_seats'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
            if (d != null) Text('${busWhen(d.leavesAt)} · ${d.to ?? ''}', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ]),
        ),
        body: d == null
            ? Center(child: c.departureLoading ? const CircularProgressIndicator() : Text('bus_departure_gone'.tr))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
                  _Header(departure: d),
                  if (d.myBookingId != null) ...[
                    const SizedBox(height: 10),
                    Material(
                      color: busSeatMine.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        leading: const Icon(Icons.event_seat_rounded, color: busSeatMine),
                        title: Text('bus_you_have_seats_here'.tr, style: textSemiBold),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Get.to(() => BusBookingScreen(bookingId: d.myBookingId!)),
                      ),
                    ),
                  ],
                  if (!d.bookable) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.full ? 'bus_full_long'.tr : (d.closedReason ?? 'bus_not_bookable'.tr), style: textMedium.copyWith(color: textColor)),
                        if (d.full) ...[
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final on = await c.toggleWaitlist(d.id);
                              showCustomSnackBar(on ? 'bus_waitlist_on'.tr : 'bus_waitlist_off'.tr, isError: false);
                            },
                            icon: Icon(d.onWaitlist ? Icons.notifications_off_outlined : Icons.notifications_active_outlined),
                            label: Text(d.onWaitlist ? 'bus_waitlist_stop'.tr : 'bus_tell_me'.tr),
                          ),
                        ],
                      ]),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: busSeatFree, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('bus_live_seats'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                  ]),
                  const SizedBox(height: 10),
                  const BusSeatLegend(),
                  const SizedBox(height: 14),
                  if (d.seatMap != null)
                    Center(child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: BusSeatMapView(
                        map: d.seatMap!,
                        picked: c.picked,
                        onTap: d.bookable ? (n) {
                          if (!c.toggleSeat(n)) showCustomSnackBar('bus_max_seats'.trParams({'n': '${c.meta?.maxSeats ?? 6}'}));
                        } : null,
                      ),
                    )),
                  const SizedBox(height: 90),
                ]),
              ),
        bottomNavigationBar: d == null || !d.bookable ? null : _BottomBar(departure: d, picked: c.picked),
      );
    });
  }
}

class _Header extends StatelessWidget {
  final BusDeparture departure;
  const _Header({required this.departure});

  @override
  Widget build(BuildContext context) {
    final d = departure;
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final free = d.rules.freeCancelHours;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          BusAgencyLogo(agency: d.agency, size: 40),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${d.agency?.name ?? ''} · ${d.classLabel}', style: textBold.copyWith(color: textColor)),
            Text([if (d.busName != null) d.busName!, 'bus_seats_n'.trParams({'n': '${d.seatsTotal}'}), ...d.amenities.map((a) => 'bus_amenity_$a'.tr)].join(' · '),
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ])),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (d.instant) BusTag('bus_instant'.tr, color: busSeatMine, icon: Icons.bolt_rounded)
          else if (d.agency?.answerMinutes != null) BusTag('bus_answers_in'.trParams({'n': '${d.agency!.answerMinutes}'}), color: theme.hintColor, icon: Icons.schedule_rounded),
          if (free != null && free > 0) BusTag('bus_free_cancel_until'.trParams({'h': '$free'}), color: const Color(0xFF15803D)),
          if (d.whenFull) BusTag('bus_leaves_when_full'.tr, color: Colors.orange.shade800),
        ]),
      ]),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final BusDeparture departure;
  final List<String> picked;
  const _BottomBar({required this.departure, required this.picked});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = departure;
    final fare = d.fromFare ?? 0;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(color: theme.cardColor, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12)]),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(picked.isEmpty ? 'bus_tap_free_seat'.tr : 'bus_seats_picked'.trParams({'seats': picked.join(', ')}),
                style: textBold.copyWith(color: theme.textTheme.bodyLarge?.color)),
            if (picked.isNotEmpty)
              Text('bus_from_fare'.trParams({'price': busMoney(fare * picked.length)}), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ])),
          ElevatedButton(
            onPressed: picked.isEmpty ? null : () => Get.to(() => BusTravellersScreen(departureId: d.id)),
            style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, minimumSize: const Size(130, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text('bus_continue'.tr, style: textBold),
          ),
        ]),
      ),
    );
  }
}
