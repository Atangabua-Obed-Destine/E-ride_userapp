import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/hotel/domain/repositories/hotel_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class HotelRepository implements HotelRepositoryInterface {
  final ApiClient apiClient;
  HotelRepository({required this.apiClient});

  static const String _h = AppConstants.hotel;

  @override
  Future getHotel(String id, String checkIn, String checkOut) => apiClient.getData('$_h/hotels/$id', query: {'check_in': checkIn, 'check_out': checkOut});

  @override
  Future ask(String hotelId, Map<String, dynamic> body) => apiClient.postData('$_h/hotels/$hotelId/ask', body);

  @override
  Future getInquiries() => apiClient.getData('$_h/inquiries');

  @override
  Future getInquiry(String id, {int? after}) => apiClient.getData('$_h/inquiries/$id', query: after == null ? null : {'after': '$after'});

  @override
  Future send(String id, String body) => apiClient.postData('$_h/inquiries/$id/messages', {'body': body});

  @override
  Future release(String id) => apiClient.postData('$_h/inquiries/$id/release', {});
}
