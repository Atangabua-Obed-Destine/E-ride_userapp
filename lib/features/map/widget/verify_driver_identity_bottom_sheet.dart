import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class VerifyDriverIdentityBottomSheet extends StatelessWidget {
  const VerifyDriverIdentityBottomSheet({super.key});

  static const List<String> _mismatchReasons = ['driver_photo', 'vehicle_model', 'license_plate_number'];

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideController>(builder: (rideController) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(Dimensions.radiusLarge),
              topRight: Radius.circular(Dimensions.radiusLarge),
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              height: 5, width: 30,
              margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeLarge),
              decoration: BoxDecoration(
                color: Theme.of(context).highlightColor,
                borderRadius: BorderRadius.circular(Dimensions.paddingSizeExtraSmall),
              ),
            ),

            rideController.showIdentityMismatchOptions ?
            _IdentityMismatchOptions(rideController: rideController) :
            _VerifyDriverIdentity(rideController: rideController),
          ]),
        ),
      );
    });
  }
}

class _VerifyDriverIdentity extends StatelessWidget {
  final RideController rideController;
  const _VerifyDriverIdentity({required this.rideController});

  @override
  Widget build(BuildContext context) {
    final driver = rideController.tripDetails?.driver;
    final vehicle = rideController.tripDetails?.vehicle;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('verify_driver_identity'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge)),
      const SizedBox(height: Dimensions.paddingSizeExtraSmall),

      Text(
        'please_verify_driver_identity_to_start_the_trip'.tr,
        textAlign: TextAlign.center,
        style: textRegular.copyWith(
          fontSize: Dimensions.fontSizeDefault,
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
        ),
      ),
      const SizedBox(height: Dimensions.paddingSizeLarge),

      ClipRRect(
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        child: ImageWidget(
          height: Get.height * 0.3, width: Get.height * 0.3,
          image: driver != null ? '${Get.find<ConfigController>().config!.imageBaseUrl!.profileImageDriver}/${driver.profileImage}' : '',
        ),
      ),
      const SizedBox(height: Dimensions.paddingSizeSmall),

      Text('${driver?.firstName ?? ''} ${driver?.lastName ?? ''}', style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
      const SizedBox(height: Dimensions.paddingSizeLarge),

      Container(
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeSmall),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(width: .75, color: Theme.of(context).hintColor.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                vehicle?.model?.name ?? '',
                style: textRegular.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
              Text(vehicle?.licencePlateNumber ?? '', style: textBold.copyWith(fontSize: Dimensions.fontSizeTwenty)),
            ]),
          ),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              color: Theme.of(context).hintColor.withValues(alpha: 0.15),
            ),
            padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              child: ImageWidget(
                height: 40, width: 40,
                image: vehicle?.model?.image != null ? '${Get.find<ConfigController>().config!.imageBaseUrl!.vehicleModel!}/${vehicle!.model!.image!}' : '',
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: Dimensions.paddingSizeLarge),

      ButtonWidget(
        buttonText: 'all_done_continue'.tr,
        radius: Dimensions.radiusOverLarge,
        onPressed: () {
          Get.back();
          rideController.toggleShowDriverVerificationTooltip(false);
        },
      ),
      const SizedBox(height: Dimensions.paddingSizeSmall),

      InkWell(
        onTap: () => rideController.toggleIdentityMismatchView(true),
        child: Text(
          'identity_mismatch'.tr,
          style: textMedium.copyWith(
            fontSize: Dimensions.fontSizeDefault, color: Theme.of(context).colorScheme.error,
            decoration: TextDecoration.underline, decorationColor: Theme.of(context).colorScheme.error,
          ),
        ),
      ),
      const SizedBox(height: Dimensions.paddingSizeSmall),
    ]);
  }
}

class _IdentityMismatchOptions extends StatelessWidget {
  final RideController rideController;
  const _IdentityMismatchOptions({required this.rideController});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('please_select_what_doesnt_match'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge)),
      const SizedBox(height: Dimensions.paddingSizeLarge),

      ...VerifyDriverIdentityBottomSheet._mismatchReasons.map((reason) {
        final isSelected = rideController.identityMismatchReasons.contains(reason);

        return InkWell(
          onTap: () => rideController.toggleIdentityMismatchReason(reason),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
            child: Row(children: [
              Expanded(
                child: Text(reason.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault)),
              ),

              SizedBox(
                width: 24, height: 24,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => rideController.toggleIdentityMismatchReason(reason),
                  checkColor: Colors.white,
                  activeColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  side: BorderSide(color: Theme.of(context).hintColor.withValues(alpha: 0.5), width: 1.5),
                ),
              ),
            ]),
          ),
        );
      }),
      const SizedBox(height: Dimensions.paddingSizeDefault),
      rideController.isLoading ?
      Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)) :
      ButtonWidget(
        buttonText: 'submit_and_cancel_trip'.tr,
        radius: Dimensions.radiusOverLarge,
        backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        textColor: Theme.of(context).colorScheme.error,
        onPressed: rideController.identityMismatchReasons.isEmpty ? null :
        () => rideController.submitIdentityMismatchAndCancelTrip(),
      ),
      const SizedBox(height: Dimensions.paddingSizeSmall),
    ]);
  }
}
