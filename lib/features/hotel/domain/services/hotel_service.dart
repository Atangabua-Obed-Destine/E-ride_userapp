import 'package:ride_sharing_user_app/features/hotel/domain/repositories/hotel_repository_interface.dart';
import 'package:ride_sharing_user_app/features/hotel/domain/services/hotel_service_interface.dart';

class HotelService implements HotelServiceInterface {
  final HotelRepositoryInterface hotelRepositoryInterface;
  HotelService({required this.hotelRepositoryInterface});

  @override
  Future getHotel(String id, String checkIn, String checkOut) => hotelRepositoryInterface.getHotel(id, checkIn, checkOut);

  @override
  Future ask(String hotelId, Map<String, dynamic> body) => hotelRepositoryInterface.ask(hotelId, body);

  @override
  Future getInquiries() => hotelRepositoryInterface.getInquiries();

  @override
  Future getInquiry(String id, {int? after}) => hotelRepositoryInterface.getInquiry(id, after: after);

  @override
  Future send(String id, String body) => hotelRepositoryInterface.send(id, body);

  @override
  Future release(String id) => hotelRepositoryInterface.release(id);
}
