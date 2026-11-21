import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/deposit/domain/models/trip_deposit_model.dart';
import 'package:ride_sharing_user_app/features/deposit/domain/services/deposit_service_interface.dart';
import 'package:ride_sharing_user_app/features/payment/controllers/payment_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/splash/domain/models/config_model.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_payment_screen.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';

/// Paying the booking deposit after a driver accepts, and reporting a driver.
/// The deposit itself lives on the trip (RideController.tripDetails.deposit),
/// so every screen that shows the trip sees the same state.
class DepositController extends GetxController implements GetxService {
  final DepositServiceInterface depositServiceInterface;
  DepositController({required this.depositServiceInterface});

  /// 'wallet' or a gateway key while a payment is in progress.
  String? payingWith;
  bool get paying => payingWith != null;

  List<ReportReason>? reasons;
  bool reporting = false;

  /// Trips whose "driver cancelled" dialog was already shown.
  final Set<String> _announced = {};

  double? get walletBalance => Get.find<ProfileController>().profileModel?.data?.wallet?.walletBalance;
  List<PaymentGateways> get gateways => Get.find<PaymentController>().paymentGateways ?? [];

  /// Wallet balance and gateways for the payment buttons.
  void prepare() {
    if (gateways.isEmpty) {
      Get.find<PaymentController>().getPaymentGetWayList();
    }
    Get.find<ProfileController>().getProfileInfo();
  }

  Future<bool> payWithWallet(String tripId) async {
    if (paying) return false;
    payingWith = 'wallet';
    update();
    final Response response = await depositServiceInterface.payWithWallet(tripId);
    payingWith = null;
    if (response.statusCode == 200) {
      _apply(tripId, response.body['data']?['deposit']);
      Get.find<ProfileController>().getProfileInfo();
      update();
      return true;
    }
    showCustomSnackBar(_firstError(response));
    update();
    await reload(tripId);
    return false;
  }

  Future<bool> payWithGateway(String tripId, String gateway) async {
    if (paying) return false;
    payingWith = gateway;
    update();
    final Response response = await depositServiceInterface.getPayUrl(tripId, gateway);
    if (response.statusCode != 200 || response.body['data']?['pay_url'] == null) {
      payingWith = null;
      showCustomSnackBar(_firstError(response));
      update();
      await reload(tripId);
      return false;
    }
    await Get.to<bool>(() => StorePaymentScreen(url: response.body['data']['pay_url'].toString()));
    // The webview's answer is a hint: the server decides. A MoMo payment can
    // land a few seconds after the customer approves it on the phone.
    TripDeposit? deposit;
    for (int i = 0; i < 6; i++) {
      deposit = await reload(tripId);
      if (deposit == null || !deposit.isAwaiting) break;
      await Future.delayed(const Duration(seconds: 2));
    }
    payingWith = null;
    update();
    if (deposit?.isAwaiting ?? false) {
      showCustomSnackBar('deposit_not_received_yet'.tr);
    }
    return deposit != null && !deposit.isAwaiting;
  }

  /// Reads the deposit again and puts it on the current trip.
  Future<TripDeposit?> reload(String tripId) async {
    final Response response = await depositServiceInterface.getDeposit(tripId);
    if (response.statusCode == 200) {
      return _apply(tripId, response.body['data']?['deposit']);
    }
    return null;
  }

  TripDeposit? _apply(String tripId, dynamic json) {
    final deposit = TripDeposit.fromJson(json);
    final rideController = Get.find<RideController>();
    if (rideController.tripDetails?.id == tripId) {
      rideController.tripDetails!.deposit = deposit;
      rideController.update();
    }
    return deposit;
  }

  /// True the first time it is asked for a trip, so a dialog shows once even
  /// when the socket and the push both arrive.
  bool firstAnnouncement(String tripId) => _announced.add(tripId);

  Future<void> loadReasons() async {
    if (reasons != null) return;
    final Response response = await depositServiceInterface.getReportReasons();
    if (response.statusCode == 200 && response.body['data'] is List) {
      reasons = (response.body['data'] as List)
          .whereType<Map>()
          .map((r) => ReportReason(r['key'].toString(), r['label'].toString()))
          .toList();
      update();
    }
  }

  Future<bool> reportDriver(String tripId, String reason, String comment) async {
    reporting = true;
    update();
    final Response response = await depositServiceInterface.reportDriver(tripId, reason, comment);
    reporting = false;
    update();
    if (response.statusCode == 200) {
      final rideController = Get.find<RideController>();
      if (rideController.tripDetails?.id == tripId) {
        rideController.tripDetails!.driverReported = true;
        rideController.update();
      }
      showCustomSnackBar('report_sent'.tr, isError: false);
      return true;
    }
    showCustomSnackBar(_firstError(response));
    return false;
  }

  String _firstError(Response response) {
    final body = response.body;
    if (body is Map) {
      final errors = body['errors'];
      if (errors is List && errors.isNotEmpty && errors.first is Map) return errors.first['message'].toString();
      if (errors is Map && errors.isNotEmpty) return (errors.values.first is List ? errors.values.first.first : errors.values.first).toString();
      if (body['message'] != null) return body['message'].toString();
    }
    return 'something_went_wrong'.tr;
  }
}
