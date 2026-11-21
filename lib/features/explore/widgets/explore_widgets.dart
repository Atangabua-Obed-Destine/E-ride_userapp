import 'package:ride_sharing_user_app/helper/image_size_helper.dart';
import 'package:ride_sharing_user_app/features/hotel/widgets/hotel_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ride_sharing_user_app/features/explore/controllers/explore_controller.dart';
import 'package:ride_sharing_user_app/features/explore/domain/models/explore_place_model.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

const Color placeVerifiedGreen = Color(0xFF12A150);
const Color placeStarAmber = Color(0xFFF5A623);

/// Labels and icons shared by the list and the detail screen.
class PlaceText {
  /// A place's type: hotel, guest house, pharmacy, hospital, ATM...
  static String category(String category) {
    switch (category) {
      case ExplorePlace.hotel:
        return 'hotel'.tr;
      case ExplorePlace.guestHouse:
        return 'guest_house'.tr;
      case ExplorePlace.lodging:
        return 'lodging'.tr;
      default:
        return 'place_type_$category'.tr;
    }
  }

  /// The icon key of an Explore category (as the server sends it), with the
  /// built-in ones as a fallback before categories have loaded.
  static String iconKey(String? category) {
    final String? fromServer = category == null ? null : Get.find<ExploreController>().categoryOf(category)?.icon;
    if (fromServer != null) return fromServer;
    switch (category) {
      case ExploreCategory.stay:
        return 'bed';
      case ExploreCategory.pharmacy:
        return 'pharmacy';
      case ExploreCategory.health:
        return 'hospital';
      case 'bank':
        return 'bank';
      case 'bus':
        return 'bus';
      default:
        return 'place';
    }
  }

  /// "24h reception" for places to stay, "Open 24 hours" for the rest.
  static String open24h(ExplorePlace place) =>
      place.exploreCategory == ExploreCategory.stay ? 'reception_24h'.tr : 'open_24_hours'.tr;

  static String distance(double? km) {
    if (km == null) return '';
    return km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
  }

  /// "10 km", "7.5 km".
  static String radius(double km) => km == km.roundToDouble() ? '${km.toInt()} km' : '${km.toStringAsFixed(1)} km';

  /// "from FCFA 15,000 / night", or null when the listing has no price.
  static String? fromPrice(ExplorePlace place) {
    final double? low = (place.priceMin ?? 0) > 0 ? place.priceMin : place.priceMax;
    if (low == null || low <= 0) return null;
    return '${'from'.tr} ${PriceConverter.convertPrice(low)} ${'per_night'.tr}';
  }

  /// "FCFA 15,000 - 40,000" (one symbol), or a single price.
  static String? priceRange(ExplorePlace place) {
    final double min = place.priceMin ?? 0;
    final double max = place.priceMax ?? 0;
    if (min <= 0 && max <= 0) return null;
    if (min > 0 && max > 0 && max > min) {
      return '${PriceConverter.convertPrice(min)} - ${PriceConverter.convertPrice(max)}';
    }
    return PriceConverter.convertPrice(min > 0 ? min : max);
  }

  static IconData amenityIcon(String key) {
    switch (key) {
      case 'wifi':
        return Icons.wifi_rounded;
      case 'backup_power':
        return Icons.bolt_rounded;
      case 'hot_water':
        return Icons.water_drop_rounded;
      case 'parking':
        return Icons.local_parking_rounded;
      case 'breakfast':
        return Icons.free_breakfast_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'bar':
        return Icons.local_bar_rounded;
      case 'air_conditioning':
        return Icons.ac_unit_rounded;
      case 'tv':
        return Icons.tv_rounded;
      case 'security':
        return Icons.security_rounded;
      case 'laundry':
        return Icons.local_laundry_service_rounded;
      case 'conference_room':
        return Icons.groups_rounded;
      case 'swimming_pool':
        return Icons.pool_rounded;
      case 'gym':
        return Icons.fitness_center_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  static String amenity(String key) => 'amenity_$key'.tr;
}

/// A place photo with a calm placeholder (no grey logo flash) and a
/// building glyph when there is no photo or it fails to load.
class PlacePhotoBox extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final double iconSize;
  /// The place's Explore category, so a missing photo shows its icon and colour.
  final String? category;
  const PlacePhotoBox({super.key, this.url, this.fit = BoxFit.cover, this.iconSize = 32, this.category});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String icon = PlaceText.iconKey(category);
    final Color tint = category == null ? theme.primaryColor : ExploreIcons.color(icon);
    final Widget fallback = Container(
      color: tint.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(category == null ? Icons.apartment_rounded : ExploreIcons.icon(icon), size: iconSize, color: tint.withValues(alpha: 0.5)),
    );
    if (url == null) return fallback;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: ImageSizeHelper.decodeWidth(context, null, null),
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(color: theme.hintColor.withValues(alpha: 0.10)),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

/// ★ 4.3 (80), with an optional compact form for photo overlays.
class PlaceRating extends StatelessWidget {
  final ExplorePlace place;
  final bool onPhoto;
  final double fontSize;
  const PlaceRating({super.key, required this.place, this.onPhoto = false, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    if (!place.hasRating) return const SizedBox.shrink();
    final Color text = onPhoto ? Colors.white : (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black);
    final Widget row = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.star_rounded, size: fontSize + 4, color: placeStarAmber),
      const SizedBox(width: 2),
      Text(place.rating!.toStringAsFixed(1), style: textBold.copyWith(fontSize: fontSize, color: text)),
      const SizedBox(width: 3),
      Text('(${place.reviews})', style: textRegular.copyWith(fontSize: fontSize - 1, color: onPhoto ? Colors.white70 : Theme.of(context).hintColor)),
    ]);
    if (!onPhoto) return Semantics(label: '${place.rating!.toStringAsFixed(1)} ${'stars'.tr}, ${place.reviews} ${'reviews'.tr}', child: ExcludeSemantics(child: row));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
      child: row,
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  final bool compact;
  const VerifiedBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final Widget icon = Icon(Icons.verified_rounded, size: compact ? 16 : 18, color: placeVerifiedGreen);
    if (compact) return Semantics(label: 'verified_by_eride'.tr, child: icon);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: placeVerifiedGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        icon,
        const SizedBox(width: 4),
        Text('verified_by_eride'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: placeVerifiedGreen)),
      ]),
    );
  }
}

/// Section title in the home-screen style: red dash, title, optional trailing text.
class ExploreSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  const ExploreSectionHeader({super.key, required this.title, this.subtitle, this.leading});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeLarge, Dimensions.paddingSizeDefault, Dimensions.paddingSize),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 4, height: 18,
          margin: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(2)),
        ),
        if (leading != null) ...[leading!, const SizedBox(width: 6)],
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
          if (subtitle != null)
            Text(subtitle!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ])),
      ]),
    );
  }
}

/// Large card for an E-Ride verified listing.
class VerifiedPlaceCard extends StatelessWidget {
  final ExplorePlace place;
  final VoidCallback onTap;
  const VerifiedPlaceCard({super.key, required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? price = PlaceText.fromPrice(place);
    return Semantics(
      button: true,
      label: '${place.name}, ${'verified_by_eride'.tr}',
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              border: Border.all(color: theme.hintColor.withValues(alpha: 0.18)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(fit: StackFit.expand, children: [
                  PlacePhotoBox(url: place.coverThumb, iconSize: 44, category: place.exploreCategory),
                  if (place.isFeatured)
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(20)),
                        child: Text('featured'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white)),
                      ),
                    ),
                  if (place.hasRating) Positioned(bottom: 10, left: 10, child: PlaceRating(place: place, onPhoto: true)),
                  if (place.photos.length > 1)
                    Positioned(
                      bottom: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.photo_library_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('${place.photos.length}', style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white)),
                        ]),
                      ),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color))),
                    const SizedBox(width: 4),
                    const VerifiedBadge(compact: true),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    [PlaceText.category(place.category), if (place.distanceKm != null) PlaceText.distance(place.distanceKm), if (place.reception24h) PlaceText.open24h(place)].join('  ·  '),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor),
                  ),
                  if (place.partner != null) ...[
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    HotelPartnerChips(partner: place.partner!),
                  ],
                  if (place.amenities.isNotEmpty) ...[
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    _AmenityStrip(amenities: place.amenities),
                  ],
                  if (price != null) ...[
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    Text(price, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.primaryColor)),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Up to four amenity icons with labels, then "+3".
class _AmenityStrip extends StatelessWidget {
  final List<String> amenities;
  const _AmenityStrip({required this.amenities});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> shown = amenities.take(4).toList();
    final int more = amenities.length - shown.length;
    final TextStyle style = textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: theme.textTheme.bodyMedium?.color);
    return Wrap(spacing: 10, runSpacing: 6, children: [
      for (final String a in shown)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(PlaceText.amenityIcon(a), size: 15, color: theme.hintColor),
          const SizedBox(width: 3),
          Text(PlaceText.amenity(a), style: style),
        ]),
      if (more > 0) Text('+$more', style: style.copyWith(color: theme.hintColor)),
    ]);
  }
}

/// Portrait card for the "Top rated" carousel.
class TopRatedPlaceCard extends StatelessWidget {
  static const double width = 210;
  final ExplorePlace place;
  final VoidCallback onTap;
  const TopRatedPlaceCard({super.key, required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: place.name,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(fit: StackFit.expand, children: [
                  PlacePhotoBox(url: place.coverThumb, category: place.exploreCategory),
                  Positioned(top: 8, left: 8, child: PlaceRating(place: place, onPhoto: true)),
                ]),
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
            Text(
              [PlaceText.category(place.category), if (place.distanceKm != null) PlaceText.distance(place.distanceKm)].join('  ·  '),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Compact row for "Near you": photo, name, rating, distance, and a ride button.
class NearbyPlaceRow extends StatelessWidget {
  final ExplorePlace place;
  final VoidCallback onTap;
  const NearbyPlaceRow({super.key, required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeSmall),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault + 2),
            child: SizedBox(width: 84, height: 84, child: PlacePhotoBox(url: place.coverThumb, iconSize: 28, category: place.exploreCategory)),
          ),
          const SizedBox(width: Dimensions.paddingSize),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(place.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
            const SizedBox(height: 3),
            if (place.hasRating) ...[PlaceRating(place: place), const SizedBox(height: 3)],
            if (place.onDuty || place.openNow != null) ...[OpenStateLabel(place: place), const SizedBox(height: 2)],
            Text(
              [PlaceText.category(place.category), if (place.distanceKm != null) PlaceText.distance(place.distanceKm)].join('  ·  '),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor),
            ),
            if (place.address.isNotEmpty)
              Text(place.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ])),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          RideThereIconButton(place: place),
        ]),
      ),
    );
  }
}

/// Round car button that books a ride to the place, with its own spinner.
class RideThereIconButton extends StatelessWidget {
  final ExplorePlace place;
  const RideThereIconButton({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GetBuilder<ExploreController>(builder: (controller) {
      final bool busy = controller.openingPlaceId == place.id;
      return Tooltip(
        message: 'ride_there'.tr,
        child: Material(
          color: theme.primaryColor.withValues(alpha: 0.12),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: place.hasLocation ? () => controller.rideThere(place) : null,
            child: SizedBox(
              width: 44, height: 44,
              child: busy
                  ? Padding(padding: const EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor))
                  : Icon(Icons.local_taxi_rounded, color: theme.primaryColor, size: 22),
            ),
          ),
        ),
      );
    });
  }
}

/// Google's required attribution for Places data shown outside a Google map.
class GoogleMapsAttribution extends StatelessWidget {
  final String? lead;
  const GoogleMapsAttribution({super.key, this.lead});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('${lead ?? 'info_from'.tr} ', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
      Text('Google Maps', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500, fontSize: 13, color: theme.hintColor)),
    ]);
  }
}

/// Icon and colour for a category's icon key (the backend's PlaceCategory::ICONS).
class ExploreIcons {
  static IconData icon(String key) {
    switch (key) {
      case 'pharmacy':
        return Icons.local_pharmacy_rounded;
      case 'hospital':
        return Icons.local_hospital_rounded;
      case 'bank':
        return Icons.account_balance_rounded;
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'bed':
        return Icons.hotel_rounded;
      case 'store':
        return Icons.storefront_rounded;
      case 'fuel':
        return Icons.local_gas_station_rounded;
      case 'police':
        return Icons.local_police_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'church':
        return Icons.church_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'atm':
        return Icons.atm_rounded;
      case 'money':
        return Icons.payments_rounded;
      case 'market':
        return Icons.shopping_basket_rounded;
      case 'home':
        return Icons.home_work_rounded;
      case 'landmark':
        return Icons.landscape_rounded;
      case 'things':
        return Icons.local_activity_rounded;
      case 'swim':
        return Icons.pool_rounded;
      case 'party':
        return Icons.nightlife_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  static Color color(String key) {
    switch (key) {
      case 'pharmacy':
        return const Color(0xFF12A150);
      case 'hospital':
        return const Color(0xFFE02020);
      case 'bank':
      case 'atm':
      case 'money':
        return const Color(0xFF1E6FD9);
      case 'bus':
        return const Color(0xFFF08A00);
      case 'bed':
        return const Color(0xFF7B4FD6);
      case 'fuel':
        return const Color(0xFF0F8B8D);
      case 'police':
        return const Color(0xFF3949AB);
      case 'home':
        return const Color(0xFFC2410C);
      case 'landmark':
      case 'things':
        return const Color(0xFF0E9F6E);
      case 'swim':
        return const Color(0xFF0284C7);
      case 'party':
        return const Color(0xFF9333EA);
      case 'restaurant':
        return const Color(0xFFEA580C);
      case 'market':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF5F6B7A);
    }
  }
}

/// "On duty until Sun" for a pharmacy on the rota, else "Open now" / "Closed now".
class OpenStateLabel extends StatelessWidget {
  final ExplorePlace place;
  const OpenStateLabel({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (String text, Color color) = place.onDuty
        ? ('${'on_duty'.tr}${place.onDutyUntil != null ? ' ${'until'.tr} ${DateFormat('EEE d MMM').format(place.onDutyUntil!)}' : ''}', placeVerifiedGreen)
        : place.openNow == true
            ? ('open_now'.tr, placeVerifiedGreen)
            : ('closed_now'.tr, theme.hintColor);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: color))),
    ]);
  }
}

