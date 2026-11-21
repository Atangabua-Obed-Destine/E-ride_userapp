import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/nearby_drivers_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The pill at the top of the map on "Choose a vehicle" / "Finding your
/// driver": how many drivers are around the pickup and how far the nearest
/// is. Tapping it frames the pickup and the nearest drivers.
class NearbyDriversChip extends StatelessWidget {
  final VoidCallback onTap;
  const NearbyDriversChip({super.key, required this.onTap});

  static const Color _online = Color(0xFF1DB954);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<NearbyDriversController>(builder: (nearby) {
      if (!nearby.isActive) return const SizedBox.shrink();

      // A move counts only trucks of the chosen size, not every driver around.
      final RideController ride = Get.find<RideController>();
      final bool move = ride.isMove || (ride.tripDetails?.isMove ?? false);
      final List<NearbyDriver> around = (move && ride.selectedType != null) ? nearby.driversFor(ride.selectedType!) : nearby.drivers;
      final int count = around.length;
      final Color text = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
      final Color hint = Theme.of(context).hintColor;

      final String label;
      final Color dot;
      if (!nearby.loaded) {
        label = 'looking_for_drivers_nearby'.tr;
        dot = hint;
      } else if (count == 0) {
        label = move ? 'no_trucks_nearby_can_request'.tr : 'no_drivers_nearby_can_request'.tr;
        dot = hint;
      } else {
        final String noun = move
            ? (count == 1 ? 'truck_near_pickup'.tr : 'trucks_near_pickup'.tr)
            : (count == 1 ? 'driver_near_pickup'.tr : 'drivers_near_pickup'.tr);
        label = '$count $noun  ·  ${'nearest_label'.tr} ${around.first.etaInline}';
        dot = _online;
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeSmall, Dimensions.paddingSizeSmall, Dimensions.paddingSizeSmall, 0),
        child: Material(
          color: Theme.of(context).cardColor,
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: count > 0 ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
                const SizedBox(width: 8),
                Flexible(child: Text(
                  label,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: text),
                )),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.center_focus_strong_rounded, size: 16, color: hint),
                ],
              ]),
            ),
          ),
        ),
      );
    });
  }
}
