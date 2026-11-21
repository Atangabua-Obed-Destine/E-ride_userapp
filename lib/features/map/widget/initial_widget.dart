import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/health_ride/widgets/health_ride_widgets.dart';
import 'package:ride_sharing_user_app/features/move/widgets/move_widgets.dart';
import 'package:ride_sharing_user_app/features/move/controllers/move_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/nearby_drivers_controller.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/expandable_bottom_sheet.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/map/widget/pick_up_note_widget.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/fare_input_widget.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/route_widget.dart';
import 'package:ride_sharing_user_app/features/payment/controllers/payment_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/ride/widgets/ride_category.dart';
import 'package:ride_sharing_user_app/features/ride/widgets/trip_fare_summery.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/trip/screens/trip_details_screen.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';


class InitialWidget extends StatefulWidget {
  final GlobalKey<ExpandableBottomSheetState> expandableKey;
  const InitialWidget({super.key, required this.expandableKey});

  @override
  State<InitialWidget> createState() => _InitialWidgetState();
}

class _InitialWidgetState extends State<InitialWidget> {
  JustTheController tooltipController = JustTheController();

  @override
  void initState() {
    var rideController = Get.find<RideController>();
    if(Get.find<PaymentController>().paymentType == 'wallet' &&
        (rideController.discountAmount.toDouble() > 0 ? rideController.discountFare : rideController.estimatedFare) >
            Get.find<ProfileController>().profileModel!.data!.wallet!.walletBalance!
    ){
      Get.find<PaymentController>().selectPaymentType('cash');
    }
  //  zoneExtraFareReason = _getExtraFairReason(Get.find<ConfigController>().config?.zoneExtraFare, Get.find<LocationController>().zoneID);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideController>(builder: (rideController){
      return GetBuilder<LocationController>(builder: (locationController){
        return Column(mainAxisSize: MainAxisSize.min, children:  [
          _SheetHeader(
            title: rideController.isMove ? 'move_choose_truck'.tr : 'choose_your_ride'.tr,
            distance: rideController.fareList.isEmpty ? null : rideController.estimatedDistance,
            duration: rideController.fareList.isEmpty ? null : rideController.estimatedDuration,
          ),
          const SizedBox(height: Dimensions.paddingSize),
          if (rideController.isHealthRide) ...[
            const HealthRideNotice(compact: true),
            const SizedBox(height: Dimensions.paddingSizeSmall),
          ],
          // A pause at the pickup or the destination: the ride can still go ahead, with a warning.
          if (rideController.fareList.isNotEmpty && rideController.fareList.first.safetyNotice != null) ...[
            _SafetyNotice(text: rideController.fareList.first.safetyNotice!),
            const SizedBox(height: Dimensions.paddingSizeSmall),
          ],

          RideCategoryWidget(onTap:(value) async {
            if(rideController.isCouponApplicable){
              await Future.delayed(const Duration(milliseconds: 500));
              widget.expandableKey.currentState?.expand(duration: 1000);
            }else{
              widget.expandableKey.currentState?.contract(duration: 500);
              widget.expandableKey.currentState?.expand(duration: 1000);
            }

          }),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          if (rideController.isMove)
            const MoveLoadWidget()
          else
            PickUpNoteWidget(),

          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: 0.18)),
            ),
            padding: const EdgeInsets.all(Dimensions.paddingSize),
            child: Column(children: [
              RouteWidget(
                totalDistance: rideController.fareList.isEmpty ? '0' :
                rideController.estimatedDistance,
                fromAddress: locationController.fromAddress?.address??'',
                extraOneAddress: rideController.isInitialWidgetRoutesExpand ? '' : locationController.extraRouteAddress?.address ?? '',
                extraTwoAddress: rideController.isInitialWidgetRoutesExpand ? '' : locationController.extraRouteTwoAddress?.address ?? '',
                toAddress: locationController.toAddress?.address??'',
                entrance: rideController.isInitialWidgetRoutesExpand ? '' : locationController.entranceController.text,
                isShowDistance: rideController.isInitialWidgetRoutesExpand ? false : true,
              ),

              InkWell(
                onTap: (){
                  rideController.toggleInitialWidgetExpansion();
                },
                child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Text('view_details'.tr, style: textRegular.copyWith(color: Theme.of(context).primaryColor)),
                  const SizedBox(width: 1),

                  Icon(rideController.isInitialWidgetRoutesExpand ? Icons.keyboard_arrow_down_outlined : Icons.keyboard_arrow_up_outlined, size: 22, color: Theme.of(context).primaryColor)
                ]),
              )
            ]),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          if(!rideController.isMove && rideController.fareList[rideController.rideCategoryIndex].extraFareReason != '') ...[
            Text('${'fares_are_a_bit_higher'.tr}${rideController.fareList[rideController.rideCategoryIndex].extraFareReason}', style: textRegular.copyWith(color: Theme.of(context).colorScheme.inverseSurface,fontSize: 11), textAlign: TextAlign.center),
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          ],

          const SizedBox(height: Dimensions.paddingSizeSmall),

          if (rideController.isMove) ...[
            MoveDepositSummary(deposit: rideController.selectedType?.bookingDeposit ?? 0),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            GetBuilder<NearbyDriversController>(builder: (nearby) {
              final bool noneAround = nearby.isActive && nearby.loaded && rideController.selectedType != null
                  && nearby.driversFor(rideController.selectedType!).isEmpty;
              return noneAround ? MoveDirectoryLink(vehicleCategoryId: rideController.selectedCategoryId) : const SizedBox();
            }),
          ] else
            TripFareSummery(
              tripFare: rideController.estimatedFare, fromParcel: false,
              discountFare: rideController.discountFare, discountAmount: rideController.discountAmount,
            ),
          const SizedBox(height: Dimensions.paddingSizeLarge),

          if(!rideController.isMove && rideController.isCouponApplicable)...[
            Align(alignment: Alignment.centerRight,
              child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeSmall,
                    vertical: Dimensions.paddingSizeExtraSmall,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
                  ),
                  child: Text('coupon_applied'.tr,style: textBold.copyWith(color: Theme.of(context).primaryColor))
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),
          ],

          if(!rideController.isMove && (Get.find<ConfigController>().config?.isFemaleRideServiceActive ?? false))...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Text('female_driver_only_for_this_trip'.tr, style: textMedium),
                const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                JustTheTooltip(
                  backgroundColor:Get.isDarkMode ?
                  Theme.of(context).primaryColor :
                  Theme.of(context).textTheme.bodyMedium!.color,
                  controller: tooltipController,
                  preferredDirection: AxisDirection.up,
                  tailLength: Dimensions.paddingSizeSmall,
                  tailBaseWidth: Dimensions.paddingSizeLarge,
                  content: Container(
                    width: Get.width * 0.8,
                    padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                    child: Text(
                      'female_rider_tooltip'.tr,
                      style: textRegular.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeDefault),
                    ),
                  ),
                  child: InkWell(
                    onTap: (){
                      tooltipController.showTooltip();
                    },
                    child: Icon(Icons.info, size: 16, color: Theme.of(context).colorScheme.inverseSurface),
                  ),
                )
              ]),

              SizedBox(height: 14,
                child: Checkbox(
                  value: rideController.isFemaleDriverSelected,
                  onChanged: (value)=> rideController.toggleFemaleDriverSelection(value!),
                  activeColor: Theme.of(context).primaryColor,
                  checkColor: Theme.of(context).cardColor,
                  side: BorderSide(color: Theme.of(context).hintColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                ),
              )
            ]),
            const SizedBox(height: Dimensions.paddingSizeDefault),
          ],

          rideController.isLoading || rideController.isSubmit || Get.find<MoveController>().uploading ?
          Center(child: SpinKitCircle(color: Theme.of(context).primaryColor, size: 40.0)) :
          rideController.isMove ?
          ButtonWidget(buttonText: 'move_request_truck'.tr, onPressed: () => _sendMoveRequest(rideController)) :
          (Get.find<ConfigController>().config!.bidOnFare! && rideController.rideType != RideType.scheduleRide
              && !(rideController.selectedType?.isDropFare ?? false) && !rideController.isHealthRide) ?
          FareInputWidget(
            expandableKey: widget.expandableKey,
            fromRide: true,
            fare: rideController.discountAmount.toDouble() > 0 ?
            rideController.discountFare.toString() :
            rideController.estimatedFare.toString(),
          ) :
          ButtonWidget(buttonText: rideController.rideType == RideType.scheduleRide ? 'book_ride'.tr : "find_rider".tr, onPressed: () {
            if(rideController.rideType == RideType.regularRide) {
              _sendFindRiderRequest(rideController);
            }else{
              rideController.submitRideRequest(rideController.noteController.text, false).then((value){
                if(value.statusCode == 200){
                  Get.find<MapController>().initializeData();
                  if (rideController.tripDetails?.deposit?.isAwaiting ?? false) {
                    // Deposit when booking: the ride is booked once it is paid (next screen).
                    showCustomSnackBar('scheduled_pay_to_confirm'.tr, isError: false);
                  } else {
                    final config = Get.find<ConfigController>().config;
                    // Deposit once a driver accepts: say so, so the rider expects the countdown.
                    final bool payOnAccept = (config?.bookingDepositStatus ?? false) && config?.bookingDepositScheduledTiming == 'accept';
                    showCustomSnackBar(
                        '${'your_trip'.tr} #${rideController.tripDetails?.refId} ${'has_been_successfully_scheduled'.tr}',
                        subMessage: (payOnAccept ? 'scheduled_pay_when_driver_accepts' : 'you_will_be_notified_when_a_driver_start_for_your').tr
                    );
                  }
                  Get.offAll(() =>  TripDetailsScreen(tripId: rideController.tripDetails?.id ?? ''));
                }
              });
            }
          }),
        ]);
      });
    });
  }

  /// A move needs a word on the load; the photos go up first so drivers see
  /// them while the request rings.
  Future<void> _sendMoveRequest(RideController rideController) async {
    if (rideController.noteController.text.trim().isEmpty) {
      showCustomSnackBar('move_describe_load_first'.tr);
      return;
    }
    final MoveController move = Get.find<MoveController>();
    final List<String>? photos = await move.uploadPhotos();
    if (photos == null) return;
    _sendFindRiderRequest(rideController, movePhotos: photos);
  }

  void _sendFindRiderRequest(RideController rideController, {List<String>? movePhotos}){
    rideController.submitRideRequest(rideController.noteController.text, false, movePhotos: movePhotos).then((value) {
      if (value.statusCode == 200) {
        if (movePhotos != null) Get.find<MoveController>().resetBooking();
        Get.find<AuthController>().saveFindingRideCreatedTime();
        rideController.updateRideCurrentState(RideState.findingRider);
        Get.find<MapController>().initializeData();
        Get.find<MapController>().setOwnCurrentLocation(
            LatLng(
                Get.find<LocationController>().fromAddress?.latitude ?? 0,
                Get.find<LocationController>().fromAddress?.longitude ?? 0
            )
        );
        Get.find<MapController>().notifyMapController();
      }
    });
  }
}

/// The pickup or the destination is in an area E-Ride paused for safety.
class _SafetyNotice extends StatelessWidget {
  final String text;
  const _SafetyNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSize),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.warning_amber_rounded, color: color, size: 20),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Expanded(child: Text(text, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color, height: 1.35))),
      ]),
    );
  }
}

/// "Choose your ride" with the estimated distance and time for the selected
/// category as small chips.
class _SheetHeader extends StatelessWidget {
  final String title;
  final String? distance;
  final String? duration;
  const _SheetHeader({required this.title, required this.distance, required this.duration});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(
        title,
        style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge),
      )),
      if((duration ?? '').isNotEmpty && duration != '0') _MetaChip(icon: Icons.schedule_rounded, text: duration!),
      if((distance ?? '').isNotEmpty && distance != '0') ...[
        const SizedBox(width: 6),
        _MetaChip(icon: Icons.route_rounded, text: RideCategoryWidget.formatDistance(distance!)),
      ],
    ]);
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final Color hint = Theme.of(context).hintColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: hint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Theme.of(context).textTheme.bodyLarge?.color),
        const SizedBox(width: 4),
        Text(text, style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall)),
      ]),
    );
  }
}
