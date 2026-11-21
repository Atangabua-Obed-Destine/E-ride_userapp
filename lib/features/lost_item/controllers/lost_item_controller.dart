import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/lost_item/domain/models/lost_item_model.dart';
import 'package:ride_sharing_user_app/features/lost_item/domain/services/lost_item_service_interface.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/trip_details_model.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/file_validation_helper.dart';

/// Lost and found, the rider's side: report something left in the car after a
/// ride, then follow it until it is back. One case per ride.
class LostItemController extends GetxController implements GetxService {
  final LostItemServiceInterface lostItemServiceInterface;
  LostItemController({required this.lostItemServiceInterface});

  /// Trip id -> its case (null: none yet). A trip missing from the map was not loaded.
  final Map<String, LostItem?> byTrip = {};
  final Set<String> _loading = {};
  bool submitting = false;
  String? acting; // the action being sent
  XFile? photo;

  bool get enabled => Get.find<ConfigController>().config?.lostItemsStatus ?? false;

  /// A completed ride with a driver, recent enough to report (the server checks exactly).
  bool canReport(TripDetails trip) {
    if (!enabled || (trip.type != 'ride_request' && trip.type != 'scheduled_request') || trip.currentStatus != 'completed' || trip.driver == null) return false;
    final DateTime? created = DateTime.tryParse(trip.createdAt ?? '');
    final int days = Get.find<ConfigController>().config?.lostItemsReportDays ?? 7;
    return created == null || DateTime.now().difference(created).inDays <= days;
  }

  Future<void> loadForTrip(String tripId, {bool force = false}) async {
    if (!enabled || _loading.contains(tripId) || (!force && byTrip.containsKey(tripId))) return;
    _loading.add(tripId);
    final Response response = await lostItemServiceInterface.getForTrip(tripId);
    _loading.remove(tripId);
    if (response.statusCode == 200 && response.body['data'] is List) {
      final List list = response.body['data'];
      byTrip[tripId] = list.isNotEmpty && list.first is Map ? LostItem.fromJson(Map<String, dynamic>.from(list.first)) : null;
      update();
    }
  }

  Future<void> pickPhoto(ImageSource source) async {
    final XFile? picked = await FileValidationHelper.validateAndPickImage(source: source, imageQuality: 70);
    if (picked != null) {
      photo = picked;
      update();
    }
  }

  void clearPhoto() {
    photo = null;
    update();
  }

  Future<bool> report(String tripId, String description) async {
    if (submitting) return false;
    if (description.trim().length < 3) {
      showCustomSnackBar('lost_item_describe_it'.tr);
      return false;
    }
    submitting = true;
    update();
    final Response response = await lostItemServiceInterface.report(tripId, description.trim(), photo);
    submitting = false;
    if (response.statusCode == 200 && response.body['data'] is Map) {
      byTrip[tripId] = LostItem.fromJson(Map<String, dynamic>.from(response.body['data']));
      photo = null;
      update();
      showCustomSnackBar('lost_item_sent'.tr, isError: false);
      return true;
    }
    update();
    ApiChecker.checkApi(response);
    return false;
  }

  Future<void> act(LostItem item, String action) async {
    if (acting != null) return;
    acting = action;
    update();
    final Response response = await lostItemServiceInterface.act(item.id, action);
    acting = null;
    if (response.statusCode == 200 && response.body['data'] is Map) {
      byTrip[item.tripRequestId] = LostItem.fromJson(Map<String, dynamic>.from(response.body['data']));
    } else {
      ApiChecker.checkApi(response);
      await loadForTrip(item.tripRequestId, force: true);
    }
    update();
  }

  /// A push about this trip's case: refresh it if the rider has it on screen.
  void onPush(String? tripId) {
    if (tripId != null && byTrip.containsKey(tripId)) loadForTrip(tripId, force: true);
  }
}
