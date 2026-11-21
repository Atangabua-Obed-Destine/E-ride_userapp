import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/explore/domain/models/explore_place_model.dart';
import 'package:ride_sharing_user_app/features/explore/screens/place_detail_screen.dart';
import 'package:ride_sharing_user_app/features/explore/widgets/explore_widgets.dart';
import 'package:ride_sharing_user_app/features/guide/controllers/guide_controller.dart';
import 'package:ride_sharing_user_app/features/guide/domain/models/guide_models.dart';
import 'package:ride_sharing_user_app/features/guide/widgets/guide_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// On a Things to do place's page: the team's guide, riders' ratings and
/// reviews (and rating it), the tours it is part of, and nearby ideas.
class PlaceGuideSection extends StatefulWidget {
  final ExplorePlace place;
  const PlaceGuideSection({super.key, required this.place});

  @override
  State<PlaceGuideSection> createState() => _PlaceGuideSectionState();
}

class _PlaceGuideSectionState extends State<PlaceGuideSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<GuideController>().loadGuide(widget.place, force: true));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ExplorePlace place = widget.place;
    return GetBuilder<GuideController>(builder: (g) {
      final PlaceGuideInfo? info = g.guideOf(place.id);
      if (info == null) {
        return g.guideLoading(place.id) ? const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator(minHeight: 2)) : const SizedBox.shrink();
      }
      final PlaceGuide? guide = info.guide;
      Widget heading(String text) => Padding(
            padding: const EdgeInsets.only(top: Dimensions.paddingSizeLarge, bottom: Dimensions.paddingSizeSmall),
            child: Text(text, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
          );
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (guide != null) ...[
          const SizedBox(height: Dimensions.paddingSize),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (guide.stayMinutes != null) GuideChip(icon: Icons.schedule_rounded, text: 'guide_stay_about'.trParams({'time': GuideText.duration(guide.stayMinutes!)})),
            GuideChip(icon: Icons.confirmation_number_outlined, text: GuideText.fee(guide.entryFee)),
            if (guide.bestTime != null) GuideChip(icon: Icons.wb_sunny_outlined, text: guide.bestTime!),
          ]),
          if (guide.story != null) ...[
            heading('guide_the_story'.tr),
            Text(guide.story!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, height: 1.45, color: theme.textTheme.bodyMedium?.color)),
          ],
          if (guide.tipLines.isNotEmpty) ...[
            heading('guide_tips'.tr),
            for (final String tip in guide.tipLines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.lightbulb_outline_rounded, size: 16, color: guideGreen)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tip, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyMedium?.color))),
                ]),
              ),
          ],
          Text('guide_checked_by_team'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: theme.hintColor)),
        ],

        heading('guide_riders_say'.tr),
        Row(children: [
          Expanded(child: GuideRatings(place: place, erideRating: info.erideRating, erideRatings: info.erideRatings)),
          OutlinedButton.icon(
            onPressed: () => RateSheet.show(place, stars: info.myStars ?? 0, comment: info.myComment),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(44, 40),
              side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: Icon(info.myStars != null ? Icons.edit_rounded : Icons.star_outline_rounded, size: 18, color: theme.primaryColor),
            label: Text(info.myStars != null ? 'guide_edit_rating'.tr : 'guide_rate_it'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
          ),
        ]),
        if (info.reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('guide_be_first'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ),
        for (final PlaceReview r in info.reviews.take(5))
          Container(
            margin: const EdgeInsets.only(top: Dimensions.paddingSizeSmall),
            padding: const EdgeInsets.all(Dimensions.paddingSize),
            width: double.infinity,
            decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(guideRadius)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(r.name, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
                const SizedBox(width: 8),
                for (int i = 1; i <= 5; i++) Icon(i <= r.stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 14, color: placeStarAmber),
              ]),
              if (r.comment != null) ...[
                const SizedBox(height: 4),
                Text(r.comment!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color)),
              ],
            ]),
          ),

        if (info.tours.isNotEmpty) ...[
          heading('guide_on_these_tours'.tr),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: info.tours.length,
              separatorBuilder: (_, __) => const SizedBox(width: Dimensions.paddingSize),
              itemBuilder: (_, i) => TourCardWidget(tour: info.tours[i]),
            ),
          ),
        ],

        if (info.nearby.isNotEmpty) ...[
          heading('guide_nearby_ideas'.tr),
          for (final NearbyThing n in info.nearby)
            InkWell(
              onTap: () => Get.to(() => PlaceDetailScreen(place: n.place), preventDuplicates: false),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 52, height: 52, child: PlacePhotoBox(url: n.place.coverThumb, category: n.place.exploreCategory, iconSize: 20))),
                  const SizedBox(width: Dimensions.paddingSize),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n.place.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
                    Text([PlaceText.category(n.place.category), if (n.ride != null) GuideText.leg(n.ride!)].join('  ·  '), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: theme.hintColor),
                ]),
              ),
            ),
        ],
      ]);
    });
  }
}
