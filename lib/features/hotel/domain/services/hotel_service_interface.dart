abstract class HotelServiceInterface {
  Future<dynamic> getHotel(String id, String checkIn, String checkOut);
  Future<dynamic> ask(String hotelId, Map<String, dynamic> body);
  Future<dynamic> getInquiries();
  Future<dynamic> getInquiry(String id, {int? after});
  Future<dynamic> send(String id, String body);
  Future<dynamic> release(String id);
}
