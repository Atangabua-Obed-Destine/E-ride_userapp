import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/listing/controllers/listing_controller.dart';
import 'package:ride_sharing_user_app/features/listing/screens/listing_detail_screen.dart';
import 'package:ride_sharing_user_app/features/listing/screens/my_listings_screen.dart';
import 'package:ride_sharing_user_app/features/listing/screens/my_visits_screen.dart';
import 'package:flutter/widgets.dart';

/// Homes & spaces pushes (action "listing_..."): what to refresh when one
/// arrives, and which screen a tap opens.
class ListingPush {
  static bool isListingPush(Map<String, dynamic> data) => '${data['action']}'.startsWith('listing_');

  /// For the owner of the place.
  static const Set<String> _ownerActions = {
    'listing_live', 'listing_changes', 'listing_refused', 'listing_removed', 'listing_confirm', 'listing_paused', 'listing_check',
    'listing_stale', 'listing_verified', 'listing_fix', 'listing_visit_scheduled', 'listing_verified_expired', 'listing_strike',
    'listing_banned',
  };
  /// Visit requests and answers the owner must act on: the requests tab.
  static const Set<String> _ownerRequestActions = {
    'listing_visit_requested', 'listing_visit_cancelled', 'listing_taking',
    // Reservation money, for the owner.
    'listing_reservation_new', 'listing_reservation_closed', 'listing_payout_paid',
  };
  /// Pushes sent to either side: the role decides the screen.
  static const Set<String> _eitherSide = {'listing_reservation_problem', 'listing_reservation_released'};

  /// The app is open: bring the lists up to date.
  static void onForeground(Map<String, dynamic> data) {
    if (!Get.isRegistered<ListingController>()) return;
    final ListingController c = Get.find<ListingController>();
    c.loadVisits();
    if (c.mineLoaded) c.loadMine();
    final String? id = data['listing_id']?.toString();
    if (id != null && id.isNotEmpty && c.listing(id) != null) c.loadListing(id);
  }

  /// The screen a tap on the push opens.
  static Widget screenFor(Map<String, dynamic> data) {
    final String action = '${data['action']}';
    final String? id = data['listing_id']?.toString();
    if (_ownerActions.contains(action)) return const MyListingsScreen();
    if (_ownerRequestActions.contains(action)) return const MyListingsScreen(initialTab: 1);
    if (action == 'listing_alert' && id != null && id.isNotEmpty) return ListingDetailScreen(listingId: id);
    if (_eitherSide.contains(action) && id != null && Get.isRegistered<ListingController>()
        && Get.find<ListingController>().visitsToMyPlaces.any((v) => v.listing?.id == id)) {
      return const MyListingsScreen(initialTab: 1);
    }
    return const MyVisitsScreen();
  }
}
