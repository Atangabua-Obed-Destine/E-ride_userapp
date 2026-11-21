import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/ride/widgets/pickup_help.dart';
import 'package:ride_sharing_user_app/features/set_destination/widget/schedule_date_time_picker_widget.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/helper/ride_controller_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Pickup time and note on the "Choose a vehicle" sheet, as a row of chips
/// instead of a collapsible panel. The pickup chip opens the schedule picker
/// when the backend allows scheduled trips (same rule as before); the note
/// chip only appears when a pickup note was written on Trip Setup.
class PickUpNoteWidget extends StatelessWidget {
  const PickUpNoteWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideController>(builder: (rideController) {
      final bool scheduled = rideController.rideType == RideType.scheduleRide;
      final config = Get.find<ConfigController>().config;
      // Moves are for now only; health rides when the admin lets them be booked ahead.
      final bool canSchedule = (config?.scheduleTripStatus ?? false) && !rideController.isMove
          && (!rideController.isHealthRide || (config?.healthRideSchedule ?? false));
      final String note = rideController.pickupNoteText;

      final String pickupLabel = scheduled
          ? '${DateFormat('E, d MMM').format(RideControllerHelper.dateFormatToShow(rideController.scheduleTripDate))}'
              ' · ${DateFormat('hh:mm a').format(RideControllerHelper.timeFormatToShow(rideController.scheduleTripTime))}'
          : 'pickup_now'.tr;

      return Column(children: [
        Row(children: [
          _SheetChip(
            icon: scheduled ? Icons.event_rounded : Icons.schedule_rounded,
            label: pickupLabel,
            trailing: (!scheduled && canSchedule) ? Icons.keyboard_arrow_down_rounded : null,
            onTap: (!scheduled && canSchedule)
                ? () => Get.bottomSheet(const ScheduleDateTimePickerWidget(), enableDrag: false, isScrollControlled: true)
                : null,
          ),

          if (note.isNotEmpty || rideController.voiceNote != null) ...[
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(child: _SheetChip(
              icon: rideController.voiceNote != null ? Icons.mic_rounded : Icons.sticky_note_2_outlined,
              label: note.isNotEmpty ? note : 'voice_note_label'.tr,
              onTap: () => PickupHelpSheet.show(),
            )),
          ] else ...[
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(child: _SheetChip(icon: Icons.record_voice_over_rounded, label: 'pickup_help_title'.tr, onTap: () => PickupHelpSheet.show())),
          ],
        ]),
        const SizedBox(height: Dimensions.paddingSizeDefault),
      ]);
    });
  }
}

class _SheetChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final IconData? trailing;
  final VoidCallback? onTap;
  const _SheetChip({required this.icon, required this.label, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color text = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: 0.18)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: Theme.of(context).primaryColor),
            const SizedBox(width: 6),
            Flexible(child: Text(
              label,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: text),
            )),
            if (trailing != null) ...[
              const SizedBox(width: 2),
              Icon(trailing, size: 18, color: text),
            ],
          ]),
        ),
      ),
    );
  }
}
