import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/move/domain/repositories/move_repository_interface.dart';
import 'package:ride_sharing_user_app/features/move/domain/services/move_service_interface.dart';

class MoveService implements MoveServiceInterface {
  final MoveRepositoryInterface moveRepositoryInterface;
  MoveService({required this.moveRepositoryInterface});

  @override
  Future uploadPhotos(List<MultipartBody> photos) async {
    return await moveRepositoryInterface.uploadPhotos(photos);
  }

  @override
  Future getDirectory(String? vehicleCategoryId) async {
    return await moveRepositoryInterface.getDirectory(vehicleCategoryId);
  }

  @override
  Future logContact(String listingId, String channel) async {
    return await moveRepositoryInterface.logContact(listingId, channel);
  }

  @override
  Future noAgreement(String tripId) async {
    return await moveRepositoryInterface.noAgreement(tripId);
  }
}
