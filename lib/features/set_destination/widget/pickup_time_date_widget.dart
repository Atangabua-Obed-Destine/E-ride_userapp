import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/set_destination/widget/schedule_date_time_picker_widget.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/helper/ride_controller_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// "Pickup now" / scheduled date-time on Trip Setup, as a single tappable
/// row. Tapping opens the schedule picker when the backend allows it.
class PickupTimeDateWidget extends StatelessWidget {
  const PickupTimeDateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideController>(builder: (rideController) {
      final bool scheduled = rideController.rideType == RideType.scheduleRide;
      final bool canSchedule = Get.find<ConfigController>().config?.scheduleTripStatus ?? false;
      final Color accent = Theme.of(context).primaryColor;
      final Color text = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

      return Column(children: [
        Material(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: canSchedule
                ? () => Get.bottomSheet(const ScheduleDateTimePickerWidget(fromSetDestinationScreen: true), enableDrag: false, isScrollControlled: true)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSize, vertical: Dimensions.paddingSize),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: 0.18)),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(11)),
                  child: Icon(scheduled ? Icons.event_rounded : Icons.schedule_rounded, size: 19, color: accent),
                ),
                const SizedBox(width: Dimensions.paddingSize),

                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    scheduled ? 'schedule_trip'.tr : 'pickup_time'.tr,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    scheduled
                        ? '${DateFormat('EEE, d MMM').format(RideControllerHelper.dateFormatToShow(rideController.scheduleTripDate))}'
                            ' · ${DateFormat('hh:mm a').format(RideControllerHelper.timeFormatToShow(rideController.scheduleTripTime))}'
                        : 'pickup_now'.tr,
                    style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: text),
                  ),
                ])),

                if (canSchedule) Icon(Icons.keyboard_arrow_down_rounded, color: text),
              ]),
            ),
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeLarge),
      ]);
    });
  }
}
