import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/move/widgets/move_widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:ride_sharing_user_app/common_widgets/expandable_bottom_sheet.dart';
import 'package:ride_sharing_user_app/features/map/widget/custom_icon_card.dart';
import 'package:ride_sharing_user_app/features/map/widget/discount_coupon_bottomsheet.dart';
import 'package:ride_sharing_user_app/features/map/widget/nearby_drivers_chip.dart';
import 'package:ride_sharing_user_app/features/map/widget/verify_and_driver_near_by_toster_widget.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/nearby_drivers_controller.dart';
import 'package:ride_sharing_user_app/features/safety_setup/controllers/safety_alert_controller.dart';
import 'package:ride_sharing_user_app/features/safety_setup/widgets/safety_alert_bottomsheet_widget.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/widgets/parcel_expendable_bottom_sheet.dart';
import 'package:ride_sharing_user_app/features/payment/screens/payment_screen.dart';
import 'package:ride_sharing_user_app/features/ride/widgets/ride_expendable_bottom_sheet.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/trip_checkin/controllers/trip_checkin_controller.dart';
import 'package:ride_sharing_user_app/theme/theme_controller.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/trip_share/controllers/trip_share_controller.dart';
import 'package:ride_sharing_user_app/features/trip_share/widgets/share_trip_card.dart';


enum MapScreenType{ride, splash, parcel, location}

class MapScreen extends StatefulWidget {
  final MapScreenType fromScreen;
  final bool isShowCurrentPosition;
  /// Overrides the app bar title, e.g. a food order tracked as a parcel.
  final String? title;
  const MapScreen({super.key, required this.fromScreen, this.isShowCurrentPosition = true, this.title});
  @override
  State<MapScreen> createState() => _MapScreenState();

  /// Opens the trip map. When one is already open further back, the app goes
  /// back to it and puts this one in its place: map screens used to pile up
  /// (one per ride, notification or list tap), and Back walked through old trips.
  static Future<T?>? open<T>(MapScreen screen) {
    if (_MapScreenState._open > 0) {
      Get.until((route) => route.settings.name == '/MapScreen' || route.isFirst);
      if (Get.currentRoute == '/MapScreen') {
        return Get.off<T>(() => screen, preventDuplicates: false);
      }
    }
    return Get.to<T>(() => screen);
  }
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver{
  GoogleMapController? _mapController;
  GlobalKey<ExpandableBottomSheetState> key = GlobalKey<ExpandableBottomSheetState>();
  // Last state the nearby-drivers layer was synced for; see _syncNearbyDrivers.
  String? _nearbyKey;
  // Map screens open right now (one replaces another on some steps).
  static int _open = 0;

  @override
  void initState() {
    super.initState();
    _open++;
    WidgetsBinding.instance.addObserver(this);
    Get.find<MapController>().setContainerHeight((widget.fromScreen == MapScreenType.parcel) ? 200 : 260, false);
    // A check-in may be waiting for an answer (the push was missed, or the app was closed).
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<TripCheckinController>().check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if(state == AppLifecycleState.resumed){
      _setMapCurrentRoutes();
      _syncNearbyDrivers(Get.find<RideController>(), force: true);
      Get.find<TripCheckinController>().check();
    }else if(state == AppLifecycleState.paused){
      // No polling while the app is in the background.
      _nearbyKey = null;
      Get.find<NearbyDriversController>().stop();
      Get.find<MapController>().clearNearbyDriverMarkers();
    }
  }

  @override
  void dispose() {
    Get.find<LocationController>().stopFollowingPosition();
    // Both redraw listeners (the dashboard map is one): not allowed while the
    // framework is finalizing this screen's removal, so right after it.
    // Skipped when another map screen took over: it runs its own layer.
    _open--;
    Future.microtask(() {
      if (_open > 0) return;
      Get.find<NearbyDriversController>().stop();
      Get.find<MapController>().clearNearbyDriverMarkers();
    });
    _mapController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    Get.find<MapController>().mapController?.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: PopScope(
        canPop: Navigator.canPop(context),
        onPopInvokedWithResult: (didPop, value){
          if(didPop){
            Future.delayed(const Duration(milliseconds: 500)).then((onValue){
              if(Get.find<RideController>().currentRideState.name == AppConstants.findingRider ||
                  Get.find<ParcelController>().currentParcelState.name == AppConstants.findingRider){
                Get.offAll(()=> const DashboardScreen());
              }
            });

          }else{
            Get.offAll(()=> const DashboardScreen());
          }
        },
        child: Scaffold(resizeToAvoidBottomInset: false,
          body: GetBuilder<RideController>(builder: (rideController){
            _syncNearbyDrivers(rideController);
            return Stack(children: [
              BodyWidget(topMargin: 0,
                appBar: AppBarWidget(
                  title: widget.title ?? (widget.fromScreen == MapScreenType.parcel ? 'your_parcel'.tr : _getAppbarTitle(rideController)),
                  subTitle: widget.fromScreen == MapScreenType.parcel ? null : rideController.isLoading ? 'refreshing_date'.tr : _getAppbarSubTitle(rideController),
                  centerTitle: true,
                  onBackPressed: () {
                    if(Navigator.canPop(context)) {
                      if(Get.find<RideController>().currentRideState.name == AppConstants.findingRider ||
                          Get.find<ParcelController>().currentParcelState.name == AppConstants.findingRider){
                        Get.offAll(()=> const DashboardScreen());
                      }else{
                        Get.back();
                      }

                    }else {
                      Get.offAll(()=> const DashboardScreen());
                    }
                  },
                ),
                body: GetBuilder<MapController>(builder: (mapController) {
                  return ExpandableBottomSheet(key: key,
                    background: GetBuilder<RideController>(builder: (rideController) {
                      return Stack(children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: mapController.sheetHeight - 20),
                          child: GoogleMap(
                              style: Get.isDarkMode ?
                              Get.find<ThemeController>().darkMap : Get.find<ThemeController>().lightMap,
                              initialCameraPosition:  CameraPosition(
                                target:  rideController.tripDetails?.pickupCoordinates != null ?
                                LatLng(
                                  rideController.tripDetails!.pickupCoordinates!.coordinates![1],
                                  rideController.tripDetails!.pickupCoordinates!.coordinates![0],
                                ) :
                                Get.find<LocationController>().initialPosition,
                                zoom: 16,
                              ),
                              onMapCreated: (GoogleMapController controller) {
                                mapController.mapController = controller;
                                if(
                                rideController.currentRideState.name == AppConstants.findingRider ||
                                    rideController.currentRideState.name == AppConstants.riseFare
                                ){
                                  mapController.initializeData();
                                  mapController.setOwnCurrentLocation(
                                      LatLng(
                                        rideController.tripDetails!.pickupCoordinates!.coordinates![1],
                                        rideController.tripDetails!.pickupCoordinates!.coordinates![0],
                                      )
                                  );
                                }else if(rideController.currentRideState.name == AppConstants.initial){
                                  mapController.getPolyline();
                                }else if(rideController.currentRideState.name == AppConstants.completeRide){
                                  mapController.initializeData();
                                }else{
                                  mapController.initializeData();
                                  mapController.setMarkersInitialPosition();
                                  rideController.startLocationRecord();
                                }
                                _mapController = controller;
                              },
                              minMaxZoomPreference: const MinMaxZoomPreference(0, AppConstants.mapZoom),
                              markers: _showNearbyDrivers(rideController) ?
                              {...mapController.markers, ...mapController.nearbyDriverMarkers} :
                              Set<Marker>.of(mapController.markers),
                              circles: _showNearbyDrivers(rideController) ? mapController.pickupCircles : const <Circle>{},
                              polylines: Set<Polyline>.of(mapController.polylines.values),
                              zoomControlsEnabled: false,
                              compassEnabled: false,
                              trafficEnabled: mapController.isTrafficEnable,
                              indoorViewEnabled: true,
                              mapToolbarEnabled: true,
                          ),
                        ),

                        Positioned(top: 0, left: 0, right: 0,
                          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            VerifyAndDriverNearByToasterWidget(fromScreen: widget.fromScreen),

                            if(_showNearbyDrivers(rideController))
                              NearbyDriversChip(onTap: () => mapController.fitPickupAndNearest()),
                          ]),
                        ),

                        if(widget.isShowCurrentPosition)
                          Positioned(bottom: Get.height * 0.34, right: 0,
                            child: Align(
                              alignment: Alignment.bottomRight,
                              child: GetBuilder<LocationController>(builder: (locationController) {
                                return CustomIconCard(
                                  icon: Images.currentLocation,
                                  iconColor: Theme.of(context).primaryColor,
                                  onTap: () async {
                                    await locationController.getCurrentLocation(mapController: _mapController);
                                    await _mapController?.moveCamera(CameraUpdate.newCameraPosition(
                                      CameraPosition(target: Get.find<LocationController>().initialPosition, zoom: 16),
                                    ));
                                  },
                                );
                              }),
                            ),
                          ),

                        Positioned(bottom: Get.height * 0.40, right:0,
                          child: Align(
                              alignment: Alignment.bottomRight,
                              child: CustomIconCard(
                                icon: mapController.isTrafficEnable ?
                                Images.trafficOnlineIcon : Images.trafficOfflineIcon,
                                iconColor: mapController.isTrafficEnable ?
                                Theme.of(context).colorScheme.secondaryContainer : Theme.of(context).hintColor,
                                onTap: () => mapController.toggleTrafficView(),
                              )
                          ),
                        ),

                        if(_isShowCouponButton(rideController))
                          Positioned(
                              bottom: Get.height * 0.52, right:0,
                              child: Align(
                                  alignment: Alignment.bottomRight,
                                  child: CustomIconCard(
                                    icon: Images.offerMapIcon,iconColor: Theme.of(context).colorScheme.inverseSurface,
                                    onTap: (){
                                      Get.bottomSheet(
                                        const DiscountAndCouponBottomSheet(),
                                        backgroundColor: Theme.of(context).cardColor,isDismissible: false,
                                      );
                                    },
                                  )
                              )
                          ),

                        if(_isLocationShareEnable())
                          Positioned(bottom: Get.height * 0.46, right:0,
                            child: Align(
                                alignment: Alignment.bottomRight,
                                child: CustomIconCard(
                                  icon: Images.shareLocation,
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Theme.of(context).cardColor,
                                      isScrollControlled: true,
                                      builder: (context) => const ShareTripSheet(),
                                    );
                                  },
                                )
                            ),
                          ),

                        if(_isSafetyFeatureActive())
                          Positioned(bottom: _isLocationShareEnable() ? Get.height * 0.52 : Get.height * 0.46, right:0,
                              child: Align(
                                  alignment: Alignment.bottomRight,
                                  child: JustTheTooltip(
                                    backgroundColor: Get.isDarkMode ?
                                    Theme.of(context).primaryColor :
                                    Theme.of(context).textTheme.bodyMedium!.color,
                                    controller: rideController.justTheController,
                                    preferredDirection: AxisDirection.right,
                                    tailLength: 10,
                                    tailBaseWidth: 20,
                                    content: Container(width: 130,
                                      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                                      child: Text(
                                        'safety_alert_sent'.tr,
                                        style: textRegular.copyWith(
                                          color: Colors.white, fontSize: Dimensions.fontSizeSmall,
                                        ),
                                      ),
                                    ),
                                    child: GetBuilder<SafetyAlertController>(builder: (safetyAlertController){
                                      return CustomIconCard(
                                        icon: safetyAlertController.currentState == SafetyAlertState.afterSendAlert ?
                                        Images.shieldCheckIcon :
                                        Images.safelyShieldIcon2,
                                        backGroundColor: safetyAlertController.currentState == SafetyAlertState.afterSendAlert ?
                                        Colors.red : null,
                                        onTap: (){
                                          Get.bottomSheet(
                                            isScrollControlled: true,
                                            const SafetyAlertBottomSheetWidget(),
                                            backgroundColor: Theme.of(context).cardColor,isDismissible: false,
                                          );
                                        },
                                      );
                                    }),
                                  )
                              )

                          ),
                      ]);
                    }),
                    persistentContentHeight: mapController.sheetHeight,

                    expandableContent: Column(mainAxisSize: MainAxisSize.min, children: [
                      widget.fromScreen == MapScreenType.parcel ?
                      GetBuilder<RideController>(builder: (parcelController) {
                        return ParcelExpendableBottomSheet(expandableKey: key);
                      }) :
                      (widget.fromScreen == MapScreenType.ride || widget.fromScreen == MapScreenType.splash) ?
                      GetBuilder<RideController>(builder: (rideController) {
                        return RideExpendableBottomSheet(expandableKey: key);
                      }) :
                      const SizedBox(),
                      SizedBox(height: MediaQuery.of(context).viewInsets.bottom),

                    ]),
                  );
                }),
              ),

              widget.fromScreen == MapScreenType.location ?
              Positioned(
                child: Align(alignment: Alignment.bottomCenter,
                  child: SizedBox(height: 70, child: Padding(
                    padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                    child: ButtonWidget(buttonText: 'set_location'.tr, onPressed: () => Get.back()),
                  )),
                ),
              ) :
              const SizedBox(),

            ]);
          }),
        ),
      ),
    );
  }

  /// Live nearby drivers show on a ride (not parcel, not scheduled) while the
  /// rider chooses a vehicle, raises the fare, or waits for a driver. Once a
  /// driver accepts they disappear.
  bool _showNearbyDrivers(RideController ride){
    final bool rideScreen = widget.fromScreen == MapScreenType.ride || widget.fromScreen == MapScreenType.splash;
    final bool stage = ride.currentRideState == RideState.initial ||
        ride.currentRideState == RideState.riseFare ||
        ride.currentRideState == RideState.findingRider;
    return rideScreen && stage &&
        ride.rideType != RideType.scheduleRide &&
        ride.tripDetails?.type != AppConstants.parcel;
  }

  LatLng? _nearbyPickup(RideController ride){
    final fromAddress = Get.find<LocationController>().fromAddress;
    final LatLng? chosen = (fromAddress?.latitude != null && fromAddress?.longitude != null) ?
      LatLng(fromAddress!.latitude!, fromAddress.longitude!) : null;
    final coords = ride.tripDetails?.pickupCoordinates?.coordinates;
    final LatLng? onTrip = (coords != null && coords.length >= 2) ? LatLng(coords[1], coords[0]) : null;
    // Before a request exists the pickup the rider just chose is the truth;
    // once it is out, the trip's own pickup is.
    return ride.currentRideState == RideState.initial ? (chosen ?? onTrip) : (onTrip ?? chosen);
  }

  /// Starts, retargets or stops the nearby-drivers poll when the stage,
  /// selected category or fare list changes. Runs after the frame so it never
  /// calls update() during build.
  void _syncNearbyDrivers(RideController ride, {bool force = false}){
    final bool show = _showNearbyDrivers(ride);
    final String key = '$show|${ride.currentRideState.name}|${ride.rideCategoryIndex}|${ride.fareList.length}';
    if(!force && key == _nearbyKey) return;
    _nearbyKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(!mounted) return;
      final NearbyDriversController nearby = Get.find<NearbyDriversController>();
      final LatLng? pickup = show ? _nearbyPickup(ride) : null;
      if(pickup != null){
        nearby.start(pickup);
        Get.find<MapController>().refreshNearbyDriverMarkers();
      }else{
        nearby.stop();
        Get.find<MapController>().clearNearbyDriverMarkers();
      }
    });
  }

  bool _isSafetyFeatureActive(){
    return ((Get.find<ConfigController>().config?.safetyFeatureStatus ?? false) &&
    (Get.find<RideController>().currentRideState.name == AppConstants.ongoingRide) &&
        Get.find<RideController>().tripDetails?.type != AppConstants.parcel) ? true : false;
  }

  String _getAppbarTitle(RideController rideController){
    if(rideController.currentRideState == RideState.initial){
      return 'chose_a_vehicle'.tr;
    }else if(rideController.currentRideState == RideState.outForPickup || rideController.currentRideState == RideState.otpSent){
      return 'oth_the_way_to_pickup'.tr;
    }else if(rideController.currentRideState == RideState.ongoingRide){
      return 'ongoing'.tr;
    }else if(rideController.currentRideState == RideState.riseFare){
      return 'rise_fare'.tr;
    }else if(rideController.currentRideState == RideState.findingRider){
      return 'finding_rider'.tr;
    }else{
      return 'your_trip'.tr;
    }
  }

  String? _getAppbarSubTitle(RideController rideController){
    if(rideController.currentRideState == RideState.ongoingRide || rideController.currentRideState == RideState.outForPickup || rideController.currentRideState == RideState.otpSent){
      return '${rideController.tripDetails?.type == AppConstants.parcel ? 'parcel'.tr : 'trip'.tr} #${rideController.tripDetails?.refId}';
    }else{
      return null;
    }
  }

  bool _isLocationShareEnable(){
    return TripShareController.canShare(Get.find<RideController>().tripDetails);
  }
}

bool _isShowCouponButton(RideController rideController){
  if((rideController.tripDetails?.type == AppConstants.parcel) && Get.find<ParcelController>().currentParcelState == ParcelDeliveryState.initial){
    return true;
  }else if((rideController.tripDetails?.type != AppConstants.parcel) && rideController.currentRideState == RideState.initial){
    return true;
  }else{
    return false;
  }
}

void _setMapCurrentRoutes(){
  RideController rideController = Get.find<RideController>();
  MapController mapController = Get.find<MapController>();

  // On resume the trip can be briefly unloaded (another load clears it while
  // it runs): nothing to rebuild then, the running load updates the screen.
  final String? tripId = rideController.currentTripDetails?.id;
  if (tripId == null) return;

  rideController.getRideDetails(tripId).then((value) {
    if (value.statusCode == 200 && rideController.currentTripDetails != null) {
      if(rideController.currentTripDetails!.type == AppConstants.parcel){
        if(rideController.currentTripDetails!.currentStatus == AppConstants.pending){
          Get.find<ParcelController>().updateParcelState(ParcelDeliveryState.findingRider);
          mapController.getPolyline();

        }else if(rideController.currentTripDetails!.currentStatus == AppConstants.accepted){
          Get.find<ParcelController>().updateParcelState(ParcelDeliveryState.otpSent);
          mapController.getPolyline();
          rideController.startLocationRecord();
          mapController.notifyMapController();

        }else if(rideController.currentTripDetails!.currentStatus == AppConstants.ongoing){
          Get.find<ParcelController>().updateParcelState(ParcelDeliveryState.parcelOngoing);
          mapController.getPolyline();
          rideController.startLocationRecord();
          mapController.notifyMapController();
          if(rideController.currentTripDetails!.parcelInformation?.payer == AppConstants.sender &&
              rideController.currentTripDetails!.paymentStatus == 'unpaid'){
            Get.off(()=>const PaymentScreen(fromParcel: true));
          }

        }else{

          Get.offAll(()=> const DashboardScreen());
        }

      }else{
        if(rideController.currentTripDetails!.currentStatus == AppConstants.pending){
          rideController.updateRideCurrentState(RideState.findingRider);
          mapController.getPolyline();

        }else if(rideController.currentTripDetails!.currentStatus == AppConstants.outForPickup){
          rideController.updateRideCurrentState(RideState.outForPickup);
          mapController.getPolyline();
          rideController.startLocationRecord();
          mapController.notifyMapController();

        }else if(rideController.currentTripDetails!.currentStatus == AppConstants.ongoing){
          rideController.updateRideCurrentState(RideState.ongoingRide);
          mapController.getPolyline();
          rideController.startLocationRecord();
          mapController.notifyMapController();

        }else if(rideController.currentTripDetails!.isMove && rideController.currentTripDetails!.currentStatus == AppConstants.completed){
          // The move ended while the app was away: no payment, just the reminder.
          finishCompletedMove(tripId);

        }else if((rideController.currentTripDetails!.currentStatus == AppConstants.completed && rideController.currentTripDetails!.paymentStatus == AppConstants.unPaid)
            || (rideController.currentTripDetails!.currentStatus == AppConstants.cancelled && rideController.currentTripDetails!.paymentStatus == AppConstants.unPaid &&
                rideController.currentTripDetails!.paidFare! > 0)){
          Get.off(()=>const PaymentScreen(fromParcel: false));
        } else{
          Get.offAll(()=> const DashboardScreen());
        }
      }
    }
  });
}
