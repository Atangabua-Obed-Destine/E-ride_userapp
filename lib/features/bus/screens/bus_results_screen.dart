import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/bus/controllers/bus_controller.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_seats_screen.dart';
import 'package:ride_sharing_user_app/features/bus/widgets/bus_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The day's departures for a route: a strip of days, quick filters, then each departure
/// (bookable first). A full one offers "Tell me" when a seat frees up.
class BusResultsScreen extends StatefulWidget {
  const BusResultsScreen({super.key});

  @override
  State<BusResultsScreen> createState() => _BusResultsScreenState();
}

class _BusResultsScreenState extends State<BusResultsScreen> {
  BusController get _c => Get.find<BusController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _c.search());
  }

  void _day(DateTime d) {
    _c.setDate(d);
    _c.search();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
        title: GetBuilder<BusController>(builder: (c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c.from ?? ''} → ${c.to ?? 'bus_anywhere'.tr}', style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
              Text('bus_prices_per_seat'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ])),
      ),
      body: GetBuilder<BusController>(builder: (c) {
        final days = List.generate(c.meta?.openDays ?? 7, (i) => DateTime.now().add(Duration(days: i)));
        final list = c.shown;
        return Column(children: [
          Container(
            color: theme.cardColor,
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(children: [
              SizedBox(
                height: 64,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final d = days[i];
                    final key = BusController.ymd(d);
                    final selected = key == BusController.ymd(c.date);
                    final n = c.result?.days[key];
                    return Semantics(
                      selected: selected, button: true,
                      child: InkWell(
                        onTap: () => _day(d),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 74,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? theme.primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: selected ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.25)),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(i < 2 ? busDay(d) : 'market_wd_${d.weekday}'.tr, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: selected ? Colors.white : textColor)),
                            Text(n == null ? '${d.day}' : 'bus_n_departures_short'.trParams({'n': '$n'}),
                                style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: selected ? Colors.white70 : theme.hintColor)),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final f in const ['all', 'morning', 'afternoon', 'vip', 'when_full'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('bus_filter_$f'.tr),
                          selected: c.filter == f,
                          onSelected: (_) => c.setFilter(f),
                          showCheckmark: false,
                          selectedColor: theme.primaryColor.withValues(alpha: 0.12),
                          labelStyle: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: c.filter == f ? theme.primaryColor : textColor),
                          side: BorderSide(color: c.filter == f ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.3)),
                        ),
                      ),
                  ],
                ),
              ),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: c.search,
              child: c.searching && c.result == null
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
                          for (final n in c.result?.notices ?? const []) BusNoticeCard(notice: n),
                          const SizedBox(height: 60),
                          Icon(Icons.directions_bus_outlined, size: 54, color: theme.hintColor.withValues(alpha: 0.5)),
                          const SizedBox(height: 10),
                          Text('bus_no_departure'.tr, textAlign: TextAlign.center, style: textSemiBold.copyWith(color: textColor)),
                          Padding(padding: const EdgeInsets.all(16),
                              child: Text('bus_no_departure_hint'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(color: theme.hintColor))),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                          itemCount: list.length + (c.result?.notices.length ?? 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final notices = c.result?.notices ?? const [];
                            if (i < notices.length) return BusNoticeCard(notice: notices[i]);
                            final d = list[i - notices.length];
                            return BusDepartureCard(
                              departure: d,
                              onTap: () => Get.to(() => BusSeatsScreen(departureId: d.id)),
                              onWaitlist: () async {
                                final on = await c.toggleWaitlist(d.id);
                                showCustomSnackBar(on ? 'bus_waitlist_on'.tr : 'bus_waitlist_off'.tr, isError: false);
                              },
                            );
                          },
                        ),
            ),
          ),
        ]);
      }),
    );
  }
}
