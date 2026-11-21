import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/home/controllers/category_controller.dart';
import 'package:ride_sharing_user_app/features/home/domain/models/categoty_model.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/nearby_drivers_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/estimated_fare_model.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The vehicle picker on the "Choose a vehicle" sheet: one row per category
/// with its artwork, estimated time and distance, and the estimated fare for
/// that category, so the choice is made on price rather than on a picture.
///
/// Selection still goes through RideController.setRideCategoryIndex, which is
/// what recomputes the fare, polyline and coupon state.
class RideCategoryWidget extends StatelessWidget {
  final Function(void)? onTap;
  const RideCategoryWidget({super.key, this.onTap});

  static const double _rowHeight = 82;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideController>(builder: (rideController) {
      return GetBuilder<NearbyDriversController>(builder: (nearby) {
      return GetBuilder<CategoryController>(builder: (categoryController) {
        final List<Category>? categories = categoryController.listFor(rideController.isMove);
        if (categories == null) {
          return Center(child: SpinKitCircle(color: Theme.of(context).primaryColor, size: 40.0));
        }
        if (categories.isEmpty) {
          return Center(child: Text('no_category_found'.tr));
        }

        // Live availability only while the nearby-drivers layer is running (the
        // "Choose a vehicle" map); Trip Setup shows the rows without it.
        final bool live = nearby.isActive && nearby.loaded;
        final String? closestId = live ? nearby.closestCategoryId(rideController.fareList) : null;

        final List<Widget> rows = [
          for (int i = 0; i < categories.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == categories.length - 1 ? 0 : Dimensions.paddingSizeSmall),
              child: Builder(builder: (context) {
                final FareModel? fare = _fareFor(rideController, categories[i].id);
                final List<NearbyDriver> around = (live && fare != null) ? nearby.driversFor(fare) : const [];
                return _VehicleRow(
                  move: rideController.isMove,
                  category: categories[i],
                  fare: fare,
                  selected: rideController.rideCategoryIndex == i,
                  onTap: () => rideController.setRideCategoryIndex(i),
                  showAvailability: live && fare != null,
                  nearbyCount: around.length,
                  nearestEta: around.isEmpty ? null : around.first.etaInline,
                  isClosest: closestId != null && closestId == fare?.vehicleCategoryId,
                );
              }),
            ),
        ];

        // Up to three rows show in full; more than that scrolls inside the sheet.
        if (categories.length <= 3) {
          return Column(mainAxisSize: MainAxisSize.min, children: rows);
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _rowHeight * 3.4),
          child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: rows),
        );
      });
      });
    });
  }

  /// The API sends distance as a bare number ("1.07"); show it with its unit.
  static String formatDistance(String distance) {
    if (distance.contains('km')) return distance;
    final double? value = double.tryParse(distance.replaceAll(',', ''));
    return value == null ? distance : '${value.toStringAsFixed(2)} km';
  }

  static FareModel? _fareFor(RideController c, String? categoryId) {
    for (final FareModel f in c.fareList) {
      if (f.vehicleCategoryId == categoryId) return f;
    }
    return null;
  }
}

class _VehicleRow extends StatelessWidget {
  /// E-Ride Move: what the vehicle fits instead of the trip figures, and the
  /// deposit instead of a price (the price is agreed with the driver).
  final bool move;
  final Category category;
  final FareModel? fare;
  final bool selected;
  final VoidCallback onTap;
  final bool showAvailability;
  final int nearbyCount;
  final String? nearestEta;
  final bool isClosest;
  const _VehicleRow({
    this.move = false,
    required this.category,
    required this.fare,
    required this.selected,
    required this.onTap,
    this.showAvailability = false,
    this.nearbyCount = 0,
    this.nearestEta,
    this.isClosest = false,
  });

  static const Color _online = Color(0xFF1DB954);

  // Same surge / extra-fee rule RideController applies when it picks the fare.
  bool get _extra => ((fare?.extraFareFee ?? 0) > 0) || ((fare?.surgeMultiplier ?? 0) > 0);
  double get _price => (_extra ? fare?.extraEstimatedFare : fare?.estimatedFare) ?? 0;
  double get _discounted => (_extra ? fare?.extraDiscountFare : fare?.discountFare) ?? 0;
  double get _discountAmount => (_extra ? fare?.extraDiscountAmount : fare?.discountAmount) ?? 0;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).primaryColor;
    final Color hint = Theme.of(context).hintColor;
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final String? imageBase = Get.find<ConfigController>().config?.imageBaseUrl?.vehicleCategory;

    final List<String> meta = [
      if ((fare?.estimatedDuration ?? '').isNotEmpty) fare!.estimatedDuration!,
      if ((fare?.estimatedDistance ?? '').isNotEmpty) RideCategoryWidget.formatDistance(fare!.estimatedDistance!),
    ];

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: RideCategoryWidget._rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSize),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.08) : hint.withValues(alpha: Get.isDarkMode ? 0.14 : 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? accent : Colors.transparent, width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: 54,
              height: 54,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: category.id == '0'
                  ? Image.asset(category.image ?? '', fit: BoxFit.contain)
                  : _VehicleArt(url: '$imageBase/${category.image}'),
            ),
            const SizedBox(width: Dimensions.paddingSize),

            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(
                  category.name ?? '',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge),
                )),
                if (isClosest) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(6)),
                    child: Text('closest_badge'.tr, style: textSemiBold.copyWith(fontSize: 9, color: Colors.white)),
                  ),
                ],
              ]),
              if (move && (category.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  category.description!.trim(),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: hint),
                ),
              ] else if (meta.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  meta.join('  ·  '),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: hint),
                ),
              ],
              if (showAvailability) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: nearbyCount > 0 ? _online : hint),
                  ),
                  const SizedBox(width: 5),
                  Flexible(child: Text(
                    nearbyCount > 0
                        ? '$nearbyCount ${'nearby_label'.tr}  ·  ${'closest_label'.tr} $nearestEta'
                        : 'none_nearby_now'.tr,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: nearbyCount > 0 ? _online : hint),
                  )),
                ]),
              ],
            ])),
            const SizedBox(width: Dimensions.paddingSizeSmall),

            if (fare != null && move)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if ((fare?.bookingDeposit ?? 0) > 0 && (Get.find<ConfigController>().config?.moveDepositStatus ?? false)) ...[
                    Text(
                      PriceConverter.convertPrice(fare!.bookingDeposit),
                      style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: selected ? accent : Theme.of(context).textTheme.bodyLarge?.color),
                    ),
                    Text('move_deposit_short'.tr, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: hint)),
                  ] else
                    Text('move_price_short'.tr, maxLines: 2, textAlign: TextAlign.end,
                        style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: hint)),
                ]),
              )
            else if (fare != null)
              Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (_discountAmount > 0)
                  Text(
                    PriceConverter.convertPrice(_price),
                    style: textRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color: hint,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: hint,
                    ),
                  ),
                Text(
                  PriceConverter.convertPrice(_discountAmount > 0 ? _discounted : _price),
                  style: textBold.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                    color: selected ? accent : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                // Drop fare: the same fixed price every time on this route.
                if (fare?.isDropFare ?? false)
                  Text('drop_price'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: accent))
                // Health ride: the normal fare, never the surge price.
                else if (fare?.isHealthRide ?? false)
                  Text('health_ride_no_surge'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).colorScheme.error)),
                // Said up front: the deposit asked once a driver accepts.
                if (selected && (fare?.bookingDeposit ?? 0) > 0 && (Get.find<ConfigController>().config?.bookingDepositStatus ?? false))
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(
                      'deposit_short'.trParams({'amount': PriceConverter.convertPrice(fare!.bookingDeposit)}),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: hint),
                    ),
                  ),
              ]),
            const SizedBox(width: Dimensions.paddingSizeSmall),

            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 22,
              color: selected ? accent : hint.withValues(alpha: 0.6),
            ),
          ]),
        ),
      ),
    );
  }
}

class _VehicleArt extends StatelessWidget {
  final String url;
  const _VehicleArt({required this.url});

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Icon(
      Icons.directions_car_rounded,
      size: 28,
      color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.55),
    );
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
