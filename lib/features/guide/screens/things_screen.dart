import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/features/explore/domain/models/explore_place_model.dart';
import 'package:ride_sharing_user_app/features/explore/widgets/explore_widgets.dart';
import 'package:ride_sharing_user_app/features/guide/controllers/guide_controller.dart';
import 'package:ride_sharing_user_app/features/guide/domain/models/guide_models.dart';
import 'package:ride_sharing_user_app/features/guide/screens/tours_screen.dart';
import 'package:ride_sharing_user_app/features/guide/widgets/guide_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Things to do: places to eat, swim, party, sights and markets, rated by
/// E-Ride riders, with the city's tours on top. "All" is E-Ride's own picks
/// (no Google search); a kind shows E-Ride's places, then Google's.
class ThingsToDoScreen extends StatefulWidget {
  final String? title;
  final String? initialKind;
  const ThingsToDoScreen({super.key, this.title, this.initialKind});

  @override
  State<ThingsToDoScreen> createState() => _ThingsToDoScreenState();
}

class _ThingsToDoScreenState extends State<ThingsToDoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final GuideController g = Get.find<GuideController>();
      await g.loadHome(force: true);
      final String start = widget.initialKind ?? GuideController.all;
      // Nothing picked by the team yet: open the first kind, so there is something to see.
      if (start == GuideController.all && (g.home?.picks.isEmpty ?? true) && (g.home?.kinds.isNotEmpty ?? false)) {
        g.setKind(g.home!.kinds.first.key);
      } else {
        g.setKind(start);
      }
    });
  }

  static String _sortLabel(ThingSort s) => switch (s) {
        ThingSort.topPicks => 'guide_sort_top'.tr,
        ThingSort.bestRated => 'guide_sort_rated'.tr,
        ThingSort.nearest => 'guide_sort_nearest'.tr,
        ThingSort.openNow => 'open_now'.tr,
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: GetBuilder<GuideController>(builder: (g) {
        final List<ThingKind> kinds = g.home?.kinds ?? [];
        final List<ExplorePlace> places = g.places;
        final bool loading = (g.kind == GuideController.all && g.homeLoading && g.home == null) || (g.kind != GuideController.all && g.kindLoading && g.placesOf(g.kind) == null);
        return BodyWidget(
          appBar: AppBarWidget(title: widget.title ?? 'things_to_do'.tr, showBackButton: true),
          body: RefreshIndicator(
            color: theme.primaryColor,
            onRefresh: g.refreshKind,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, Dimensions.paddingSizeDefault, 0, 100),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                  child: Text('guide_things_sub'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                ),
                const SizedBox(height: Dimensions.paddingSize),
                const ActiveTourBanner(),

                if (g.tours.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                    child: GuideHeader(
                      title: g.city != null ? 'guide_tours_in'.trParams({'city': g.city!}) : 'guide_tours'.tr,
                      subtitle: 'guide_tours_sub'.tr,
                      onSeeAll: () => Get.to(() => const ToursScreen()),
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  SizedBox(
                    height: 190,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                      itemCount: g.tours.length,
                      separatorBuilder: (_, __) => const SizedBox(width: Dimensions.paddingSize),
                      itemBuilder: (_, i) => TourCardWidget(tour: g.tours[i]),
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                ],

                // Kinds: All, Eat, Swim, Party...
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                    children: [
                      _KindChip(label: 'all'.tr, icon: Icons.apps_rounded, selected: g.kind == GuideController.all, onTap: () => g.setKind(GuideController.all)),
                      for (final ThingKind k in kinds)
                        _KindChip(label: k.name, icon: ExploreIcons.icon(k.icon), color: ExploreIcons.color(k.icon), selected: g.kind == k.key, onTap: () => g.setKind(k.key)),
                    ],
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                    children: [
                      for (final ThingSort s in ThingSort.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: TextButton(
                            onPressed: () => g.setSort(s),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 40),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              foregroundColor: g.sort == s ? theme.primaryColor : theme.hintColor,
                            ),
                            child: Container(
                              padding: const EdgeInsets.only(bottom: 3),
                              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: g.sort == s ? theme.primaryColor : Colors.transparent, width: 2))),
                              child: Text(_sortLabel(s), style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: g.sort == s ? theme.primaryColor : theme.hintColor)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                if (loading)
                  const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                else if (g.homeFailed && g.home == null)
                  _Empty(text: 'guide_load_failed'.tr, action: 'retry'.tr, onAction: () => g.loadHome(force: true))
                else if (places.isEmpty)
                  _Empty(text: g.kind == GuideController.all
                      ? 'guide_no_picks'.tr
                      : g.kindGoogleMissing ? 'guide_google_missing'.tr : 'guide_nothing_here'.tr)
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                    child: Column(children: [
                      for (final ExplorePlace p in places) ...[
                        ThingCard(place: p),
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                      ],
                    ]),
                  ),
                if (places.any((p) => !p.isVerified))
                  const Padding(padding: EdgeInsets.all(Dimensions.paddingSizeDefault), child: GoogleMapsAttribution()),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _KindChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  const _KindChip({required this.label, required this.icon, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color fg = selected ? Colors.white : (theme.textTheme.bodyLarge?.color ?? Colors.black);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? (Get.isDarkMode ? theme.primaryColor : const Color(0xFF1D2D2B)) : theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: selected ? Colors.transparent : theme.hintColor.withValues(alpha: 0.3)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: selected ? Colors.white : (color ?? fg)),
              const SizedBox(width: 6),
              Text(label, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: fg)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const _Empty({required this.text, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
      child: Column(children: [
        Icon(Icons.travel_explore_rounded, size: 44, color: theme.hintColor.withValues(alpha: 0.5)),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Text(text, textAlign: TextAlign.center, style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.hintColor)),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ]),
    );
  }
}
