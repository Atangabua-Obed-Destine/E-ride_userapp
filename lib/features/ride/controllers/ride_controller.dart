import 'package:flutter/services.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/models/assistant_models.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:ride_sharing_user_app/common_widgets/trip_arrival_card.dart';
import 'package:ride_sharing_user_app/features/message/controllers/chat_inbox_controller.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';
import 'package:ride_sharing_user_app/features/map/screens/map_screen.dart';
import 'package:ride_sharing_user_app/features/parcel/domain/models/parcel_estimated_fare_model.dart';
import 'package:ride_sharing_user_app/features/refund_request/controllers/refund_request_controller.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/bidding_model.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/estimated_fare_model.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/final_fare_model.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/nearest_driver_model.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/remaining_distance_model.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/ride_list_model.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/trip_details_model.dart';
import 'package:ride_sharing_user_app/features/ride/domain/services/ride_service_interface.dart';
import 'package:ride_sharing_user_app/features/safety_setup/controllers/safety_alert_controller.dart';
import 'package:ride_sharing_user_app/features/trip/controllers/trip_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/live_trip_notification_helper.dart';
import 'package:ride_sharing_user_app/helper/notification_helper.dart';
import 'package:ride_sharing_user_app/helper/pusher_helper.dart';
import 'package:ride_sharing_user_app/helper/ride_controller_helper.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/home/controllers/category_controller.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_chat_controller.dart';
import 'package:ride_sharing_user_app/features/payment/controllers/payment_controller.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

enum RideState{initial, riseFare, findingRider, outForPickup, afterAcceptRider, otpSent, ongoingRide, completeRide}
enum RideType{regularRide, scheduleRide}


class RideController extends GetxController implements GetxService {
  final RideServiceInterface rideServiceInterface;
  RideController({required this.rideServiceInterface});

  RideState currentRideState = RideState.initial;
  TripDetails? _tripDetails;
  TripDetails? get tripDetails => _tripDetails;
  set tripDetails(TripDetails? value) {
    _tripDetails = value;
    if(value == null) {
      LiveTripNotificationHelper.dispose();
    }
  }
  TripDetails? rideDetails;
  double currentFarePrice = 0;
  int rideCategoryIndex = 0;
  bool isLoading = false;
  String estimatedDistance = '0';
  String estimatedDuration = '0';
  double estimatedFare = 0;
  double actualFare = 0;
  List<FareModel> fareList = [];
  ParcelEstimatedFare? parcelEstimatedFare;
  String parcelFare = '0';
  String encodedPolyLine = '';
  bool loading = false;
  bool isEstimate = false;
  bool isSubmit = false;
  List<Nearest> nearestDriverList = [];
  FinalFare? finalFare;
  List<Bidding> biddingList = [];
  List<RemainingDistanceModel> remainingDistanceModel = [];
  bool isCouponApplicable = false;
  double discountFare = 0;
  double discountAmount = 0;
  List<String>? _thumbnailPaths;
  List<String>? get thumbnailPaths => _thumbnailPaths;
  JustTheController justTheController = JustTheController();
  RideType _rideType = RideType.regularRide;
  String _pickupNote = '';
  String get pickupNoteText => _pickupNote;

  /// The voice note for the driver (where to find the customer), sent with the booking.
  VoiceTripResult? voiceNote;
  /// The customer was asked once, this booking, how the driver finds them.
  bool pickupHelpAsked = false;
  /// Something tells the driver where to find the customer.
  bool get hasPickupHelp => _pickupNote.isNotEmpty || voiceNote != null;

  void setVoiceNote(VoiceTripResult? note) {
    voiceNote = note;
    update();
  }

  /// The words from a voice note become the written pickup note, unless one was written.
  void usePickupText(String text) {
    if (text.trim().isEmpty || _pickupNote.isNotEmpty || pickupNoteController.text.trim().isNotEmpty) return;
    final String t = text.trim();
    pickupNoteController.text = t.length > 200 ? t.substring(0, 200) : t;
    _pickupNote = pickupNoteController.text;
    update();
  }
  RideType get rideType => _rideType;
  String? scheduleTripDate;
  DateTime? scheduleTripTime;
  RideListModel? runningRideList;
  bool isInitialWidgetRoutesExpand = false;
  bool showIdentityMismatchOptions = false;
  List<String> identityMismatchReasons = [];

  TripDetails? get currentTripDetails => tripDetails;

  bool isShowDriverArrivalTooltip = false;
  bool isShowDriverVerificationTooltip = false;

  TextEditingController inputFarePriceController = TextEditingController(text: '0.00');
  TextEditingController noteController = TextEditingController();
  final TextEditingController pickupNoteController = TextEditingController();
  bool isFemaleDriverSelected = false;

  /// E-Ride Move booking in progress: the vehicle list is the trucks, the
  /// only amount is the deposit, and the price is agreed with the driver.
  /// Set by the entry point before the trip exists; once it does,
  /// TripDetails.isMove is what counts.
  bool isMove = false;
  void setMoveMode(bool value) {
    isMove = value;
    rideCategoryIndex = 0;
    fareList = [];
    if (value) noteController.clear();
  }

  /// Health ride booking in progress: an urgent ride to care. The server gives
  /// the normal fare with no surge, and there is no bidding. Set by the entry
  /// point; once the trip exists, TripDetails.isHealthRide is what counts.
  bool isHealthRide = false;
  void setHealthMode(bool value) {
    isHealthRide = value;
    if (value) {
      rideCategoryIndex = 0;
      fareList = [];
    }
  }

  void initData() {
    currentRideState = RideState.initial;
    tripDetails = null;
    isLoading = false;
    loading = false;
    encodedPolyLine = '';
    scheduleTripDate = null;
    scheduleTripTime = null;
    _pickupNote = '';
    voiceNote = null;
    pickupHelpAsked = false;
    pickupNoteController.clear();
    isFemaleDriverSelected = false;
  }

  void updateRideCurrentState(RideState newState) {
    currentRideState = newState;
    update();
  }


  Future<void> setBidingAmount(String balance) async{
    if(balance.isNotEmpty){
      actualFare = double.parse(balance);
      parcelFare = balance;
    }
    update();
  }

  String categoryName = '';
  String selectedCategoryId = '';
  FareModel? selectedType;
  void setRideCategoryIndex(int newIndex){
    final categories = Get.find<CategoryController>().listFor(isMove);
    if (categories == null || newIndex >= categories.length) return;
    rideCategoryIndex = newIndex;
    categoryName = categories[rideCategoryIndex].id!;

    Get.find<CategoryController>().setCouponFilterIndex(newIndex + 2);

    if(fareList.isNotEmpty){
      for(int i = 0; i< fareList.length; i++){
        if(fareList[i].vehicleCategoryId == categoryName){
          selectedType =  fareList[i];
          break;
        }
      }

      estimatedDistance = selectedType!.estimatedDistance!;
      estimatedDuration = selectedType!.estimatedDuration!;
      selectedCategoryId = selectedType!.vehicleCategoryId!;
      encodedPolyLine = selectedType!.polyline!;
      estimatedFare = (((selectedType?.extraFareFee ?? 0) > 0) || ((selectedType?.surgeMultiplier ?? 0) >0)) ? selectedType?.extraEstimatedFare ?? 0 : selectedType?.estimatedFare ?? 0;
      currentFarePrice = estimatedFare;
      actualFare = estimatedFare;
      isCouponApplicable = selectedType!.couponApplicable!;
      discountFare = (((selectedType?.extraFareFee ?? 0) > 0) || ((selectedType?.surgeMultiplier ?? 0) >0)) ? selectedType?.extraDiscountFare ?? 0 : selectedType?.discountFare ?? 0;
      discountAmount = (((selectedType?.extraFareFee ?? 0) > 0) || ((selectedType?.surgeMultiplier ?? 0) >0)) ? selectedType?.extraDiscountAmount ?? 0 : selectedType?.discountAmount ?? 0;
      Get.find<MapController>().getPolyline();
    }

    update();
  }

  void resetControllerValue(){
    currentRideState = RideState.initial;
    rideCategoryIndex = 0;
    update();
  }

  void clearRideDetails(){
    tripDetails = null;
    rideDetails = null;
    update();
  }

  /// Puts a live trip back after another trip's details were shown in its place.
  void restoreTripDetails(TripDetails trip) {
    tripDetails = trip;
    update();
    // The 10 s timer stopped when the other trip emptied tripDetails while loading.
    getRideDetails(trip.id!).then((_) => startLocationRecord());
  }

  @override
  onInit(){
    if(tripDetails != null && Get.find<AuthController>().getUserToken() != ''){
      startLocationRecord();
    }else{
      stopLocationRecord();
    }
    super.onInit();
  }


  Future<Response> getEstimatedFare(bool parcel) async {
    loading = true;
    isEstimate = true;
    update();
    parcelEstimatedFare = null;
    LocationController locController = Get.find<LocationController>();
    ParcelController parcelController = Get.find<ParcelController>();
    Address fromPosition = parcel ? locController.parcelSenderAddress! : locController.fromAddress!;
    Address toPosition = parcel ? locController.parcelReceiverAddress! : locController.toAddress!;
    DateTime scheduleDate = RideControllerHelper.dateFormatToShow(scheduleTripDate);
    DateTime scheduleTime = RideControllerHelper.timeFormatToShow(scheduleTripTime);

    DateTime scheduledTime = DateTime(scheduleDate.year,scheduleDate.month,scheduleDate.day,scheduleTime.hour,scheduleTime.minute,scheduleTime.second);

    Response? response = await rideServiceInterface.getEstimatedFare(
      pickupLatLng: LatLng(fromPosition.latitude!, fromPosition.longitude!),
      destinationLatLng: LatLng(toPosition.latitude!, toPosition.longitude!),
      currentLatLng: LatLng(locController.initialPosition.latitude, locController.initialPosition.longitude),
      type: parcel ? 'parcel' : 'ride_request',
      rideRequestType: parcel ? null : _rideType == RideType.regularRide ? 'regular' : 'scheduled',
      pickupAddress : parcel ? parcelController.senderAddressController.text
          : locController.fromAddress!.address.toString(),
      destinationAddress: parcel ? parcelController.receiverAddressController.text
          : locController.toAddress!.address!,
      extraOne: locController.extraOneRoute,
      extraTwo: locController.extraTwoRoute,
      extraOneLatLng: locController.extraRouteAddress != null ? LatLng(
        locController.extraRouteAddress!.latitude!, locController.extraRouteAddress!.longitude!,
      ) : null,
      extraTwoLatLng: locController.extraRouteTwoAddress != null ? LatLng(
        locController.extraRouteTwoAddress!.latitude!, locController.extraRouteTwoAddress!.longitude!,
      ) : null,
      parcelWeight: Get.find<ParcelController>().parcelWeightController.text,
      parcelCategoryId: parcel ? parcelController.parcelCategoryList![parcelController.selectedParcelCategory].id : '',
      scheduledAt: _rideType == RideType.scheduleRide ? scheduledTime.toString() : '',
      extra: (isMove && !parcel) ? {'service': 'move'} : (isHealthRide && !parcel) ? {'health_ride': 1} : null,
    );

    if(response!.statusCode == 200) {
      loading = false;
      isEstimate = false;

      if(parcel) {
        parcelEstimatedFare = ParcelEstimatedFare.fromJson(response.body);
        encodedPolyLine = ParcelEstimatedFare.fromJson(response.body).data!.encodedPolyline!;
        parcelFare = ParcelEstimatedFare.fromJson(response.body).data!.estimatedFare!.toString();
      }else{
        fareList = [];
        fareList.addAll(EstimatedFareModel.fromJson(response.body).data!);
        setRideCategoryIndex(rideCategoryIndex != 0 ?  rideCategoryIndex : 0);
        if(fareList[rideCategoryIndex].polyline == null){
          showCustomSnackBar('road_not_found'.tr,isError: true);
        }

      }
    }else{
      loading = false;
      isEstimate = false;
      if (!parcel && isIncompleteRide(response)) {
        openExistingRide();
      } else {
        ApiChecker.checkApi(response);
        if(response.statusCode == 403 && !parcel) {
          tripDetails = null;
          rideDetails = null;
        }
      }
    }

    update();
    return response;
  }

  Future<Response> submitRideRequest(String note, bool parcel, {String categoryId = '', List<String>? movePhotos}) async {
    // A second tap while the first booking is on its way: ignored (callers act on 200 only).
    if (isSubmit) return const Response(statusCode: 429, statusText: 'already_sending');
    final bool move = isMove && !parcel;
    final bool health = isHealthRide && !parcel && !move && tripDetails == null;
    initCountingTimeStates();
    isSubmit = true;
    update();

    LocationController locController = Get.find<LocationController>();
    Address pickUpPosition = parcel ? locController.parcelSenderAddress! : tripDetails == null ? locController.fromAddress! : Address();
    Address destinationPosition = parcel ? locController.parcelReceiverAddress! : tripDetails == null ? locController.toAddress! : Address();

    DateTime scheduleDate = RideControllerHelper.dateFormatToShow(scheduleTripDate);
    DateTime scheduleTime = RideControllerHelper.timeFormatToShow(scheduleTripTime);

    DateTime scheduledTime = DateTime(scheduleDate.year,scheduleDate.month,scheduleDate.day,scheduleTime.hour,scheduleTime.minute,scheduleTime.second);

    Response response = await rideServiceInterface.submitRideRequest(
      pickupLat: pickUpPosition.latitude.toString(),
      pickupLng: pickUpPosition.longitude.toString(),
      destinationLat: destinationPosition.latitude.toString(),
      destinationLng: destinationPosition.longitude.toString(),
      customerCurrentLat: locController.initialPosition.latitude.toString(),
      customerCurrentLng: locController.initialPosition.longitude.toString(), type: parcel ? 'parcel' : 'ride_request',
        rideRequestType: parcel ? null : _rideType == RideType.regularRide ? 'regular' : 'scheduled',
      pickupAddress: parcel ? Get.find<ParcelController>().senderAddressController.text
          : tripDetails == null ? locController.fromAddress!.address.toString() : tripDetails!.pickupAddress!,
      destinationAddress: parcel ? Get.find<ParcelController>().receiverAddressController.text
          : locController.toAddress?.address ?? tripDetails!.destinationAddress! ,
      vehicleCategoryId: parcel ? categoryId : selectedCategoryId,
      estimatedDistance: parcel ? parcelEstimatedFare!.data!.estimatedDistance!.toString() : estimatedDistance,
      estimatedTime: parcel ? parcelEstimatedFare!.data!.estimatedDuration!.replaceFirst('min', '') : estimatedDuration,
      estimatedFare: parcel ? parcelFare : estimatedFare.toString(),
      actualFare: parcel ? parcelFare : estimatedFare != actualFare ? actualFare.toString() : estimatedFare.toString(),
      bid:(parcel || move || health) ? false : estimatedFare != actualFare,
      note: note,
      // A move is paid to the driver in person; nothing is charged in the app.
      paymentMethod: move ? 'cash' : Get.find<PaymentController>().offeredPaymentType,
      encodedPolyline: parcel ? encodedPolyLine : fareList.isNotEmpty ? fareList[rideCategoryIndex].polyline! : '',
      middleAddress: [locController.extraRouteAddress?.address ?? '', locController.extraRouteTwoAddress?.address ?? ''],
      entrance: locController.entranceController.text.toString(),
      extraOne: locController.extraOneRoute,
      extraTwo: locController.extraTwoRoute,
      extraLatOne: locController.extraRouteAddress != null ? locController.extraRouteAddress!.latitude.toString() : '',
      extraLngOne: locController.extraRouteAddress != null ? locController.extraRouteAddress!.longitude.toString() : '',
      extraLatTwo: locController.extraRouteTwoAddress != null ? locController.extraRouteTwoAddress!.latitude.toString() : '',
      extraLngTwo: locController.extraRouteTwoAddress != null ? locController.extraRouteTwoAddress!.longitude.toString() : '',
      areaId: parcel ? '' : fareList.isNotEmpty ? fareList[rideCategoryIndex].areaId ?? '' : '',
      senderName: Get.find<ParcelController>().senderNameController.text,
      senderPhone: Get.find<ParcelController>().getSenderContactNumber,
      senderAddress: Get.find<ParcelController>().senderAddressController.text,
      receiverName: Get.find<ParcelController>().receiverNameController.text,
      receiverPhone: Get.find<ParcelController>().getReceiverContactNumber,
      receiverAddress: Get.find<ParcelController>().receiverAddressController.text,
      parcelCategoryId: parcel ? Get.find<ParcelController>().parcelCategoryList![Get.find<ParcelController>().selectedParcelCategory].id : '',
      payer: Get.find<ParcelController>().payReceiver?'receiver':"sender",
      weight: Get.find<ParcelController>().parcelWeightController.text,
      tripRequestId: parcel ? null : tripDetails?.id,
      returnFee: parcel ? parcelEstimatedFare?.data?.returnFee : 0,
      cancellationFee: parcel ? parcelEstimatedFare?.data?.cancellationFee : 0,
      extraEstimatedFare: parcel ? (parcelEstimatedFare?.data?.extraEstimatedFare ?? 0) : (selectedType?.extraEstimatedFare ?? 0),
      extraDiscountFare: parcel ? (parcelEstimatedFare?.data?.extraDiscountFare ?? 0) : (selectedType?.extraDiscountFare ?? 0),
      extraDiscountAmount: parcel ? (parcelEstimatedFare?.data?.extraDiscountAmount ?? 0) : (selectedType?.extraDiscountAmount ?? 0),
      extraReturnFee: parcel ? (parcelEstimatedFare?.data?.extraReturnFee ?? 0) : (selectedType?.extraReturnFee ?? 0),
      extraCancellationFee: parcel ? (parcelEstimatedFare?.data?.extraCancellationFee ?? 0) : (selectedType?.extraCancellationFee ?? 0),
      extraFareAmount: parcel ? (parcelEstimatedFare?.data?.extraFareAmount ?? 0) : (selectedType?.extraFareAmount ?? 0),
      extraFareFee: parcel ? (parcelEstimatedFare?.data?.extraFareFee ?? 0) : (selectedType?.extraFareFee ?? 0),
      zoneId: parcel ? parcelEstimatedFare?.data?.zoneId ?? '' : selectedType?.zoneId ,
      scheduledAt: _rideType == RideType.scheduleRide ? scheduledTime.toString() : '',
      surgeMultiplier: parcel ? parcelEstimatedFare?.data?.surgeMultiplier : selectedType?.surgeMultiplier,
      pickupNote: _pickupNote,
      isFemaleDriverRequired : parcel ? null : isFemaleDriverSelected,
      extra: {
        if (move) 'move_photos': jsonEncode(movePhotos ?? const []),
        if (health) 'health_ride': 1,
        // The customer's voice note for the driver.
        if (voiceNote != null && (parcel || tripDetails == null)) 'voice_note': voiceNote!.name,
      },
    );

    if(response.statusCode == 200 && response.body['data'] != null) {
      biddingList = [];
      tripDetails = TripDetailsModel.fromJson(response.body).data!;
      tripDetails!.id = response.body['data']['id'];
      if (parcel && Get.isRegistered<MarketChatController>()) {
        // A delivery booked from an E-Ride Market chat is posted back into that chat.
        Get.find<MarketChatController>().onParcelBooked('${tripDetails!.id}', destinationPosition.latitude, destinationPosition.longitude);
      }
      if (parcel) Get.find<ParcelController>().lockedPayReceiver = null;
      encodedPolyLine = tripDetails!.encodedPolyline ?? ''; // a trip can have no route line
      if(encodedPolyLine != '' && encodedPolyLine.isNotEmpty) {

      //  Get.find<MapController>().getPolyline();

      }
      Get.find<ParcelController>().receiverNameController.clear();
      Get.find<ParcelController>().receiverContactController.clear();
      Get.find<ParcelController>().receiverAddressController.clear();
      Get.find<ParcelController>().onChangeReceiverCountryCode(null);
      Get.find<ParcelController>().onChangeSenderCountryCode(null);
      Get.find<ParcelController>().parcelWeightController.clear();
      PusherHelper().pusherDriverStatus(response.body['data']['id']);
      isSubmit = false;
      noteController.clear();
      pickupNoteController.clear();
      _pickupNote = '';
      voiceNote = null;
      pickupHelpAsked = false;
    }else{
      isSubmit = false;
      if (!parcel && isIncompleteRide(response)) {
        openExistingRide();
      } else {
        ApiChecker.checkApi(response);
        if(response.statusCode == 403) {
          tripDetails = null;
          rideDetails = null;
        }
      }
    }
    actualFare = 0;
    isLoading = false;
    update();

    return response;
  }

  void clearExtraRoute(){
    Get.find<LocationController>().extraOneRoute = false;
    Get.find<LocationController>().extraTwoRoute = false;
    Get.find<LocationController>().extraRouteAddress = null;
    Get.find<LocationController>().extraRouteTwoAddress = null;
  }

  Future<Response> getRideDetails(String tripId,{bool isUpdate = true}) async {
    isLoading = true;
    // A refresh of the same trip keeps it while it loads, and if the load fails
    // (timeout, 429): clearing it stopped the location timer and blanked the trip.
    if (tripDetails?.id != tripId) tripDetails = null;
    _thumbnailPaths = null;
    if(isUpdate){
      update();
    }

    Response response = await rideServiceInterface.getRideDetails(tripId);
    if (response.statusCode == 200) {
      Get.find<MapController>().notifyMapController();
      tripDetails = TripDetailsModel.fromJson(response.body).data!;
      // Keep the trip chat live (and its unread badge) while a driver is assigned.
      Get.find<ChatInboxController>().syncTrip(tripDetails!.id, tripDetails!.currentStatus);
      estimatedDistance = tripDetails!.estimatedDistance!.toString();
      isLoading = false;

      encodedPolyLine = tripDetails!.encodedPolyline ?? ''; // a trip can have no route line
      List<Attachments> attachments = tripDetails?.parcelRefund?.attachments ?? [];
      _thumbnailPaths = List.filled(attachments.length, '');

      if(tripDetails?.parcelRefund?.attachments != null){
       Future.forEach(tripDetails!.parcelRefund!.attachments!, (element) async{
        if(element.file!.contains('.mp4')){
          String? path = await Get.find<RefundRequestController>().generateThumbnail(element.file!);
          _thumbnailPaths?[tripDetails!.parcelRefund!.attachments!.indexOf(element)] =  path ?? '';

          update();
        }
      });
      }

    }
    update();
    return response;
  }

  bool runningTrip = false;

  /// The server's "Please complete previous ride first".
  static bool isIncompleteRide(Response response) =>
      response.statusCode == 403 && response.body is Map && response.body['response_code'] == 'incomplete_ride_403';

  bool _openingExisting = false;

  /// The customer already has a ride going (booked twice, or the app lost the
  /// screen): open that ride where it stands instead of showing an error.
  Future<void> openExistingRide() async {
    if (_openingExisting) return;
    _openingExisting = true;
    try {
      await getCurrentRegularRide();
      final String? id = rideDetails?.id;
      if (id == null) {
        showCustomSnackBar('please_complete_previous_ride_first'.tr);
        return;
      }
      showCustomSnackBar('you_already_have_a_ride'.tr, isError: false);
      final String? status = rideDetails!.currentStatus;
      if (status == AppConstants.pending || status == AppConstants.accepted || status == AppConstants.outForPickup) {
        await getRideDetails(id, isUpdate: false);
        PusherHelper().pusherDriverStatus(id);
        if (status == AppConstants.pending) {
          Get.find<AuthController>().saveFindingRideCreatedTime();
          updateRideCurrentState(RideState.findingRider);
        } else {
          updateRideCurrentState(RideState.outForPickup);
        }
        Get.offAll(() => const MapScreen(fromScreen: MapScreenType.splash));
      } else {
        // On the trip, or finished and not paid yet: the usual routing.
        NotificationHelper.notificationToRouteNavigate(id, false);
      }
    } finally {
      _openingExisting = false;
    }
  }

  Future<Response> getCurrentRegularRide() async {
    Response response = await rideServiceInterface.getCurrentRegularRide();
    if (response.statusCode == 200 && response.body['data'] != null) {
      rideDetails = TripDetailsModel.fromJson(response.body).data!;
      estimatedDistance = rideDetails!.estimatedDistance!.toString();
      encodedPolyLine = rideDetails!.encodedPolyline ?? '';
    }else if(response.statusCode == 403){
      rideDetails = null;
    }
    update();
    return response;
  }

  Future<Response> remainingDistance(String requestID,{bool mapBound = false}) async {
    isLoading = true;

    Response response = await rideServiceInterface.remainDistance(requestID);
    // No road route: nothing to draw or measure this time (the next check comes in a few seconds).
    if (response.statusCode == 200 && response.body is List && (response.body as List).isNotEmpty) {
      Get.find<MapController>().getDriverToPickupOrDestinationPolyline(response.body[0]["encoded_polyline"],mapBound: mapBound);
      remainingDistanceModel = [];
      for(var distance in response.body) {
        remainingDistanceModel.add(RemainingDistanceModel.fromJson(distance));
      }

      if(Get.find<MapController>().isInside && tripDetails != null && currentRideState == RideState.outForPickup) {
        currentRideState = RideState.otpSent;
      }
      if(Get.find<MapController>().isInside && Get.find<ParcelController>().currentParcelState == ParcelDeliveryState.acceptRider){
        Get.find<ParcelController>().updateParcelState(ParcelDeliveryState.otpSent);
      }

      if(tripDetails != null && remainingDistanceModel.isNotEmpty) {
        LiveTripNotificationHelper.showOrUpdate(trip: tripDetails!, distance: remainingDistanceModel[0]);
      }
      _announceArrivalStage();

      isLoading = false;
    }else{
      isLoading = false;
    }
    update();
    return response;
  }

  Future<Response> getBiddingList(String tripId, int offset) async {
    isLoading = true;

    Response response = await rideServiceInterface.biddingList(tripId, offset);
    if (response.statusCode == 200) {
      biddingList = [];
      biddingList.addAll(BiddingModel.fromJson(response.body).data!);
      isLoading = false;
    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    update();
    return response;
  }

  Future<Response> ignoreBidding(String bidId,String tripId) async {
    isLoading = true;
    update();
    Response response = await rideServiceInterface.ignoreBidding(bidId);
    if (response.statusCode == 200) {
     getBiddingList(tripId, 1).then((value){
       if(biddingList.isEmpty){
         Get.back();
       }
     });
      isLoading = false;
    }else{
      getBiddingList(tripId, 1).then((value){
        if(biddingList.isEmpty){
          Get.back();
          Future.delayed(const Duration(milliseconds: 300)).then((value){
            ApiChecker.checkApi(response);
          });
        }
      });
      isLoading = false;
    }
    update();
    return response;
  }

  Future<Response> getNearestDriverList(String  lat, String lng) async {
    Response response = await rideServiceInterface.nearestDriverList(lat, lng);
    if (response.statusCode == 200) {
      nearestDriverList = [];
      nearestDriverList.addAll(NearestDriverModel.fromJson(response.body).data!);
      Get.find<MapController>().searchDeliveryMen();
    }else{
      ApiChecker.checkApi(response);
    }
    update();
    return response;
  }

  Timer? _timer;
  TripArrivalStage _arrivalStage = TripArrivalStage.enRoute;
  String? _arrivalTripId;
  AudioPlayer? _arrivalPlayer;

  /// A buzz and a soft sound when the trip becomes "almost there" and again
  /// at "arrived", once each per trip.
  void _announceArrivalStage() {
    if (tripDetails?.currentStatus != AppConstants.ongoing || remainingDistanceModel.isEmpty) return;
    if (_arrivalTripId != tripDetails!.id) {
      _arrivalTripId = tripDetails!.id;
      _arrivalStage = TripArrivalStage.enRoute;
    }
    final TripArrivalStage stage = TripArrivalCard.stageFor(remainingDistanceModel[0].distance);
    if (stage.index > _arrivalStage.index) {
      HapticFeedback.heavyImpact();
      try {
        (_arrivalPlayer ??= AudioPlayer()).play(AssetSource('sound/chat_pop.wav'));
      } catch (_) {}
      _arrivalStage = stage;
    }
  }

  /// The trip the 10 s timer follows. Another trip opened from the activity list
  /// borrows tripDetails for a while: the timer waits instead of polling that one.
  String? _recordTripId;
  int _recordTick = 0;

  void startLocationRecord() {
    ///For First time call next call every 10 seconds.......
    if(Get.find<RideController>().tripDetails != null && Get.find<AuthController>().getUserToken() != ''){
      Get.find<RideController>().remainingDistance(Get.find<RideController>().tripDetails!.id!,mapBound: true);
    }else{
      _timer?.cancel();
    }
    _recordTripId = tripDetails?.id;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if(Get.find<RideController>().tripDetails != null && Get.find<AuthController>().getUserToken() != '' ){
        if (tripDetails?.id != _recordTripId) return;
        // In the background only every 30 s: enough for the trip notification.
        _recordTick++;
        if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed && _recordTick % 3 != 0) return;
        if(Get.find<RideController>().tripDetails?.type == AppConstants.parcel && (Get.find<RideController>().tripDetails?.currentStatus == AppConstants.accepted || Get.find<RideController>().tripDetails?.currentStatus == AppConstants.ongoing)){
          Get.find<RideController>().remainingDistance(Get.find<RideController>().tripDetails!.id!);

        // Any ride, scheduled ones too (their type is scheduled_request): the driver's
        // position and arrival time on the map came only for regular rides.
        }else if(Get.find<RideController>().tripDetails?.type != AppConstants.parcel && (Get.find<RideController>().tripDetails?.currentStatus == AppConstants.outForPickup || Get.find<RideController>().tripDetails?.currentStatus == AppConstants.ongoing)){
          Get.find<RideController>().remainingDistance(Get.find<RideController>().tripDetails!.id!);

        }
      }else{
        _timer?.cancel();
      }

    });
  }

  void stopLocationRecord() {
    _timer?.cancel();
  }

  Future<Response> tripAcceptOrRejected(String tripId, String type, String driverId) async {
    isLoading = true;
    update();
    Response response = await rideServiceInterface.tripAcceptOrReject(tripId, type, driverId);
    if (response.statusCode == 200) {
      biddingList = [];
      showCustomSnackBar('trip_is_accepted'.tr, isError: false);
      Get.back();
      getRideDetails(tripId).then((value) {
        if(value.statusCode == 200){
          remainingDistance(tripDetails!.id!,mapBound: true);
          updateRideCurrentState(RideState.otpSent);
          Get.find<MapController>().notifyMapController();
          Get.offAll(()=> const MapScreen(fromScreen: MapScreenType.ride));
        }
      });
      isLoading = false;
    }else{
      getBiddingList(tripId, 1).then((value){
        if(biddingList.isEmpty){
          Get.back();
          Future.delayed(const Duration(milliseconds: 300)).then((value){
            ApiChecker.checkApi(response);
          });
        }
      });
      isLoading = false;
    }
    update();
    return response;
  }

  void clearBiddingList(){
    biddingList = [];
    update();
  }

  void toggleIdentityMismatchView(bool isShow){
    showIdentityMismatchOptions = isShow;
    identityMismatchReasons = [];
    update();
  }

  void toggleShowDriverNearByTooltip(bool action){
    isShowDriverArrivalTooltip = action;
    update();
  }

  void toggleShowDriverVerificationTooltip(bool action){
    isShowDriverVerificationTooltip = action;
    update();
  }

  void toggleIdentityMismatchReason(String reason){
    if(identityMismatchReasons.contains(reason)){
      identityMismatchReasons.remove(reason);
    }else{
      identityMismatchReasons.add(reason);
    }
    update();
  }

  Future<void> submitIdentityMismatchAndCancelTrip() async {
    Response response = await tripStatusUpdate(
      tripDetails!.id!, 'cancelled', 'ride_request_cancelled_successfully',
      '', identityMismatchReason: identityMismatchReasons
    );
    if(response.statusCode == 200){
      showIdentityMismatchOptions = false;
      identityMismatchReasons = [];
      Get.back();
      Get.find<BottomMenuController>().navigateToDashboard();
    }
  }

  Future<Response> tripStatusUpdate(String tripId, String status, String message, String cancellationCause, {List<String>? identityMismatchReason,  bool afterAccept = false}) async {
    isLoading = true;
    update();
    Response response = await rideServiceInterface.tripStatusUpdate(tripId, status, cancellationCause, identityMismatchReason: identityMismatchReason);
    if (response.statusCode == 200) {
      Get.find<TripController>().othersCancellationController.clear();
      Get.find<SafetyAlertController>().cancelDriverNeedSafetyStream();
      if(status == AppConstants.cancelled && !afterAccept){
        tripDetails = null;
      }
      showCustomSnackBar(message.tr, isError: false);
      isLoading = false;
    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    update();
    return response;
  }

  Future<Response> getFinalFare(String tripId) async {
    isLoading = true;
    update();
    Response response = await rideServiceInterface.getFinalFare(tripId);
    if (response.statusCode == 200 ) {
      if(response.body['data'] != null){
        finalFare = FinalFareModel.fromJson(response.body).data!;
      }
    }else{
      ApiChecker.checkApi(response);
    }
    isLoading = false;
    update();
    return response;
  }

  double? firstCount = 0;
  double? secondCount = 0;
  double? thirdCount = 0;
  int stateCount = 0;
  Timer? _findingStateAnimation;

  void countingTimeStates() async{
    _findingStateAnimation?.cancel();
    if(stateCount == 0){
      await Future.delayed(const Duration(seconds: 1)).then((value){
        firstCount = null;
        secondCount = 0;
        thirdCount = 0;
        update();
      });

      _findingStateAnimation = Timer.periodic(const Duration(minutes: 1), (time){
        firstCount = 1;
        stateCount = 1;
        countingTimeStates();
      });
    }

    if(stateCount == 1){
      await Future.delayed(const Duration(milliseconds: 100)).then((value){
        firstCount = 1;
        secondCount = null;
        thirdCount = 0;
        update();
      });

      _findingStateAnimation = Timer.periodic(const Duration(minutes: 1), (time){
        secondCount = 1;
        stateCount = 2;
        countingTimeStates();
      });
    }

    if(stateCount == 2){
      await  Future.delayed(const Duration(milliseconds: 100)).then((value){
        firstCount = 1;
        secondCount = 1;
        thirdCount = null;
        update();
      });

      _findingStateAnimation = Timer.periodic(const Duration(minutes: 3), (time){
        thirdCount = 1;
        stateCount = 3;
        update();
        _findingStateAnimation?.cancel();
      });
    }

    if(stateCount == 3){
      update();
    }

  }

  void initCountingTimeStates({bool isRestart = false}){
    if(isRestart){
      if(stateCount == 3){
        firstCount = 0;
        secondCount = 0;
        thirdCount = 0;
        stateCount = 0;
      }
      countingTimeStates();
    }else{
      firstCount = 0;
      secondCount = 0;
      thirdCount = 0;
      stateCount = 0;
    }
  }

  void resumeCountingTimeState(int duration){
     if(duration < 60){
       secondCount =0;
       thirdCount = 0;
       stateCount = 0;

     }else if(duration >60 && duration < 120){
       firstCount =1;
       thirdCount = 0;
       stateCount = 1;
     }else if (duration >120 && duration < 300){
       firstCount =1;
       secondCount = 1;
       stateCount = 2;

     }else{
       firstCount =1;
       secondCount = 1;
       thirdCount =1;
       stateCount = 3;
     }
     countingTimeStates();
  }

  Future<Response> parcelReturned(String tripId) async {
    isLoading = true;
    update();
    Response response = await rideServiceInterface.parcelReceived(tripId);
    if (response.statusCode == 200) {
      getRideDetails(tripId);
      Get.find<ParcelController>().getRunningParcelList();
    }else {
      ApiChecker.checkApi(response);
    }
    isLoading = false;
    update();
    return response;
  }

  void showSafetyAlertTooltip(){
    justTheController.showTooltip();
  }

  void setRideType(RideType rideType, {bool isUpdate = false}){
    _rideType = rideType;
    if(isUpdate){
      update();
    }
  }

  void setScheduleTripDate(String date){
    scheduleTripDate = date;
  }

  void setScheduleTripTime(DateTime time){
    scheduleTripTime = time;
  }

  Future<Response> updateScheduleTripTimeDate(String? tripId) async {
    isLoading = true;
    update();
    DateTime scheduleDate = RideControllerHelper.dateFormatToShow(scheduleTripDate);
    DateTime scheduleTime = RideControllerHelper.timeFormatToShow(scheduleTripTime);

    DateTime scheduledTime = DateTime(scheduleDate.year,scheduleDate.month,scheduleDate.day,scheduleTime.hour,scheduleTime.minute,scheduleTime.second);

    Response response = await rideServiceInterface.updateScheduleTripTimeDate(tripId, '$scheduledTime');
    if (response.statusCode == 200) {
      tripDetails = TripDetailsModel.fromJson(response.body).data!;
      isLoading = false;
    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    update();
    return response;
  }

  Future<void> getRunningRideList() async{
    isLoading = true;
    Response response = await rideServiceInterface.getRunningRideList();
    if(response.statusCode == 200 ){
      isLoading = false;
      if(response.body['data'] != null){
        runningRideList = RideListModel.fromJson(response.body);
        // Home knows the running trip from this list without loading its
        // details, so the trip chat (and its unread badge) starts here too.
        for (final TripDetails trip in runningRideList?.data ?? const <TripDetails>[]) {
          Get.find<ChatInboxController>().syncTrip(trip.id, trip.currentStatus);
        }
      }
    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    isLoading = false;
    update();
  }

  void setPickupNote() {
    _pickupNote = pickupNoteController.text.trim();
    update();
  }

  void clearPickupNote() {
    _pickupNote = '';
    pickupNoteController.clear();
    update();
  }

  void toggleInitialWidgetExpansion(){
    isInitialWidgetRoutesExpand = !isInitialWidgetRoutesExpand;
    update();
  }

  void toggleFemaleDriverSelection(bool value){
    isFemaleDriverSelected = value;
    update();
  }

}

class ThumbnailPathModel{
  final String? path;

  ThumbnailPathModel(this.path);
}