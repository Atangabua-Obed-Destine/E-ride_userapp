abstract class BusServiceInterface {
  Future<dynamic> getMeta();
  Future<dynamic> search(Map<String, dynamic> query);
  Future<dynamic> getAgencies();
  Future<dynamic> getAgency(String id);
  Future<dynamic> getDeparture(String id);
  Future<dynamic> toggleWaitlist(String departureId);
  Future<dynamic> requestSeats(String departureId, Map<String, dynamic> body);
  Future<dynamic> getBookings(String when, int offset);
  Future<dynamic> getBooking(String id);
  Future<dynamic> pay(String id);
  Future<dynamic> cancel(String id);
  Future<dynamic> keep(String id);
}
