import 'package:ride_sharing_user_app/features/trip_share/domain/repositories/trip_share_repository_interface.dart';
import 'package:ride_sharing_user_app/features/trip_share/domain/services/trip_share_service_interface.dart';

class TripShareService implements TripShareServiceInterface {
  final TripShareRepositoryInterface tripShareRepositoryInterface;
  TripShareService({required this.tripShareRepositoryInterface});

  @override
  Future getShareLink(String tripId) async {
    return await tripShareRepositoryInterface.getShareLink(tripId);
  }

  @override
  Future stopSharing(String tripId) async {
    return await tripShareRepositoryInterface.stopSharing(tripId);
  }

  @override
  Future getContacts() async {
    return await tripShareRepositoryInterface.getContacts();
  }

  @override
  Future addContact(String name, String phone) async {
    return await tripShareRepositoryInterface.addContact(name, phone);
  }

  @override
  Future updateContact(String id, String name, String phone) async {
    return await tripShareRepositoryInterface.updateContact(id, name, phone);
  }

  @override
  Future deleteContact(String id) async {
    return await tripShareRepositoryInterface.deleteContact(id);
  }
}
