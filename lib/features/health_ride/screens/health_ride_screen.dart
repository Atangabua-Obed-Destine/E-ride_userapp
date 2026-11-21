import 'package:ride_sharing_user_app/features/assistant/widgets/help_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/features/health_ride/controllers/health_ride_controller.dart';
import 'package:ride_sharing_user_app/features/health_ride/domain/models/health_place_model.dart';
import 'package:ride_sharing_user_app/features/health_ride/widgets/health_ride_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Health ride: pick a hospital, clinic or pharmacy near you (nearest first) and
/// get a driver fast. The normal fare, never the surge price, and no bidding.
class HealthRideScreen extends StatefulWidget {
  const HealthRideScreen({super.key});

  @override
  State<HealthRideScreen> createState() => _HealthRideScreenState();
}

class _HealthRideScreenState extends State<HealthRideScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame: the load notifies GetBuilders, which cannot rebuild mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<HealthRideController>().load());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: BodyWidget(
        appBar: AppBarWidget(title: 'health_ride'.tr, showBackButton: true),
        body: GetBuilder<HealthRideController>(builder: (health) {
          final result = health.result;
          return RefreshIndicator(
            onRefresh: health.load,
            child: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
              const Align(alignment: Alignment.centerRight, child: HelpButton(helpKey: 'health_ride')),
              const HealthRideNotice(),
              if (result != null && result.dailyLimit > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                  child: Text(
                    health.noRidesLeft ? 'health_ride_none_left'.tr
                        : 'health_rides_left'.trParams({'left': '${result.ridesLeft}', 'limit': '${result.dailyLimit}'}),
                    style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall,
                        color: health.noRidesLeft ? theme.colorScheme.error : theme.hintColor),
                  ),
                ),
              Text('health_ride_pick_place'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, icon: const Icon(Icons.local_hospital_rounded, size: 18), label: Text('health_hospitals'.tr)),
                  ButtonSegment(value: 1, icon: const Icon(Icons.local_pharmacy_rounded, size: 18), label: Text('health_pharmacies'.tr)),
                ],
                selected: {health.tab},
                showSelectedIcon: false,
                onSelectionChanged: (s) => health.setTab(s.first),
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              if (health.loading && result == null)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
              else if (health.places.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeLarge),
                  child: Text('health_no_places'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(color: theme.hintColor)),
                )
              else
                for (final HealthPlace place in health.places)
                  HealthPlaceTile(place: place, busy: health.openingId == place.id, onTap: () => health.rideTo(place)),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              OutlinedButton.icon(
                onPressed: health.rideElsewhere,
                icon: const Icon(Icons.search_rounded),
                label: Text('health_ride_elsewhere'.tr),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              ),
            ]),
          );
        }),
      ),
    );
  }
}
