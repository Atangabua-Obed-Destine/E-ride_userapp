import 'package:ride_sharing_user_app/features/assistant/widgets/need_results.dart';
import 'package:ride_sharing_user_app/features/bus/controllers/bus_controller.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/move/controllers/move_controller.dart';
import 'package:ride_sharing_user_app/features/home/controllers/category_controller.dart';
import 'package:ride_sharing_user_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/ride/widgets/ride_category.dart';
import 'package:ride_sharing_user_app/features/set_destination/widget/input_field_for_set_route.dart';
import 'package:ride_sharing_user_app/features/set_destination/widget/pick_location_widget.dart';
import 'package:ride_sharing_user_app/features/set_destination/widget/pickup_time_date_widget.dart';
import 'package:ride_sharing_user_app/features/set_destination/widget/process_button_widget.dart';
import 'package:ride_sharing_user_app/features/set_destination/widget/reservation_note_widget.dart';
import 'package:ride_sharing_user_app/helper/route_helper.dart';
import 'package:ride_sharing_user_app/localization/localization_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/location/view/pick_map_screen.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/divider_widget.dart';
import 'dart:math' as math;
import 'package:ride_sharing_user_app/features/health_ride/widgets/health_ride_widgets.dart';
import 'package:ride_sharing_user_app/features/ride/widgets/pickup_help.dart';


class SetDestinationScreen extends StatefulWidget {
  final Address? address;
  final String? searchText;
  final RideType rideType;
  /// E-Ride Move: book a truck; the price is agreed with the driver.
  final bool move;
  /// Health ride: an urgent ride to care, for now only, with no surge or bidding.
  final bool health;
  const SetDestinationScreen({super.key, this.address,this.searchText, this.rideType = RideType.regularRide, this.move = false, this.health = false});

  @override
  State<SetDestinationScreen> createState() => _SetDestinationScreenState();
}

class _SetDestinationScreenState extends State<SetDestinationScreen> {
  FocusNode pickLocationFocus = FocusNode();
  FocusNode destinationLocationFocus = FocusNode();
  ScrollController scrollController = ScrollController();
  double dialogTopPosition = 0;
  double bottomWhiteSpace = 0;
  var keyboardVisibilityController = KeyboardVisibilityController();
  late StreamSubscription<bool> keyboardSubscription;
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();

    Get.find<RideController>().setRideType(widget.rideType);
    Get.find<LocationController>().initAddLocationData();
    Get.find<LocationController>().initTextControllers();
    Get.find<RideController>().clearExtraRoute();
    Get.find<MapController>().initializeData();
    Get.find<RideController>().initData();
    Get.find<RideController>().setMoveMode(widget.move);
    Get.find<RideController>().setHealthMode(widget.health && !widget.move);
    if (widget.move) {
      // After the first frame: these notify GetBuilders, which cannot rebuild mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<CategoryController>().getMoveCategoryList();
        Get.find<MoveController>().resetBooking();
      });
    }
    Get.find<ParcelController>().updatePaymentPerson(false, notify: false);
    Get.find<LocationController>().setPickUp(Get.find<LocationController>().getUserAddress());
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<LocationController>().refreshPickupFromGps());

    if(widget.address != null) {
      Get.find<LocationController>().setDestination(widget.address);
    }
    if(widget.searchText != null){
      Get.find<LocationController>().setDestination(Address(address: widget.searchText));
      Future.delayed(const Duration(seconds: 1)).then((_){
        Get.find<LocationController>().searchLocation(Get.context!, widget.searchText ?? '', type: LocationType.to);
      });
    }

    // Bus destinations for the smart search ("bus Douala"): kept for 5 minutes.
    if (_smartSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Get.isRegistered<BusController>()) Get.find<BusController>().loadMeta();
      });
    }

    keyboardSubscription = keyboardVisibilityController.onChange.listen((bool visible) {
      if(!visible){
        bottomWhiteSpace = 0;
      }
    });

  }

  final GlobalKey _stackKey = GlobalKey();

  /// Room for the results between their top and the keyboard (the screen does
  /// not shrink for it), measured where the list really starts on screen.
  double _resultsMaxHeight(BuildContext context) {
    final RenderBox? stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final double stackTop = (stack != null && stack.hasSize) ? stack.localToGlobal(Offset.zero).dy : 140;
    // The window's own numbers: the Scaffold hides the keyboard from the body's MediaQuery.
    final MediaQueryData window = MediaQueryData.fromView(View.of(context));
    final double bottom = window.size.height - math.max(window.viewInsets.bottom, window.padding.bottom);
    // At least one row and a bit, so a small phone still shows something to scroll.
    return math.max(100, bottom - stackTop - dialogTopPosition - 12);
  }

  /// Needs in the destination field: on ride bookings, not on Move or health rides.
  bool get _smartSearch => !widget.move && !widget.health && widget.rideType == RideType.regularRide;

  @override
  void dispose() {
    keyboardSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(top: false, child: Scaffold(
      resizeToAvoidBottomInset: false,
      body: GetBuilder<RideController>(builder: (rideController){
        return BodyWidget(
          appBar: AppBarWidget(
            title: widget.move ? 'move_setup'.tr : widget.health ? 'health_ride'.tr : rideController.rideType == RideType.scheduleRide ? 'schedule_trip_setup'.tr : 'trip_setup'.tr, centerTitle: true,
            onBackPressed: () {
              if(Navigator.canPop(context)) {
                Get.back();
              }else {
                Get.offAll(()=> const DashboardScreen());
              }
            },
          ),
          body: GetBuilder<LocationController>(builder: (locationController) {
            return Stack(key: _stackKey, clipBehavior: Clip.none, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault,
                  Dimensions.paddingSizeDefault,Dimensions.paddingSizeSmall,
                ),
                child: SingleChildScrollView(controller: scrollController, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,children: [
                  RideCategoryWidget(),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  // Moves are booked for now only; health rides too, unless the admin lets them be booked ahead.
                  if (widget.health) const HealthRideNotice(),
                  if (!widget.move && (!widget.health || (Get.find<ConfigController>().config?.healthRideSchedule ?? false))) PickupTimeDateWidget(),

                  Row(children: [
                    Container(
                      width: 4, height: 18,
                      margin: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
                      decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(2)),
                    ),
                    Text('set_your_location'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
                  ]),
                  const SizedBox(height: Dimensions.paddingSize),

                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: 0.18)),
                    ),
                    child: Column(children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _LocationFromToWidget(),

                        Expanded(child: Padding(
                          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            PickLocationWidget(
                              locationType: LocationType.from,
                              rideDetails: rideController.rideDetails,
                              focusNode: pickLocationFocus,
                              textEditingController: locationController.pickupLocationController,
                              isShowCrossButton: false,
                              textFieldHint: 'pick_location'.tr,
                              locationIconTap: (){
                                RouteHelper.goPageAndHideTextField(context, PickMapScreen(
                                    type: LocationType.from,
                                    address: locationController.fromAddress
                                ));
                              },
                              textFieldTap: (){
                                setScrollAndDialogPosition(LocationType.from, locationController);
                              },
                            ),
                            const SizedBox(height: Dimensions.paddingSizeSmall),

                            // Where exactly the driver finds the customer: written, or a voice note.
                            const PickupHelpRow(),

                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeExtraSmall,),
                              child: Text('to'.tr, style: textRegular.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color)),
                            ),

                            if(locationController.extraOneRoute)
                              PickLocationWidget(
                                locationType: LocationType.extraOne,
                                textFieldHint: 'extra_route_one'.tr,
                                rideDetails: rideController.rideDetails,
                                focusNode: null,
                                textEditingController: locationController.extraRouteOneController,
                                isShowCrossButton: true,
                                locationIconTap: (){
                                  RouteHelper.goPageAndHideTextField(context, PickMapScreen(
                                      type: LocationType.extraOne,
                                      address: locationController.extraRouteAddress
                                  ));
                                },
                                textFieldTap: (){
                                  setScrollAndDialogPosition(LocationType.extraOne, locationController);
                                },
                              ),

                            SizedBox(height: locationController.extraOneRoute ? Dimensions.paddingSizeDefault : 0),

                            if(locationController.extraTwoRoute)
                              PickLocationWidget(
                                locationType: LocationType.extraTwo,
                                textFieldHint: 'extra_route_two'.tr,
                                rideDetails: rideController.rideDetails,
                                focusNode: null,
                                textEditingController: locationController.extraRouteTwoController,
                                isShowCrossButton: true,
                                locationIconTap: (){
                                  RouteHelper.goPageAndHideTextField(context, PickMapScreen(
                                      type: LocationType.extraTwo,
                                      address: locationController.extraRouteTwoAddress
                                  ));
                                },
                                textFieldTap: (){
                                  setScrollAndDialogPosition(LocationType.extraTwo, locationController);
                                },
                              ),

                            SizedBox(height: locationController.extraTwoRoute ? Dimensions.paddingSizeDefault : 0),

                            Row(children: [
                              Expanded(child: PickLocationWidget(
                                locationType: LocationType.to,
                                textFieldHint: 'destination'.tr,
                                rideDetails: rideController.rideDetails,
                                focusNode: destinationLocationFocus,
                                textEditingController: locationController.destinationLocationController,
                                isShowCrossButton: false,
                                locationIconTap: (){
                                  RouteHelper.goPageAndHideTextField(context, PickMapScreen(
                                      type: LocationType.to,
                                      address: locationController.toAddress
                                  ));
                                },
                                textFieldTap: (){
                                  setScrollAndDialogPosition(LocationType.to, locationController);
                                },
                              )),

                              SizedBox(width: locationController.extraTwoRoute ? 0 : Dimensions.paddingSizeSmall),

                              if(!(!Get.find<ConfigController>().config!.addIntermediatePoint! || locationController.extraTwoRoute))
                                InkWell(
                                  onTap: () => locationController.setExtraRoute(),
                                  child: Container(
                                    height: 46, width: 46,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(Dimensions.radiusLarge - 2),
                                    ),
                                    child: Icon(Icons.add_rounded, color: Theme.of(context).primaryColor),
                                  ),
                                ),
                            ]),
                            const SizedBox(height: Dimensions.paddingSizeDefault),

                            locationController.addEntrance ?
                            SizedBox(width: 200, child: InputField(
                              showSuffix: false,
                              controller: locationController.entranceController,
                              node: locationController.entranceNode,
                              hint: 'enter_entrance'.tr,
                            )) :
                            InkWell(
                              onTap: () => locationController.setAddEntrance(),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                SizedBox(height: 30, child: Transform(
                                  alignment: Alignment.center,
                                  transform: Get.find<LocalizationController>().isLtr ?
                                  Matrix4.rotationY(0) :
                                  Matrix4.rotationY(math.pi),
                                  child: Image.asset(Images.curvedArrow,color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.7)),
                                )),
                                const SizedBox(width: Dimensions.paddingSizeSmall),

                                Row(crossAxisAlignment: CrossAxisAlignment.end,children: [
                                  Icon(Icons.add, color: Theme.of(context).primaryColor,size: 16),

                                  Padding(
                                    padding: const EdgeInsets.only(top: Dimensions.paddingSizeDefault),
                                    child: Text(
                                      'add_entrance'.tr,
                                      style: textRegular.copyWith(color: Theme.of(context).primaryColor, fontSize: Dimensions.fontSizeSmall,),
                                    ),
                                  ),
                                ]),
                              ]),
                            ),
                          ]),
                        )),
                      ]),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Dimensions.paddingSizeExtraLarge, 0,
                          Dimensions.paddingSizeExtraLarge,Dimensions.paddingSizeSmall,
                        ),
                        child: Text(
                          'you_can_add_multiple_route_to'.tr,
                          style: textRegular.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                            color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ]),
                  ),

                  if(rideController.rideType == RideType.scheduleRide)
                    ReservationNoteWidget(globalKey: _key),

                  SizedBox(height: bottomWhiteSpace)
                ])),
              ),

              if(locationController.resultShow)
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: InkWell(
                    onTap: () => locationController.setSearchResultShowHide(show: false),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Get.isDarkMode ?
                        Theme.of(context).canvasColor :
                        Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: 0.18)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10)),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      margin: EdgeInsets.fromLTRB(30, dialogTopPosition, 30, 0),
                      // Fits above the keyboard and scrolls: the needs on top
                      // must never push the places out of reach.
                      constraints: BoxConstraints(maxHeight: _resultsMaxHeight(context)),
                      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // What the customer seems to need ("pharmacie", "bus Douala"),
                      // above the places, when typing where a ride should go.
                      if (_smartSearch && locationController.locationType == LocationType.to)
                        NeedResults(text: locationController.destinationLocationController.text),
                      ListView.builder(
                        itemCount: locationController.predictionList?.data?.suggestions?.length ?? 0,
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index){
                          return  InkWell(
                            onTap: () {
                              pickLocationFocus.unfocus();
                              destinationLocationFocus.unfocus();
                              Get.find<LocationController>().setLocation(
                                fromSearch: true,
                                locationController.predictionList?.data?.suggestions?[index].placePrediction?.placeId ?? '',
                                locationController.predictionList?.data?.suggestions?[index].placePrediction?.text?.text ?? '', null,
                                type: locationController.locationType,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: Dimensions.paddingSizeDefault,
                                horizontal: Dimensions.paddingSizeSmall,
                              ),
                              child: Row(children: [
                                Container(
                                  width: 32, height: 32,
                                  margin: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).hintColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    switch (locationController.predictionList?.data?.suggestions?[index].placePrediction?.types?.firstOrNull) {
                                      'landmark' => Icons.signpost_rounded,
                                      'saved_place' => Icons.bookmark_rounded,
                                      _ => Icons.place_rounded,
                                    },
                                    size: 18, color: Theme.of(context).primaryColor,
                                  ),
                                ),

                                Expanded(child: Text(
                                  locationController.predictionList?.data?.suggestions?[index].placePrediction?.text?.text ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.displayMedium!.copyWith(
                                    color: Theme.of(context).textTheme.bodyLarge!.color,
                                    fontSize: Dimensions.fontSizeDefault,
                                  ),
                                )),
                              ]),
                            ),
                          );
                        },
                      ),
                      ])),
                    ),
                  ),
                ) ,
            ]);
          }),
        );
      }),
      bottomNavigationBar: ProcessButtonWidget(
        pickLocationFocus: pickLocationFocus,
        destinationLocationFocus: destinationLocationFocus,
      ),
    ));
  }

  void setScrollAndDialogPosition(LocationType locationType, LocationController locationController){

    scrollController.jumpTo(MediaQuery.of(context).size.height + Get.height * 0.3);
    bottomWhiteSpace = Get.find<RideController>().rideType == RideType.scheduleRide ? (Get.height * 0.4 -  (_key.currentContext?.size?.height ?? 0)) : Get.height * 0.4;

    if(locationType == LocationType.from) {
      dialogTopPosition = Get.height * 0.2;
    }else if(locationType == LocationType.extraOne) {
      dialogTopPosition = locationController.extraTwoRoute ? Get.height * 0.18 : Get.height * 0.23;
    }else if(locationType == LocationType.extraTwo) {
      dialogTopPosition = Get.height * 0.23;
    }else if(locationType == LocationType.to) {
      dialogTopPosition = Get.height * 0.28;
    }
    setState(() {});
  }
}

class _LocationFromToWidget extends StatelessWidget {
  const _LocationFromToWidget();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideController>(
      builder: (rideController) {
        return Padding(
          padding:  const EdgeInsets.fromLTRB(Dimensions.paddingSizeSmall,Dimensions.paddingSizeLarge, 0, 0),
          child: Column(children: [
            SizedBox(
              width: Dimensions.iconSizeLarge, height: Dimensions.iconSizeLarge,
              child: Center(child: Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).primaryColor, width: 3),
                ),
              )),
            ),

            SizedBox(height: !rideController.hasPickupHelp ? 108 : (rideController.voiceNote != null ? 150 : 116), width: 10, child: CustomDivider(
              height: 8, dashWidth: .75,
              axis: Axis.vertical,
              color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.5),
            )),

            SizedBox(
              width: Dimensions.iconSizeMedium,
              child: Transform(
                alignment: Alignment.center,
                transform: Get.find<LocalizationController>().isLtr ?
                Matrix4.rotationY(0) :
                Matrix4.rotationY(math.pi),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 22,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ]),
        );
      }
    );
  }
}
