import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/move/controllers/move_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/trip_details_model.dart';
import 'package:ride_sharing_user_app/features/trip_checkin/domain/models/trip_checkin_model.dart';
import 'package:ride_sharing_user_app/features/trip_checkin/domain/services/trip_checkin_service_interface.dart';
import 'package:ride_sharing_user_app/features/trip_checkin/widgets/trip_checkin_dialog.dart';
import 'package:ride_sharing_user_app/features/trip_share/controllers/trip_share_controller.dart';
import 'package:ride_sharing_user_app/features/trip_share/domain/models/trusted_contact_model.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

/// Trip check-ins: during a ride the server watches the car. When it stops too
/// long, leaves its route or runs far too long, E-Ride asks the rider "Is
/// everything OK?" (push, then this dialog). "I need help", or no answer in
/// time, alerts E-Ride and the rider's trusted contacts. Also night sharing:
/// one trusted contact who follows every night ride.
class TripCheckinController extends GetxController implements GetxService {
  final TripCheckinServiceInterface tripCheckinServiceInterface;
  TripCheckinController({required this.tripCheckinServiceInterface});

  static const String asked = 'asked';
  static const String ok = 'ok';
  static const String help = 'help';
  static const String noAnswer = 'no_answer';
  static const String closed = 'closed';

  TripCheckinInfo? info;
  bool answering = false;
  final Set<String> nightBusy = {};
  bool _dialogOpen = false;

  bool get enabled => info?.enabled ?? false;
  bool get isNight => info?.isNight ?? false;

  /// The switch and the night hours, without a trip (trusted contacts screen, share card).
  Future<void> loadInfo() async {
    _setInfo(await tripCheckinServiceInterface.getInfo(null));
    update();
  }

  /// Is E-Ride waiting for an answer on this trip (by default the ride in progress)? Then ask.
  Future<void> check([String? tripId]) async {
    tripId ??= _rideInProgress();
    if (tripId == null || tripId.isEmpty) return;
    _setInfo(await tripCheckinServiceInterface.getInfo(tripId));
    update();
    final TripCheckin? checkin = info?.checkin;
    if (checkin != null && checkin.status == asked && !_dialogOpen) {
      _dialogOpen = true;
      await Get.dialog(TripCheckinDialog(checkin: checkin), barrierDismissible: false);
      _dialogOpen = false;
    }
  }

  String? _rideInProgress() {
    final TripDetails? trip = Get.find<RideController>().tripDetails;
    return trip?.id != null && trip!.currentStatus == AppConstants.ongoing ? trip.id : null;
  }

  /// The status after the answer (ok, help, or no_answer / closed when it came too late), null on error.
  Future<String?> answer(TripCheckin checkin, String answer) async {
    answering = true;
    update();
    final Response response = await tripCheckinServiceInterface.answer(checkin.id, answer);
    answering = false;
    update();
    if (response.statusCode == 200 && response.body['data'] is Map) {
      return '${response.body['data']['status']}';
    }
    showCustomSnackBar(MoveController.firstError(response));
    return null;
  }

  /// After the dialog closed: say what happens now.
  void confirm(String status) {
    if (status == ok) {
      showCustomSnackBar('trip_checkin_thanks'.tr, isError: false);
    } else if (status == help || status == noAnswer) {
      showCustomSnackBar('trip_checkin_help_sent'.tr, isError: false);
    } else if (status == closed) {
      showCustomSnackBar('trip_checkin_trip_ended'.tr, isError: false);
    }
  }

  /// One contact at a time follows every night ride; switching one on switches the others off.
  Future<void> setNightShare(TrustedContact contact, bool on) async {
    nightBusy.add(contact.id);
    update();
    final Response response = await tripCheckinServiceInterface.setNightShare(contact.id, on);
    nightBusy.remove(contact.id);
    if (!Get.find<TripShareController>().applyContacts(response)) {
      showCustomSnackBar(MoveController.firstError(response));
    } else if (on) {
      showCustomSnackBar('night_share_on'.trParams({'name': contact.name}), isError: false);
    }
    update();
  }

  void _setInfo(Response response) {
    if (response.statusCode == 200 && response.body['data'] is Map<String, dynamic>) {
      info = TripCheckinInfo.fromJson(response.body['data']);
    }
  }
}
