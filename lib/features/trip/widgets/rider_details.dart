import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/contact_widget.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';

/// Your driver, on the live ride sheet: avatar in a red ring, name, rating
/// and car, call / message actions, and the number plate drawn as a plate so
/// the rider can match it at the kerb. Same data as before; only the layout
/// changed.
class ActivityScreenRiderDetails extends StatelessWidget {
  const ActivityScreenRiderDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideController>(builder: (rideController) {
      final trip = rideController.tripDetails;
      final driver = trip?.driver;
      final vehicle = trip?.vehicle;
      final Color accent = Theme.of(context).primaryColor;
      final Color hint = Theme.of(context).hintColor;
      final Color text = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
      final String rating = trip?.driverAvgRating != null
          ? double.parse(trip!.driverAvgRating!).toStringAsFixed(1) : '0';
      final String? driverBase = Get.find<ConfigController>().config?.imageBaseUrl?.profileImageDriver;
      final String? modelBase = Get.find<ConfigController>().config?.imageBaseUrl?.vehicleModel;

      return Container(
        padding: const EdgeInsets.all(Dimensions.paddingSize),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: hint.withValues(alpha: 0.18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: 2)),
              child: ClipOval(
                child: ImageWidget(
                  height: 50, width: 50, fit: BoxFit.cover,
                  placeholder: Images.personPlaceholder,
                  image: driver != null ? '$driverBase/${driver.profileImage}' : '',
                ),
              ),
            ),
            const SizedBox(width: Dimensions.paddingSize),

            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                driver != null ? '${driver.firstName ?? ''} ${driver.lastName ?? ''}' : '',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: text),
              ),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFC53D)),
                const SizedBox(width: 3),
                Text(rating, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: text)),
                if ((vehicle?.model?.name ?? '').isNotEmpty) ...[
                  Text('  ·  ', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: hint)),
                  Flexible(child: Text(
                    vehicle!.model!.name!,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: hint),
                  )),
                ],
              ]),
            ])),
            const SizedBox(width: Dimensions.paddingSizeSmall),

            ContactWidget(driverId: driver?.id ?? '0'),
          ]),

          if (vehicle != null) ...[
            const SizedBox(height: Dimensions.paddingSize),
            Divider(height: 1, color: hint.withValues(alpha: 0.14)),
            const SizedBox(height: Dimensions.paddingSize),

            Row(children: [
              // Number plate
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF15151A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Text(
                  (vehicle.licencePlateNumber ?? '').toUpperCase(),
                  style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: Colors.white, letterSpacing: 1.6),
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),

              if ((trip?.vehicleCategory?.name ?? '').isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    trip!.vehicleCategory!.name!,
                    style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: accent),
                  ),
                ),
              const Spacer(),

              if (vehicle.model?.image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ImageWidget(
                    height: 40, width: 56, fit: BoxFit.contain,
                    image: '$modelBase/${vehicle.model!.image!}',
                  ),
                ),
            ]),
          ],
        ]),
      );
    });
  }
}
