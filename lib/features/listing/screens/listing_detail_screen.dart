import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/call_options_sheet.dart';
import 'package:ride_sharing_user_app/features/listing/controllers/listing_controller.dart';
import 'package:ride_sharing_user_app/features/listing/domain/models/listing_model.dart';
import 'package:ride_sharing_user_app/features/listing/screens/my_listings_screen.dart';
import 'package:ride_sharing_user_app/features/listing/widgets/listing_widgets.dart';
import 'package:ride_sharing_user_app/features/listing/widgets/reservation_widgets.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// One place to rent: photos (E-Ride's marked), the badge and E-Ride's report,
/// the terms, how to live there, and booking a visit. The owner's number only
/// appears once a visit is accepted.
class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  final Listing? initial;
  const ListingDetailScreen({super.key, required this.listingId, this.initial});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  int _photo = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ListingController c = Get.find<ListingController>();
      c.loadListing(widget.listingId);
      c.loadMeta();
      if (!c.visitsLoaded) c.loadVisits();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GetBuilder<ListingController>(builder: (c) {
      final Listing? l = c.listing(widget.listingId) ?? widget.initial;
      if (l == null) {
        return Scaffold(appBar: AppBar(), body: Center(child: c.detailLoading ? const CircularProgressIndicator() : Text('listing_not_available'.tr)));
      }
      final ListingVisit? visit = c.openVisitTo(l.id);
      return Scaffold(
        // The theme's scaffold colour is the dark header band of other screens; this page is all content.
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
        body: CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: theme.cardColor,
            foregroundColor: theme.textTheme.bodyLarge?.color,
            actions: [
              if (!l.isMine)
                IconButton(
                  tooltip: 'listing_report'.tr,
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: () => ListingSheet.show(ReportListingSheet(listingId: l.id)),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(background: _Photos(listing: l, index: _photo, onChanged: (i) => setState(() => _photo = i))),
          ),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ListingBadge(listing: l),
                const Spacer(),
                if (l.status == 'rented') Text('listing_status_rented'.tr, style: textBold.copyWith(color: theme.hintColor)),
              ]),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Text(l.title, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: 2),
              Text('${ListingText.type(l.type)} · ${l.neighbourhood}${l.ownerFirstName != null ? ' · ${'listing_by'.tr} ${l.ownerFirstName}' : ''}',
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              if (l.confirmedAt != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.event_available_rounded, size: 16, color: l.notConfirmedRecently ? listingAmber : listingVerifiedGreen),
                  const SizedBox(width: 4),
                  Text(ListingText.confirmed(l.confirmedAt), style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall,
                      color: l.notConfirmedRecently ? listingAmber : listingVerifiedGreen)),
                ]),
              ],

              const SizedBox(height: Dimensions.paddingSizeDefault),
              _Box(children: [
                Text(ListingText.rent(l), style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.primaryColor)),
                if (l.rentPeriod == 'year')
                  Text('listing_about_per_month'.trParams({'amount': PriceConverter.convertPrice(l.monthlyRent)}),
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                _Line(label: 'listing_advance'.tr, value: l.advanceMonths == null ? 'listing_ask_owner'.tr : 'listing_months'.trParams({'count': '${l.advanceMonths}'})),
                _Line(label: 'listing_caution'.tr, value: l.caution == null ? 'listing_ask_owner'.tr : PriceConverter.convertPrice(l.caution!)),
                _Line(label: 'listing_free'.tr, value: '${l.unitsAvailable} · ${l.availableFrom == null || l.availableFrom!.isBefore(DateTime.now()) ? 'listing_now'.tr : ListingText.day(l.availableFrom)}'),
                _Line(label: 'listing_furnished'.tr, value: l.furnished ? 'yes'.tr : 'no'.tr),
                if (l.reservation != null) ...[
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.shield_rounded, size: 18, color: listingVerifiedGreen),
                    const SizedBox(width: 6),
                    Expanded(child: Text('listing_reserve_offer'.trParams({'amount': PriceConverter.convertPrice(l.reservation!.amount)}),
                        style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color))),
                  ]),
                ],
              ]),

              if (l.verified) ...[
                const SizedBox(height: Dimensions.paddingSizeDefault),
                _Box(color: listingVerifiedGreen.withValues(alpha: 0.07), children: [
                  Row(children: [
                    const Icon(Icons.verified_rounded, color: listingVerifiedGreen, size: 20),
                    const SizedBox(width: 6),
                    Expanded(child: Text('listing_verified_report'.trParams({'date': ListingText.day(l.verificationDate)}),
                        style: textBold.copyWith(color: theme.textTheme.bodyLarge?.color))),
                  ]),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  for (final check in l.verificationChecks)
                    Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
                      const Icon(Icons.check_rounded, color: listingVerifiedGreen, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text('listing_check_$check'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall))),
                    ])),
                ]),
              ],

              // "Living there" only when the owner said something about it.
              ...() {
                final List<Widget> facts = [
                  if (l.water != null) _Fact(icon: Icons.water_drop_outlined, text: 'listing_water_${l.water}'.tr),
                  if (l.power != null) _Fact(icon: Icons.bolt_rounded, text: 'listing_power_${l.power}'.tr),
                  if (l.backupPower) _Fact(icon: Icons.battery_charging_full_rounded, text: 'listing_has_backup_power'.tr),
                  if (l.toilet != null) _Fact(icon: Icons.wc_rounded, text: 'listing_toilet_${l.toilet}'.tr),
                  if (l.kitchen != null) _Fact(icon: Icons.kitchen_outlined, text: 'listing_kitchen_${l.kitchen}'.tr),
                  if (l.fenced) _Fact(icon: Icons.fence_rounded, text: 'listing_fenced'.tr),
                  if (l.security) _Fact(icon: Icons.security_rounded, text: 'listing_security'.tr),
                  for (final a in l.amenities.where(ListingAmenity.icons.containsKey))
                    _Fact(icon: ListingAmenity.icon(a), text: ListingAmenity.label(a)),
                ];
                final bool hasText = (l.description ?? '').isNotEmpty;
                if (facts.isEmpty && !hasText) return const <Widget>[];
                return <Widget>[
                  const ListingSectionTitle(''),
                  Text('listing_living_there'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault)),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  if (facts.isNotEmpty) Wrap(spacing: Dimensions.paddingSizeSmall, runSpacing: Dimensions.paddingSizeSmall, children: facts),
                  if (hasText) ...[
                    const SizedBox(height: Dimensions.paddingSizeDefault),
                    Text(l.description!, style: textRegular.copyWith(height: 1.4, color: theme.textTheme.bodyMedium?.color)),
                  ],
                ];
              }(),

              const ListingSectionTitle(''),
              Text('listing_where_it_is'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault)),
              const SizedBox(height: 4),
              Text([l.neighbourhood, if ((l.address ?? '').isNotEmpty) l.address!].join(' · '),
                  style: textRegular.copyWith(color: theme.textTheme.bodyMedium?.color)),
              if (l.landmarkDistanceM != null && l.landmarkName != null) ...[
                const SizedBox(height: 4),
                Text('${ListingText.distance(l.landmarkDistanceM!)} ${'listing_from'.tr} ${l.landmarkName} · ${ListingText.walk(l.landmarkDistanceM!)}',
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              ],

              const SizedBox(height: Dimensions.paddingSizeDefault),
              Container(
                padding: const EdgeInsets.all(Dimensions.paddingSize),
                decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.shield_outlined, color: theme.primaryColor, size: 20),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Expanded(child: Text('listing_never_pay_before_visit'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall))),
                ]),
              ),
              const SizedBox(height: 120),
            ]),
          )),
        ]),
        // Sized to its content: ButtonWidget centres itself and would otherwise fill the screen.
        bottomNavigationBar: ColoredBox(color: theme.cardColor, child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall, Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall),
            child: _BottomAction(listing: l, visit: visit),
          ),
        ]))),
      );
    });
  }
}

class _BottomAction extends StatelessWidget {
  final Listing listing;
  final ListingVisit? visit;
  const _BottomAction({required this.listing, this.visit});

  @override
  Widget build(BuildContext context) {
    final ListingController c = Get.find<ListingController>();
    final ThemeData theme = Theme.of(context);
    if (listing.isMine) {
      return ButtonWidget(buttonText: 'listing_manage_in_my_listings'.tr, onPressed: () => Get.to(() => const MyListingsScreen()));
    }
    if (!listing.isLive && visit == null) {
      return Text('listing_not_available'.tr, textAlign: TextAlign.center, style: textMedium.copyWith(color: theme.hintColor));
    }
    final ListingVisit? v = visit;
    if (v == null) {
      return ButtonWidget(buttonText: 'listing_book_visit'.tr, onPressed: () => ListingSheet.show(BookVisitSheet(listing: listing)));
    }
    final String when = '${ListingText.day(v.date)}, ${ListingText.window(v.window)}';
    if (v.status == 'requested') {
      return _Status(text: 'listing_visit_waiting'.trParams({'when': when}));
    }
    if (v.status == 'proposed') {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        _Status(text: 'listing_visit_proposed_to_you'.trParams({'when': '${ListingText.day(v.proposedDate)}, ${ListingText.window(v.proposedWindow ?? '')}'})),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        ButtonWidget(buttonText: 'listing_accept_new_time'.tr, onPressed: c.saving ? null : () => c.seekerRespond(v.id, 'accept_proposal')),
      ]);
    }
    // Accepted, or the day has come.
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (v.reservation != null)
        ReservationPanel(visit: v)
      else
        _Status(text: 'listing_visit_on'.trParams({'when': when, 'name': v.otherName})),
      if (v.canReserve) ...[
        const SizedBox(height: Dimensions.paddingSizeSmall),
        ButtonWidget(buttonText: 'listing_reserve_with_eride'.tr, onPressed: () => ListingSheet.show(ReserveSheet(visitId: v.id))),
      ],
      const SizedBox(height: Dimensions.paddingSizeSmall),
      Row(children: [
        if (v.otherPhone != null)
          Expanded(child: ButtonWidget(buttonText: 'listing_call_owner'.tr, transparent: true, showBorder: true,
              onPressed: () => CallOptionsSheet.show(phone: v.otherPhone, name: v.otherName))),
        if (v.otherPhone != null) const SizedBox(width: Dimensions.paddingSizeSmall),
        Expanded(child: v.canRate
            ? ButtonWidget(buttonText: 'listing_how_was_visit'.tr, onPressed: () => ListingSheet.show(VisitOutcomeSheet(visit: v)))
            : ButtonWidget(buttonText: 'listing_ride_there'.tr, onPressed: c.openingId != null ? null : () => c.rideThere(
                id: listing.id, latitude: listing.latitude, longitude: listing.longitude, label: '${listing.title}, ${listing.neighbourhood}'))),
      ]),
    ]);
  }
}

class _Status extends StatelessWidget {
  final String text;
  const _Status({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Dimensions.paddingSize),
        decoration: BoxDecoration(color: Theme.of(context).hintColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Text(text, textAlign: TextAlign.center, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
      );
}

class _Photos extends StatelessWidget {
  final Listing listing;
  final int index;
  final ValueChanged<int> onChanged;
  const _Photos({required this.listing, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (listing.photos.isEmpty) return const ListingPhotoBox(url: null, radius: BorderRadius.zero);
    final ListingPhoto current = listing.photos[index.clamp(0, listing.photos.length - 1)];
    return Stack(fit: StackFit.expand, children: [
      PageView.builder(
        itemCount: listing.photos.length,
        onPageChanged: onChanged,
        itemBuilder: (_, i) => ListingPhotoBox(url: listing.photos[i].url, radius: BorderRadius.zero),
      ),
      Positioned(left: 12, bottom: 12, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(current.byEride ? Icons.verified_rounded : Icons.person_outline_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(current.byEride ? 'listing_photo_by_eride'.trParams({'date': ListingText.day(current.takenAt)}) : 'listing_photo_by_owner'.tr,
              style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white)),
        ]),
      )),
      Positioned(right: 12, bottom: 12, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
        child: Text('${index + 1} / ${listing.photos.length}', style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white)),
      )),
    ]);
  }
}

class _Box extends StatelessWidget {
  final List<Widget> children;
  final Color? color;
  const _Box({required this.children, this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        decoration: BoxDecoration(color: color ?? Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  const _Line({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Expanded(child: Text(label, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
        Text(value, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Fact({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: theme.primaryColor),
        const SizedBox(width: 6),
        Text(text, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
      ]),
    );
  }
}
