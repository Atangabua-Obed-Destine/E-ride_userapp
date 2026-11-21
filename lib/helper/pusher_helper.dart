import 'dart:convert';
import 'package:ride_sharing_user_app/features/deposit/widgets/deposit_widgets.dart';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/move/widgets/move_widgets.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ride_sharing_user_app/features/map/controllers/map_controller.dart';
import 'package:ride_sharing_user_app/features/map/screens/map_screen.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/payment/screens/payment_screen.dart';
import 'package:ride_sharing_user_app/features/payment/screens/review_screen.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/ride/widgets/confirmation_trip_dialog.dart';
import 'package:ride_sharing_user_app/features/safety_setup/controllers/safety_alert_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/trip_event_gate.dart';
import 'package:ride_sharing_user_app/helper/trip_watchdog.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class PusherHelper {
  static PusherChannelsClient?  pusherClient;

  /// Channels of the trips being followed, oldest first. The library does not restore
  /// subscriptions after a reconnect, so they are subscribed again from here.
  static final Map<String, List<PrivateChannel>> _tripChannels = {};
  static const int _maxFollowedTrips = 5;
  static final Map<String, Map<String, Function(String)>> _replays = {};

  /// Runs a followed trip's handler as if its event had arrived ([event]: accepted,
  /// started, cancelled, completed, paid). Does nothing for a trip not followed.
  static void replay(String tripId, String event, Map<String, dynamic> data) {
    _replays[tripId]?[event]?.call(jsonEncode(data));
  }

  static void initializePusher() async{
    // Checks the live ride now and then, in case an event never arrives.
    TripWatchdog.start();
    // No configuration (it failed to load): no socket address to connect to.
    if (Get.find<ConfigController>().config == null) return;

    // Already connected (a new login): keep the socket, drop the previous session's trips.
    if (pusherClient != null) {
      for (final List<PrivateChannel> channels in _tripChannels.values) {
        for (final PrivateChannel channel in channels) {
          channel.unsubscribe();
        }
      }
      _tripChannels.clear();
      _replays.clear();
      return;
    }

    PusherChannelsOptions testOptions = PusherChannelsOptions.fromHost(
      host: Get.find<ConfigController>().config!.webSocketUrl ?? '',
      scheme: Get.find<ConfigController>().config!.websocketScheme == 'https' ? 'wss' : 'ws',
      key: Get.find<ConfigController>().config!.webSocketKey ?? '',
      port: int.parse(Get.find<ConfigController>().config?.webSocketPort ?? '6001'),
    );

    final PusherChannelsClient client = PusherChannelsClient.websocket(
      options: testOptions,
      connectionErrorHandler: (exception, trace, refresh) async {
        Get.find<ConfigController>().setPusherStatus('Disconnected');
        refresh();
      },
    );
    pusherClient = client;

    client.lifecycleStream.listen((state) {
      Get.find<ConfigController>().setPusherStatus(
        state == PusherChannelsClientLifeCycleState.establishedConnection ? 'Connected' : 'Disconnected',
      );
    });
    client.onConnectionEstablished.listen((_) {
      customPrint('pusher: connected, subscribing ${_tripChannels.length} trip(s)');
      for (final List<PrivateChannel> channels in _tripChannels.values) {
        for (final PrivateChannel channel in channels) {
          channel.subscribeIfNotUnsubscribed();
        }
      }
      // Events sent while the socket was down are lost: check the live trip now.
      TripWatchdog.checkNow();
    });

    await client.connect();
  }

  PrivateChannel _tripChannel(String name) {
    final ConfigController config = Get.find<ConfigController>();
    return pusherClient!.privateChannel(name, authorizationDelegate:
    EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
      authorizationEndpoint: Uri.parse('${config.config!.websocketScheme == 'https' ? 'https' : 'http'}://${config.config!.webSocketUrl}/broadcasting/auth'),
      headers:  {
        "Accept": "application/json",
        "Authorization": "Bearer ${Get.find<AuthController>().getUserToken()}",
      },
    ));
  }

  /// Follows a trip's events. Safe to call again for the same trip.
  void pusherDriverStatus(String tripId){
    final PusherChannelsClient? client = pusherClient;
    if (client == null || _tripChannels.containsKey(tripId)) return;

    if (_tripChannels.length >= _maxFollowedTrips) {
      final String oldest = _tripChannels.keys.first;
      _replays.remove(oldest);
      for (final PrivateChannel channel in _tripChannels.remove(oldest)!) {
        channel.unsubscribe();
      }
    }

    final PrivateChannel pusherDriverAccepted = _tripChannel("private-driver-trip-accepted.$tripId");
    final PrivateChannel driverTripStarted = _tripChannel("private-driver-trip-started.$tripId");
    final PrivateChannel driverTripCancelled = _tripChannel("private-driver-trip-cancelled.$tripId");
    // The booking deposit was not paid in time: the trip is cancelled.
    final PrivateChannel tripDepositExpired = _tripChannel("private-trip-deposit-expired.$tripId");
    final PrivateChannel driverTripCompleted = _tripChannel("private-driver-trip-completed.$tripId");
    final PrivateChannel driverPaymentReceived = _tripChannel("private-driver-payment-received.$tripId");

    final List<PrivateChannel> channels = [
      pusherDriverAccepted, driverTripStarted, driverTripCancelled,
      tripDepositExpired, driverTripCompleted, driverPaymentReceived,
    ];
    _tripChannels[tripId] = channels;

    void onAccepted(String raw) {
      if (!TripEventGate.firstTime(tripId, TripEventGate.accepted)) return;
      Get.find<RideController>().getRideDetails(jsonDecode(raw)['id']).then((value){
        if(value.statusCode == 200){
          // A ride booked ahead and only accepted so far: the driver sets off near the
          // pickup time, so stay where the rider is. Once the driver is on the way
          // (out_for_pickup, sent on this channel too), the live map opens.
          final trip = Get.find<RideController>().tripDetails;
          final pickupAt = DateTime.tryParse(trip?.scheduledAt ?? '');
          if (trip?.type == AppConstants.scheduleRequest && trip?.currentStatus != AppConstants.outForPickup
              && pickupAt != null && pickupAt.difference(DateTime.now()).inMinutes > 30) {
            // Nothing moved: "on the way" a moment later must still act.
            TripEventGate.forget(tripId, TripEventGate.accepted);
            Get.find<RideController>().update();
            return;
          }
          if(jsonDecode(raw)['type'] == AppConstants.parcel){
            Get.find<ParcelController>().updateParcelState(ParcelDeliveryState.acceptRider);
            Get.find<RideController>().startLocationRecord();
            Get.find<MapController>().notifyMapController();
            Get.offAll(() => const MapScreen(fromScreen: MapScreenType.parcel));
          }else{
            Get.find<RideController>().updateRideCurrentState(RideState.outForPickup);
            Get.find<RideController>().startLocationRecord();
            Get.find<MapController>().notifyMapController();
            Get.offAll(() => const MapScreen(fromScreen: MapScreenType.splash));
          }
        }
      });
    }
    pusherDriverAccepted.bind("driver-trip-accepted.$tripId").listen((event) => onAccepted(event.data ?? '{}'));

    void onStarted(String raw) {
      if (!TripEventGate.firstTime(tripId, TripEventGate.started)) return;
      Get.find<RideController>().startLocationRecord();
      if(jsonDecode(raw)['type']== AppConstants.parcel){
        Get.find<MapController>().getPolyline();
        Get.find<ParcelController>().updateParcelState(ParcelDeliveryState.parcelOngoing);

        if(Get.find<RideController>().tripDetails == null ){
          Get.find<RideController>().getRideDetails(jsonDecode(raw)['id']).then((value) {
            if (Get.find<RideController>().tripDetails!.parcelInformation!.payer == 'sender' && Get.find<RideController>().tripDetails!.paymentStatus != AppConstants.paid) {
              Get.find<RideController>().getFinalFare(jsonDecode(raw)['id']).then((value) {
                if (value.statusCode == 200) {
                  Get.find<MapController>().notifyMapController();
                  Get.off(() => const PaymentScreen(fromParcel: true,));
                }
              });
            }
          });
        }else{
          if (Get.find<RideController>().tripDetails!.parcelInformation!.payer == 'sender' && Get.find<RideController>().tripDetails!.paymentStatus != AppConstants.paid) {
            Get.find<RideController>().getFinalFare(jsonDecode(raw)['id']).then((value) {
              if (value.statusCode == 200) {
                Get.find<MapController>().notifyMapController();
                Get.off(() => const PaymentScreen(fromParcel: true,));
              }
            });
          }
        }

      }else{
        Get.find<RideController>().getRideDetails(jsonDecode(raw)['id']);
        Get.find<RideController>().updateRideCurrentState(RideState.ongoingRide);
        Get.find<SafetyAlertController>().checkDriverNeedSafety();
        MapScreen.open(const MapScreen(fromScreen: MapScreenType.splash));
      }
    }
    driverTripStarted.bind("driver-trip-started.$tripId").listen((event) => onStarted(event.data ?? '{}'));

    Future<void> onCancelled(String raw) async {
      if (!TripEventGate.firstTime(tripId, TripEventGate.cancelled)) return;
      final Map<String, dynamic> data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final RideController ride = Get.find<RideController>();
      final bool scheduled = ride.tripDetails?.type == AppConstants.scheduleRequest;
      final String? newTripId = data['new_trip_id']?.toString();
      ride.stopLocationRecord();
      Get.find<SafetyAlertController>().cancelDriverNeedSafetyStream();
      // The driver cancelled and E-Ride is already finding another one: follow the
      // new trip on the finding screen (the push saying so can be late or lost).
      if (newTripId != null && newTripId.isNotEmpty && !scheduled) {
        Get.find<AuthController>().saveFindingRideCreatedTime();
        ride.updateRideCurrentState(RideState.findingRider);
        pusherDriverStatus(newTripId);
        await ride.getRideDetails(newTripId, isUpdate: false);
        Get.offAll(() => const MapScreen(fromScreen: MapScreenType.splash));
        showCustomSnackBar('driver_cancelled_finding_another'.tr, isError: false);
        return;
      }
      // Nobody accepted in time: there never was a driver to report.
      final bool noDriver = data['reason'] == 'no_driver' || (ride.tripDetails?.id == tripId && ride.tripDetails?.driver == null);
      Get.offAll(const DashboardScreen());
      if (noDriver) {
        showCustomSnackBar('no_driver_accepted'.tr);
      } else {
        showDriverCancelledSheet(tripId, scheduled: scheduled);
      }
    }
    driverTripCancelled.bind("driver-trip-cancelled.$tripId").listen((event) => onCancelled(event.data ?? '{}'));

    void onDepositExpired(String raw) {
      if (!TripEventGate.firstTime(tripId, TripEventGate.depositExpired)) return;
      Get.find<RideController>().stopLocationRecord();
      Get.offAll(const DashboardScreen());
      showDepositExpiredSheet(tripId);
    }
    tripDepositExpired.bind("trip-deposit-expired.$tripId").listen((event) => onDepositExpired(event.data ?? '{}'));

    void onCompleted(String raw) {
      if (!TripEventGate.firstTime(tripId, TripEventGate.completed)) return;
      if(jsonDecode(raw)['type']== AppConstants.parcel){
        Get.find<RideController>().clearRideDetails();
        if(Get.find<ConfigController>().config!.reviewStatus!) {
          Get.off(()=> ReviewScreen(tripId: jsonDecode(raw)['id']));
        }else{
          Get.offAll(const DashboardScreen());
        }
      }else if(Get.find<RideController>().tripDetails?.isMove ?? false){
        // A move is paid to the driver in person: no payment screen.
        finishCompletedMove(jsonDecode(raw)['id']);
      }else{
        Get.dialog(const ConfirmationTripDialog(isStartedTrip: false,), barrierDismissible: false);
        Get.find<RideController>().getFinalFare(jsonDecode(raw)['id']).then((value) {
          if(value.statusCode == 200 && (Get.find<RideController>().finalFare?.isMove ?? false)){
            if (Get.isDialogOpen ?? false) Get.back();
            finishCompletedMove(jsonDecode(raw)['id']);
          }else if(value.statusCode == 200){
            Get.find<RideController>().updateRideCurrentState(RideState.completeRide);
            Get.find<MapController>().notifyMapController();
            Get.find<RideController>().stopLocationRecord();
            Get.find<SafetyAlertController>().cancelDriverNeedSafetyStream();
            Get.off(()=>const PaymentScreen());
          }
        });
      }
    }
    driverTripCompleted.bind("driver-trip-completed.$tripId").listen((event) => onCompleted(event.data ?? '{}'));

    void onPaid(String raw) {
      if (!TripEventGate.firstTime(tripId, TripEventGate.paid)) return;
      if (jsonDecode(raw)['type']== 'ride_request') {
        if(Get.find<ConfigController>().config!.reviewStatus!){
          Get.off(()=> ReviewScreen(tripId: jsonDecode(raw)['id']));
          Get.find<RideController>().tripDetails = null;
        }else{
          Get.offAll(() => const DashboardScreen());
          Get.find<RideController>().tripDetails = null;
        }

      } else {
        Get.find<RideController>().getRideDetails(jsonDecode(raw)['id']).then((_){
          if(Get.find<RideController>().tripDetails?.parcelInformation?.payer == 'sender'){
            Get.find<ParcelController>().updateParcelState(ParcelDeliveryState.parcelOngoing);
            Get.find<RideController>().startLocationRecord();
            Get.offAll(() => const MapScreen(fromScreen: MapScreenType.parcel));
          }else{
            Get.offAll(() => const DashboardScreen());
            Get.find<RideController>().tripDetails = null;
          }
        });
      }
    }
    driverPaymentReceived.bind("driver-payment-received.$tripId").listen((event) => onPaid(event.data ?? '{}'));

    // The same handlers, for the status check that catches events missed while
    // the socket was down (TripWatchdog). The event gate keeps each one to once.
    _replays[tripId] = {
      'accepted': onAccepted,
      'started': onStarted,
      'cancelled': onCancelled,
      'depositExpired': onDepositExpired,
      'completed': onCompleted,
      'paid': onPaid,
    };

    // Not connected yet: onConnectionEstablished subscribes them.
    if (client.socketId != null) {
      for (final PrivateChannel channel in channels) {
        channel.subscribe();
      }
    }
  }

}
