import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/trip_share/domain/repositories/trip_share_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class TripShareRepository implements TripShareRepositoryInterface {
  final ApiClient apiClient;
  TripShareRepository({required this.apiClient});

  @override
  Future getShareLink(String tripId) async {
    return await apiClient.postData('${AppConstants.tripShare}$tripId/share', {});
  }

  @override
  Future stopSharing(String tripId) async {
    return await apiClient.deleteData('${AppConstants.tripShare}$tripId/share');
  }

  @override
  Future getContacts() async {
    return await apiClient.getData(AppConstants.trustedContacts);
  }

  @override
  Future addContact(String name, String phone) async {
    return await apiClient.postData(AppConstants.trustedContacts, {'name': name, 'phone': phone});
  }

  @override
  Future updateContact(String id, String name, String phone) async {
    return await apiClient.putData('${AppConstants.trustedContacts}/$id', {'name': name, 'phone': phone});
  }

  @override
  Future deleteContact(String id) async {
    return await apiClient.deleteData('${AppConstants.trustedContacts}/$id');
  }
}
