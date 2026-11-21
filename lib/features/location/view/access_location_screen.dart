import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/loader_widget.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/location/view/pick_map_screen.dart';
import 'package:ride_sharing_user_app/features/location/widgets/location_radar.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';

class AccessLocationScreen extends StatelessWidget {
  const AccessLocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        body: BodyWidget(
          appBar: AppBarWidget(title: 'set_location'.tr, showBackButton: false),
          body: GetBuilder<LocationController>(builder: (locationController) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                // The artwork and copy take the free space, the actions stay
                // pinned to the bottom. The old layout centred everything, which
                // left the two buttons floating mid-screen above a large gap.
                child: Column(children: [

                  Expanded(
                    child: LayoutBuilder(builder: (context, viewport) {
                      return SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          // Fill the free space so the block can sit centred,
                          // while still scrolling on a short screen.
                          constraints: BoxConstraints(minHeight: viewport.maxHeight),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Dimensions.paddingSizeExtraLarge,
                              vertical: Dimensions.paddingSizeLarge,
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const SizedBox(height: Dimensions.paddingSizeLarge),

                          LayoutBuilder(builder: (context, constraints) {
                            // Shrink on small screens so the actions never get
                            // pushed off the bottom.
                            final double side = constraints.maxWidth.clamp(0.0, 252.0);
                            return LocationRadar(size: side);
                          }),

                          const SizedBox(height: Dimensions.paddingSizeExtraLarge),

                          Text(
                            'find_driver_near_you'.tr,
                            textAlign: TextAlign.center,
                            style: textBold.copyWith(
                              fontSize: 22,
                              height: 1.3,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                          const SizedBox(height: Dimensions.paddingSizeSmall),

                          Text(
                            'please_select_you_location_to_start_finding_available_driver_near_you'.tr,
                            textAlign: TextAlign.center,
                            // Body copy used to render in the brand red, same as
                            // the heading, which left the screen with no visual
                            // hierarchy and poor contrast.
                            style: textRegular.copyWith(
                              fontSize: Dimensions.fontSizeDefault,
                              height: 1.6,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                            ]),
                          ),
                        ),
                      );
                    }),
                  ),

                  const _LocationActions(),
                ]),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _LocationActions extends StatelessWidget {
  const _LocationActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeExtraLarge,
        0,
        Dimensions.paddingSizeExtraLarge,
        Dimensions.paddingSizeExtraLarge,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        ButtonWidget(
          buttonText: 'use_current_location'.tr,
          icon: Icons.my_location,
          radius: Dimensions.paddingSizeSmall,
          boldText: true,
          onPressed: () async {
            if (GetPlatform.isIOS) {
              _saveAndNavigate();
            } else {
              Get.find<LocationController>().checkPermission(() async {
                _saveAndNavigate();
              });
            }
          },
        ),
        const SizedBox(height: Dimensions.paddingSizeSmall),

        // Secondary, so the two actions are no longer two identical red bars
        // competing for the same attention.
        ButtonWidget(
          buttonText: 'set_from_map'.tr,
          icon: Icons.map_outlined,
          transparent: true,
          showBorder: true,
          radius: Dimensions.paddingSizeSmall,
          onPressed: () => Get.to(() => const PickMapScreen(type: LocationType.accessLocation)),
        ),
        const SizedBox(height: Dimensions.paddingSizeDefault),

        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 14,
            color: Theme.of(context).hintColor,
          ),
          const SizedBox(width: Dimensions.paddingSizeExtraSmall),
          Flexible(
            child: Text(
              'location_used_only_for_matching'.tr,
              textAlign: TextAlign.center,
              style: textRegular.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall,
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  void _saveAndNavigate() async {
    Get.dialog(const LoaderWidget(), barrierDismissible: false);
    Address? address = await Get.find<LocationController>().getCurrentLocation();
    if (address != null) {
      await Get.find<LocationController>().saveUserAddress(address);
      Get.find<BottomMenuController>().navigateToDashboard();
    } else {
      Get.back();
      bool isLocationServiceEnable = await Geolocator.isLocationServiceEnabled();
      if (isLocationServiceEnable) {
        showCustomSnackBar('service_not_available'.tr);
      } else {
        showCustomSnackBar('your_location_access_first'.tr);
      }
    }
  }
}
