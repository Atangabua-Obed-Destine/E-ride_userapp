import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/move/domain/repositories/move_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class MoveRepository implements MoveRepositoryInterface {
  final ApiClient apiClient;
  MoveRepository({required this.apiClient});

  @override
  Future uploadPhotos(List<MultipartBody> photos) async {
    return await apiClient.postMultipartData(AppConstants.movePhotos, {}, MultipartBody('', null), photos);
  }

  @override
  Future getDirectory(String? vehicleCategoryId) async {
    return await apiClient.getData(AppConstants.moveDirectory, query: {
      if (vehicleCategoryId != null && vehicleCategoryId.isNotEmpty) 'vehicle_category_id': vehicleCategoryId,
    });
  }

  @override
  Future logContact(String listingId, String channel) async {
    return await apiClient.postData('${AppConstants.moveDirectoryContact}$listingId/contact', {'channel': channel});
  }

  @override
  Future noAgreement(String tripId) async {
    return await apiClient.putData('${AppConstants.moveBase}$tripId/no-agreement', {});
  }
}
