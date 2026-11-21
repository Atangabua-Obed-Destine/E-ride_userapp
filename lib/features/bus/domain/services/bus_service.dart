import 'package:ride_sharing_user_app/features/bus/domain/repositories/bus_repository_interface.dart';
import 'package:ride_sharing_user_app/features/bus/domain/services/bus_service_interface.dart';

class BusService implements BusServiceInterface {
  final BusRepositoryInterface busRepositoryInterface;
  BusService({required this.busRepositoryInterface});

  @override
  Future getMeta() => busRepositoryInterface.getMeta();

  @override
  Future search(Map<String, dynamic> query) => busRepositoryInterface.search(query);

  @override
  Future getAgencies() => busRepositoryInterface.getAgencies();

  @override
  Future getAgency(String id) => busRepositoryInterface.getAgency(id);

  @override
  Future getDeparture(String id) => busRepositoryInterface.getDeparture(id);

  @override
  Future toggleWaitlist(String departureId) => busRepositoryInterface.toggleWaitlist(departureId);

  @override
  Future requestSeats(String departureId, Map<String, dynamic> body) => busRepositoryInterface.requestSeats(departureId, body);

  @override
  Future getBookings(String when, int offset) => busRepositoryInterface.getBookings(when, offset);

  @override
  Future getBooking(String id) => busRepositoryInterface.getBooking(id);

  @override
  Future pay(String id) => busRepositoryInterface.pay(id);

  @override
  Future cancel(String id) => busRepositoryInterface.cancel(id);

  @override
  Future keep(String id) => busRepositoryInterface.keep(id);
}
