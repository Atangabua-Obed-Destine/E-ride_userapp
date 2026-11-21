import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_shed_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_venue_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Markets and sheds: E-Ride's markets (Bamenda Main Market...), and the shops' sheds in them.

const Color marketVenueColor = Color(0xFFB45309);

/// Metres between two points.
double venueMetres(double lat1, double lng1, double lat2, double lng2) {
  const double r = 6371000;
  final double dLat = (lat2 - lat1) * math.pi / 180;
  final double dLng = (lng2 - lng1) * math.pi / 180;
  final double a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}

/// "85 m" or "1.4 km".
String venueDistance(double metres) => metres < 1000 ? '${(metres / 5).round() * 5} m' : '${(metres / 1000).toStringAsFixed(1)} km';

/// The gate nearest a point (or the market itself when it has no gates).
MarketEntrance nearestEntrance(List<MarketEntrance> gates, double lat, double lng, {required double fallbackLat, required double fallbackLng}) {
  if (gates.isEmpty) return MarketEntrance(name: '', lat: fallbackLat, lng: fallbackLng);
  return gates.reduce((a, b) => venueMetres(a.lat, a.lng, lat, lng) <= venueMetres(b.lat, b.lng, lat, lng) ? a : b);
}

/// "Ground floor", "1st floor", "Basement" in the app's language.
String floorName(int floor) {
  if (floor == 0) return 'floor_ground'.tr;
  if (floor < 0) return 'floor_basement'.tr;
  if (floor <= 3) return 'floor_$floor'.tr;
  return 'floor_n'.trParams({'n': '$floor'});
}

/// "Main hall, 1st floor, Block C, Shed 112": where the shed is, in words.
String shedWords(MarketShopVenue v) {
  final parts = [
    if (v.shedBuilding != null) v.shedBuilding!,
    if (v.shedFloor != null) floorName(v.shedFloor!),
    if (v.shedBlock != null) v.shedBlock!,
    if (v.shedNumber != null) 'venue_shed_n'.trParams({'n': v.shedNumber!}),
  ];
  return parts.isEmpty ? v.name : parts.join(', ');
}

/// "Shed 112" in a small pill, with the block when there is one.
class ShedPill extends StatelessWidget {
  final MarketShopVenue venue;
  final bool large;
  const ShedPill({super.key, required this.venue, this.large = false});

  @override
  Widget build(BuildContext context) {
    final String text = shedWords(venue);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 10 : 6, vertical: large ? 5 : 2),
      decoration: BoxDecoration(color: marketVenueColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.storefront_rounded, size: large ? 16 : 12, color: marketVenueColor),
        const SizedBox(width: 4),
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: textBold.copyWith(fontSize: large ? Dimensions.fontSizeDefault : Dimensions.fontSizeExtraSmall, color: marketVenueColor))),
      ]),
    );
  }
}

/// "Shed checked by E-Ride" or "Not verified yet".
class ShedCheckTag extends StatelessWidget {
  final bool checked;
  const ShedCheckTag({super.key, required this.checked});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color c = checked ? marketVerified : theme.hintColor;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(checked ? Icons.verified_rounded : Icons.help_outline_rounded, size: 14, color: c),
      const SizedBox(width: 3),
      Text((checked ? 'venue_shed_checked' : 'venue_shed_not_checked').tr,
          style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: c)),
    ]);
  }
}

/// Market home: the markets, to find a shed.
class MarketVenuesRow extends StatefulWidget {
  const MarketVenuesRow({super.key});

  @override
  State<MarketVenuesRow> createState() => _MarketVenuesRowState();
}

class _MarketVenuesRowState extends State<MarketVenuesRow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<MarketController>().loadVenues());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GetBuilder<MarketController>(builder: (market) {
      final venues = market.venues ?? const <MarketVenue>[];
      if (venues.isEmpty) return const SizedBox.shrink();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall, Dimensions.paddingSizeDefault, 6),
          child: Row(children: [
            const Icon(Icons.location_city_rounded, size: 18, color: marketVenueColor),
            const SizedBox(width: 6),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('venue_row_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
              Text('venue_row_sub'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
            ])),
          ]),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
            itemCount: venues.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _VenueCard(venue: venues[i]),
          ),
        ),
      ]);
    });
  }
}

class _VenueCard extends StatelessWidget {
  final MarketVenue venue;
  const _VenueCard({required this.venue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: marketVenueColor.withValues(alpha: Get.isDarkMode ? 0.2 : 0.07),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Get.to(() => MarketVenueScreen(venue: venue)),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: marketVenueColor.withValues(alpha: 0.25))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(venue.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color, height: 1.2)),
            Row(children: [
              Expanded(child: Text(
                venue.shopsCount == 0
                    ? 'venue_no_shops_short'.tr
                    : 'venue_counts'.trParams({'n': '${venue.shopsCount}', 'v': '${venue.verifiedCount}'}),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor),
              )),
              if (venue.distanceKm != null)
                Text('${venue.distanceKm!.toStringAsFixed(1)} km', style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: marketVenueColor)),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// On a shop's page: its market and shed, and the way there on foot.
class ShopShedCard extends StatelessWidget {
  final MarketShop shop;
  const ShopShedCard({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = shop.venue!;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: marketVenueColor.withValues(alpha: 0.3)),
        color: marketVenueColor.withValues(alpha: Get.isDarkMode ? 0.15 : 0.05),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (v.shopfront != null)
          SizedBox(height: 150, width: double.infinity, child: ImageWidget(image: v.shopfront!, fit: BoxFit.cover)),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.name, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
            const SizedBox(height: 4),
            Row(children: [ShedPill(venue: v, large: true), const SizedBox(width: 8), Flexible(child: ShedCheckTag(checked: v.checked))]),
            if (shop.mapNote != null) ...[
              const SizedBox(height: 6),
              Text(shop.mapNote!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color, height: 1.35)),
            ],
            if (shop.sells.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final s in shop.sells) _SellsChip(text: s)]),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => Get.to(() => MarketVenueScreen(slug: v.slug)),
                icon: const Icon(Icons.location_city_rounded, size: 18),
                label: Text('venue_see_market'.tr, maxLines: 1, overflow: TextOverflow.ellipsis),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
              )),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.icon(
                onPressed: shop.map == null ? null : () => Get.to(() => MarketShedScreen(shop: shop)),
                icon: const Icon(Icons.directions_walk_rounded, size: 18),
                label: Text('venue_walk_there'.tr, maxLines: 1, overflow: TextOverflow.ellipsis),
                style: FilledButton.styleFrom(backgroundColor: marketVenueColor, minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _SellsChip extends StatelessWidget {
  final String text;
  const _SellsChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(4), border: Border.all(color: theme.hintColor.withValues(alpha: 0.25))),
      child: Text(text, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.textTheme.bodyMedium?.color)),
    );
  }
}

/// What a shop sells, as small chips.
class SellsChips extends StatelessWidget {
  final List<String> sells;
  final int max;
  const SellsChips({super.key, required this.sells, this.max = 3});

  @override
  Widget build(BuildContext context) {
    if (sells.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 4, runSpacing: 4, children: [for (final s in sells.take(max)) _SellsChip(text: s)]);
  }
}
