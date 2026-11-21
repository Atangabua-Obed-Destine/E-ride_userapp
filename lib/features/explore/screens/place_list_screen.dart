import 'package:ride_sharing_user_app/features/hotel/controllers/hotel_controller.dart';
import 'package:ride_sharing_user_app/features/hotel/screens/hotel_chats_screen.dart';
import 'package:ride_sharing_user_app/features/hotel/screens/hotel_screen.dart';
import 'package:ride_sharing_user_app/features/hotel/widgets/hotel_widgets.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/features/explore/controllers/explore_controller.dart';
import 'package:ride_sharing_user_app/features/explore/domain/models/explore_place_model.dart';
import 'package:ride_sharing_user_app/features/explore/screens/place_detail_screen.dart';
import 'package:ride_sharing_user_app/features/explore/widgets/explore_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// One Explore Bamenda category near the customer: on-duty pharmacies (when
/// it is Pharmacies), verified listings, then Google's top rated (carousel)
/// and nearest places (list). One scroll view, built lazily, so only photos
/// that come on screen are fetched.
class PlaceListScreen extends StatefulWidget {
  final String categoryKey;
  final String title;
  final String icon;
  const PlaceListScreen({super.key, required this.categoryKey, required this.title, this.icon = 'place'});

  @override
  State<PlaceListScreen> createState() => _PlaceListScreenState();
}

class _PlaceListScreenState extends State<PlaceListScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame: home also listens to this controller, and an
    // update while this route is being built is not allowed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<ExploreController>().open(widget.categoryKey);
      if (widget.categoryKey == ExploreCategory.stay) Get.find<HotelController>().loadInquiries(quiet: true);
    });
  }

  void _open(ExplorePlace place) => place.partner != null
      ? Get.to(() => HotelScreen(id: place.partner!.hotelId, name: place.name))
      : Get.to(() => PlaceDetailScreen(place: place));

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: GetBuilder<ExploreController>(builder: (controller) {
        // Another category's result may still be showing for a frame.
        final ExploreResult? result = controller.categoryKey == widget.categoryKey ? controller.result : null;
        final bool firstLoad = result == null && (controller.loading || !controller.failed);
        final List<ExplorePlace> onDuty = controller.onDuty;
        final List<ExplorePlace> verified = controller.verified;
        final List<ExplorePlace> topRated = controller.topRated;
        final List<ExplorePlace> nearby = controller.nearby;
        final bool showsGoogle = topRated.isNotEmpty || nearby.isNotEmpty;

        return BodyWidget(
          appBar: AppBarWidget(title: widget.title, showBackButton: true),
          body: RefreshIndicator(
            color: theme.primaryColor,
            onRefresh: () => controller.load(force: true),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _Intro(title: widget.title, icon: widget.icon, nearLabel: controller.nearLabel)),
                if (result?.notice != null) SliverToBoxAdapter(child: _Notice(text: result!.notice!)),
                SliverToBoxAdapter(child: _Filters(controller: controller)),
                if (widget.categoryKey == ExploreCategory.stay && result?.hotelPartners == true)
                  SliverToBoxAdapter(child: _HotelBar(onDates: () => controller.load(force: true))),

                if (firstLoad)
                  const SliverToBoxAdapter(child: _Skeleton())
                else if (result == null)
                  SliverFillRemaining(hasScrollBody: false, child: _Message(
                    icon: Icons.wifi_off_rounded,
                    title: 'explore_load_failed'.tr,
                    action: 'try_again'.tr,
                    onAction: () => controller.load(force: true),
                  ))
                else if (result.isEmpty)
                  SliverFillRemaining(hasScrollBody: false, child: _Message(
                    icon: ExploreIcons.icon(widget.icon),
                    title: 'explore_nothing_nearby'.tr,
                    body: controller.nearLabel == null ? 'stay_set_location_hint'.tr : null,
                    action: 'try_again'.tr,
                    onAction: () => controller.load(force: true),
                  ))
                else if (controller.filteredEmpty)
                  SliverFillRemaining(hasScrollBody: false, child: _Message(
                    icon: Icons.filter_alt_off_rounded,
                    title: controller.filter == ExploreFilter.openNow ? 'explore_none_open_now'.tr : 'no_stays_for_filter'.tr,
                    action: 'show_all'.tr,
                    onAction: () => controller.setFilter(ExploreFilter.all),
                  ))
                else ...[
                  if (onDuty.isNotEmpty) ...[
                    SliverToBoxAdapter(child: ExploreSectionHeader(
                      title: 'on_duty_pharmacies'.tr,
                      subtitle: 'on_duty_pharmacies_hint'.tr,
                      leading: const Icon(Icons.nightlight_round, color: placeVerifiedGreen, size: 20),
                    )),
                    SliverList.separated(
                      itemCount: onDuty.length,
                      separatorBuilder: (_, __) => Divider(height: 1, indent: 112, color: theme.hintColor.withValues(alpha: 0.15)),
                      itemBuilder: (_, i) => NearbyPlaceRow(place: onDuty[i], onTap: () => _open(onDuty[i])),
                    ),
                  ],

                  if (verified.isNotEmpty) ...[
                    SliverToBoxAdapter(child: ExploreSectionHeader(
                      title: 'verified_by_eride'.tr,
                      subtitle: 'verified_places_hint'.tr,
                      leading: const Icon(Icons.verified_rounded, color: placeVerifiedGreen, size: 20),
                    )),
                    SliverList.separated(
                      itemCount: verified.length,
                      separatorBuilder: (_, __) => const SizedBox(height: Dimensions.paddingSizeDefault),
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                        child: VerifiedPlaceCard(place: verified[i], onTap: () => _open(verified[i])),
                      ),
                    ),
                  ],

                  if (topRated.isNotEmpty) ...[
                    SliverToBoxAdapter(child: ExploreSectionHeader(title: 'top_rated_near_you'.tr, subtitle: 'top_rated_hint'.tr)),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: TopRatedPlaceCard.width * 3 / 4 + 58,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                          itemCount: topRated.length,
                          separatorBuilder: (_, __) => const SizedBox(width: Dimensions.paddingSize),
                          itemBuilder: (_, i) => TopRatedPlaceCard(place: topRated[i], onTap: () => _open(topRated[i])),
                        ),
                      ),
                    ),
                  ],

                  if (nearby.isNotEmpty) ...[
                    SliverToBoxAdapter(child: ExploreSectionHeader(
                      title: 'near_you'.tr,
                      subtitle: result.radiusKm != null ? '${'within'.tr} ${PlaceText.radius(result.radiusKm!)}' : null,
                    )),
                    SliverList.separated(
                      itemCount: nearby.length,
                      separatorBuilder: (_, __) => Divider(height: 1, indent: 112, color: theme.hintColor.withValues(alpha: 0.15)),
                      itemBuilder: (_, i) => NearbyPlaceRow(place: nearby[i], onTap: () => _open(nearby[i])),
                    ),
                  ],

                  if (!result.googleAvailable && (verified.isNotEmpty || onDuty.isNotEmpty))
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeLarge, Dimensions.paddingSizeDefault, 0),
                      child: Text('explore_more_unavailable'.tr, textAlign: TextAlign.center,
                          style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                    )),

                  if (showsGoogle)
                    const SliverToBoxAdapter(child: Padding(
                      padding: EdgeInsets.only(top: Dimensions.paddingSizeLarge),
                      child: GoogleMapsAttribution(),
                    )),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _Intro extends StatelessWidget {
  final String title;
  final String icon;
  final String? nearLabel;
  const _Intro({required this.title, required this.icon, this.nearLabel});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tint = ExploreIcons.color(icon);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, 0),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Icon(ExploreIcons.icon(icon), color: tint, size: 26),
        ),
        const SizedBox(width: Dimensions.paddingSize),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('explore_near_you'.trParams({'category': title}), maxLines: 2, overflow: TextOverflow.ellipsis,
              style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.near_me_rounded, size: 14, color: theme.hintColor),
            const SizedBox(width: 4),
            Expanded(child: Text(
              nearLabel != null ? '${'near'.tr} $nearLabel' : 'explore_intro'.tr,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor),
            )),
          ]),
        ])),
      ]),
    );
  }
}

/// The admin's notice for this category, e.g. emergency numbers on Hospitals.
class _Notice extends StatelessWidget {
  final String text;
  const _Notice({required this.text});

  @override
  Widget build(BuildContext context) {
    final Color red = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSize, Dimensions.paddingSizeDefault, 0),
      child: Container(
        padding: const EdgeInsets.all(Dimensions.paddingSize),
        decoration: BoxDecoration(color: red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Dimensions.radiusLarge)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.emergency_rounded, color: red, size: 20),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(child: Text(text, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).textTheme.bodyLarge?.color))),
        ]),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final ExploreController controller;
  const _Filters({required this.controller});

  static String _label(ExploreFilter f) {
    switch (f) {
      case ExploreFilter.all:
        return 'filter_all'.tr;
      case ExploreFilter.openNow:
        return 'open_now'.tr;
      case ExploreFilter.hotels:
        return 'hotels'.tr;
      case ExploreFilter.guestHouses:
        return 'guest_houses_and_lodges'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSize, Dimensions.paddingSizeDefault, 0),
        children: [
          for (final ExploreFilter f in controller.filters)
            Padding(
              padding: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
              child: ChoiceChip(
                label: Text(_label(f)),
                selected: controller.filter == f,
                onSelected: (_) => controller.setFilter(f),
                showCheckmark: false,
                selectedColor: theme.primaryColor,
                backgroundColor: theme.hintColor.withValues(alpha: 0.08),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                labelStyle: textMedium.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: controller.filter == f ? Colors.white : theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final Color c = Theme.of(context).hintColor.withValues(alpha: 0.12);
    Widget bar(double w, double h) => Container(width: w, height: h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)));
    return Padding(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (int i = 0; i < 5; i++) Padding(
          padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
          child: Row(children: [
            Container(width: 84, height: 84, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(160, 14), const SizedBox(height: 8), bar(90, 12), const SizedBox(height: 8), bar(130, 12)])),
          ]),
        ),
      ]),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String action;
  final VoidCallback onAction;
  const _Message({required this.icon, required this.title, required this.action, required this.onAction, this.body});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 56, color: theme.hintColor),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Text(title, textAlign: TextAlign.center,
            style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyMedium?.color)),
        if (body != null) ...[
          const SizedBox(height: 4),
          Text(body!, textAlign: TextAlign.center, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ],
        TextButton(onPressed: onAction, child: Text(action, style: textMedium.copyWith(color: theme.primaryColor))),
      ]),
    );
  }
}

/// Places to stay with partner hotels: the dates (free rooms are counted for them) and "My hotel chats".
class _HotelBar extends StatelessWidget {
  final VoidCallback onDates;
  const _HotelBar({required this.onDates});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 4, Dimensions.paddingSizeDefault, 8),
      child: Row(children: [
        Expanded(child: HotelDatesBar(onChanged: onDates)),
        const SizedBox(width: 8),
        GetBuilder<HotelController>(builder: (c) => SizedBox(
              width: 52, height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => Get.to(() => const HotelChatsScreen()),
                child: Badge(
                  isLabelVisible: c.unread > 0,
                  label: Text('${c.unread}'),
                  child: Icon(Icons.chat_bubble_outline_rounded, color: theme.textTheme.bodyLarge?.color, semanticLabel: 'hotel_my_chats'.tr),
                ),
              ),
            )),
      ]),
    );
  }
}
