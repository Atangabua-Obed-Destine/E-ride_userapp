import 'dart:async';

import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/helper/pusher_helper.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

/// A safety net for the live ride or parcel. Trip events come over the websocket
/// and as a push; on a weak network or a phone saving battery both can be late
/// or lost, and the customer would stay on "finding a driver" while the driver
/// is already at the pickup, or never get to rate a delivered parcel. Every few
/// seconds during a live trip (and right after the socket reconnects) this asks
/// the server where the trip stands and, if it moved on, runs the same handler
/// the event would have run. The event gate keeps each step to once, whichever
/// of the three gets there first.
class TripWatchdog {
  static Timer? _timer;
  static bool _busy = false;

  static const Duration _every = Duration(seconds: 12);
  static const List<RideState> _watchedStates = [
    RideState.findingRider, RideState.outForPickup, RideState.otpSent, RideState.ongoingRide,
  ];
  static const List<ParcelDeliveryState> _watchedParcelStates = [
    ParcelDeliveryState.findingRider, ParcelDeliveryState.acceptRider, ParcelDeliveryState.otpSent, ParcelDeliveryState.parcelOngoing,
  ];

  static void start() {
    _timer ??= Timer.periodic(_every, (_) => checkNow());
  }

  static Future<void> checkNow() async {
    if (_busy || !Get.isRegistered<RideController>()) return;
    final RideController ride = Get.find<RideController>();
    final trip = ride.tripDetails;
    final String? tripId = trip?.id;
    if (trip == null || tripId == null) return;
    final bool parcel = trip.type == AppConstants.parcel;
    // A food order's delivery: its own screen follows the order, and a rider
    // dropping it is replaced quietly (no "your driver cancelled").
    if (parcel && Get.isRegistered<StoreController>() && Get.find<StoreController>().order?.tripRequestId == tripId) return;
    final ParcelController? parcels = parcel && Get.isRegistered<ParcelController>() ? Get.find<ParcelController>() : null;
    if (parcel ? (parcels == null || !_watchedParcelStates.contains(parcels.currentParcelState)) : !_watchedStates.contains(ride.currentRideState)) return;

    _busy = true;
    try {
      final RideState screen = ride.currentRideState;
      final ParcelDeliveryState? parcelScreen = parcels?.currentParcelState;
      final Response response = await ride.getRideDetails(tripId, isUpdate: false);
      if (response.statusCode != 200) return;
      final fresh = ride.tripDetails;
      final String? now = fresh?.currentStatus;
      // Only when the server is past what the screen shows (not merely changed:
      // another refresh may already have stored the new status without moving on).
      if (fresh?.id != tripId || now == null) return;
      if (parcel) {
        if (parcels!.currentParcelState != parcelScreen || _matchesParcel(parcelScreen!, now)) return;
      } else if (ride.currentRideState != screen || _matches(screen, now)) {
        return;
      }

      final Map<String, dynamic> data = {'id': tripId, 'type': fresh?.type ?? 'ride_request'};
      switch (now) {
        case 'accepted':
        case 'out_for_pickup':
          PusherHelper.replay(tripId, 'accepted', data);
        case 'ongoing':
          PusherHelper.replay(tripId, 'started', data);
        case 'completed':
          PusherHelper.replay(tripId, 'completed', data);
        case 'cancelled':
          PusherHelper.replay(tripId, 'cancelled', {...data, if (fresh?.driver == null) 'reason': 'no_driver'});
      }
    } on Object catch (_) {
      // A missed check is fine: the next one comes in a few seconds.
    } finally {
      _busy = false;
    }
  }

  /// Whether the server's status is the one this screen is for.
  static bool _matches(RideState screen, String status) => switch (screen) {
        RideState.findingRider => status == 'pending',
        RideState.outForPickup || RideState.otpSent => status == 'accepted' || status == 'out_for_pickup',
        RideState.ongoingRide => status == 'ongoing',
        _ => true,
      };

  /// The same for a parcel. Returning and returned are the return flow's own
  /// screens: nothing to catch up on here.
  static bool _matchesParcel(ParcelDeliveryState screen, String status) => switch (screen) {
        ParcelDeliveryState.findingRider => status == 'pending',
        ParcelDeliveryState.acceptRider || ParcelDeliveryState.otpSent => status == 'accepted' || status == 'out_for_pickup',
        ParcelDeliveryState.parcelOngoing => status == 'ongoing' || status == 'returning' || status == 'returned',
        _ => true,
      };
}
