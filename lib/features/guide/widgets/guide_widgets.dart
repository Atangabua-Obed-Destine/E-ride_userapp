import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/explore/domain/models/explore_place_model.dart';
import 'package:ride_sharing_user_app/features/explore/screens/place_detail_screen.dart';
import 'package:ride_sharing_user_app/features/explore/widgets/explore_widgets.dart';
import 'package:ride_sharing_user_app/features/guide/controllers/guide_controller.dart';
import 'package:ride_sharing_user_app/features/guide/domain/models/guide_models.dart';
import 'package:ride_sharing_user_app/features/guide/screens/tour_screen.dart';
import 'package:ride_sharing_user_app/features/guide/screens/tour_stop_screen.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_menu_screen.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Corners in the tour guide: small, the way the team likes them.
const double guideRadius = 8;
const Color guideGreen = Color(0xFF0E9F6E);

class GuideText {
  /// "About 1 h 30", "45 min".
  static String duration(int minutes) {
    if (minutes < 60) return 'guide_minutes'.trParams({'n': '$minutes'});
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    return m == 0 ? 'guide_hours'.trParams({'h': '$h'}) : 'guide_hours_minutes'.trParams({'h': '$h', 'm': m.toString().padLeft(2, '0')});
  }

  static String fee(int? fee) {
    if (fee == null) return 'guide_fee_unknown'.tr;
    if (fee == 0) return 'guide_free_entry'.tr;
    return 'guide_entry_fee'.trParams({'fee': PriceConverter.convertPrice(fee.toDouble())});
  }

  /// "10 min ride · about FCFA 500".
  static String leg(RideLeg leg) {
    final String time = 'guide_ride_minutes'.trParams({'n': '${leg.minutes}'});
    return leg.fare != null ? '$time  ·  ${'guide_about'.trParams({'price': PriceConverter.convertPrice(leg.fare!)})}' : time;
  }

  /// "About 4 h · rides about FCFA 3,000".
  static String tourMeta(TourCard t) {
    final String time = 'guide_about_time'.trParams({'time': duration(t.minutes)});
    return t.rideFare != null ? '$time  ·  ${'guide_rides_about'.trParams({'price': PriceConverter.convertPrice(t.rideFare!)})}' : time;
  }
}

/// Small grey fact chip: "Stay about 1 h", "Free entry".
class GuideChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const GuideChip({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: theme.textTheme.bodyMedium?.color),
        const SizedBox(width: 5),
        Flexible(child: Text(text, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color))),
      ]),
    );
  }
}

/// "★ 4.6 · 12 E-Ride ratings   Google 4.3 (120)".
class GuideRatings extends StatelessWidget {
  final ExplorePlace place;
  final double? erideRating;
  final int? erideRatings;
  const GuideRatings({super.key, required this.place, this.erideRating, this.erideRatings});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? er = erideRating ?? place.erideRating;
    final int en = erideRatings ?? place.erideRatings;
    final List<Widget> parts = [];
    if (er != null && en > 0) {
      parts.add(Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_rounded, size: 16, color: placeStarAmber),
        const SizedBox(width: 2),
        Text(er.toStringAsFixed(1), style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(width: 4),
        Text(en == 1 ? 'guide_one_eride_rating'.tr : 'guide_eride_ratings'.trParams({'n': '$en'}),
            style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
      ]));
    }
    if (place.hasRating) {
      parts.add(Text('Google ${place.rating!.toStringAsFixed(1)} (${place.reviews})',
          style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)));
    }
    if (parts.isEmpty) {
      return Text('guide_not_rated_yet'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor));
    }
    return Wrap(spacing: 12, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: parts);
  }
}

/// Opens the Food & Shops store behind a place, to order from it.
Future<void> orderFromPartner(PartnerStore partner) async {
  final bool ok = await Get.find<StoreController>().openStoreById(partner.id);
  if (ok) {
    Get.to(() => const StoreMenuScreen());
  } else {
    showCustomSnackBar('guide_partner_not_here'.tr);
  }
}

/// "E-Ride partner": this place takes orders in the app.
class PartnerBadge extends StatelessWidget {
  const PartnerBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFFB45309).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.shopping_bag_rounded, size: 11, color: Color(0xFFB45309)),
          const SizedBox(width: 3),
          Text('guide_partner'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: const Color(0xFFB45309))),
        ]),
      );
}

/// A Things to do place: photo, name, what and where, ratings, a rider's
/// words, then About and Visit (and Order when it is an E-Ride partner).
class ThingCard extends StatelessWidget {
  final ExplorePlace place;
  const ThingCard({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final GuideController guide = Get.find<GuideController>();
    final List<String> meta = [
      PlaceText.category(place.category),
      if (place.distanceKm != null) PlaceText.distance(place.distanceKm),
      if (place.openNow != null) place.openNow! ? 'open_now'.tr : 'closed_now'.tr,
    ];
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(guideRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(guideRadius),
        onTap: () => Get.to(() => PlaceDetailScreen(place: place)),
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(width: 84, height: 84, child: PlacePhotoBox(url: place.coverThumb, category: place.exploreCategory, iconSize: 28)),
            ),
            const SizedBox(width: Dimensions.paddingSize),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(place.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault + 1, color: theme.textTheme.bodyLarge?.color))),
                if (place.isVerified) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: placeVerifiedGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text('guide_team_pick'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: placeVerifiedGreen)),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              Text(meta.join('  ·  '), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              const SizedBox(height: 4),
              GuideRatings(place: place),
              if (place.partnerStore != null) ...[
                const SizedBox(height: 4),
                const PartnerBadge(),
              ],
              if (place.erideQuote != null) ...[
                const SizedBox(height: 3),
                Text('"${place.erideQuote}"', maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, fontStyle: FontStyle.italic, color: theme.textTheme.bodyMedium?.color)),
              ],
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Row(children: [
                SizedBox(height: 36, child: OutlinedButton(
                  onPressed: () => Get.to(() => PlaceDetailScreen(place: place)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    side: BorderSide(color: theme.hintColor.withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text('guide_about_place'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
                )),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                GetBuilder<GuideController>(builder: (g) => SizedBox(height: 36, child: ElevatedButton.icon(
                  onPressed: place.hasLocation && g.ridingTo == null ? () => guide.startVisit(place) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: g.ridingTo == place.id
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.local_taxi_rounded, size: 16),
                  label: Text('guide_visit'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white)),
                ))),
                if (place.partnerStore != null) ...[
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Flexible(child: SizedBox(height: 36, child: OutlinedButton(
                    onPressed: () => orderFromPartner(place.partnerStore!),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      side: const BorderSide(color: Color(0xFFB45309)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text('guide_order'.tr, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: const Color(0xFFB45309))),
                  ))),
                ],
              ]),
            ])),
          ]),
        ),
      ),
    );
  }
}

/// A tour in a horizontal strip: cover, stops, title, time and ride cost.
class TourCardWidget extends StatelessWidget {
  final TourCard tour;
  final double width;
  const TourCardWidget({super.key, required this.tour, this.width = 250});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(guideRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Get.to(() => TourScreen(tourId: tour.id, title: tour.title)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 110,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                tour.cover != null
                    ? PlacePhotoBox(url: tour.cover, category: 'visit')
                    : Container(color: guideGreen.withValues(alpha: 0.14), child: const Icon(Icons.route_rounded, size: 40, color: guideGreen)),
                Positioned(left: 8, bottom: 8, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                  child: Text(tour.stopsCount == 1 ? 'guide_one_stop'.tr : 'guide_n_stops'.trParams({'n': '${tour.stopsCount}'}),
                      style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: const Color(0xFF1D2D2B))),
                )),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tour.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault + 1, color: theme.textTheme.bodyLarge?.color)),
                const SizedBox(height: 2),
                Text(GuideText.tourMeta(tour), maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Five stars to tap, 44px each.
class StarsInput extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;
  const StarsInput({super.key, required this.value, required this.onChanged, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (int n = 1; n <= 5; n++)
        Semantics(
          button: true,
          selected: value >= n,
          label: 'guide_n_stars'.trParams({'n': '$n'}),
          child: InkResponse(
            onTap: () => onChanged(n),
            radius: 24,
            child: SizedBox(width: 44, height: 44, child: Icon(
              value >= n ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: placeStarAmber,
            )),
          ),
        ),
    ]);
  }
}

/// Rate a place: stars and a few words. Rating again replaces the old one.
class RateSheet extends StatefulWidget {
  final ExplorePlace place;
  final int initialStars;
  final String? initialComment;
  const RateSheet({super.key, required this.place, this.initialStars = 0, this.initialComment});

  static Future<void> show(ExplorePlace place, {int stars = 0, String? comment}) => showModalBottomSheet(
        context: Get.context!,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Get.theme.cardColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(guideRadius))),
        builder: (_) => RateSheet(place: place, initialStars: stars, initialComment: comment),
      );

  @override
  State<RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<RateSheet> {
  late int _stars = widget.initialStars;
  late final TextEditingController _comment = TextEditingController(text: widget.initialComment ?? '');

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('guide_how_was'.trParams({'name': widget.place.name}),
              style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 4),
          Text('guide_rate_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          StarsInput(value: _stars, onChanged: (n) => setState(() => _stars = n)),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          TextField(
            controller: _comment,
            maxLength: 300,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'guide_review_hint'.tr,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          GetBuilder<GuideController>(builder: (g) => SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _stars == 0 || g.rating ? null : () async {
                final bool ok = await g.rate(widget.place, _stars, _comment.text);
                if (ok && context.mounted) Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: g.rating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('guide_send_rating'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
            ),
          )),
        ]),
        ),
      ),
    );
  }
}

/// On home and Explore while a tour or visit is going: where the person is
/// headed, and a way back to the guide.
class ActiveTourBanner extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  const ActiveTourBanner({super.key, this.padding = const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault)});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<GuideController>(builder: (g) {
      final TourRun? run = g.run;
      if (run == null) return const SizedBox.shrink();
      final ThemeData theme = Theme.of(context);
      final String title = run.isVisit ? 'guide_visiting'.trParams({'name': run.current.name}) : run.title;
      final String sub = run.isVisit
          ? 'guide_open_guide_on_arrival'.tr
          : 'guide_stop_of'.trParams({'num': '${run.index + 1}', 'total': '${run.stops.length}', 'place': run.current.name});
      return Padding(
        padding: padding,
        child: Material(
          color: guideGreen,
          borderRadius: BorderRadius.circular(guideRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(guideRadius),
            onTap: () => Get.to(() => const TourStopScreen()),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSize, vertical: Dimensions.paddingSizeSmall),
              child: Row(children: [
                Icon(run.isVisit ? Icons.place_rounded : Icons.route_rounded, color: Colors.white),
                const SizedBox(width: Dimensions.paddingSize),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: Colors.white)),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white.withValues(alpha: 0.9))),
                ])),
                Text('guide_open'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white)),
                Icon(Icons.chevron_right_rounded, color: theme.cardColor),
              ]),
            ),
          ),
        ),
      );
    });
  }
}

/// A section title with an optional "See all".
class GuideHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  const GuideHeader({super.key, required this.title, this.subtitle, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
        if (subtitle != null) Text(subtitle!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
      ])),
      if (onSeeAll != null)
        TextButton(onPressed: onSeeAll, child: Text('see_all'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor))),
    ]);
  }
}
