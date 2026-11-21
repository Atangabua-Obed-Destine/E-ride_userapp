import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/bus/domain/repositories/bus_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class BusRepository implements BusRepositoryInterface {
  final ApiClient apiClient;
  BusRepository({required this.apiClient});

  static const String _b = AppConstants.bus;

  @override
  Future getMeta() => apiClient.getData('$_b/meta');

  @override
  Future search(Map<String, dynamic> query) => apiClient.getData('$_b/search', query: query);

  @override
  Future getAgencies() => apiClient.getData('$_b/agencies');

  @override
  Future getAgency(String id) => apiClient.getData('$_b/agencies/$id');

  @override
  Future getDeparture(String id) => apiClient.getData('$_b/departures/$id');

  @override
  Future toggleWaitlist(String departureId) => apiClient.postData('$_b/departures/$departureId/waitlist', {});

  @override
  Future requestSeats(String departureId, Map<String, dynamic> body) => apiClient.postData('$_b/departures/$departureId/request', body);

  @override
  Future getBookings(String when, int offset) => apiClient.getData('$_b/bookings', query: {'when': when, 'offset': '$offset', 'limit': '20'});

  @override
  Future getBooking(String id) => apiClient.getData('$_b/bookings/$id');

  @override
  Future pay(String id) => apiClient.postData('$_b/bookings/$id/pay', {});

  @override
  Future cancel(String id) => apiClient.postData('$_b/bookings/$id/cancel', {});

  @override
  Future keep(String id) => apiClient.postData('$_b/bookings/$id/keep', {});
}
