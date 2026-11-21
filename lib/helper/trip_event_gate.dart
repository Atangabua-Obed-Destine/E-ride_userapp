/// A trip event reaches the app twice: over the websocket and as a push. Both are
/// kept, because either can be late or lost on a mobile network, but only the first
/// to arrive acts. Handling both opened a second trip screen or a second dialog.
class TripEventGate {
  static const String accepted = 'accepted';
  static const String started = 'started';
  static const String cancelled = 'cancelled';
  static const String depositExpired = 'deposit_expired';
  static const String completed = 'completed';
  static const String paid = 'paid';

  static const Duration _window = Duration(seconds: 60);
  static final Map<String, DateTime> _seen = {};

  /// True the first time this event is seen for this trip.
  static bool firstTime(String? tripId, String event) {
    if (tripId == null) return true;
    final DateTime now = DateTime.now();
    _seen.removeWhere((_, at) => now.difference(at) > _window);
    final String key = '$tripId/$event';
    if (_seen.containsKey(key)) return false;
    _seen[key] = now;
    return true;
  }

  /// Lets the next copy of this event act again (it was seen, but nothing was done).
  static void forget(String? tripId, String event) => _seen.remove('$tripId/$event');

  /// False when the websocket already delivered the event in this push.
  static bool shouldHandlePush(Map<String, dynamic> data) {
    final String? event = _eventOfPush(data['action']?.toString());
    return event == null || firstTime(data['ride_request_id']?.toString(), event);
  }

  static String? _eventOfPush(String? action) {
    switch (action) {
      case 'driver_on_the_way':
        return accepted;
      case 'trip_started':
        return started;
      case 'trip_canceled':
        return cancelled;
      case 'deposit_expired':
        return depositExpired;
      case 'trip_completed':
      case 'parcel_completed':
        return completed;
      case 'payment_successful':
        return paid;
      default:
        return null;
    }
  }
}
