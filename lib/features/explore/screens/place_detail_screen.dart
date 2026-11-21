import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing_user_app/common_widgets/call_options_sheet.dart';
import 'package:ride_sharing_user_app/features/explore/controllers/explore_controller.dart';
import 'package:ride_sharing_user_app/features/explore/domain/models/explore_place_model.dart';
import 'package:ride_sharing_user_app/features/explore/widgets/explore_widgets.dart';
import 'package:ride_sharing_user_app/features/guide/controllers/guide_controller.dart';
import 'package:ride_sharing_user_app/features/guide/widgets/place_guide_section.dart';
import 'package:ride_sharing_user_app/features/guide/widgets/guide_widgets.dart';
import 'package:ride_sharing_user_app/features/health_ride/controllers/health_ride_controller.dart';
import 'package:ride_sharing_user_app/features/health_ride/domain/models/health_place_model.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:url_launcher/url_launcher.dart';

/// One Explore Bamenda place: photos, rating, open state and hours, price and
/// amenities for places to stay, location, and the actions that matter
/// (Ride there, Call, WhatsApp, Directions).
class PlaceDetailScreen extends StatefulWidget {
  final ExplorePlace place;
  const PlaceDetailScreen({super.key, required this.place});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  final PageController _pages = PageController();
  final ScrollController _scroll = ScrollController();
  int _page = 0;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    // The name moves into the top bar once the photos have scrolled away.
    _scroll.addListener(() {
      final double photoHeight = MediaQuery.of(context).size.width * 0.72;
      final bool collapsed = _scroll.offset > photoHeight - kToolbarHeight - 24;
      if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ExplorePlace place = widget.place;
    final ExploreController controller = Get.find<ExploreController>();
    final double photoHeight = MediaQuery.of(context).size.width * 0.72;
    final String? price = PlaceText.priceRange(place);

    return Scaffold(
      // The app's scaffold colour is the dark header band; content sits on the card colour.
      backgroundColor: theme.cardColor,
      bottomNavigationBar: _ActionBar(place: place),
      body: CustomScrollView(controller: _scroll, slivers: [
        SliverAppBar(
          expandedHeight: photoHeight,
          pinned: true,
          stretch: true,
          backgroundColor: theme.cardColor,
          surfaceTintColor: Colors.transparent,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: _CircleButton(icon: Icons.arrow_back_rounded, tooltip: 'back'.tr, onTap: () => Get.back()),
          ),
          title: AnimatedOpacity(
            opacity: _collapsed ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
          ),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: _Gallery(
              place: place,
              controller: _pages,
              page: _page,
              onPage: (i) => setState(() => _page = i),
            ),
          ),
        ),

        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (place.isVerified) ...[const VerifiedBadge(), const SizedBox(height: Dimensions.paddingSizeSmall)],
            Text(place.name, style: textBold.copyWith(fontSize: Dimensions.fontSizeOverLarge - 2, color: theme.textTheme.bodyLarge?.color)),
            const SizedBox(height: 4),
            Text(
              [PlaceText.category(place.category), if (place.distanceKm != null) 'stay_distance_away'.trParams({'distance': PlaceText.distance(place.distanceKm)})].join('  ·  '),
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.hintColor),
            ),
            if (place.hasRating) ...[
              const SizedBox(height: Dimensions.paddingSizeSmall),
              _RatingLine(place: place, onReviews: place.mapsUrl != null ? () => controller.directions(place) : null),
            ],
            if (place.onDuty || place.openNow != null || place.reception24h) ...[
              const SizedBox(height: Dimensions.paddingSizeSmall),
              place.reception24h && !place.onDuty
                  ? Row(children: [
                      const Icon(Icons.schedule_rounded, size: 16, color: placeVerifiedGreen),
                      const SizedBox(width: 5),
                      Text(PlaceText.open24h(place), style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: placeVerifiedGreen)),
                    ])
                  : OpenStateLabel(place: place),
            ],

            // An E-Ride partner: order from here, delivered by a rider.
            if (place.partnerStore != null) ...[
              const SizedBox(height: Dimensions.paddingSizeDefault),
              Material(
                color: const Color(0xFFB45309).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(guideRadius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(guideRadius),
                  onTap: () => orderFromPartner(place.partnerStore!),
                  child: Padding(
                    padding: const EdgeInsets.all(Dimensions.paddingSize),
                    child: Row(children: [
                      const Icon(Icons.shopping_bag_rounded, color: Color(0xFFB45309)),
                      const SizedBox(width: Dimensions.paddingSize),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('guide_partner_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
                        Text((place.partnerStore!.isShop ? 'guide_partner_sub_shop' : 'guide_partner_sub_food').tr,
                            style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(color: const Color(0xFFB45309), borderRadius: BorderRadius.circular(6)),
                        child: Text('guide_order'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white)),
                      ),
                    ]),
                  ),
                ),
              ),
            ],

            // Things to do: the team's guide, riders' ratings, tours and nearby ideas.
            if (controller.isThing(place.exploreCategory)) PlaceGuideSection(place: place),

            if (price != null) ...[
              const SizedBox(height: Dimensions.paddingSizeDefault),
              _Panel(child: Row(children: [
                Icon(Icons.bed_rounded, color: theme.primaryColor),
                const SizedBox(width: Dimensions.paddingSize),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('price_per_night'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                  Text(price, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
                  Text('price_confirm_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: theme.hintColor)),
                ])),
              ])),
            ],

            if (place.checkIn != null || place.checkOut != null || (place.reception24h && place.exploreCategory == ExploreCategory.stay)) ...[
              const SizedBox(height: Dimensions.paddingSizeSmall),
              _Panel(child: Row(children: [
                if (place.checkIn != null) Expanded(child: _Fact(icon: Icons.login_rounded, label: 'check_in'.tr, value: place.checkIn!)),
                if (place.checkOut != null) Expanded(child: _Fact(icon: Icons.logout_rounded, label: 'check_out'.tr, value: place.checkOut!)),
                if (place.reception24h) Expanded(child: _Fact(icon: Icons.room_service_rounded, label: place.exploreCategory == ExploreCategory.stay ? 'reception'.tr : 'open'.tr, value: '24h')),
              ])),
            ],

            if (place.amenities.isNotEmpty) ...[
              _Heading(text: 'amenities'.tr),
              Wrap(spacing: Dimensions.paddingSizeSmall, runSpacing: Dimensions.paddingSizeSmall, children: [
                for (final String a in place.amenities)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: theme.hintColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(PlaceText.amenityIcon(a), size: 16, color: theme.primaryColor),
                      const SizedBox(width: 6),
                      Text(PlaceText.amenity(a), style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color)),
                    ]),
                  ),
              ]),
            ],

            if (place.hours.isNotEmpty) ...[
              _Heading(text: 'opening_hours'.tr),
              _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final String line in place.hours)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(line, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color)),
                  ),
              ])),
            ],

            if (place.description != null) ...[
              _Heading(text: 'about_this_place'.tr),
              Text(place.description!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, height: 1.45, color: theme.textTheme.bodyMedium?.color)),
            ],

            _Heading(text: 'stay_location'.tr),
            if (place.address.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.place_rounded, size: 18, color: theme.hintColor),
                  const SizedBox(width: 6),
                  Expanded(child: Text(place.address, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyMedium?.color))),
                ]),
              ),
            if (place.hasLocation) _MapPreview(place: place, onTap: () => controller.directions(place)),

            if (!place.isVerified) ...[
              const SizedBox(height: Dimensions.paddingSizeLarge),
              _Panel(child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 18, color: theme.hintColor),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(child: Text(place.exploreCategory == ExploreCategory.stay ? 'google_place_note'.tr : 'google_place_note_generic'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
              ])),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              const GoogleMapsAttribution(),
            ],
            const SizedBox(height: Dimensions.paddingSizeExtraLarge),
          ]),
        )),
      ]),
    );
  }
}

class _Gallery extends StatelessWidget {
  final ExplorePlace place;
  final PageController controller;
  final int page;
  final ValueChanged<int> onPage;
  const _Gallery({required this.place, required this.controller, required this.page, required this.onPage});

  @override
  Widget build(BuildContext context) {
    if (place.photos.isEmpty) return PlacePhotoBox(iconSize: 64, category: place.exploreCategory);
    final PlacePhoto current = place.photos[page.clamp(0, place.photos.length - 1)];
    return Stack(fit: StackFit.expand, children: [
      PageView.builder(
        controller: controller,
        itemCount: place.photos.length,
        onPageChanged: onPage,
        itemBuilder: (_, i) => PlacePhotoBox(url: place.photos[i].url, iconSize: 64, category: place.exploreCategory),
      ),
      // Keeps the back button and dots readable on bright photos.
      const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0x55000000), Color(0x00000000), Color(0x00000000), Color(0x66000000)],
        stops: [0, 0.3, 0.65, 1],
      )))),
      if (place.photos.length > 1)
        Positioned(
          bottom: 14, left: 0, right: 0,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int i = 0; i < place.photos.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == page ? 18 : 7, height: 7,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: i == page ? 1 : 0.6), borderRadius: BorderRadius.circular(4)),
              ),
          ]),
        ),
      if (current.author != null)
        Positioned(
          bottom: place.photos.length > 1 ? 30 : 12, right: 12,
          child: GestureDetector(
            onTap: current.authorUri == null ? null : () => launchUrl(Uri.parse(current.authorUri!), mode: LaunchMode.externalApplication),
            child: Text('${'photo_by'.tr} ${current.author}', style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white)),
          ),
        ),
    ]);
  }
}

class _RatingLine extends StatelessWidget {
  final ExplorePlace place;
  final VoidCallback? onReviews;
  const _RatingLine({required this.place, this.onReviews});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double rating = place.rating ?? 0;
    return Row(children: [
      for (int i = 1; i <= 5; i++)
        Icon(
          rating >= i ? Icons.star_rounded : (rating >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
          size: 20, color: placeStarAmber,
        ),
      const SizedBox(width: 6),
      Text(rating.toStringAsFixed(1), style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
      const SizedBox(width: 4),
      Flexible(child: InkWell(
        onTap: onReviews,
        child: Text(
          '${place.reviews} ${'reviews_on_google'.tr}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: textRegular.copyWith(
            fontSize: Dimensions.fontSizeSmall,
            color: onReviews != null ? theme.primaryColor : theme.hintColor,
            decoration: onReviews != null ? TextDecoration.underline : null,
            decorationColor: theme.primaryColor,
          ),
        ),
      )),
    ]);
  }
}

class _MapPreview extends StatelessWidget {
  final ExplorePlace place;
  final VoidCallback onTap;
  const _MapPreview({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final LatLng at = LatLng(place.latitude!, place.longitude!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
      child: SizedBox(
        height: 170,
        child: Stack(children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: at, zoom: 15.5),
            liteModeEnabled: true,
            markers: {Marker(markerId: const MarkerId('place'), position: at)},
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            scrollGesturesEnabled: false,
            zoomGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            onTap: (_) => onTap(),
          ),
          Positioned(
            right: 10, bottom: 10,
            child: Material(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              elevation: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.directions_rounded, size: 16, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 4),
                    Text('directions'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Bottom bar: the main action (Ride there) and the contact shortcuts.
class _ActionBar extends StatelessWidget {
  final ExplorePlace place;
  const _ActionBar({required this.place});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ExploreController controller = Get.find<ExploreController>();
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSize, Dimensions.paddingSizeDefault, Dimensions.paddingSize),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Hospitals, clinics and pharmacies: an urgent ride there, with no surge.
          if (place.hasLocation && const ['health', 'pharmacy'].contains(place.exploreCategory)
              && (Get.find<ConfigController>().config?.healthRideStatus ?? false)) ...[
            GetBuilder<HealthRideController>(builder: (health) => SizedBox(
              width: double.infinity, height: 46,
              child: OutlinedButton.icon(
                onPressed: health.openingId == place.id ? null : () => health.rideTo(HealthPlace(
                  id: place.id, kind: place.exploreCategory == 'pharmacy' ? 'pharmacy' : 'hospital', name: place.name,
                  address: place.address, latitude: place.latitude!, longitude: place.longitude!,
                )),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusLarge)),
                ),
                icon: const Icon(Icons.local_hospital_rounded, size: 20),
                label: Text('health_ride_there'.tr, style: textBold.copyWith(color: theme.colorScheme.error)),
              ),
            )),
            const SizedBox(height: Dimensions.paddingSizeSmall),
          ],
          Row(children: [
            if (place.phone != null) ...[
              _SquareAction(icon: Icons.call_rounded, label: 'call'.tr, onTap: () => CallOptionsSheet.show(phone: place.phone, name: place.name)),
              const SizedBox(width: Dimensions.paddingSizeSmall),
            ],
            if (place.whatsapp != null) ...[
              _SquareAction(icon: Icons.chat_rounded, label: 'WhatsApp', color: const Color(0xFF25D366), onTap: () => controller.whatsApp(place)),
              const SizedBox(width: Dimensions.paddingSizeSmall),
            ],
            if (place.website != null) ...[
              _SquareAction(icon: Icons.language_rounded, label: 'website'.tr, onTap: () => controller.website(place)),
              const SizedBox(width: Dimensions.paddingSizeSmall),
            ],
            Expanded(child: GetBuilder<ExploreController>(builder: (c) {
              final bool busy = c.openingPlaceId == place.id;
              // Things to do: Visit is a one-place tour (ride there, the guide on arrival, rate it).
              final bool visit = c.isThing(place.exploreCategory);
              return SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: place.hasLocation && !busy ? () => visit ? Get.find<GuideController>().startVisit(place) : c.rideThere(place) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: theme.primaryColor.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusLarge)),
                  ),
                  icon: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.local_taxi_rounded, size: 20),
                  label: Text(visit ? 'guide_visit'.tr : 'ride_there'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
                ),
              );
            })),
          ]),
          ]),
        ),
      ),
    );
  }
}

class _SquareAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _SquareAction({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final Color tint = color ?? Theme.of(context).primaryColor;
    return Tooltip(
      message: label,
      child: Material(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        child: InkWell(
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          onTap: onTap,
          child: SizedBox(width: 52, height: 52, child: Icon(icon, color: tint, size: 24)),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).cardColor.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(icon, size: 22, color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSize),
      decoration: BoxDecoration(
        color: theme.hintColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
      ),
      child: child,
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Fact({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(children: [
      Icon(icon, size: 18, color: theme.primaryColor),
      const SizedBox(width: 6),
      Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: theme.hintColor)),
        Text(value, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
      ])),
    ]);
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Dimensions.paddingSizeLarge, bottom: Dimensions.paddingSizeSmall),
      child: Text(text, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Theme.of(context).textTheme.bodyLarge?.color)),
    );
  }
}
