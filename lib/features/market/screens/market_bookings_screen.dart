import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_booking_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_booking_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_service_settings_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_service_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// A booking in a list: the service, when, with whom, and its status.
class MarketBookingRow extends StatelessWidget {
  final MarketBooking booking;
  final bool showDay;
  const MarketBookingRow({super.key, required this.booking, this.showDay = true});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final needsMe = (b.isProvider && (b.status == MarketBooking.requested || b.status == MarketBooking.quoteRequested)) ||
        (!b.isProvider && (b.status == MarketBooking.suggested || b.status == MarketBooking.quoted));
    final when = b.startsAt != null
        ? (showDay ? marketWhen(b.startsAt) : marketTimeRange(b.startsAt, b.endsAt))
        : (b.whenText ?? 'market_price_to_come'.tr);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await Get.to(() => MarketBookingScreen(bookingId: b.id));
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                border: Border.all(color: needsMe ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.15), width: needsMe ? 1.5 : 1)),
            child: Row(children: [
              b.cover != null
                  ? ImageWidget(image: b.cover!, width: 48, height: 48, radius: 10, fit: BoxFit.cover)
                  : Container(width: 48, height: 48, decoration: BoxDecoration(color: marketServiceBg, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.event_available_outlined, color: marketServiceFg)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.itemTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
                Text('$when · ${b.isProvider ? (b.clientName ?? '') : b.shopName}', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                if (b.location == 'client' && b.isProvider)
                  Text('market_at_client_short'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.primaryColor)),
              ])),
              const SizedBox(width: 6),
              MarketBookingStatusChip(booking: b),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The client's bookings: upcoming (with what to answer first) and past.
class MarketMyBookingsScreen extends StatefulWidget {
  const MarketMyBookingsScreen({super.key});

  @override
  State<MarketMyBookingsScreen> createState() => _MarketMyBookingsScreenState();
}

class _MarketMyBookingsScreenState extends State<MarketMyBookingsScreen> {
  MarketBookingController get _c => Get.find<MarketBookingController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.loadList('client', 'upcoming');
      _c.loadList('client', 'past');
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
          title: Text('market_my_bookings'.tr),
          bottom: TabBar(tabs: [Tab(text: 'market_upcoming'.tr), Tab(text: 'market_past'.tr)]),
        ),
        body: GetBuilder<MarketBookingController>(builder: (c) => TabBarView(children: [
          _list(c, 'upcoming', Icons.event_available_outlined, 'market_no_upcoming'.tr),
          _list(c, 'past', Icons.history_rounded, 'market_no_past'.tr),
        ])),
      ),
    );
  }

  Widget _list(MarketBookingController c, String tab, IconData icon, String empty) {
    final list = [...c.list('client', tab)];
    if (tab == 'upcoming') {
      // What waits for me first.
      list.sort((a, b) {
        int rank(MarketBooking x) => x.status == MarketBooking.suggested || x.status == MarketBooking.quoted ? 0 : 1;
        return rank(a).compareTo(rank(b));
      });
    }
    return RefreshIndicator(
      onRefresh: () => c.loadList('client', tab),
      child: c.isLoading('client', tab) && list.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? ListView(children: [SizedBox(height: 420, child: MarketEmpty(icon: icon, title: empty, body: 'market_bookings_empty_body'.tr))])
              : ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [for (final b in list) MarketBookingRow(booking: b)]),
    );
  }
}

/// The provider's bookings: requests to answer, then the day (a strip of the next 7 days).
class MarketProviderBookingsScreen extends StatefulWidget {
  const MarketProviderBookingsScreen({super.key});

  @override
  State<MarketProviderBookingsScreen> createState() => _MarketProviderBookingsScreenState();
}

class _MarketProviderBookingsScreenState extends State<MarketProviderBookingsScreen> {
  String _date = marketApiDate(DateTime.now());

  MarketBookingController get _c => Get.find<MarketBookingController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await Future.wait([_c.loadList('provider', 'requests'), _c.loadList('provider', 'day', date: _date)]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
        title: Text('market_bookings'.tr),
        actions: [
          IconButton(tooltip: 'market_when_free'.tr, icon: const Icon(Icons.tune_rounded),
              onPressed: () => Get.to(() => const MarketServiceSettingsScreen())),
        ],
      ),
      body: GetBuilder<MarketBookingController>(builder: (c) {
        final requests = c.list('provider', 'requests');
        final day = c.list('provider', 'day', _date);
        final days = c.providerDays;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
            if (requests.isNotEmpty) ...[
              Text('market_to_answer'.trParams({'count': '${requests.length}'}), style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
              const SizedBox(height: 8),
              for (final b in requests) MarketBookingRow(booking: b),
              const SizedBox(height: Dimensions.paddingSizeDefault),
            ],
            if (days.isNotEmpty)
              SizedBox(height: 70, child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final d = days[i];
                  final date = '${d['date']}';
                  final on = date == _date;
                  final dt = DateTime.parse(date);
                  final n = int.tryParse('${d['count']}') ?? 0;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() => _date = date);
                      c.loadList('provider', 'day', date: date);
                    },
                    child: Container(
                      width: 58,
                      decoration: BoxDecoration(color: on ? textColor : theme.cardColor, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: on ? Colors.transparent : theme.hintColor.withValues(alpha: 0.25))),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('market_wd_${dt.weekday}'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: on ? theme.cardColor : theme.hintColor)),
                        Text('${dt.day}', style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: on ? theme.cardColor : textColor)),
                        Text(n == 0 ? '-' : '$n', style: textSemiBold.copyWith(fontSize: 10, color: on ? theme.cardColor : theme.primaryColor)),
                      ]),
                    ),
                  );
                },
              )),
            const SizedBox(height: 12),
            Text(marketDayLabel(DateTime.parse(_date)), style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
            const SizedBox(height: 8),
            if (c.isLoading('provider', 'day', _date) && day.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (day.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('market_day_empty'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(color: theme.hintColor)))
            else
              for (final b in day) MarketBookingRow(booking: b, showDay: false),
            const SizedBox(height: 40),
          ]),
        );
      }),
    );
  }
}
