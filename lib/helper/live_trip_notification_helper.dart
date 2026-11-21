import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/remaining_distance_model.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/trip_details_model.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

/// Bridges live ride/parcel progress to a native custom-designed
/// system notification (Android RemoteViews notification / iOS Live Activity).
class LiveTripNotificationHelper {
  static const MethodChannel _channel = MethodChannel('com.i_nnova.eride/live_trip_notification');

  /// Fixed id so each iOS update REPLACES the previous notification instead of stacking.
  static bool _permissionRequested = false;

  /// On Android 13+ a notification is a silent no-op unless POST_NOTIFICATIONS
  /// is granted. Request it once (no-op if already granted / not applicable).
  static Future<void> _ensureNotificationPermission() async {
    if(_permissionRequested) {
      return;
    }
    _permissionRequested = true;
    try {
      if(!await Permission.notification.isGranted) {
        await Permission.notification.request();
      }
    } catch (e) {
      customPrint('LiveTripNotificationHelper permission request failed: $e');
    }
  }

  static Future<void> showOrUpdate({required TripDetails trip, required RemainingDistanceModel distance}) async {
    final bool isParcel = trip.type == AppConstants.parcel;
    final bool isPickupPhase = isParcel ? trip.currentStatus == AppConstants.accepted : trip.currentStatus == AppConstants.outForPickup;
    final bool isOngoingPhase = trip.currentStatus == AppConstants.ongoing;

    if(!isPickupPhase && !isOngoingPhase) {
      return;
    }

    await _ensureNotificationPermission();

    final int etaMinutes = distance.durationSec != null ? (distance.durationSec! / 60).ceil().clamp(1, 999) : 0;

    final double estimatedDistance = trip.estimatedDistance ?? 0;
    double progress = 0;
    if(estimatedDistance > 0 && distance.distance != null) {
      progress = 1 - (distance.distance! / estimatedDistance);
    }
    progress = progress.clamp(0, 1);

    final String title = isPickupPhase
        ? '$etaMinutes ${'min_away_from_pickup_point'.tr}'
        : (isParcel ? '$etaMinutes ${'min_away_from_delivery_point'.tr}' : '$etaMinutes ${'min_away_from_destination'.tr}');

    final String subtitle = isPickupPhase ? 'driver_arriving_soon'.tr : 'heading_to_destination'.tr;

    String avatarUrl = '';
    if(trip.driver?.profileImage != null && trip.driver!.profileImage!.isNotEmpty) {
      avatarUrl = '${Get.find<ConfigController>().config?.imageBaseUrl?.profileImageDriver}/${trip.driver!.profileImage}';
    }

    String vehicleImageUrl = '';
    if(trip.vehicle?.model?.image != null && trip.vehicle!.model!.image!.isNotEmpty) {
      vehicleImageUrl = '${Get.find<ConfigController>().config?.imageBaseUrl?.vehicleCategory}/${trip.vehicleCategory!.image}';
    }

    final String driverName = '${trip.driver?.firstName ?? ''} ${trip.driver?.lastName ?? ''}'.trim();
    final String vehicleModel = trip.vehicle?.model?.name ?? '';
    final String plateNumber = trip.vehicle?.licencePlateNumber ?? '';

    try {
      await _channel.invokeMethod('showOrUpdate', {
        'tripId': trip.id ?? '',
        'title': title,
        'subtitle': subtitle,
        'etaText': '$etaMinutes',
        'progress': progress,
        'driverName': driverName,
        'vehicleModel': vehicleModel,
        'plateNumber': plateNumber,
        'vehicleType': trip.vehicleCategory?.type ?? '',
        'avatarUrl': avatarUrl,
        'vehicleImageUrl': vehicleImageUrl,
      });
    } catch (e) {
      customPrint('LiveTripNotificationHelper.showOrUpdate failed: $e');
    }


  }

  static Future<void> dispose() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      customPrint('LiveTripNotificationHelper.dispose failed: $e');
    }
  }
}
