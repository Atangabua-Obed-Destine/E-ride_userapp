import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/bus/controllers/bus_controller.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_booking_screen.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_seats_screen.dart';
import 'package:ride_sharing_user_app/features/bus/screens/bus_trips_screen.dart';

/// E-Ride Bus Travel pushes (action bus_*): what they refresh, and where a tap goes.
class BusPush {
  BusPush._();

  static bool isBusPush(Map<String, dynamic> data) => '${data['action']}'.startsWith('bus_') || '${data['type']}' == 'bus';

  static String? _s(dynamic v) => v == null || '$v'.isEmpty || '$v' == 'null' ? null : '$v';

  /// The app is open: bring the booking on screen (and the trip list) up to date. The notification still shows.
  static void onForeground(Map<String, dynamic> data) {
    if (!Get.isRegistered<BusController>()) return;
    final c = Get.find<BusController>();
    final id = _s(data['bus_booking_id']);
    if (id != null && c.booking(id) != null) c.loadBooking(id, quiet: true);
    if (c.listLoaded('upcoming')) c.loadList('upcoming');
    final dep = _s(data['bus_departure_id']);
    if (dep != null && c.departure(dep) != null) c.loadDeparture(dep, quiet: true);
  }

  /// The screen a tap on the push opens.
  static Widget screenFor(Map<String, dynamic> data) {
    final booking = _s(data['bus_booking_id']);
    final departure = _s(data['bus_departure_id']);
    if (booking != null) return BusBookingScreen(bookingId: booking);
    if (departure != null) return BusSeatsScreen(departureId: departure);
    return const BusTripsScreen();
  }
}
