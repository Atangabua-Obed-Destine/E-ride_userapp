import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing_user_app/features/home/widgets/home_services_row.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/theme/theme_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/features/home/widgets/banner_shimmer.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/util/styles.dart';


/// "Drivers near you": the map of nearby online drivers, with a live count
/// pill fed by the same nearestDriverList the markers come from.
class HomeMapView extends StatefulWidget {
  const HomeMapView({super.key});

  @override
  HomeMapViewState createState() => HomeMapViewState();
}

class HomeMapViewState extends State<HomeMapView> {
  GoogleMapController? _mapController;
  int isFirstCount = 0;


  @override
  void initState() {
    super.initState();
  }


  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MapController>(builder: (mapController) {
      return GetBuilder<LocationController>(builder: (locationController) {
        Completer<GoogleMapController> mapCompleter = Completer<GoogleMapController>();
        if(mapController.mapController != null) {
          mapCompleter.complete(mapController.mapController);
        }
        if(mapController.nearestDeliveryManMarkers == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
            child: BannerShimmer(),
          );
        }

        final int online = Get.find<RideController>().nearestDriverList.length;

        return Column(children: [
          HomeSectionHeader(
            title: 'drivers_near_you'.tr,
            trailing: _OnlinePill(count: online),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
            child: Container(height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
                border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: 0.18)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
                child: GoogleMap(
                  style: Get.isDarkMode ?
                  Get.find<ThemeController>().darkMap :
                  Get.find<ThemeController>().lightMap,
                  markers: mapController.nearestDeliveryManMarkers!.toSet(),
                  initialCameraPosition: CameraPosition(target: LatLng(
                    Get.find<LocationController>().getUserAddress()?.latitude ?? 0,
                    Get.find<LocationController>().getUserAddress()?.longitude ?? 0,
                  ), zoom: 13),
                   minMaxZoomPreference: const MinMaxZoomPreference(0, 16),
                  onMapCreated: (gController) {
                    _mapController = gController;
                    mapController.setMapController(gController);
                  },
                  // A still map on Android (lite mode): the drivers are what
                  // matters here, and a live map inside the scrolling page is
                  // heavy on low-end phones.
                  liteModeEnabled: Platform.isAndroid,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  zoomGesturesEnabled: false,
                ),
              ),
            ),
          ),
        ]);
      });
    });
  }
}

class _OnlinePill extends StatelessWidget {
  final int count;
  const _OnlinePill({required this.count});

  @override
  Widget build(BuildContext context) {
    final bool any = count > 0;
    final Color tone = any ? const Color(0xFF1DB954) : Theme.of(context).hintColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: tone),
        ),
        const SizedBox(width: 6),
        Text(
          any ? '$count ${'drivers_online'.tr}' : 'no_drivers_online_right_now'.tr,
          style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: tone),
        ),
      ]),
    );
  }
}
