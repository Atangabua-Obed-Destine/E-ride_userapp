import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing_user_app/features/explore/screens/place_detail_screen.dart';
import 'package:ride_sharing_user_app/features/explore/widgets/explore_widgets.dart';
import 'package:ride_sharing_user_app/features/guide/controllers/guide_controller.dart';
import 'package:ride_sharing_user_app/features/guide/domain/models/guide_models.dart';
import 'package:ride_sharing_user_app/features/guide/screens/tour_stop_screen.dart';
import 'package:ride_sharing_user_app/features/guide/widgets/guide_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// A tour: the stops on a map and in order, the ride between each, total time
/// and ride cost, then Start tour (a normal ride to stop 1).
class TourScreen extends StatefulWidget {
  final String tourId;
  final String? title;
  const TourScreen({super.key, required this.tourId, this.title});

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<TourScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<GuideController>().loadTour(widget.tourId, force: true));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GetBuilder<GuideController>(builder: (g) {
      final TourDetail? tour = g.tourOf(widget.tourId);
      final bool running = g.run?.tourId == widget.tourId;
      return Scaffold(
        backgroundColor: theme.cardColor,
        appBar: AppBar(
          backgroundColor: theme.cardColor,
          surfaceTintColor: Colors.transparent,
          foregroundColor: theme.textTheme.bodyLarge?.color,
          elevation: 0,
          title: Text(tour?.card.title ?? widget.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
        ),
        bottomNavigationBar: tour == null || tour.stops.isEmpty ? null : _StartBar(tour: tour, running: running),
        body: tour == null
            ? Center(child: g.tourLoading ? const CircularProgressIndicator() : Text('guide_load_failed'.tr, style: textMedium.copyWith(color: theme.hintColor)))
            : ListView(
                padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeExtraLarge),
                children: [
                  _TourMap(stops: tour.stops),
                  Padding(
                    padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        GuideChip(icon: Icons.flag_rounded, text: tour.card.stopsCount == 1 ? 'guide_one_stop'.tr : 'guide_n_stops'.trParams({'n': '${tour.card.stopsCount}'})),
                        GuideChip(icon: Icons.schedule_rounded, text: 'guide_about_time'.trParams({'time': GuideText.duration(tour.card.minutes)})),
                        if (tour.card.rideFare != null)
                          GuideChip(icon: Icons.local_taxi_rounded, text: GuideText.tourMeta(tour.card).split('  ·  ').last),
                      ]),
                      if (tour.card.intro != null) ...[
                        const SizedBox(height: Dimensions.paddingSize),
                        Text(tour.card.intro!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, height: 1.45, color: theme.textTheme.bodyMedium?.color)),
                      ],
                      const SizedBox(height: Dimensions.paddingSizeSmall),
                      Text('guide_estimate_note'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: theme.hintColor)),
                      const SizedBox(height: Dimensions.paddingSizeDefault),
                      for (final TourStopItem s in tour.stops) _StopRow(stop: s, last: s == tour.stops.last),
                    ]),
                  ),
                ],
              ),
      );
    });
  }
}

class _TourMap extends StatelessWidget {
  final List<TourStopItem> stops;
  const _TourMap({required this.stops});

  @override
  Widget build(BuildContext context) {
    final List<LatLng> points = stops.where((s) => s.place.hasLocation).map((s) => LatLng(s.place.latitude!, s.place.longitude!)).toList();
    if (points.isEmpty) return const SizedBox.shrink();
    double minLat = points.first.latitude, maxLat = minLat, minLng = points.first.longitude, maxLng = minLng;
    for (final LatLng p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final LatLng center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final double span = math.max(math.max(maxLat - minLat, maxLng - minLng), 0.004);
    // Rough zoom so every stop fits, with a margin.
    final double zoom = (math.log(360 / span) / math.ln2 - 1.3).clamp(10.0, 16.0);
    return SizedBox(
      height: 220,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: center, zoom: zoom),
        liteModeEnabled: true,
        markers: {
          for (int i = 0; i < stops.length; i++)
            if (stops[i].place.hasLocation)
              Marker(
                markerId: MarkerId('stop$i'),
                position: LatLng(stops[i].place.latitude!, stops[i].place.longitude!),
                infoWindow: InfoWindow(title: '${i + 1}. ${stops[i].place.name}'),
                icon: BitmapDescriptor.defaultMarkerWithHue(i == 0 ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed),
              ),
        },
        polylines: {
          if (points.length > 1)
            Polyline(polylineId: const PolylineId('route'), points: points, width: 3, color: guideGreen, patterns: [PatternItem.dash(18), PatternItem.gap(10)]),
        },
        zoomControlsEnabled: false,
        myLocationButtonEnabled: false,
        mapToolbarEnabled: false,
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final TourStopItem stop;
  final bool last;
  const _StopRow({required this.stop, required this.last});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 30, child: Column(children: [
          Container(
            width: 26, height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: stop.position == 1 ? guideGreen : theme.primaryColor, borderRadius: BorderRadius.circular(13)),
            child: Text('${stop.position}', style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white)),
          ),
          if (!last) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: theme.hintColor.withValues(alpha: 0.25))),
        ])),
        const SizedBox(width: Dimensions.paddingSize),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeLarge),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (stop.ride != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(Icons.local_taxi_rounded, size: 14, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Flexible(child: Text(
                    stop.position == 1 ? '${'guide_from_you'.tr}: ${GuideText.leg(stop.ride!)}' : GuideText.leg(stop.ride!),
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: theme.hintColor),
                  )),
                ]),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => Get.to(() => PlaceDetailScreen(place: stop.place)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(width: 64, height: 56, child: PlacePhotoBox(url: stop.place.coverThumb, category: stop.place.exploreCategory, iconSize: 22)),
                ),
                const SizedBox(width: Dimensions.paddingSize),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(stop.place.name, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
                  Text('${PlaceText.category(stop.place.category)}  ·  ${'guide_stay_about'.trParams({'time': GuideText.duration(stop.stayMinutes)})}',
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                  if (stop.place.hasErideRating || stop.place.hasRating) Padding(padding: const EdgeInsets.only(top: 2), child: GuideRatings(place: stop.place)),
                ])),
              ]),
            ),
            if (stop.note != null || stop.guide?.story != null) ...[
              const SizedBox(height: 6),
              Text(stop.note ?? stop.guide!.story!, maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, height: 1.4, color: theme.textTheme.bodyMedium?.color)),
            ],
          ]),
        )),
      ]),
    );
  }
}

class _StartBar extends StatelessWidget {
  final TourDetail tour;
  final bool running;
  const _StartBar({required this.tour, required this.running});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final GuideController g = Get.find<GuideController>();
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('guide_start_hint'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: g.ridingTo != null
                    ? null
                    : running
                        ? () => Get.to(() => const TourStopScreen())
                        : () async {
                            if (g.run != null && !await _replaceRun(g.run!)) return;
                            await g.startTour(tour);
                          },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: g.ridingTo != null
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(running ? Icons.route_rounded : Icons.local_taxi_rounded, size: 20),
                label: Text(running ? 'guide_continue_tour'.tr : 'guide_start_tour'.tr,
                    style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  static Future<bool> _replaceRun(TourRun current) async {
    final bool? ok = await Get.dialog<bool>(AlertDialog(
      title: Text('guide_replace_title'.tr),
      content: Text('guide_replace_body'.trParams({'name': current.title})),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('cancel'.tr)),
        TextButton(onPressed: () => Get.back(result: true), child: Text('guide_start_tour'.tr)),
      ],
    ));
    return ok == true;
  }
}
