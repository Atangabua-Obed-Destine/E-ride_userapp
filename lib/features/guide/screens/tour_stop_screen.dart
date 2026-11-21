import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/explore/domain/models/explore_place_model.dart';
import 'package:ride_sharing_user_app/features/explore/screens/place_detail_screen.dart';
import 'package:ride_sharing_user_app/features/explore/widgets/explore_widgets.dart';
import 'package:ride_sharing_user_app/features/guide/controllers/guide_controller.dart';
import 'package:ride_sharing_user_app/features/guide/domain/models/guide_models.dart';
import 'package:ride_sharing_user_app/features/guide/screens/tour_screen.dart';
import 'package:ride_sharing_user_app/features/guide/widgets/guide_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// At a stop of the tour (or the one place of a visit): what to see and do,
/// rate it, then the next stop, somewhere nearby, or home.
class TourStopScreen extends StatefulWidget {
  const TourStopScreen({super.key});

  @override
  State<TourStopScreen> createState() => _TourStopScreenState();
}

class _TourStopScreenState extends State<TourStopScreen> {
  String? _loadedFor;

  void _load(GuideController g) {
    final TourRun? run = g.run;
    if (run == null || _loadedFor == run.current.id) return;
    _loadedFor = run.current.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      g.loadGuide(run.current);
      if (run.tourId != null && g.tourOf(run.tourId!) == null) g.loadTour(run.tourId!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GetBuilder<GuideController>(builder: (g) {
      final TourRun? run = g.run;
      if (run == null) {
        return Scaffold(
          appBar: AppBar(),
          body: Center(child: Text('guide_no_run'.tr, style: textMedium.copyWith(color: theme.hintColor))),
        );
      }
      _load(g);
      final ExplorePlace place = run.current;
      final PlaceGuideInfo? info = g.guideOf(place.id);
      final PlaceGuide? guide = info?.guide;
      final TourDetail? tour = run.tourId != null ? g.tourOf(run.tourId!) : null;
      final TourStopItem? stopItem = tour?.stops.firstWhereOrNull((s) => s.place.id == place.id);
      final TourStopItem? nextItem = run.next != null ? tour?.stops.firstWhereOrNull((s) => s.place.id == run.next!.id) : null;
      final int? stay = stopItem?.stayMinutes ?? guide?.stayMinutes;

      return Scaffold(
        // The app's scaffold colour is the dark header band; this page sits on the card colour.
        backgroundColor: theme.cardColor,
        body: CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: 190,
            pinned: true,
            backgroundColor: theme.cardColor,
            foregroundColor: theme.textTheme.bodyLarge?.color,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 16, end: 16),
              title: LayoutBuilder(builder: (_, c) => c.maxHeight > kToolbarHeight + MediaQuery.of(context).padding.top + 10
                  ? const SizedBox.shrink()
                  : Text(run.isVisit ? 'guide_your_visit'.tr : run.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color))),
              background: Stack(fit: StackFit.expand, children: [
                PlacePhotoBox(url: place.photos.isNotEmpty ? place.photos.first.url : null, category: place.exploreCategory),
                Positioned(left: 12, bottom: 12, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: guideGreen, borderRadius: BorderRadius.circular(6)),
                  child: Text(run.isVisit ? 'guide_you_are_visiting'.tr : 'guide_stop_n_of'.trParams({'n': '${run.index + 1}', 'total': '${run.stops.length}'}),
                      style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white)),
                )),
              ]),
            ),
          ),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(place.name, style: textBold.copyWith(fontSize: Dimensions.fontSizeTwenty, color: theme.textTheme.bodyLarge?.color)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (stay != null) GuideChip(icon: Icons.schedule_rounded, text: 'guide_stay_about'.trParams({'time': GuideText.duration(stay)})),
                  if (guide != null) GuideChip(icon: Icons.confirmation_number_outlined, text: GuideText.fee(guide.entryFee)),
                  if (guide?.bestTime != null) GuideChip(icon: Icons.wb_sunny_outlined, text: guide!.bestTime!),
                ]),
                if (stopItem?.note != null) ...[
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Text(stopItem!.note!, style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
                ],
                if (guide?.story != null) ...[
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Text(guide!.story!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, height: 1.45, color: theme.textTheme.bodyMedium?.color)),
                ],
                if ((guide?.tipLines ?? []).isNotEmpty) ...[
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  for (final String tip in guide!.tipLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.lightbulb_outline_rounded, size: 15, color: guideGreen)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(tip, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color))),
                      ]),
                    ),
                ],
                if (info == null && g.guideLoading(place.id))
                  const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator(minHeight: 2)),
                const SizedBox(height: 6),
                Row(children: [
                  TextButton(
                    onPressed: () => Get.to(() => PlaceDetailScreen(place: place)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(44, 40)),
                    child: Text('guide_more_about'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: g.ridingTo != null ? null : g.rideToCurrent,
                    icon: const Icon(Icons.local_taxi_rounded, size: 16),
                    label: Text('guide_not_there_yet'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall)),
                  ),
                ]),
              ])),
              const SizedBox(height: Dimensions.paddingSize),

              // Rate it.
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('guide_how_was'.trParams({'name': place.name}), style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
                StarsInput(
                  value: info?.myStars ?? 0,
                  onChanged: (n) => RateSheet.show(place, stars: n, comment: info?.myComment),
                ),
                Text(info?.myStars != null ? 'guide_you_rated'.tr : 'guide_rate_hint'.tr,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              ])),
              const SizedBox(height: Dimensions.paddingSizeLarge),

              if (!run.isVisit) ..._tourNext(context, g, run, nextItem) else ..._visitNext(context, g, place, info),
            ]),
          )),
        ]),
      );
    });
  }

  List<Widget> _tourNext(BuildContext context, GuideController g, TourRun run, TourStopItem? nextItem) {
    final ThemeData theme = Theme.of(context);
    final ExplorePlace? next = run.next;
    return [
      if (next != null) ...[
        Text('guide_next_stop'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        _Card(child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 56, height: 56, child: PlacePhotoBox(url: next.coverThumb, category: next.exploreCategory, iconSize: 22))),
          const SizedBox(width: Dimensions.paddingSize),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${run.index + 2}. ${next.name}', style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
            if (nextItem?.ride != null)
              Text(GuideText.leg(nextItem!.ride!), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ])),
        ])),
        const SizedBox(height: Dimensions.paddingSize),
        _PrimaryButton(
          label: 'guide_ride_next'.tr,
          busy: g.ridingTo != null,
          onTap: g.nextStop,
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextButton(onPressed: g.skipStop, child: Text('guide_skip_stop'.tr)),
          TextButton(onPressed: () => _confirmEnd(g), child: Text('guide_end_tour'.tr, style: TextStyle(color: theme.colorScheme.error))),
        ]),
        if (run.tourId != null)
          Center(child: TextButton(
            onPressed: () => Get.to(() => TourScreen(tourId: run.tourId!, title: run.title)),
            child: Text('guide_see_all_stops'.tr),
          )),
      ] else ...[
        _Card(child: Column(children: [
          const Icon(Icons.emoji_events_rounded, size: 40, color: guideGreen),
          const SizedBox(height: 6),
          Text('guide_last_stop'.tr, textAlign: TextAlign.center, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 4),
          Text('guide_last_stop_sub'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ])),
        const SizedBox(height: Dimensions.paddingSize),
        _PrimaryButton(label: 'guide_ride_home'.tr, icon: Icons.home_rounded, onTap: g.rideHome),
        Center(child: TextButton(onPressed: () { g.endRun(); Get.back(); }, child: Text('guide_finish_tour'.tr))),
      ],
    ];
  }

  List<Widget> _visitNext(BuildContext context, GuideController g, ExplorePlace place, PlaceGuideInfo? info) {
    final ThemeData theme = Theme.of(context);
    return [
      Text('guide_when_done'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      _Card(padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSize, vertical: 4), child: Column(children: [
        for (final NearbyThing n in (info?.nearby ?? []).take(3))
          _OptionRow(
            icon: ExploreIcons.icon(PlaceText.iconKey(n.place.exploreCategory)),
            color: ExploreIcons.color(PlaceText.iconKey(n.place.exploreCategory)),
            title: n.place.name,
            subtitle: [PlaceText.category(n.place.category), if (n.ride != null) GuideText.leg(n.ride!)].join('  ·  '),
            onTap: () => g.startVisit(n.place),
          ),
        _OptionRow(
          icon: Icons.search_rounded,
          color: theme.textTheme.bodyLarge?.color ?? Colors.black,
          title: 'guide_somewhere_else'.tr,
          subtitle: 'guide_somewhere_else_sub'.tr,
          onTap: g.rideSomewhereElse,
          last: true,
        ),
      ])),
      if ((info?.tours ?? []).isNotEmpty) ...[
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Center(child: TextButton(
          onPressed: () => Get.to(() => TourScreen(tourId: info.tours.first.id, title: info.tours.first.title)),
          child: Text('guide_part_of_tour'.trParams({'name': info!.tours.first.title}), textAlign: TextAlign.center),
        )),
      ],
      const SizedBox(height: Dimensions.paddingSize),
      _PrimaryButton(label: 'guide_ride_home'.tr, icon: Icons.home_rounded, onTap: g.rideHome),
      Center(child: TextButton(onPressed: () { g.endRun(); Get.back(); }, child: Text('guide_end_visit'.tr))),
    ];
  }

  Future<void> _confirmEnd(GuideController g) async {
    final bool? ok = await Get.dialog<bool>(AlertDialog(
      title: Text('guide_end_tour'.tr),
      content: Text('guide_end_tour_body'.tr),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('cancel'.tr)),
        TextButton(onPressed: () => Get.back(result: true), child: Text('guide_end_tour'.tr)),
      ],
    ));
    if (ok == true) {
      g.endRun();
      Get.back();
    }
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(Dimensions.paddingSize)});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: Theme.of(context).hintColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(guideRadius)),
        child: child,
      );
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool last;
  const _OptionRow({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap, this.last = false});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: theme.hintColor.withValues(alpha: 0.12)))),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: Dimensions.paddingSize),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ])),
          Icon(Icons.chevron_right_rounded, color: theme.hintColor),
        ]),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap, this.icon = Icons.local_taxi_rounded, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 20),
        label: Text(label, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
      ),
    );
  }
}
