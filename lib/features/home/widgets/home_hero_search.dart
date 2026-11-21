import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/home/widgets/voice_search_dialog.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/set_destination/screens/set_destination_screen.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The "Where to?" card that straddles the seam between the dark header and
/// the white body on the home screen. Only the search: every service (ride,
/// food, parcel, hotels) has its own tile in HomeServiceGrid just below.
///
///   search row   -> SetDestinationScreen (regular ride)
///   "Later"      -> SetDestinationScreen (schedule ride), only when the
///                   backend has schedule trips enabled
///   microphone   -> VoiceSearchDialog
class HomeHeroSearch extends StatelessWidget {
  /// Total card height, so HomeScreen can reserve room for it.
  static const double height = 66;
  /// How much of the card rises above the body card into the header.
  static const double overlap = 33;

  const HomeHeroSearch({super.key});

  @override
  Widget build(BuildContext context) {
    final bool dark = Get.isDarkMode;
    final Color ink = dark ? Theme.of(context).primaryColor : const Color(0xFF15151A);
    final bool canSchedule = Get.find<ConfigController>().config?.scheduleTripStatus ?? false;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: dark ? 0.25 : 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.45 : 0.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(children: [
          SizedBox(
            height: height - 2,
            child: Row(children: [
              Expanded(
                child: InkWell(
                  onTap: () => Get.to(() => const SetDestinationScreen()),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: ink),
                        child: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: Dimensions.paddingSize),

                      Expanded(
                        child: Text(
                          'where_to'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textSemiBold.copyWith(
                            fontSize: Dimensions.fontSizeLarge,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),

              if (canSchedule)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _LaterChip(
                    onTap: () => Get.to(() => const SetDestinationScreen(rideType: RideType.scheduleRide)),
                  ),
                ),

              IconButton(
                tooltip: 'voice_search'.tr,
                onPressed: () => Get.dialog(const VoiceSearchDialog(), barrierDismissible: false),
                icon: Icon(Icons.mic_none_rounded, color: Theme.of(context).hintColor),
              ),
              const SizedBox(width: 4),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _LaterChip extends StatelessWidget {
  final VoidCallback onTap;
  const _LaterChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).hintColor.withValues(alpha: Get.isDarkMode ? 0.18 : 0.10),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.schedule_rounded, size: 16, color: Theme.of(context).textTheme.bodyLarge?.color),
            const SizedBox(width: 6),
            Text(
              'later'.tr,
              style: textMedium.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
