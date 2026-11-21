import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class ReservationNoteWidget extends StatelessWidget {
  final GlobalKey globalKey;
  const ReservationNoteWidget({super.key, required this.globalKey});

  /// Seconds (as the config sends them) in the admin's unit: "3 days", "1 hour", "30 minutes".
  static String _span(int? seconds, String? type) {
    final unit = type == 'day' ? 86400 : type == 'hour' ? 3600 : 60;
    final name = type == 'day' ? 'day' : type == 'hour' ? 'hour' : 'minute';
    final n = ((seconds ?? 0) / unit).round();
    return 'span_$name${n == 1 ? '' : 's'}'.trParams({'n': '$n'});
  }

  @override
  Widget build(BuildContext context) {
    final config = Get.find<ConfigController>().config;
    return Column(key: globalKey, children: [
      const SizedBox(height: Dimensions.paddingSizeExtraLarge),

      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall)
        ),
        padding: EdgeInsets.all(Dimensions.paddingSizeDefault),
        child: Column(spacing: Dimensions.paddingSizeSmall, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('about_reservation'.tr),

          Row(spacing: Dimensions.paddingSizeSmall, children: [
            Icon(Icons.info, color: Theme.of(context).colorScheme.tertiaryContainer, size: 16),

            // The admin's limits (Business setup > Trips > Scheduled trips): how far ahead, and the shortest notice.
            Expanded(child: Text(
              'schedule_limits_note'.trParams({
                'max': _span(config?.advanceScheduleBookTime, config?.advanceScheduleBookTimeType),
                'min': _span(config?.minimumScheduleBookTime, config?.minimumScheduleBookTimeType),
              }),
              style: textRegular,
            ))
          ]),

          // The booking deposit and when cancelling is free (Trip management > Booking deposits).
          if (config?.bookingDepositStatus ?? false)
            Row(spacing: Dimensions.paddingSizeSmall, children: [
              Icon(Icons.info, color: Theme.of(context).colorScheme.tertiaryContainer, size: 16),
              Expanded(child: Text(
                (config?.bookingDepositScheduledTiming == 'before_pickup' ? 'reservation_deposit_before_pickup'
                    : config?.bookingDepositScheduledTiming == 'booking' ? 'reservation_deposit_booking' : 'reservation_deposit_accept').tr,
                style: textRegular,
              ))
            ]),

          Row(spacing: Dimensions.paddingSizeSmall, children: [
            Icon(Icons.info, color: Theme.of(context).colorScheme.tertiaryContainer, size: 16),

            Expanded(child: Text(
              (config?.bookingDepositStatus ?? false)
                  ? 'reservation_free_cancel_until'.trParams({'minutes': '${config?.bookingDepositScheduledFreeCancelMinutes ?? 60}'})
                  : 'enjoy_free_cancellation_before_your_trip_begins'.tr,
              style: textRegular,
            ))
          ]),

          Row(spacing: Dimensions.paddingSizeSmall, children: [
            Icon(Icons.info, color: Theme.of(context).colorScheme.tertiaryContainer, size: 16),

            Expanded(child: Text('if_the_trip_is_cancelled_while_in_progress'.tr, style: textRegular))
          ]),
        ]),
      )
    ]);
  }
}
