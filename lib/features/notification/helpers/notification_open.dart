import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/bus/helpers/bus_push.dart';
import 'package:ride_sharing_user_app/features/hotel/helpers/hotel_push.dart';
import 'package:ride_sharing_user_app/features/jobs/helpers/job_push.dart';
import 'package:ride_sharing_user_app/features/listing/listing_push.dart';
import 'package:ride_sharing_user_app/features/market/helpers/market_push.dart';
import 'package:ride_sharing_user_app/features/notification/domain/models/notification_model.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/trip/screens/trip_details_screen.dart';
import 'package:ride_sharing_user_app/features/wallet/screens/wallet_screen.dart';
import 'package:ride_sharing_user_app/helper/notification_helper.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

/// "Open" in a notification's detail sheet: the same place its push opens
/// (the chat, the order, the job, the trip...). Nothing when it has no place.
class NotificationOpen {
  NotificationOpen._();

  static const Set<String> _wallet = {
    'fund_added_by_admin', 'fund_added_digitally', 'refunded_to_wallet', 'withdraw_request_approved', 'withdraw_request_rejected',
    'withdraw_request_reversed', 'withdraw_request_settled', 'danger_report_reward',
  };
  static const Set<String> _router = {
    'referral_reward_received', 'someone_used_your_code', 'refunded_as_coupon', 'privacy_policy_updated', 'legal_updated',
    'terms_and_conditions_updated',
  };
  // Pushes about a ride that is over by now or never was: the bid, the search.
  static const Set<String> _noTrip = {'received_new_bid', 'searching_for_rider', 'deposit_expired', 'level_up'};

  /// The push data the router reads, rebuilt from the stored notification.
  static Map<String, dynamic> dataOf(Notifications n) => {
        ...n.data,
        'action': n.action,
        'type': n.type,
        'notification_type': n.notificationType,
        'ride_request_id': n.rideRequestId,
        'body': n.description,
        'user_name': '${n.data['user_name'] ?? n.data['sender_name'] ?? ''}',
      };

  static String? _s(dynamic v) => v == null || '$v'.isEmpty || '$v' == 'null' ? null : '$v';

  /// The button's label key, or null when the notification leads nowhere.
  static String? label(Notifications n) {
    final Map<String, dynamic> data = dataOf(n);
    final String action = n.action ?? '';
    if (action == 'market_message') return 'notification_open_chat';
    if (BusPush.isBusPush(data)) return 'notification_open_trip';
    if (HotelPush.isHotelPush(data)) return 'notification_open_chat';
    if (action.startsWith('id_')) return 'notification_open';
    if (JobPush.isJobPush(data) || MarketPush.isMarketPush(data) || ListingPush.isListingPush(data)) return 'notification_open';
    if (action.startsWith('store_order_')) return _s(data['order_id']) != null ? 'notification_open_order' : null;
    if (action == 'new_message') return _s(n.type) != null && _s(n.rideRequestId) != null ? 'notification_open_chat' : null;
    if (action == 'trip_checkin_contact' || action == 'night_ride_shared') {
      return RegExp(r'https?://\S+').hasMatch(n.description ?? '') ? 'notification_open_link' : null;
    }
    if (_wallet.contains(action) || n.notificationType == 'fund' || n.notificationType == 'withdraw_request') return 'notification_open_wallet';
    if (_router.contains(action)) return 'notification_open';
    if (_noTrip.contains(action)) return null;
    if (_s(n.rideRequestId) != null) return 'notification_open_trip';
    return null;
  }

  static Future<void> open(Notifications n) async {
    final Map<String, dynamic> data = dataOf(n);
    final String action = n.action ?? '';
    if (_wallet.contains(action) || n.notificationType == 'fund' || n.notificationType == 'withdraw_request') {
      Get.to(() => const WalletScreen());
      return;
    }
    final String? trip = _s(n.rideRequestId);
    final bool routed = action == 'market_message' || BusPush.isBusPush(data) || HotelPush.isHotelPush(data) || action.startsWith('id_') || JobPush.isJobPush(data) || MarketPush.isMarketPush(data)
        || ListingPush.isListingPush(data) || action.startsWith('store_order_') || action == 'new_message'
        || action == 'trip_checkin_contact' || action == 'night_ride_shared' || action == 'lost_item' || _router.contains(action);
    if (routed || trip == null) {
      NotificationHelper.notificationRouteCheck(data);
      return;
    }
    await _openTrip(trip);
  }

  /// A ride or parcel still going opens on the map (or payment when unpaid); any other, its details.
  static Future<void> _openTrip(String tripId) async {
    final RideController ride = Get.find<RideController>();
    await ride.getRideDetails(tripId);
    final trip = ride.tripDetails;
    if (trip != null && trip.id == tripId) {
      final String? status = trip.currentStatus;
      final bool live = status == AppConstants.outForPickup || status == AppConstants.ongoing
          || (trip.type == AppConstants.parcel && status == AppConstants.accepted);
      final bool unpaid = status == AppConstants.completed && trip.paymentStatus == AppConstants.unPaid;
      if (live || unpaid) {
        NotificationHelper.notificationToRouteNavigate(tripId, false);
        return;
      }
    }
    Get.to(() => TripDetailsScreen(tripId: tripId));
  }
}
