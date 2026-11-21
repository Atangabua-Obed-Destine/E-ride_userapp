import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/parcel/screens/parcel_screen.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/set_destination/screens/set_destination_screen.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_list_screen.dart';
import 'package:ride_sharing_user_app/features/explore/screens/explore_screen.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Opened by the raised E-Ride button on the nav dock. Three big targets, each
/// going to the same screen the home tiles go to, so booking is one tap away
/// from every tab.
class QuickBookSheet extends StatelessWidget {
  const QuickBookSheet({super.key});

  static Future<void> show() => Get.bottomSheet(
        const QuickBookSheet(),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );

  @override
  Widget build(BuildContext context) {
    final bool canSchedule = Get.find<ConfigController>().config?.scheduleTripStatus ?? false;
    final bool canOrder = Get.find<ConfigController>().config?.storeOrderingStatus ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimensions.paddingSizeDefault, Dimensions.paddingSize, Dimensions.paddingSizeDefault, Dimensions.paddingSizeLarge,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              width: 44, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).hintColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: Dimensions.paddingSizeLarge),

            Text('what_do_you_need'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge)),
            const SizedBox(height: 4),
            Text(
              'quick_book_subtitle'.tr,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),

            _QuickCard(
              icon: Icons.directions_car_rounded,
              title: 'book_a_ride'.tr,
              subtitle: 'book_a_ride_subtitle'.tr,
              onTap: () => _go(const SetDestinationScreen()),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),

            _QuickCard(
              icon: Icons.inventory_2_rounded,
              title: 'send_a_parcel'.tr,
              subtitle: 'send_a_parcel_subtitle'.tr,
              onTap: () => _go(const ParcelScreen()),
            ),

            if (canOrder) ...[
              const SizedBox(height: Dimensions.paddingSizeSmall),
              _QuickCard(
                icon: Icons.lunch_dining_rounded,
                title: (Get.find<ConfigController>().config?.storeServiceLabel?.isNotEmpty ?? false)
                    ? Get.find<ConfigController>().config!.storeServiceLabel!
                    : 'food_and_shops'.tr,
                subtitle: 'food_and_shops_subtitle'.tr,
                onTap: () => _go(const StoreListScreen()),
              ),
            ],

            if (Get.find<ConfigController>().config?.exploreStatus ?? Get.find<ConfigController>().config?.stayStatus ?? false) ...[
              const SizedBox(height: Dimensions.paddingSizeSmall),
              _QuickCard(
                icon: Icons.travel_explore_rounded,
                title: (Get.find<ConfigController>().config?.exploreLabel?.isNotEmpty ?? false)
                    ? Get.find<ConfigController>().config!.exploreLabel!
                    : 'explore_bamenda'.tr,
                subtitle: 'explore_quick_subtitle'.tr,
                onTap: () => _go(const ExploreScreen()),
              ),
            ],

            if (canSchedule) ...[
              const SizedBox(height: Dimensions.paddingSizeSmall),
              _QuickCard(
                icon: Icons.schedule_rounded,
                title: 'schedule_a_trip'.tr,
                subtitle: 'schedule_a_trip_subtitle'.tr,
                onTap: () => _go(const SetDestinationScreen(rideType: RideType.scheduleRide)),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  static void _go(Widget screen) {
    Get.back();
    Get.to(() => screen);
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).primaryColor;
    return Material(
      color: Theme.of(context).hintColor.withValues(alpha: Get.isDarkMode ? 0.14 : 0.07),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSize),
          child: Row(children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: accent, size: 26),
            ),
            const SizedBox(width: Dimensions.paddingSizeDefault),

            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
              ),
            ])),

            Icon(Icons.chevron_right_rounded, color: Theme.of(context).hintColor),
          ]),
        ),
      ),
    );
  }
}
