import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing_user_app/common_widgets/expandable_bottom_sheet.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/parcel/domain/models/parcel_category_model.dart';
import 'package:ride_sharing_user_app/features/parcel/domain/models/parcel_list_model.dart';
import 'package:ride_sharing_user_app/features/parcel/domain/models/suggested_vehicle_category_model.dart';
import 'package:ride_sharing_user_app/features/parcel/domain/services/parcel_service_interface.dart';
import 'package:ride_sharing_user_app/features/payment/controllers/payment_controller.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/helper/country_code_helper.dart';

/// A parcel booking opened from somewhere else with its details filled in
/// (E-Ride Market: the seller sends an item to the buyer's delivery point).
class ParcelPrefill {
  final Address? sender;
  final Address receiver;
  final String receiverName;
  final String? receiverPhone;
  /// true: the receiver pays the rest of the fare; false: the sender; null: the sender chooses.
  final bool? payReceiver;
  const ParcelPrefill({this.sender, required this.receiver, required this.receiverName, this.receiverPhone, this.payReceiver});
}

enum ParcelDeliveryState{initial, parcelInfoDetails, addOtherParcelDetails, riseFare, findingRider, suggestVehicle, acceptRider, otpSent, parcelOngoing, parcelComplete}

class ParcelController extends GetxController with GetSingleTickerProviderStateMixin implements GetxService {
  final ParcelServiceInterface parcelServiceInterface;
  ParcelController({required this.parcelServiceInterface});

  ParcelDeliveryState currentParcelState = ParcelDeliveryState.initial;
  late TabController tabController = TabController(length: 2, vsync: this);
  bool isLoading = false;
  bool parcelDetailsAvailable = false;
  int selectedParcelCategory = 0;
  bool payReceiver = false;
  SuggestedVehicleCategoryModel? suggestedVehicleCategoryModel;
  List<SuggestedCategory>? suggestedCategoryList;
  List<ParcelCategory>? parcelCategoryList;
  bool getSuggested = false;

  TextEditingController senderContactController = TextEditingController();
  TextEditingController senderNameController = TextEditingController();
  TextEditingController senderAddressController = TextEditingController();

  TextEditingController receiverContactController = TextEditingController();
  TextEditingController receiverNameController = TextEditingController();
  TextEditingController receiverAddressController = TextEditingController();

  TextEditingController parcelDimensionController = TextEditingController();
  TextEditingController parcelWeightController = TextEditingController();
  TextEditingController parcelTypeController = TextEditingController();

  FocusNode senderContactNode = FocusNode();
  FocusNode senderNameNode = FocusNode();
  FocusNode senderAddressNode = FocusNode();

  FocusNode receiverContactNode = FocusNode();
  FocusNode receiverNameNode = FocusNode();
  FocusNode receiverAddressNode = FocusNode();

  FocusNode parcelDimensionNode = FocusNode();
  FocusNode parcelWeightNode = FocusNode();

  String? _senderCountryDialCode;
  String? _receiverCountryDialCode;

  String? get getSenderCountryCode => _senderCountryDialCode;
  String? get getReceiverCountryDialCode => _receiverCountryDialCode;

  String? get getSenderContactNumber => '$_senderCountryDialCode${senderContactController.text}';
  String? get getReceiverContactNumber => '$_receiverCountryDialCode${receiverContactController.text}';

  void onChangeSenderCountryCode(String? code, {bool isUpdate = true}) {
    _senderCountryDialCode = code;

    if(isUpdate) {
      update();
    }
  }
  void onChangeReceiverCountryCode(String? code) {
    _receiverCountryDialCode = code;
    update();
  }


  /// Set when the seller books an E-Ride Market delivery and the admin decided who
  /// pays the rest of the fare (true: the buyer on delivery, false: the seller).
  /// Null lets the sender choose, as for any parcel.
  bool? lockedPayReceiver;

  /// The buyer's first name, for the "E-Ride Market delivery" note on the parcel screen.
  String? marketBuyerName;

  void initParcelData() {
    payReceiver = false;
    lockedPayReceiver = null;
    marketBuyerName = null;
    currentParcelState = ParcelDeliveryState.initial;
    tabController.index = 0;
    isLoading = false;
    parcelDetailsAvailable = false;
    getSuggested = false;
    selectedParcelCategory = 0;
    senderAddressController.text = '';
    senderContactController.text = '';
    senderNameController.text = '';
    receiverAddressController.text = '';
    receiverContactController.text = '';
    receiverNameController.text = '';
  }

  void updateParcelCategoryIndex(int newIndex) {
    selectedParcelCategory = newIndex;
    parcelTypeController.text = parcelCategoryList![selectedParcelCategory].name!;
    update();
  }

  void updateTabControllerIndex(int newIndex){
    tabController.index = newIndex;
    final locationController = Get.find<LocationController>();
    final mapController = Get.find<MapController>();
    if (newIndex == 0) {
      final sender = locationController.parcelSenderAddress;
      if (sender?.latitude != null && sender?.longitude != null) {
        mapController.showParcelAddressMarker(
          LatLng(sender!.latitude!, sender.longitude!),
          isSender: true,
        );
      } else {
        mapController.clearParcelAddressMarkers();
      }
    } else {
      final receiver = locationController.parcelReceiverAddress;
      if (receiver?.latitude != null && receiver?.longitude != null) {
        mapController.showParcelAddressMarker(
          LatLng(receiver!.latitude!, receiver.longitude!),
          isSender: false,
        );
      } else {
        mapController.clearParcelAddressMarkers();
      }
    }
    update();
  }

  void updateParcelDetailsStatus() {
    if(parcelWeightController.text.isNotEmpty && parcelDimensionController.text.isNotEmpty) {
      parcelDetailsAvailable = true;
    }else {
      parcelDetailsAvailable = false;
    }
    update();
  }

  void updateParcelState(ParcelDeliveryState newState) {
    currentParcelState = newState;
    update();
  }

  /// Fills the booking from [prefill], after [initParcelData] cleared it.
  void applyPrefill(ParcelPrefill prefill) {
    final location = Get.find<LocationController>();
    if (prefill.sender?.latitude != null) location.setSenderAddress(prefill.sender);
    location.setReceiverAddress(prefill.receiver);
    receiverNameController.text = prefill.receiverName;
    final String phone = prefill.receiverPhone ?? '';
    final String? code = phone.isEmpty ? null : CountryCodeHelper.getCountryCode(phone);
    _receiverCountryDialCode = code ?? '+237';
    receiverContactController.text = code == null ? phone : phone.replaceFirst(code, '');
    marketBuyerName = prefill.receiverName;
    lockedPayReceiver = prefill.payReceiver;
    updatePaymentPerson(prefill.payReceiver ?? true);
  }

  void updatePaymentPerson(bool newValue, {bool notify = true}) {
    payReceiver = lockedPayReceiver ?? newValue;
    // The receiver pays on delivery, in cash: with cash turned off, the sender pays in the app.
    if (!(Get.find<ConfigController>().config?.paymentCashStatus ?? true)) payReceiver = false;
    if(payReceiver == true){
      Get.find<PaymentController>().selectPaymentType('cash');
    }
    if(notify){
      update();
    }

  }


  String parcelPrice = '0';

  Future<void> getParcelCategoryList({bool notify= true}) async {
    isLoading = true;
    Response response = await parcelServiceInterface.getParcelCategory();
    if(response.statusCode == 200 && response.body['data'] != null){
      parcelCategoryList = [];
      isLoading = false;
      parcelCategoryList!.addAll(ParcelCategoryModel.fromJson(response.body).data!);
      if(parcelCategoryList!.isNotEmpty) {
        parcelTypeController.text = parcelCategoryList!.first.name!;
      }
    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    isLoading = false;
    if(notify){
      update();
    }
  }

  Future<Response> getSuggestedCategoryList() async {
    getSuggested = true;
    update();
    Response response = await parcelServiceInterface.getSuggestedVehicleCategory(parcelWeightController.text);
    if(response.statusCode == 200 ){
      suggestedCategoryList = [];
      isLoading = false;
      if(response.body['data'] != null){
        suggestedVehicleCategoryModel = SuggestedVehicleCategoryModel.fromJson(response.body);
        suggestedCategoryList!.addAll(SuggestedVehicleCategoryModel.fromJson(response.body).data!.data!);
      }
    }else{
      getSuggested = false;
      ApiChecker.checkApi(response);
    }
    getSuggested = false;
    update();
    return response;
  }


  ParcelListModel? parcelListModel;
  Future<Response> getRunningParcelList() async {
    isLoading = true;
    Response response = await parcelServiceInterface.getRunningParcelList(1);
    if(response.statusCode == 200 ){
      isLoading = false;
      if(response.body['data'] != null){
        parcelListModel = ParcelListModel.fromJson(response.body);
      }
    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    isLoading = false;
    update();
    return response;
  }

  void clearParcelModel(){
    parcelListModel = null;
  }

  ParcelListModel? unpaidParcelListModel;
  Future<Response> getUnpaidParcelList() async {
    isLoading = true;
    Response response = await parcelServiceInterface.getUnpaidParcelList(1);
    if(response.statusCode == 200 ){
      isLoading = false;
      if(response.body['data'] != null){
        unpaidParcelListModel = ParcelListModel.fromJson(response.body);
      }
    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    isLoading = false;
    update();
    return response;
  }


  Future<void> focusOnBottomSheet(GlobalKey<ExpandableBottomSheetState> key) async {
    // After the keyboard has opened: it adds its height to the sheet's content.
    await Future.delayed(const Duration(milliseconds: 500));
    key.currentState?.expand(duration: 200);
  }

  void setParcelLoadingActive (int index){
    parcelListModel!.data![index].isLoading = true;
    update();
  }
  void setParcelLoadingDeactive (int index){
    parcelListModel!.data![index].isLoading = false;
    update();
  }

}