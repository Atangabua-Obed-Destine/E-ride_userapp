import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/bus/controllers/bus_controller.dart';
import 'package:ride_sharing_user_app/features/bus/domain/models/bus_models.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_agency_screen.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_booking_screen.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_results_screen.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_trips_screen.dart';
import 'package:ride_sharing_user_app/features/bus/widgets/bus_widgets.dart';
import 'package:ride_sharing_user_app/features/explore/controllers/explore_controller.dart';
import 'package:ride_sharing_user_app/features/explore/domain/models/explore_place_model.dart';
import 'package:ride_sharing_user_app/features/explore/screens/place_detail_screen.dart';
import 'package:ride_sharing_user_app/features/explore/screens/place_list_screen.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:url_launcher/url_launcher.dart';

/// Explore > Bus agencies, when bus booking is on: book a seat (from, to, day), popular trips,
/// the agencies bookable in E-Ride, then the other agencies Google knows (call them, or ride there).
class BusHomeScreen extends StatefulWidget {
  final String title;
  const BusHomeScreen({super.key, required this.title});

  @override
  State<BusHomeScreen> createState() => _BusHomeScreenState();
}

class _BusHomeScreenState extends State<BusHomeScreen> {
  BusController get _c => Get.find<BusController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.loadMeta(force: true);
      _c.loadAgencies();
      _c.loadList('upcoming');
      Get.find<ExploreController>().open('bus');
    });
  }

  Future<void> _refresh() async {
    await Future.wait([_c.loadMeta(force: true), _c.loadAgencies(), _c.loadList('upcoming'), Get.find<ExploreController>().load(force: true)]);
  }

  void _find() {
    if (_c.from == null) return;
    Get.to(() => const BusResultsScreen());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
        title: Text(widget.title),
        actions: [
          GetBuilder<BusController>(builder: (c) => IconButton(
                tooltip: 'bus_my_trips'.tr,
                onPressed: () => Get.to(() => const BusTripsScreen()),
                icon: Badge(isLabelVisible: c.attention > 0, label: Text('${c.attention}'), child: const Icon(Icons.confirmation_number_outlined)),
              )),
        ],
      ),
      body: GetBuilder<BusController>(builder: (c) {
        final BusRoute? route = c.meta?.routeFrom(c.from);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
            for (final n in c.meta?.notices ?? const <BusNotice>[]) BusNoticeCard(notice: n),
            _SearchCard(controller: c, route: route, onFind: _find),
            if (c.list('upcoming').isNotEmpty) ...[
              const SizedBox(height: 14),
              _NextTrip(booking: c.list('upcoming').first),
            ],
            if (route != null && route.to.isNotEmpty) ...[
              const SizedBox(height: 20),
              _Heading('bus_popular_from'.trParams({'city': route.from})),
              SizedBox(
                height: 104,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: route.to.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _PopularCard(dest: route.to[i], onTap: () {
                    c.setTo(route.to[i].city);
                    _find();
                  }),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _Heading('bus_book_in_eride'.tr, sub: 'bus_book_in_eride_hint'.tr),
            if (c.agenciesLoading)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
            else if (c.agencies.isEmpty)
              Text('bus_no_agency_yet'.tr, style: textRegular.copyWith(color: theme.hintColor))
            else
              ...c.agencies.map((a) => _AgencyRow(agency: a)),
            const SizedBox(height: 20),
            _GoogleAgencies(known: c.agencies.map((a) => a.googlePlaceId).whereType<String>().toSet(), title: widget.title),
          ]),
        );
      }),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  final String? sub;
  const _Heading(this.text, {this.sub});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Theme.of(context).textTheme.bodyLarge?.color)),
          if (sub != null) Text(sub!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
        ]),
      );
}

/// From, to, the day, and Find seats.
class _SearchCard extends StatelessWidget {
  final BusController controller;
  final BusRoute? route;
  final VoidCallback onFind;
  const _SearchCard({required this.controller, required this.route, required this.onFind});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final froms = c.meta?.routes.map((r) => r.from).toList() ?? [];
    final tos = route?.to.map((d) => d.city).toList() ?? [];
    final days = List.generate(7, (i) => DateTime.now().add(Duration(days: i)));
    InputDecoration deco(String label, IconData icon) => InputDecoration(
          labelText: label, prefixIcon: Icon(icon, size: 20), isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('bus_book_a_seat'.tr.toUpperCase(), style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor, letterSpacing: 1)),
        const SizedBox(height: 12),
        if (c.meta == null)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        else if (froms.isEmpty)
          Text('bus_no_route_yet'.tr, style: textRegular.copyWith(color: theme.hintColor))
        else ...[
          DropdownButtonFormField<String>(
            initialValue: froms.contains(c.from) ? c.from : null,
            decoration: deco('bus_from'.tr, Icons.trip_origin_rounded),
            items: froms.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: c.setFrom,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            key: ValueKey('to-${c.from}'),
            initialValue: tos.contains(c.to) ? c.to : null,
            decoration: deco('bus_to'.tr, Icons.place_outlined),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text('bus_anywhere'.tr)),
              ...tos.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t))),
            ],
            onChanged: c.setTo,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = days[i];
                final selected = BusController.ymd(d) == BusController.ymd(c.date);
                return ChoiceChip(
                  label: Text(busDay(d)),
                  selected: selected,
                  onSelected: (_) => c.setDate(d),
                  labelStyle: textSemiBold.copyWith(color: selected ? theme.primaryColor : textColor, fontSize: Dimensions.fontSizeSmall),
                  selectedColor: theme.primaryColor.withValues(alpha: 0.12),
                  side: BorderSide(color: selected ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.3)),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(height: 50, child: ElevatedButton.icon(
            onPressed: c.from == null ? null : onFind,
            icon: const Icon(Icons.search_rounded),
            label: Text('bus_find_seats'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
            style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          )),
        ],
      ]),
    );
  }
}

/// The next trip, right under the search: its status and a tap to open it.
class _NextTrip extends StatelessWidget {
  final BusBooking booking;
  const _NextTrip({required this.booking});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = booking;
    return Material(
      color: theme.primaryColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Get.to(() => BusBookingScreen(bookingId: b.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(Icons.confirmation_number_outlined, color: theme.primaryColor),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${b.from ?? ''} → ${b.to ?? ''}', style: textBold.copyWith(color: theme.textTheme.bodyLarge?.color)),
              Text('${busWhen(b.leavesAt)} · ${b.agency?.name ?? ''}', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ])),
            BusStatusChip(booking: b),
          ]),
        ),
      ),
    );
  }
}

class _PopularCard extends StatelessWidget {
  final BusDestinationSummary dest;
  final VoidCallback onTap;
  const _PopularCard({required this.dest, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 150, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.hintColor.withValues(alpha: 0.15))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(dest.city, maxLines: 1, overflow: TextOverflow.ellipsis, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
            if (dest.fromFare != null) Text('bus_from_fare'.trParams({'price': busMoney(dest.fromFare)}), style: textSemiBold.copyWith(color: theme.primaryColor)),
            Text('bus_departures_week'.trParams({'n': '${dest.departures}'}), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ]),
        ),
      ),
    );
  }
}

class _AgencyRow extends StatelessWidget {
  final BusAgency agency;
  const _AgencyRow({required this.agency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = agency;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Get.to(() => BusAgencyScreen(agencyId: a.id)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              BusAgencyLogo(agency: a),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textBold.copyWith(color: theme.textTheme.bodyLarge?.color))),
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF15803D)),
                ]),
                Text([
                  if (a.rating != null) '★ ${a.rating!.toStringAsFixed(1)}${a.ratingCount > 0 ? ' (${a.ratingCount})' : ''}',
                  if (a.address != null) a.address!,
                ].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                if (a.destinations.isNotEmpty)
                  Text(a.destinations.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
              ])),
              if (a.nextDeparture != null)
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('bus_next'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
                  Text(busTime(a.nextDeparture), style: textBold.copyWith(color: theme.primaryColor)),
                ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The other bus agencies Google knows near the person: not bookable in E-Ride, so call or ride there.
class _GoogleAgencies extends StatelessWidget {
  final Set<String> known;
  final String title;
  const _GoogleAgencies({required this.known, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GetBuilder<ExploreController>(builder: (e) {
      if (e.categoryKey != 'bus') return const SizedBox();
      final List<ExplorePlace> places = [...e.topRated, ...e.nearby]
          .where((p) => p.googlePlaceId == null || !known.contains(p.googlePlaceId)).toList();
      final seen = <String>{};
      places.retainWhere((p) => seen.add(p.id));
      if (places.isEmpty) return const SizedBox();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Heading('bus_other_agencies'.tr, sub: 'bus_other_agencies_hint'.tr),
        ...places.take(8).map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Get.to(() => PlaceDetailScreen(place: p)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textSemiBold.copyWith(color: theme.textTheme.bodyLarge?.color)),
                        Text([
                          if (p.rating != null) '★ ${p.rating!.toStringAsFixed(1)}',
                          if (p.distanceKm != null) '${p.distanceKm!.toStringAsFixed(1)} km',
                        ].join(' · '), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                      ])),
                      if (p.phone != null)
                        IconButton(tooltip: 'bus_call'.tr, icon: const Icon(Icons.call_outlined),
                            onPressed: () => launchUrl(Uri.parse('tel:${p.phone}'))),
                      if (p.hasLocation)
                        TextButton(onPressed: () => e.rideThere(p), child: Text('bus_ride_there'.tr)),
                    ]),
                  ),
                ),
              ),
            )),
        TextButton(onPressed: () => Get.to(() => PlaceListScreen(categoryKey: 'bus', title: title, icon: 'bus')), child: Text('bus_see_all_on_explore'.tr)),
      ]);
    });
  }
}
