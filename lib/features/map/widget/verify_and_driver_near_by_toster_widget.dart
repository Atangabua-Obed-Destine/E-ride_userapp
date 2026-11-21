import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/map/screens/map_screen.dart';
import 'package:ride_sharing_user_app/features/map/widget/verify_driver_identity_bottom_sheet.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/helper/extensin_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class VerifyAndDriverNearByToasterWidget extends StatelessWidget {
  final MapScreenType fromScreen;
  const VerifyAndDriverNearByToasterWidget({super.key, required this.fromScreen});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideController>(builder: (rideController){
      return fromScreen == MapScreenType.parcel ?
      const SizedBox() :
      rideController.currentRideState == RideState.findingRider ?
      Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
            color: Theme.of(context).cardColor
        ),
        margin: EdgeInsets.all(Dimensions.paddingSizeSmall),
        padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
        child: Row(children: [
          Icon(Icons.info, color: context.customThemeColors.infoColor),
          const SizedBox(width: Dimensions.paddingSizeSmall),

          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('searching_for_rider'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall)),

              Text('looking_for_the_best_ride_for_you'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7))),
            ]),
          )
        ]),
      ) :
      ((Get.find<ConfigController>().config?.enableDriverIdentifyBeforeOngoing ?? false) && rideController.isShowDriverVerificationTooltip && (rideController.currentRideState == RideState.outForPickup || rideController.currentRideState == RideState.otpSent)) ?
      InkWell(
        onTap: () {
          rideController.toggleIdentityMismatchView(false);
          Get.bottomSheet(
            const VerifyDriverIdentityBottomSheet(),
            backgroundColor: Theme.of(context).cardColor,
            isScrollControlled: true,
          );
        },
        child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
              color: Theme.of(context).cardColor
          ),
          margin: EdgeInsets.all(Dimensions.paddingSizeSmall),
          padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
          child: Row(children: [
            Icon(Icons.info, color: context.customThemeColors.infoColor),
            const SizedBox(width: Dimensions.paddingSizeSmall),

            Flexible     (
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('verify_driver_identity'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall)),

                  InkWell(
                    onTap: ()=> rideController.toggleShowDriverVerificationTooltip(false),
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).hintColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 14, color: Theme.of(context).textTheme.bodyMedium?.color),
                    ),
                  ),
                ]),

                Text(Get.find<ConfigController>().config?.driverVerificationMessage ?? '', style: textRegular.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: Dimensions.fontSizeSmall))
              ]),
            )
          ]),
        ),
      ) :
      ((Get.find<ConfigController>().config?.enableAutoArrivalNotification ?? false) && rideController.isShowDriverArrivalTooltip && (rideController.currentRideState == RideState.outForPickup || rideController.currentRideState == RideState.otpSent)) ?
      Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
            color: Theme.of(context).cardColor
        ),
        margin: EdgeInsets.all(Dimensions.paddingSizeSmall),
        padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
        child: Row(children: [
          Icon(Icons.info, color: context.customThemeColors.infoColor),
          const SizedBox(width: Dimensions.paddingSizeSmall),

          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('driver_is_nearby'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall)),

                InkWell(
                  onTap: ()=> rideController.toggleShowDriverNearByTooltip(false),
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).hintColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 14, color: Theme.of(context).textTheme.bodyMedium?.color),
                  ),
                ),
              ]),

              RichText(text: TextSpan(text: 'driver_is'.tr, children: [
                TextSpan(text: ' ${rideController.remainingDistanceModel.isNotEmpty ? rideController.remainingDistanceModel[0].duration?.split(' ').first : ((Get.find<ConfigController>().config?.notificationArriveTime ?? 0)/60)} ', style: textBold.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: Dimensions.fontSizeSmall)),
                TextSpan(text: 'minutes_away_avoid_unnecessary_calls'.tr, style: textRegular.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: Dimensions.fontSizeSmall))
              ], style: textRegular.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: Dimensions.fontSizeSmall)))
            ]),
          )
        ]),
      ) :
      const SizedBox();
    });
  }
}
