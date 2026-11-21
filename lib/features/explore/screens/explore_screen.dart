import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ride_sharing_user_app/features/listing/controllers/listing_controller.dart';
import 'package:ride_sharing_user_app/features/listing/screens/listing_home_screen.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/bus/controllers/bus_controller.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_home_screen.dart';
import 'package:ride_sharing_user_app/features/explore/controllers/explore_controller.dart';
import 'package:ride_sharing_user_app/features/explore/domain/models/explore_place_model.dart';
import 'package:ride_sharing_user_app/features/explore/screens/place_detail_screen.dart';
import 'package:ride_sharing_user_app/features/explore/screens/place_list_screen.dart';
import 'package:ride_sharing_user_app/features/explore/widgets/explore_widgets.dart';
import 'package:ride_sharing_user_app/features/guide/controllers/guide_controller.dart';
import 'package:ride_sharing_user_app/features/guide/domain/models/guide_models.dart';
import 'package:ride_sharing_user_app/features/guide/screens/things_screen.dart';
import 'package:ride_sharing_user_app/features/guide/screens/tour_screen.dart';
import 'package:ride_sharing_user_app/features/guide/screens/tours_screen.dart';
import 'package:ride_sharing_user_app/features/guide/widgets/guide_widgets.dart';
import 'package:ride_sharing_user_app/features/health_ride/widgets/health_ride_widgets.dart';
import 'package:ride_sharing_user_app/features/home/widgets/home_header_motif.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Explore Bamenda, E-Ride's city guide: the city's tours first, then Things to
/// do, the team's picks, and the everyday essentials (pharmacies, hospitals,
/// banks, buses, rooms, homes). Nothing here runs a Google search; opening a
/// category does.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final ScrollController _scroll = ScrollController();
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    // After the first frame: home also listens to this controller, and an
    // update while this route is being built is not allowed.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _scroll.addListener(() {
      final bool c = _scroll.offset > 150;
      if (c != _collapsed) setState(() => _collapsed = c);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait([
      Get.find<ExploreController>().loadCategories(),
      // Tours, kinds and the team's picks (database only).
      Get.find<GuideController>().loadHome(force: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ExploreController explore = Get.find<ExploreController>();
    return Scaffold(
      backgroundColor: theme.cardColor,
      body: RefreshIndicator(
        color: theme.primaryColor,
        onRefresh: _load,
        child: CustomScrollView(controller: _scroll, slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 236,
            // The app's scaffold colour is its dark header band, as on home.
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: AnimatedOpacity(
              opacity: _collapsed ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Text(explore.label, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _Hero(label: explore.label, near: explore.nearLabel),
            ),
          ),
          SliverToBoxAdapter(child: GetBuilder<GuideController>(builder: (g) {
            return GetBuilder<ExploreController>(builder: (c) {
              final List<ExploreCategory>? categories = c.categories;
              final List<ExploreCategory> essentials = (categories ?? []).where((k) => k.key != ExploreCategory.things).toList();
              final bool hasThings = (categories ?? []).any((k) => k.key == ExploreCategory.things);
              final List<ThingKind> kinds = g.home?.kinds ?? [];
              final List<ExplorePlace> picks = (g.home?.picks ?? []).take(10).toList();
              return Padding(
                padding: const EdgeInsets.only(top: Dimensions.paddingSizeLarge, bottom: 100),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const ActiveTourBanner(),

                  // Tours of the city.
                  if (g.tours.isNotEmpty) ...[
                    _Section(
                      title: g.city != null ? 'guide_tours_in'.trParams({'city': g.city!}) : 'guide_tours'.tr,
                      subtitle: 'guide_tours_sub'.tr,
                      onSeeAll: g.tours.length > 1 ? () => Get.to(() => const ToursScreen()) : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                      child: _FeaturedTour(tour: g.tours.first),
                    ),
                    if (g.tours.length > 1) ...[
                      const SizedBox(height: Dimensions.paddingSize),
                      SizedBox(
                        height: 190,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                          itemCount: g.tours.length - 1,
                          separatorBuilder: (_, __) => const SizedBox(width: Dimensions.paddingSize),
                          itemBuilder: (_, i) => TourCardWidget(tour: g.tours[i + 1]),
                        ),
                      ),
                    ],
                    const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                  ],

                  // Things to do, by kind.
                  if (hasThings && kinds.isNotEmpty) ...[
                    _Section(
                      title: 'things_to_do'.tr,
                      subtitle: 'guide_things_sub'.tr,
                      onSeeAll: () => Get.to(() => ThingsToDoScreen(title: 'things_to_do'.tr)),
                    ),
                    SizedBox(
                      height: 132,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                        itemCount: kinds.length,
                        separatorBuilder: (_, __) => const SizedBox(width: Dimensions.paddingSizeSmall),
                        itemBuilder: (_, i) => _KindTile(kind: kinds[i]),
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                  ],

                  // The team's picks.
                  if (picks.isNotEmpty) ...[
                    _Section(title: 'explore_picks'.tr, subtitle: 'explore_picks_sub'.tr),
                    SizedBox(
                      height: 214,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                        itemCount: picks.length,
                        separatorBuilder: (_, __) => const SizedBox(width: Dimensions.paddingSize),
                        itemBuilder: (_, i) => _PickCard(place: picks[i]),
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                  ],

                  // Everyday essentials.
                  _Section(title: 'explore_essentials'.tr, subtitle: 'explore_essentials_sub'.tr),
                  if (categories == null)
                    const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                  else if (essentials.isEmpty && !hasThings)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
                      child: Text('explore_no_categories'.tr, textAlign: TextAlign.center,
                          style: textMedium.copyWith(color: theme.hintColor, fontSize: Dimensions.fontSizeDefault)),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: Dimensions.paddingSizeSmall,
                        crossAxisSpacing: Dimensions.paddingSizeSmall,
                        childAspectRatio: 1.45,
                        children: [for (final ExploreCategory k in essentials) _EssentialTile(category: k)],
                      ),
                    ),
                  // An urgent ride to care, when it is on.
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  const HealthRideHomeCard(),
                ]),
              );
            });
          })),
        ]),
      ),
    );
  }
}

/// The dark header: E-Ride's route motif, the city, and where results are measured from.
class _Hero extends StatelessWidget {
  final String label;
  final String? near;
  const _Hero({required this.label, this.near});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double top = MediaQuery.of(context).padding.top;
    return Stack(fit: StackFit.expand, children: [
      // The route motif stays in the top right corner, clear of the words.
      Positioned(right: 0, top: 0, width: MediaQuery.of(context).size.width * 0.5, height: top + kToolbarHeight + 24,
          child: HomeHeaderMotif(accent: theme.primaryColor)),
      Padding(
        padding: EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, MediaQuery.of(context).padding.top + kToolbarHeight, Dimensions.paddingSizeDefault, Dimensions.paddingSizeLarge),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
          Row(children: [
            Container(width: 18, height: 3, color: theme.primaryColor),
            const SizedBox(width: 8),
            Text('explore_eyebrow'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, letterSpacing: 1.6, color: Colors.white.withValues(alpha: 0.75))),
          ]),
          const SizedBox(height: 8),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: textBold.copyWith(fontSize: 30, height: 1.1, color: Colors.white)),
          const SizedBox(height: 6),
          Text('explore_hero_sub'.tr, maxLines: 2, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, height: 1.35, color: Colors.white.withValues(alpha: 0.8))),
          if (near != null) ...[
            const SizedBox(height: Dimensions.paddingSize),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.near_me_rounded, size: 14, color: theme.primaryColor),
                const SizedBox(width: 6),
                Flexible(child: Text('explore_near'.trParams({'place': near!}), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white))),
              ]),
            ),
          ],
        ]),
      ),
    ]);
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  const _Section({required this.title, this.subtitle, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeSmall, Dimensions.paddingSize),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(width: 4, height: 36, margin: const EdgeInsets.only(right: 10), color: theme.primaryColor),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
          if (subtitle != null)
            Text(subtitle!, maxLines: 2, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ])),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: Text('see_all'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor))),
      ]),
    );
  }
}

/// The city's first tour, large: a route drawn with its stops, then what it is.
class _FeaturedTour extends StatelessWidget {
  final TourCard tour;
  const _FeaturedTour({required this.tour});

  @override
  Widget build(BuildContext context) {
    const Color deep = Color(0xFF0A5C44);
    return Material(
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Get.to(() => TourScreen(tourId: tour.id, title: tour.title)),
        child: Ink(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [guideGreen, deep])),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 128,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                if (tour.cover != null) Opacity(opacity: 0.35, child: PlacePhotoBox(url: tour.cover, category: 'visit')),
                CustomPaint(painter: _RoutePainter(stops: math.max(tour.stopsCount, 2))),
                Positioned(left: 12, top: 12, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                  child: Text('explore_featured_tour'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, letterSpacing: 0.8, color: deep)),
                )),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tour.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: textBold.copyWith(fontSize: Dimensions.fontSizeTwenty, height: 1.2, color: Colors.white)),
                const SizedBox(height: 4),
                Text(tour.stopNames.join('  ·  '), maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, height: 1.35, color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: Dimensions.paddingSize),
                Row(children: [
                  Expanded(child: Text(
                    [tour.stopsCount == 1 ? 'guide_one_stop'.tr : 'guide_n_stops'.trParams({'n': '${tour.stopsCount}'}), GuideText.tourMeta(tour)].join('  ·  '),
                    maxLines: 2,
                    style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white),
                  )),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('explore_see_tour'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: deep)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 16, color: deep),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A winding dashed route across the card with a numbered dot per stop.
class _RoutePainter extends CustomPainter {
  final int stops;
  _RoutePainter({required this.stops});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width, h = size.height;
    final Path path = Path()..moveTo(w * 0.08, h * 0.78);
    path.cubicTo(w * 0.28, h * 0.05, w * 0.42, h * 1.05, w * 0.6, h * 0.45);
    path.cubicTo(w * 0.72, h * 0.08, w * 0.86, h * 0.55, w * 0.94, h * 0.3);
    final Paint dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final metric = path.computeMetrics().first;
    for (double d = 0; d < metric.length; d += 14) {
      canvas.drawPath(metric.extractPath(d, math.min(d + 7, metric.length)), dash);
    }
    final Paint dot = Paint()..color = Colors.white;
    final Paint ring = Paint()
      ..color = const Color(0xFF0A5C44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (int i = 0; i < stops; i++) {
      final t = metric.getTangentForOffset(metric.length * (stops == 1 ? 0.5 : i / (stops - 1)));
      if (t == null) continue;
      canvas.drawCircle(t.position, 11, dot);
      canvas.drawCircle(t.position, 11, ring);
      final TextPainter tp = TextPainter(
        text: TextSpan(text: '${i + 1}', style: const TextStyle(color: Color(0xFF0A5C44), fontSize: 11, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, t.position - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) => old.stops != stops;
}

/// A Things to do kind as a coloured tile, like home's Explore cards.
class _KindTile extends StatelessWidget {
  final ThingKind kind;
  const _KindTile({required this.kind});

  @override
  Widget build(BuildContext context) {
    final Color tint = ExploreIcons.color(kind.icon);
    final Color deep = Color.lerp(tint, Colors.black, 0.35)!;
    return SizedBox(
      width: 118,
      child: Material(
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Get.to(() => ThingsToDoScreen(title: 'things_to_do'.tr, initialKind: kind.key)),
          child: Ink(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [tint, deep])),
            child: Stack(children: [
              Positioned(right: -14, bottom: -16, child: Icon(ExploreIcons.icon(kind.icon), size: 84, color: Colors.white.withValues(alpha: 0.14))),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(8)),
                    child: Icon(ExploreIcons.icon(kind.icon), color: Colors.white, size: 20),
                  ),
                  const Spacer(),
                  Text(kind.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, height: 1.15, color: Colors.white)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// One of the team's checked places: photo, name, what it is, riders' rating.
class _PickCard extends StatelessWidget {
  final ExplorePlace place;
  const _PickCard({required this.place});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: 172,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Get.to(() => PlaceDetailScreen(place: place)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 118,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                PlacePhotoBox(url: place.coverThumb, category: place.exploreCategory, iconSize: 34),
                Positioned(left: 8, top: 8, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                  child: Text('guide_team_pick'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: placeVerifiedGreen)),
                )),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
          Text([PlaceText.category(place.category), if (place.distanceKm != null) PlaceText.distance(place.distanceKm)].join('  ·  '),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.star_rounded, size: 15, color: placeStarAmber),
            const SizedBox(width: 3),
            Flexible(child: Text(
              place.hasErideRating ? '${place.erideRating!.toStringAsFixed(1)}  ·  ${place.erideRatings == 1 ? 'guide_one_eride_rating'.tr : 'guide_eride_ratings'.trParams({'n': '${place.erideRatings}'})}' : 'guide_not_rated_yet'.tr,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color),
            )),
          ]),
        ]),
      ),
    );
  }
}

/// An everyday category (pharmacies, hospitals, banks, buses, rooms, homes): a coloured tile with its line.
class _EssentialTile extends StatelessWidget {
  final ExploreCategory category;
  const _EssentialTile({required this.category});

  @override
  Widget build(BuildContext context) {
    final Color tint = ExploreIcons.color(category.icon);
    final Color deep = Color.lerp(tint, Colors.black, 0.3)!;
    final String tagKey = 'explore_tag_${category.key}';
    final String tag = tagKey.tr == tagKey ? 'explore_tag_default'.tr : tagKey.tr;
    final Widget plain = Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(8)),
      child: Icon(ExploreIcons.icon(category.icon), color: Colors.white, size: 20),
    );
    // Homes: a count when a visit, a reservation or a place needs the person.
    final Widget icon = category.key != ExploreCategory.homes
        ? plain
        : GetBuilder<ListingController>(builder: (c) {
            final int n = c.meta?.attention ?? 0;
            return Badge(isLabelVisible: n > 0, label: Text(n > 99 ? '99+' : '$n'), child: plain);
          });
    return Semantics(
      button: true,
      label: '${category.name}. $tag',
      child: Material(
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => ExploreCategoryTile.open(category),
          child: Ink(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [tint, deep])),
            child: Stack(children: [
              Positioned(right: -16, bottom: -20, child: Icon(ExploreIcons.icon(category.icon), size: 96, color: Colors.white.withValues(alpha: 0.13))),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  icon,
                  const Spacer(),
                  Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: Colors.white)),
                  Text(tag, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: Colors.white.withValues(alpha: 0.85))),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A category as a tinted tile: icon, name, arrow. Used here and on home.
class ExploreCategoryTile extends StatelessWidget {
  final ExploreCategory category;
  final bool compact;
  const ExploreCategoryTile({super.key, required this.category, this.compact = false});

  static Future<void> open(ExploreCategory c) async {
    final ExploreController explore = Get.find<ExploreController>();
    if (c.key == ExploreCategory.things) {
      Get.to(() => ThingsToDoScreen(title: c.name));
    } else if (explore.isThing(c.key)) {
      // A kind of Things to do (e.g. from Ask E-Ride): open it there, with ratings and Visit.
      Get.to(() => ThingsToDoScreen(initialKind: c.key));
    } else if (c.key == ExploreCategory.homes) {
      await Get.to(() => ListingHomeScreen(title: c.name));
      Get.find<ListingController>().loadMeta(force: true);
    } else if (c.key == 'bus' && (await Get.find<BusController>().loadMeta())?.enabled == true) {
      // Bus agencies: book a seat in E-Ride when bus booking is on.
      Get.to(() => BusHomeScreen(title: c.name));
    } else {
      Get.to(() => PlaceListScreen(categoryKey: c.key, title: c.name, icon: c.icon));
    }
  }

  /// Homes: a red count when a visit, a reservation or a place needs the person.
  Widget _homesBadge(Widget icon) {
    if (category.key != ExploreCategory.homes) return icon;
    return GetBuilder<ListingController>(builder: (c) {
      final int n = c.meta?.attention ?? 0;
      return Badge(
        isLabelVisible: n > 0,
        label: Text(n > 99 ? '99+' : '$n'),
        child: Semantics(label: n > 0 ? 'home_needs_you'.trParams({'n': '$n'}) : null, child: icon),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tint = ExploreIcons.color(category.icon);
    return Semantics(
      button: true,
      label: category.name,
      child: Material(
        color: Get.isDarkMode ? Color.alphaBlend(tint.withValues(alpha: 0.14), theme.cardColor) : tint.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => open(category),
          child: Padding(
            padding: EdgeInsets.all(compact ? 10 : 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _homesBadge(Container(
                width: compact ? 38 : 46, height: compact ? 38 : 46,
                decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(compact ? 12 : 14)),
                child: Icon(ExploreIcons.icon(category.icon), color: Colors.white, size: compact ? 22 : 26),
              )),
              const Spacer(),
              Text(category.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(fontSize: compact ? Dimensions.fontSizeSmall : Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color, height: 1.2)),
            ]),
          ),
        ),
      ),
    );
  }
}
