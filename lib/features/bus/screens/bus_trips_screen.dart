import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/bus/controllers/bus_controller.dart';
import 'package:ride_sharing_user_app/features/bus/domain/models/bus_models.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_booking_screen.dart';
import 'package:ride_sharing_user_app/features/bus/widgets/bus_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// My bus trips: coming up (what needs me first), and past.
class BusTripsScreen extends StatefulWidget {
  const BusTripsScreen({super.key});

  @override
  State<BusTripsScreen> createState() => _BusTripsScreenState();
}

class _BusTripsScreenState extends State<BusTripsScreen> {
  BusController get _c => Get.find<BusController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.loadList('upcoming');
      _c.loadList('past');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
          title: Text('bus_my_trips'.tr),
          bottom: TabBar(tabs: [Tab(text: 'bus_upcoming'.tr), Tab(text: 'bus_past'.tr)]),
        ),
        body: GetBuilder<BusController>(builder: (c) => TabBarView(children: [
              _list(c, 'upcoming', 'bus_no_upcoming'.tr),
              _list(c, 'past', 'bus_no_past'.tr),
            ])),
      ),
    );
  }

  Widget _list(BusController c, String when, String empty) {
    final theme = Theme.of(context);
    final list = [...c.list(when)];
    if (when == 'upcoming') {
      int rank(BusBooking b) => b.toPay ? 0 : b.waiting ? 1 : 2;
      list.sort((a, b) => rank(a).compareTo(rank(b)));
    }
    return RefreshIndicator(
      onRefresh: () => c.loadList(when),
      child: c.listLoading(when) && list.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 90),
                  Icon(Icons.confirmation_number_outlined, size: 54, color: theme.hintColor.withValues(alpha: 0.5)),
                  const SizedBox(height: 10),
                  Text(empty, textAlign: TextAlign.center, style: textRegular.copyWith(color: theme.hintColor)),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => BusTripRow(booking: list[i]),
                ),
    );
  }
}

class BusTripRow extends StatelessWidget {
  final BusBooking booking;
  const BusTripRow({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = booking;
    final needsMe = b.toPay;
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Get.to(() => BusBookingScreen(bookingId: b.id)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
              border: Border.all(color: needsMe ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.15), width: needsMe ? 1.5 : 1)),
          child: Row(children: [
            BusAgencyLogo(agency: b.agency, size: 42),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${b.from ?? ''} → ${b.to ?? ''}', style: textSemiBold.copyWith(color: theme.textTheme.bodyLarge?.color)),
              Text('${busWhen(b.leavesAt)} · ${b.agency?.name ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              Text('bus_seats_picked'.trParams({'seats': b.seats.join(', ')}), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ])),
            BusStatusChip(booking: b),
          ]),
        ),
      ),
    );
  }
}
